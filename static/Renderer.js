import { PointCloud, WasmTracker, CameraPath, default as init } from "./wasm-pkg/wasm_vors.js";

// WASM stuff ##################################################################

export let wasm;
export let wasm_tracker;
export let camera;
export let scene;
export let controls;
export let renderer;
export let nb_frames = 0;
export let last_tracked_frame = 0;

// Full geometry point cloud.
export let point_cloud;
export let geometry;
export let pos_buffer_attr;
export let nb_particles = 1000000;
export let end_valid = 0;
export let set_end_valid = (n) => end_valid = n;

// Current frame point cloud.
export let current_geometry;

// Camera path
export let camera_path;
export let camera_path_nb_frames = 10000;
export let camera_pose_attr;
export let camera_path_geometry;

// Current camera keyframe pose.
export let current_camera_path_geometry;

// Keyframe miniature canvas context.
export let canvas_2d_ctx;
export let canvas_2d_ctx_ref;

// P3P point clouds.
export let p3p_point_cloud_1;
export let p3p_point_cloud_2;
export let p3p_point_cloud_3;
export let p3p_point_cloud_4;

// Prepare WebGL context with THREE.
camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 0.01, 100);
camera.position.set(0, 0, -1);
camera.up.set( 0, 1, 0 );
scene = new THREE.Scene();
scene.background = new THREE.Color( 0x050505 );

// Prepare visualization.
geometry = new THREE.BufferGeometry();
geometry.setDrawRange(0, end_valid / 3);
current_geometry = new THREE.BufferGeometry();
current_geometry.setDrawRange(0, 0);
camera_path_geometry = new THREE.BufferGeometry();
camera_path_geometry.setDrawRange(0, 0);
current_camera_path_geometry = new THREE.BufferGeometry();
current_camera_path_geometry.setDrawRange(0, 0);

// Prepare P3P point clouds visualization.
p3p_point_cloud_1 = new THREE.BufferGeometry();
p3p_point_cloud_2 = new THREE.BufferGeometry();
p3p_point_cloud_3 = new THREE.BufferGeometry();
p3p_point_cloud_4 = new THREE.BufferGeometry();
p3p_point_cloud_1.setDrawRange(0, 0);
p3p_point_cloud_2.setDrawRange(0, 0);
p3p_point_cloud_3.setDrawRange(0, 0);
p3p_point_cloud_4.setDrawRange(0, 0);

// Run Forest!
load_wasm();

async function load_wasm() {
	// Initialize the wasm module.
	wasm = await init("./wasm-pkg/wasm_vors_bg.wasm");
	wasm_tracker = WasmTracker.new();
	point_cloud = PointCloud.new(nb_particles);
	camera_path = CameraPath.new(camera_path_nb_frames);

	// Bind geometry to THREE buffers.
	let pos_mem_buffer = getPosMemBuffer(point_cloud, nb_particles);
	pos_buffer_attr = new THREE.BufferAttribute(pos_mem_buffer, 3).setDynamic(true);
	scene.add(create_particles(geometry, pos_buffer_attr, 1, 0xffffff));

	// Add a second point cloud for current frame.
	scene.add(create_particles(current_geometry, pos_buffer_attr, 4, 0xff0000));

	// Add point clouds for P3P potential initializations.
	scene.add(create_particles(p3p_point_cloud_1, pos_buffer_attr, 4, 0xFFE546));
	scene.add(create_particles(p3p_point_cloud_2, pos_buffer_attr, 4, 0x9FD74B));
	scene.add(create_particles(p3p_point_cloud_3, pos_buffer_attr, 4, 0x38BB76));
	scene.add(create_particles(p3p_point_cloud_4, pos_buffer_attr, 4, 0x1D838C));

	// Bind camera path to THREE buffers.
	let camera_pose_buffer = getCameraPoseBuffer();
	camera_pose_attr = new THREE.BufferAttribute(camera_pose_buffer, 3).setDynamic(true);
	scene.add(create_particles(camera_path_geometry, camera_pose_attr, 2, 0xAA77DD));

	// Add a geometry for the current keyframe camera.
	scene.add(create_particles(current_camera_path_geometry, camera_pose_attr, 10, 0xFF0000));

	// Setup the renderer.
	renderer = new THREE.WebGLRenderer();
	renderer.setPixelRatio(window.devicePixelRatio);
	renderer.setSize(window.innerWidth, window.innerHeight);
	renderer.domElement.style.display = "block";
	controls = new THREE.OrbitControls(camera, renderer.domElement);
	controls.target = new THREE.Vector3(0, 0, 0.1);
	controls.screenSpacePanning = true;
	controls.update();
}

export function chooseP3pInitial(id, base_kf) {
	let keyframe = wasm_tracker.choose_p3p_initial(id, base_kf);
	last_tracked_frame -= 1;
	end_valid = point_cloud.reset_kf(keyframe);
	let force_keyframe = true;
	track(force_keyframe);
	let section = point_cloud.section(keyframe);
	geometry.setDrawRange(0, end_valid / 3);
	updateGeometry(section.start, section.end);
	// Clear potential P3P poses.
	p3p_point_cloud_1.setDrawRange(0, 0);
	p3p_point_cloud_2.setDrawRange(0, 0);
	p3p_point_cloud_3.setDrawRange(0, 0);
	p3p_point_cloud_4.setDrawRange(0, 0);
}

function create_particles(geom, buffer, size, color) {
	geom.addAttribute("position", buffer);
	let material = new THREE.PointsMaterial({size: size, sizeAttenuation: false, color: color});
	let particles = new THREE.Points(geom, material);
	particles.frustumCulled = false;
	return particles;
}

export function pickReference(index) {
	wasm_tracker.pick_reference_kf_data(index);
	let ptr = wasm_tracker.reference_keyframe_data();
	let data = new Uint8ClampedArray(wasm.memory.buffer, ptr, 4 * 320 * 240);
	let image_data = new ImageData(data, 320, 240);
	canvas_2d_ctx_ref.putImageData(image_data, 0, 0);
}

export function restartFromKeyframe(baseKf, keyframe) {
	assert(baseKf < keyframe, "Base keyframe >= restart keyframe");
	end_valid = point_cloud.reset_kf(keyframe);
	last_tracked_frame = camera_path.reset_kf(keyframe);
	let base_frame = camera_path.index_kf(baseKf);
	wasm_tracker.reset_at(base_frame, last_tracked_frame, keyframe);
	geometry.setDrawRange(0, end_valid / 3);
	camera_path_geometry.setDrawRange(0, last_tracked_frame);
	let force_keyframe = true;
	track(force_keyframe);
}

// export function restartFromKeyframeP3p(baseKf, keyframe, p3p_ref_points, p3p_key_points) {
// 	assert(baseKf < keyframe, "Base keyframe >= restart keyframe");
// 	end_valid = point_cloud.reset_kf(keyframe);
// 	last_tracked_frame = camera_path.reset_kf(keyframe);
// 	let base_frame = camera_path.index_kf(baseKf);
// 	wasm_tracker.reset_at_p3p(base_frame, last_tracked_frame, keyframe, p3p_ref_points, p3p_key_points);
// 	geometry.setDrawRange(0, end_valid / 3);
// 	camera_path_geometry.setDrawRange(0, last_tracked_frame);
// 	let force_keyframe = true;
// 	track(force_keyframe);
// }

export function p3pVisualize(baseKf, keyframe, p3p_ref_points, p3p_key_points) {
	assert(baseKf < keyframe, "Base keyframe >= restart keyframe");
	let base_frame = camera_path.index_kf(baseKf);
	let probabilities = wasm_tracker.p3p_visualize(base_frame, last_tracked_frame, p3p_ref_points, p3p_key_points, point_cloud);
	let nb_p3p = probabilities.length - 1;
	// Update geometry draw range.
	if (nb_p3p >= 1) { updateDrawRange(p3p_point_cloud_1, point_cloud.section(keyframe + 1)); }
	if (nb_p3p >= 2) { updateDrawRange(p3p_point_cloud_2, point_cloud.section(keyframe + 2)); }
	if (nb_p3p >= 3) { updateDrawRange(p3p_point_cloud_3, point_cloud.section(keyframe + 3)); }
	if (nb_p3p >= 4) { updateDrawRange(p3p_point_cloud_4, point_cloud.section(keyframe + 4)); }
	// Transfer geometry to GPU.
	if (nb_p3p > 0) {
		let first_section = point_cloud.section(keyframe + 1);
		let last_section = point_cloud.section(keyframe + nb_p3p);
		updateGeometry(first_section.start, last_section.end);
	}
	return probabilities;
}

function assert(condition, message) {
    if (!condition) { throw message || "Assertion failed"; }
}

function updateCurrentKfImage(index) {
	wasm_tracker.pick_current_kf_data(index);
	let kf_img_data_ptr = wasm_tracker.current_keyframe_data();
	let kf_img_data = new Uint8ClampedArray(wasm.memory.buffer, kf_img_data_ptr, 4 * 320 * 240);
	let image_data = new ImageData(kf_img_data, 320, 240);
	canvas_2d_ctx.putImageData(image_data, 0, 0);
}

function getCameraPoseBuffer() {
	return new Float32Array(wasm.memory.buffer, camera_path.poses(), 3 * camera_path_nb_frames);
}

export function getPosMemBuffer(point_cloud, nb_particles) {
	return new Float32Array(wasm.memory.buffer, point_cloud.points(), 3 * nb_particles);
}

function updateCurrentCameraPoseKf(frame) {
	let index = camera_path.index_kf(frame);
	current_camera_path_geometry.setDrawRange(index, 1);
}

function updateDrawRange(geom, section) {
	let start = section.start / 3;
	let end = section.end / 3;
	let nb_points = end - start;
	geom.setDrawRange(start, nb_points);
}

function renderLoop() {
	controls.update();
	renderer.render(scene, camera);
	window.requestAnimationFrame(renderLoop);
}

export function track(force_keyframe = false) {
	last_tracked_frame += 1;
	trackFrame(force_keyframe, last_tracked_frame, nb_frames);
	return (last_tracked_frame < nb_frames);
}

function trackFrame(force_keyframe, frame_id, nb_frames) {
	if (frame_id < nb_frames) {
		const frame_pose = wasm_tracker.track(frame_id, force_keyframe);
		console.log(frame_pose);
		// update point cloud.
		let start_update = end_valid;
		end_valid = point_cloud.tick(wasm_tracker);
		geometry.setDrawRange(0, end_valid / 3);
		updateGeometry(start_update, end_valid);
		// update camera path.
		camera_path.tick(wasm_tracker);
		camera_path_geometry.setDrawRange(0, frame_id);
		updateCameraGeometry(3 * frame_id, 3 * (frame_id + 1));
	}
}

export function updateCameraGeometry(start, end) {
	let nb_update = end - start;
	if (nb_update > 0) {
		// Update buffers because wasm memory might grow.
		camera_pose_attr.setArray(getCameraPoseBuffer());
		camera_pose_attr.updateRange.offset = start;
		camera_pose_attr.updateRange.count = nb_update;
		camera_pose_attr.needsUpdate = true;
	}
}

export function updateGeometry(start, end) {
	updateGeometryDetail(point_cloud, nb_particles, pos_buffer_attr, start, end);
}

function updateGeometryDetail(point_cloud, nb_particles, pos_attr, start, end) {
	let nb_update = end - start;
	if (nb_update > 0) {
		// Update buffers because wasm memory might grow.
		pos_attr.setArray(getPosMemBuffer(point_cloud, nb_particles));

		pos_attr.updateRange.offset = start;
		pos_attr.updateRange.count = nb_update;
		pos_attr.needsUpdate = true;
	}
}

function onResize(width, height) {
	camera.aspect = width / height;
	camera.updateProjectionMatrix();
	renderer.setSize(width, height);
}


// WEB COMPONENT stuff #########################################################

class Renderer extends HTMLElement {
	constructor() {
		super();
		this.width = 0;
		this.height = 0;
		this.attachShadow({ mode: 'open' });
		this.shadowRoot.appendChild(renderer.domElement);
		console.log("Renderer custom element constructor.");
		renderLoop();
	}

	static get observedAttributes() {
		return ['width', 'height', 'canvas-id', 'canvas-id-ref', 'nb-frames', 'current'];
	}

	attributeChangedCallback(name, oldValue, newValue) {
		switch (name) {
			case 'width':
				if (newValue === oldValue) break;
				this.width = +newValue;
				onResize(this.width, this.height);
				break;
			case 'height':
				if (newValue === oldValue) break;
				this.height = +newValue;
				onResize(this.width, this.height);
				break;
			case 'canvas-id':
				if (newValue === oldValue) break;
				if (oldValue == null) { // wait for DOM to be actually ready.
					requestAnimationFrame(() => {
						canvas_2d_ctx = document.getElementById(newValue).getContext('2d');
						updateCurrentKfImage(+newValue);
					});
				} else {
					canvas_2d_ctx = document.getElementById(newValue).getContext('2d');
				}
				break;
			case 'canvas-id-ref':
				if (newValue === oldValue) break;
				if (oldValue == null) { // wait for DOM to be actually ready.
					requestAnimationFrame(() => {
						canvas_2d_ctx_ref = document.getElementById(newValue).getContext('2d');
					});
				} else {
					canvas_2d_ctx_ref = document.getElementById(newValue).getContext('2d');
				}
				break;
			case 'nb-frames':
				if (newValue === oldValue) break;
				nb_frames = +newValue;
				break;
			case 'current':
				// if (oldValue == null) break; // Do not trigger at initialization.
				if (newValue === oldValue) break; // Do not accidentally trigger.
				console.log(`current from ${oldValue} to ${newValue}`);
				updateDrawRange(current_geometry, point_cloud.section(+newValue));
				updateCurrentCameraPoseKf(+newValue);
				if (oldValue == null) break;
				updateCurrentKfImage(+newValue);
				break;
		}
	}

	connectedCallback() {
		console.log("connected");
	}

	disconnectedCallback() {
		console.log("disconnected");
	}
}

window.customElements.define("custom-renderer", Renderer);
