use visual_odometry_rs as vors;
use wasm_bindgen::prelude::*;

use image;
use nalgebra::DMatrix;
use std::{error::Error, io::Read};

use byteorder::{BigEndian, ReadBytesExt};
use png::HasParameters;
use std::collections::HashMap;
use std::io::Cursor;
use tar;

use vors::core::camera::Intrinsics;
use vors::core::track::inverse_compositional as track;
use vors::dataset::tum_rgbd;
use vors::misc::interop;

use png_decoder::png as png_me;

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
    change_keyframe: bool,
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
        }
    }

    pub fn allocate(&mut self, length: usize) {
        self.tar_buffer = vec![0; length];
    }

    pub fn memory_pos(&self) -> *const u8 {
        self.tar_buffer.as_ptr()
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
        self.tracker = Some(config.init(depth_time, &depth_map, img_time, img));
        self.change_keyframe = true;

        // Return the number of frames contained in the archive.
        self.associations.len()
    }

    pub fn track(&mut self, frame_id: usize) -> String {
        let assoc = &self.associations[frame_id];
        let (depth_map, img) =
            _read_image_pair_bis(assoc, &self.tar_buffer, &self.entries).expect("92");

        // Track the rgb-d image.
        if let Some(ref mut t) = self.tracker {
            self.change_keyframe = t.track(
                assoc.depth_timestamp,
                &depth_map,
                assoc.color_timestamp,
                img,
            );
            let (timestamp, pose) = t.current_frame();
            return (tum_rgbd::Frame { timestamp, pose }).to_string();
        };

        // Return formatted camera pose.
        unreachable!()
    }
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
fn parse_associations_buf(buffer: &[u8]) -> Result<Vec<tum_rgbd::Association>, Box<Error>> {
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
) -> Result<(DMatrix<u16>, DMatrix<u8>), Box<Error>> {
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

fn _png_decode_u16(input: &[u8]) -> Result<(usize, usize, Vec<u16>), Box<Error>> {
    let png_img = png_me::decode_no_check(input)?;
    let mut buffer_u16 = vec![0; png_img.width * png_img.height];
    let mut buffer_cursor = Cursor::new(&png_img.data);
    buffer_cursor.read_u16_into::<BigEndian>(&mut buffer_u16)?;
    Ok((png_img.width, png_img.height, buffer_u16))
}

// Point cloud stuff ###########################################################

#[wasm_bindgen]
pub struct PointCloud {
    end: usize,
    points: Vec<f32>,
    colors: Vec<f32>,
}

/// Public methods, exported to JavaScript.
#[wasm_bindgen]
impl PointCloud {
    pub fn new(nb_points: usize) -> PointCloud {
        let points = vec![0.0; 3 * nb_points];
        let colors = vec![0.0; 3 * nb_points];
        console_log!("PointCloud initialized");
        PointCloud {
            end: 0,
            points,
            colors,
        }
    }

    pub fn points(&self) -> *const f32 {
        self.points.as_ptr()
    }

    pub fn colors(&self) -> *const f32 {
        self.colors.as_ptr()
    }

    pub fn tick(&mut self, wasm_tracker: &WasmTracker) -> usize {
        if wasm_tracker.change_keyframe {
            // unimplemented!();
            console_log!("new keyframe");
            let start = self.end;
            let points_3d = wasm_tracker
                .tracker
                .as_ref()
                .map(|t| t.points_3d())
                .expect("tracker");
            self.end = start + 3 * points_3d.len();
            let points = &mut self.points[start..self.end];
            let colors = &mut self.colors[start..self.end];
            colors.iter_mut().for_each(|x| *x = 0.9);
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
