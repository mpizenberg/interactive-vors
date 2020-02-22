use serde_wasm_bindgen;
use wasm_bindgen::prelude::*;

use image;
use nalgebra::{self, DMatrix, Quaternion, Translation, UnitQuaternion, Vector3, Vector4};
use std::{error::Error, io::Read};

use byteorder::{BigEndian, ReadBytesExt};
use png::HasParameters;
use std::collections::HashMap;
use std::io::Cursor;
use tar;

use visual_odometry_rs as vors;
use vors::core::camera::Intrinsics;
use vors::core::track::inverse_compositional_norm as track;
use vors::dataset::tum_rgbd;
use vors::misc::interop;
use vors::misc::type_aliases::{Iso3, Point2};

use png_decoder::png as png_me;

use p3p;

type Vec3 = Vector3<f32>;
type Vec4 = Vector4<f32>;

#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);
}

macro_rules! console_log {
    ($($t:tt)*) => (log(&format_args!($($t)*).to_string()))
}

#[wasm_bindgen]
pub struct WasmTracker {
    tar_buffer: Vec<u8>,
    entries: HashMap<String, FileEntry>,
    associations: Vec<tum_rgbd::Association>,
    tracker: Option<track::Tracker>,
    pub change_keyframe: bool,
    keyframes: Vec<DMatrix<u8>>,
    keyframes_candidates: Vec<Vec<(usize, usize)>>,
    current_keyframe_data: Vec<u8>,
    reference_keyframe_data: Vec<u8>,
    poses_history: Vec<Iso3>,
    p3p_poses: Vec<Iso3>,
}

/// Public methods, exported to JavaScript.
#[wasm_bindgen]
impl WasmTracker {
    pub fn new() -> WasmTracker {
        console_log!("Initialize WasmTracker");
        WasmTracker {
            tar_buffer: Vec::new(),
            entries: HashMap::new(),
            associations: Vec::new(),
            tracker: None,
            change_keyframe: false,
            keyframes: vec![],
            keyframes_candidates: vec![],
            current_keyframe_data: vec![0; 320 * 240 * 4],
            reference_keyframe_data: vec![0; 320 * 240 * 4],
            poses_history: vec![],
            p3p_poses: vec![],
        }
    }

    pub fn allocate(&mut self, length: usize) {
        self.tar_buffer = vec![0; length];
    }

    pub fn memory_pos(&self) -> *const u8 {
        self.tar_buffer.as_ptr()
    }

    pub fn reference_keyframe_data(&self) -> *const u8 {
        self.reference_keyframe_data.as_ptr()
    }

    pub fn current_keyframe_data(&self) -> *const u8 {
        self.current_keyframe_data.as_ptr()
    }

    pub fn build_entries_map(&mut self) {
        // Init archive from in memory tar buffer.
        let mut archive = tar::Archive::new(self.tar_buffer.as_slice());

        for file in archive.entries().expect("48") {
            // Check for an I/O error.
            let file = file.expect("50");
            self.entries.insert(
                file.path().unwrap().to_str().expect("52").to_owned(),
                FileEntry {
                    offset: file.raw_file_position() as usize,
                    length: file.header().entry_size().expect("55") as usize,
                },
            );
        }
    }

    pub fn init(&mut self, camera_id: &str) -> usize {
        let intrinsics = create_camera(camera_id).expect("62");
        let associations_buffer = get_buffer("associations.txt", &self.tar_buffer, &self.entries);
        self.associations = parse_associations_buf(associations_buffer).expect("64");

        // Setup tracking configuration.
        let config = track::Config {
            nb_levels: 6,
            candidates_diff_threshold: 7,
            depth_scale: tum_rgbd::DEPTH_SCALE,
            intrinsics: intrinsics,
            idepth_variance: 0.0001,
        };

        // Initialize tracker with first depth and color image.
        let (depth_map, img) =
            _read_image_pair_bis(&self.associations[0], &self.tar_buffer, &self.entries)
                .expect("81");
        let depth_time = self.associations[0].depth_timestamp;
        let img_time = self.associations[0].color_timestamp;
        let tracker = config.init(depth_time, &depth_map, img_time, img);
        let keyframe_img = tracker.keyframe_img();
        let keyframe_img = keyframe_img.transpose();
        update_kf_data(&mut self.current_keyframe_data, &keyframe_img);
        self.keyframes.push(keyframe_img);
        self.keyframes_candidates
            .push(tracker.keyframe_candidates().to_owned());

        // Push initial pose to history.
        let (_, pose) = tracker.current_frame();
        self.poses_history.push(pose);

        self.tracker = Some(tracker);
        self.change_keyframe = true;

        // Return the number of frames contained in the archive.
        self.associations.len()
    }

    pub fn pick_reference_kf_data(&mut self, index: usize) {
        update_kf_data(&mut self.reference_keyframe_data, &self.keyframes[index]);
        let (width, _) = self.keyframes[index].shape(); // DMatrix is transposed
        let data = &mut self.reference_keyframe_data[..];
        for &(x, y) in self.keyframes_candidates[index].iter() {
            let pix = 4 * (y * width + x);
            data[pix] = 255;
            data[pix + 1] = 0;
            data[pix + 2] = 0;
        }
    }

    pub fn pick_current_kf_data(&mut self, index: usize) {
        update_kf_data(&mut self.current_keyframe_data, &self.keyframes[index]);
    }

    pub fn reset_at(
        &mut self,
        base_frame_id: usize,
        last_tracked_frame_id: usize,
        keyframe_id: usize,
    ) {
        let config = self.tracker.as_ref().expect("reset_kf").config().clone();
        let (depth_map, img) = _read_image_pair_bis(
            &self.associations[base_frame_id],
            &self.tar_buffer,
            &self.entries,
        )
        .expect("81");
        let depth_time = self.associations[base_frame_id].depth_timestamp;
        let img_time = self.associations[base_frame_id].color_timestamp;
        let mut tracker = config.init(depth_time, &depth_map, img_time, img);
        // Reset the pose to the one of the chosen keyframe.
        let base_pose = self.poses_history[base_frame_id];
        tracker.reset_pose(base_pose, base_pose);

        let keyframe_img = tracker.keyframe_img();
        let keyframe_img = keyframe_img.transpose();
        update_kf_data(&mut self.current_keyframe_data, &keyframe_img);
        self.keyframes.resize(keyframe_id, DMatrix::zeros(0, 0));
        self.keyframes_candidates.resize(keyframe_id, vec![]);
        self.poses_history
            .resize(last_tracked_frame_id + 1, Iso3::identity());
        self.tracker = Some(tracker);
        self.change_keyframe = true;
    }

    // pub fn reset_at_p3p(
    //     &mut self,
    //     base_frame_id: usize,
    //     last_tracked_frame_id: usize,
    //     keyframe_id: usize,
    //     p3p_ref_points: JsValue,
    //     p3p_key_points: JsValue,
    // ) {
    //     let config = self.tracker.as_ref().expect("reset_kf").config().clone();
    //     let (depth_map, img) = _read_image_pair_bis(
    //         &self.associations[base_frame_id],
    //         &self.tar_buffer,
    //         &self.entries,
    //     )
    //     .expect("81");
    //     let depth_time = self.associations[base_frame_id].depth_timestamp;
    //     let img_time = self.associations[base_frame_id].color_timestamp;
    //     let mut tracker = config.init(depth_time, &depth_map, img_time, img);
    //
    //     // Reset the pose to the one of the chosen keyframe.
    //     let pose = self.poses_history[base_frame_id];
    //     tracker.reset_pose(pose, pose);
    //
    //     // Compute P3P initialization for the tracker.
    //     let p3p_ref_points: [(f32, f32); 3] =
    //         serde_wasm_bindgen::from_value(p3p_ref_points).expect("woops");
    //     let p3p_key_points: [(f32, f32); 3] =
    //         serde_wasm_bindgen::from_value(p3p_key_points).expect("woops");
    //
    //     // Identify 3D points associated to p3p_ref_points.
    //     let ref_candidates_coords = tracker.keyframe_candidates();
    //     let ref_candidates_idepths = tracker.keyframe_candidates_idepths();
    //     let (closest_0, ref_0) = closest_to(p3p_ref_points[0], ref_candidates_coords);
    //     let (closest_1, ref_1) = closest_to(p3p_ref_points[1], ref_candidates_coords);
    //     let (closest_2, ref_2) = closest_to(p3p_ref_points[2], ref_candidates_coords);
    //     console_log!("ref_0_pos: {:?}", ref_0);
    //     console_log!("ref_1_pos: {:?}", ref_1);
    //     console_log!("ref_2_pos: {:?}", ref_2);
    //     let idepth_0 = ref_candidates_idepths[closest_0];
    //     let idepth_1 = ref_candidates_idepths[closest_1];
    //     let idepth_2 = ref_candidates_idepths[closest_2];
    //     let intrinsics = &tracker.intrinsics()[1];
    //     let to_camera_coords =
    //         |(u, v), idepth| intrinsics.back_project(Point2::new(u, v), 1.0 / idepth);
    //     let to_3d_world = |coords, idepth| pose * to_camera_coords(coords, idepth);
    //     let world_3d_points = [
    //         to_3d_world(ref_0, idepth_0).coords.into(),
    //         to_3d_world(ref_1, idepth_1).coords.into(),
    //         to_3d_world(ref_2, idepth_2).coords.into(),
    //     ];
    //
    //     // Compute potential poses with P3P crate.
    //     let bearing_vec_0 = to_camera_coords(p3p_key_points[0], 1.0).coords;
    //     let bearing_vec_1 = to_camera_coords(p3p_key_points[1], 1.0).coords;
    //     let bearing_vec_2 = to_camera_coords(p3p_key_points[2], 1.0).coords;
    //     let bearing_vectors = [
    //         ((1.0 / bearing_vec_0[2]) * bearing_vec_0).into(),
    //         ((1.0 / bearing_vec_1[2]) * bearing_vec_1).into(),
    //         ((1.0 / bearing_vec_2[2]) * bearing_vec_2).into(),
    //     ];
    //     let key_projections = p3p::nordberg::solve(&world_3d_points, &bearing_vectors);
    //     // console_log!("reference pose: {}", pose);
    //     console_log!("potential poses:");
    //     let key_poses: Vec<_> = key_projections
    //         .iter()
    //         .map(|p| {
    //             let rot_quat = Quaternion::from(Vec4::from(p.rotation));
    //             let rot = UnitQuaternion::from_quaternion(rot_quat);
    //             let trans = Translation::from(Vec3::from(p.translation));
    //             let key_pose = Iso3::from_parts(trans, rot).inverse();
    //             console_log!("{:?}", key_pose.translation);
    //             key_pose
    //         })
    //         .collect();
    //
    //     // Select the one with lowest reprojection error.
    //     let (_, retrack_img) = _read_image_pair_bis(
    //         &self.associations[last_tracked_frame_id + 1],
    //         &self.tar_buffer,
    //         &self.entries,
    //     )
    //     .expect("ohoh");
    //     key_poses.iter().for_each(|pose| {
    //         let reproj_error = tracker.reprojection_error(pose, &retrack_img);
    //         console_log!("reprojection error: {:?}", reproj_error);
    //     });
    //
    //     // Update current frame pose of tracker with this one.
    //     let estimated_pose = std::iter::once(&pose)
    //         .chain(key_poses.iter())
    //         .min_by(|p1, p2| {
    //             let (inside_ratio_1, error_1) = tracker.reprojection_error(p1, &retrack_img);
    //             let (inside_ratio_2, error_2) = tracker.reprojection_error(p2, &retrack_img);
    //             if inside_ratio_2 > 0.25 {
    //                 error_1.partial_cmp(&error_2).unwrap()
    //             } else {
    //                 std::cmp::Ordering::Less
    //             }
    //         })
    //         .unwrap();
    //     tracker.reset_pose(pose, *estimated_pose);
    //
    //     // Following is the same than the reset_at function.
    //     let keyframe_img = tracker.keyframe_img();
    //     let keyframe_img = keyframe_img.transpose();
    //     update_kf_data(&mut self.current_keyframe_data, &keyframe_img);
    //     self.keyframes.resize(keyframe_id, DMatrix::zeros(0, 0));
    //     self.keyframes_candidates.resize(keyframe_id, vec![]);
    //     self.poses_history
    //         .resize(last_tracked_frame_id, Iso3::identity());
    //
    //     self.tracker = Some(tracker);
    //     self.change_keyframe = true;
    // }

    pub fn p3p_visualize(
        &mut self,
        base_frame_id: usize,
        last_tracked_frame_id: usize,
        p3p_ref_points: JsValue,
        p3p_key_points: JsValue,
        point_cloud: &mut PointCloud,
    ) -> JsValue {
        let config = self.tracker.as_ref().expect("reset_kf").config().clone();
        let (depth_map, img) = _read_image_pair_bis(
            &self.associations[base_frame_id],
            &self.tar_buffer,
            &self.entries,
        )
        .expect("81");
        let depth_time = self.associations[base_frame_id].depth_timestamp;
        let img_time = self.associations[base_frame_id].color_timestamp;
        let mut p3p_tracker = config.init(depth_time, &depth_map, img_time, img);

        // Reset the pose to the one of the chosen keyframe.
        let base_pose = self.poses_history[base_frame_id];
        let current_pose = self.poses_history[last_tracked_frame_id];
        p3p_tracker.reset_pose(base_pose, current_pose);

        // Compute P3P initialization for the tracker.
        let p3p_ref_points: [(f32, f32); 3] =
            serde_wasm_bindgen::from_value(p3p_ref_points).expect("woops");
        let p3p_key_points: [(f32, f32); 3] =
            serde_wasm_bindgen::from_value(p3p_key_points).expect("woops");

        // Identify 3D points associated to p3p_ref_points.
        let ref_candidates_coords = p3p_tracker.keyframe_candidates();
        let ref_candidates_idepths = p3p_tracker.keyframe_candidates_idepths();
        let (closest_0, ref_0) = closest_to(p3p_ref_points[0], ref_candidates_coords);
        let (closest_1, ref_1) = closest_to(p3p_ref_points[1], ref_candidates_coords);
        let (closest_2, ref_2) = closest_to(p3p_ref_points[2], ref_candidates_coords);
        console_log!("ref_0_pos: {:?}", ref_0);
        console_log!("ref_1_pos: {:?}", ref_1);
        console_log!("ref_2_pos: {:?}", ref_2);
        let idepth_0 = ref_candidates_idepths[closest_0];
        let idepth_1 = ref_candidates_idepths[closest_1];
        let idepth_2 = ref_candidates_idepths[closest_2];
        let intrinsics = &p3p_tracker.intrinsics()[1];
        let to_camera_coords =
            |(u, v), idepth| intrinsics.back_project(Point2::new(u, v), 1.0 / idepth);
        let to_3d_world = |coords, idepth| base_pose * to_camera_coords(coords, idepth);
        let world_3d_points = [
            to_3d_world(ref_0, idepth_0).coords.into(),
            to_3d_world(ref_1, idepth_1).coords.into(),
            to_3d_world(ref_2, idepth_2).coords.into(),
        ];

        // Compute potential poses with P3P crate.
        let bearing_vec_0 = to_camera_coords(p3p_key_points[0], 1.0).coords;
        let bearing_vec_1 = to_camera_coords(p3p_key_points[1], 1.0).coords;
        let bearing_vec_2 = to_camera_coords(p3p_key_points[2], 1.0).coords;
        let bearing_vectors = [
            ((1.0 / bearing_vec_0[2]) * bearing_vec_0).into(),
            ((1.0 / bearing_vec_1[2]) * bearing_vec_1).into(),
            ((1.0 / bearing_vec_2[2]) * bearing_vec_2).into(),
        ];
        let key_projections = p3p::nordberg::solve(&world_3d_points, &bearing_vectors);
        // console_log!("reference pose: {}", pose);
        console_log!("potential poses:");
        let key_poses: Vec<_> = key_projections
            .iter()
            .map(|p| {
                let rot_quat = Quaternion::from(Vec4::from(p.rotation));
                let rot = UnitQuaternion::from_quaternion(rot_quat);
                let trans = Translation::from(Vec3::from(p.translation));
                Iso3::from_parts(trans, rot).inverse()
            })
            .collect();

        // Update the 3D points buffer with 3D points for each pose.
        key_poses.iter().for_each(|&p3p_pose| {
            console_log!("{:?}", p3p_pose.translation);
            let mut temp_tracker = self.tracker.as_ref().unwrap().clone();
            temp_tracker.reset_pose(p3p_pose, p3p_pose);
            let p3ds = temp_tracker.points_3d();
            let start = point_cloud.end;
            point_cloud.end = start + 3 * p3ds.len();
            point_cloud.sections.push((start, point_cloud.end));
            let points = &mut point_cloud.points[start..point_cloud.end];
            points.chunks_mut(3).zip(p3ds.iter()).for_each(|(p, p3d)| {
                p[0] = p3d.x;
                p[1] = p3d.y;
                p[2] = p3d.z;
            });
        });

        // Compute reprojection error for each pose (+ current one).
        console_log!("last_tracked_frame_id: {}", last_tracked_frame_id);
        let (_, retrack_img) = _read_image_pair_bis(
            &self.associations[last_tracked_frame_id],
            &self.tar_buffer,
            &self.entries,
        )
        .expect("ohoh");
        self.p3p_poses.clear();
        let reproj_errors =
            std::iter::once(&current_pose)
                .chain(key_poses.iter())
                .map(|p3p_pose| {
                    self.p3p_poses.push(*p3p_pose);
                    p3p_tracker.reprojection_error(p3p_pose, &retrack_img)
                });

        // Transform each reprojection error into a score.
        // Increase score if there is a low amount of inside points.
        let scores: Vec<_> = reproj_errors
            .map(|(inside_ratio, mean_error)| {
                console_log!("(inside, error): ({},{})", inside_ratio, mean_error);
                if inside_ratio < 0.25 {
                    1.0 / (2.0 * mean_error)
                } else {
                    1.0 / mean_error
                }
            })
            .collect();

        // Transform scores into probabilities.
        // Higher score equals lower probability.
        let sum_scores: f32 = scores.iter().sum();
        let probabilities: Vec<_> = scores.iter().map(|s| s / sum_scores).collect();
        serde_wasm_bindgen::to_value(&probabilities).expect("woops")
    }

    pub fn choose_p3p_initial(&mut self, id: usize, base_frame_id: usize) -> usize {
        let keyframe_id = self.keyframes.len() - 1;
        let last_tracked_frame_id = self.poses_history.len() - 1;
        self.reset_at(base_frame_id, last_tracked_frame_id - 1, keyframe_id);
        let base_pose = self.poses_history[base_frame_id];
        let p3p_reset_pose = self.p3p_poses[id];
        let tracker = self.tracker.as_mut().unwrap();
        tracker.reset_pose(base_pose, p3p_reset_pose);
        keyframe_id
    }

    pub fn track(&mut self, frame_id: usize, force_keyframe: bool) -> String {
        let assoc = &self.associations[frame_id];
        let (depth_map, img) =
            _read_image_pair_bis(assoc, &self.tar_buffer, &self.entries).expect("92");

        // Track the rgb-d image.
        if let Some(ref mut t) = self.tracker {
            self.change_keyframe = t.track(
                force_keyframe,
                assoc.depth_timestamp,
                &depth_map,
                assoc.color_timestamp,
                img,
            );
            let (timestamp, pose) = t.current_frame();
            if self.change_keyframe {
                let keyframe_img = t.keyframe_img();
                let keyframe_img = keyframe_img.transpose();
                self.keyframes.push(keyframe_img);
                self.keyframes_candidates
                    .push(t.keyframe_candidates().to_owned());
            }
            self.poses_history.push(pose);
            return (tum_rgbd::Frame { timestamp, pose }).to_string();
        };

        // Return formatted camera pose.
        unreachable!()
    }
}

fn closest_to(point: (f32, f32), coords: &[(usize, usize)]) -> (usize, (f32, f32)) {
    let (id, &(u, v)) = coords
        .iter()
        .enumerate()
        .min_by(|&(_id1, &(u1, v1)), &(_id2, &(u2, v2))| {
            let d1 = (u1 as f32 - point.0).powi(2) + (v1 as f32 - point.1).powi(2);
            let d2 = (u2 as f32 - point.0).powi(2) + (v2 as f32 - point.1).powi(2);
            d1.partial_cmp(&d2).unwrap()
        })
        .unwrap();
    (id, (u as f32, v as f32))
}

/// Update self.current_keyframe_data.
/// The DMatrix in argument must already have been transposed to have the same
/// components order in column major.
fn update_kf_data(current_data: &mut [u8], kf: &DMatrix<u8>) {
    current_data
        .chunks_mut(4)
        .zip(kf.iter())
        .for_each(|(slice, &value)| {
            slice[0] = value;
            slice[1] = value;
            slice[2] = value;
            slice[3] = 255;
        });
}

/// Create camera depending on `camera_id` command line argument.
fn create_camera(camera_id: &str) -> Result<Intrinsics, String> {
    match camera_id {
        "fr1" => Ok(tum_rgbd::INTRINSICS_FR1),
        "fr2" => Ok(tum_rgbd::INTRINSICS_FR2),
        "fr3" => Ok(tum_rgbd::INTRINSICS_FR3),
        "icl" => Ok(tum_rgbd::INTRINSICS_ICL_NUIM),
        _ => {
            // eprintln!("{}", USAGE);
            Err(format!("Unknown camera id: {}", camera_id))
        }
    }
}

/// Open an association file (in bytes form) and parse it into a vector of Association.
fn parse_associations_buf(buffer: &[u8]) -> Result<Vec<tum_rgbd::Association>, Box<dyn Error>> {
    let mut content = String::new();
    let mut slice = buffer;
    slice.read_to_string(&mut content)?;
    tum_rgbd::parse::associations(&content).map_err(|s| s.into())
}

struct FileEntry {
    offset: usize,
    length: usize,
}

fn get_buffer<'a>(name: &str, file: &'a [u8], entries: &HashMap<String, FileEntry>) -> &'a [u8] {
    let entry = entries.get(name).expect("Entry is not in archive");
    &file[entry.offset..entry.offset + entry.length]
}

/// Read a depth and color image given by an association.
fn _read_image_pair(
    assoc: &tum_rgbd::Association,
    file: &[u8],
    entries: &HashMap<String, FileEntry>,
) -> Result<(DMatrix<u16>, DMatrix<u8>), image::ImageError> {
    // Read depth image.
    let depth_path_str = assoc.depth_file_path.to_str().expect("oaea").to_owned();
    let depth_buffer = get_buffer(&depth_path_str, file, entries);
    let (w, h, depth_map_vec_u16) = _read_png_16bits_buf(depth_buffer)?;
    let depth_map = DMatrix::from_row_slice(h, w, depth_map_vec_u16.as_slice());

    // Read color image.
    let img_path_str = assoc.color_file_path.to_str().expect("oaeaauuu").to_owned();
    let img_buffer = get_buffer(&img_path_str, file, entries);
    let img = image::load(Cursor::new(img_buffer), image::ImageFormat::PNG)?;
    let img_mat = interop::matrix_from_image(img.to_luma());

    Ok((depth_map, img_mat))
}

fn _read_image_pair_bis(
    assoc: &tum_rgbd::Association,
    file: &[u8],
    entries: &HashMap<String, FileEntry>,
) -> Result<(DMatrix<u16>, DMatrix<u8>), Box<dyn Error>> {
    // Read depth image.
    let depth_path_str = assoc.depth_file_path.to_str().expect("oaea").to_owned();
    let depth_buffer = get_buffer(&depth_path_str, file, entries);
    let (w, h, depth_map_vec_u16) = _png_decode_u16(depth_buffer)?;
    let depth_map = DMatrix::from_row_slice(h, w, depth_map_vec_u16.as_slice());

    // Read color image.
    let img_path_str = assoc.color_file_path.to_str().expect("oaeaauuu").to_owned();
    let img_buffer = get_buffer(&img_path_str, file, entries);
    let png_img = png_me::decode_no_check(img_buffer)?;
    let (width, height, data) = (png_img.width, png_img.height, png_img.data);
    let img = image::RgbImage::from_raw(width as u32, height as u32, data).expect("toto");
    let dyn_img = image::DynamicImage::ImageRgb8(img);
    let img_mat = interop::matrix_from_image(dyn_img.to_luma());

    Ok((depth_map, img_mat))
}

fn _read_png_16bits_buf<R: Read>(r: R) -> Result<(usize, usize, Vec<u16>), png::DecodingError> {
    let mut decoder = png::Decoder::new(r);
    // Use the IDENTITY transformation because by default
    // it will use STRIP_16 which only keep 8 bits.
    // See also SWAP_ENDIAN that might be useful
    //   (but seems not possible to use according to documentation).
    decoder.set(png::Transformations::IDENTITY);
    let (info, mut reader) = decoder.read_info()?;
    let mut buffer = vec![0; info.buffer_size()];
    reader.next_frame(&mut buffer)?;

    // Transform buffer into 16 bits slice.
    // if cfg!(target_endian = "big") ...
    let mut buffer_u16 = vec![0; (info.width * info.height) as usize];
    let mut buffer_cursor = Cursor::new(buffer);
    buffer_cursor.read_u16_into::<BigEndian>(&mut buffer_u16)?;

    // Return u16 buffer.
    Ok((info.width as usize, info.height as usize, buffer_u16))
}

fn _png_decode_u16(input: &[u8]) -> Result<(usize, usize, Vec<u16>), Box<dyn Error>> {
    let png_img = png_me::decode_no_check(input)?;
    let mut buffer_u16 = vec![0; png_img.width * png_img.height];
    let mut buffer_cursor = Cursor::new(&png_img.data);
    buffer_cursor.read_u16_into::<BigEndian>(&mut buffer_u16)?;
    Ok((png_img.width, png_img.height, buffer_u16))
}

// Camera stuff ################################################################

#[wasm_bindgen]
pub struct CameraPath {
    poses: Vec<f32>,
    indices_kf: Vec<usize>,
    end: usize,
}

#[wasm_bindgen]
impl CameraPath {
    pub fn new(nb_frames: usize) -> CameraPath {
        assert!(nb_frames > 0);
        CameraPath {
            poses: vec![0.0; 3 * nb_frames],
            indices_kf: vec![],
            end: 0,
        }
    }

    pub fn poses(&self) -> *const f32 {
        self.poses.as_ptr()
    }

    pub fn index_kf(&self, id: usize) -> usize {
        self.indices_kf[id] / 3
    }

    /// Reset CameraPath as if the given keyframe was the last one (not included).
    /// Return the id of the last tracked frame.
    pub fn reset_kf(&mut self, kf_id: usize) -> usize {
        let last_tracked_frame = self.index_kf(kf_id) - 1;
        self.end = self.indices_kf[kf_id];
        self.indices_kf.resize(kf_id, 0);
        last_tracked_frame
    }

    pub fn tick(&mut self, wasm_tracker: &WasmTracker) {
        let (_, pose) = wasm_tracker
            .tracker
            .as_ref()
            .map(|t| t.current_frame())
            .expect("current_frame");
        let translation = pose.translation.vector;
        self.poses[self.end] = translation.x;
        self.poses[self.end + 1] = translation.y;
        self.poses[self.end + 2] = translation.z;
        if wasm_tracker.change_keyframe {
            self.indices_kf.push(self.end);
        }
        self.end += 3;
    }
}

// Point cloud stuff ###########################################################

#[wasm_bindgen]
pub struct PointCloud {
    sections: Vec<(usize, usize)>,
    end: usize,
    points: Vec<f32>,
}

#[wasm_bindgen]
pub struct Section {
    pub start: usize,
    pub end: usize,
}

/// Public methods, exported to JavaScript.
#[wasm_bindgen]
impl PointCloud {
    pub fn new(nb_points: usize) -> PointCloud {
        let sections = vec![];
        let points = vec![0.0; 3 * nb_points];
        console_log!("PointCloud initialized");
        PointCloud {
            sections,
            end: 0,
            points,
        }
    }

    pub fn section(&self, frame: usize) -> Section {
        let (start, end) = self.sections[frame];
        Section { start, end }
    }

    pub fn points(&self) -> *const f32 {
        self.points.as_ptr()
    }

    /// Reset point cloud as if given keyframe was the last one.
    /// Return the limit of valid points in buffer.
    pub fn reset_kf(&mut self, kf_id: usize) -> usize {
        self.sections.resize(kf_id, (0, 0));
        self.end = self.sections[kf_id - 1].1;
        self.end
    }

    pub fn tick(&mut self, wasm_tracker: &WasmTracker) -> usize {
        if wasm_tracker.change_keyframe {
            // unimplemented!();
            console_log!("new keyframe");
            let start = self.end;
            let points_3d = wasm_tracker.tracker.as_ref().expect("tracker").points_3d();
            self.end = start + 3 * points_3d.len();
            self.sections.push((start, self.end));
            let points = &mut self.points[start..self.end];
            points
                .chunks_mut(3)
                .zip(points_3d.iter())
                .for_each(|(p, p3d)| {
                    p[0] = p3d.x;
                    p[1] = p3d.y;
                    p[2] = p3d.z;
                });
        }
        self.end
    }
}
