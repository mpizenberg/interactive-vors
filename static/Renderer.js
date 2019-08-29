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

// Prepare WebGL context with THREE.
camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 0.01, 100);
camera.position.set(0, 0, -1);
scene = new THREE.Scene();
scene.background = new THREE.Color( 0x050505 );

// Perpare visualization.
geometry = new THREE.BufferGeometry();
geometry.setDrawRange(0, end_valid / 3);
current_geometry = new THREE.BufferGeometry();
current_geometry.setDrawRange(0, 0);
camera_path_geometry = new THREE.BufferGeometry();
camera_path_geometry.setDrawRange(0, 0);
current_camera_path_geometry = new THREE.BufferGeometry();
current_camera_path_geometry.setDrawRange(0, 0);

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
	geometry.addAttribute("position", pos_buffer_attr);
	let material = new THREE.PointsMaterial({size: 0.01, color: 0xffffff});
	let particles = new THREE.Points(geometry, material);
	particles.frustumCulled = false;
	scene.add(particles);

	// Add a second point cloud for current frame.
	current_geometry.addAttribute("position", pos_buffer_attr);
	let current_material = new THREE.PointsMaterial({size: 0.05, color: 0xff0000});
	let current_particles = new THREE.Points(current_geometry, current_material);
	current_particles.frustumCulled = false;
	scene.add(current_particles);

	// Bind camera path to THREE buffers.
	let camera_pose_buffer = getCameraPoseBuffer();
	camera_pose_attr = new THREE.BufferAttribute(camera_pose_buffer, 3).setDynamic(true);
	camera_path_geometry.addAttribute('position', camera_pose_attr);
	let camera_path_material = new THREE.PointsMaterial({color: 0xAA77DD, size: 0.03});
	let line = new THREE.Points(camera_path_geometry, camera_path_material);
	line.frustumCulled = false;
	scene.add(line);

	// Add a geometry for the current keyframe camera.
	current_camera_path_geometry.addAttribute('position', camera_pose_attr);
	let current_camera_path_material = new THREE.PointsMaterial({color: 0xFF0000, size: 0.08});
	let current_line = new THREE.Points(current_camera_path_geometry, current_camera_path_material);
	current_line.frustumCulled = false;
	scene.add(current_line);

	// Setup the renderer.
	renderer = new THREE.WebGLRenderer();
	renderer.setPixelRatio(window.devicePixelRatio);
	renderer.setSize(window.innerWidth, window.innerHeight);
	renderer.domElement.style.display = "block";
	controls = new THREE.OrbitControls(camera, renderer.domElement);
	controls.update();
}

function getCameraPoseBuffer() {
	return new Float32Array(wasm.memory.buffer, camera_path.poses(), 3 * camera_path_nb_frames);
}

export function getPosMemBuffer(point_cloud, nb_particles) {
	return new Float32Array(wasm.memory.buffer, point_cloud.points(), 3 * nb_particles);
}

function updateCurrentCameraPoseKf(frame) {
	let index = camera_path.index_kf(frame);
	current_camera_path_geometry.setDrawRange(index/3, 1);
}

function updateCurrentPointCloud(frame) {
	let section = point_cloud.section(frame);
	let start = section.start / 3;
	let end = section.end / 3;
	let nb_points = end - start;
	current_geometry.setDrawRange(start, nb_points);
}

function renderLoop() {
	controls.update();
	renderer.render(scene, camera);
	window.requestAnimationFrame(renderLoop);
}

export function track() {
	last_tracked_frame += 1;
	trackFrame(last_tracked_frame, nb_frames);
}

function trackFrame(frame_id, nb_frames) {
	if (frame_id < nb_frames) {
		const frame_pose = wasm_tracker.track(frame_id);
		console.log(frame_pose);
		// update point cloud.
		let start_update = end_valid;
		end_valid = point_cloud.tick(wasm_tracker);
		geometry.setDrawRange(0, end_valid / 3);
		updateGeometry(start_update, end_valid);
		// update camera path.
		camera_path.tick(wasm_tracker);
		camera_path_geometry.setDrawRange(0, frame_id);
		updateCameraGeometry(3 * (frame_id - 1), 3 * frame_id);
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
		renderLoop();
	}

	static get observedAttributes() {
		return ['width', 'height', 'current', 'nb-frames'];
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
			case 'nb-frames':
				if (newValue === oldValue) break;
				nb_frames = +newValue;
				break;
			case 'current':
				// if (oldValue == null) break; // Do not trigger at initialization.
				if (newValue === oldValue) break; // Do not accidentally trigger.
				updateCurrentPointCloud(+newValue);
				updateCurrentCameraPoseKf(+newValue);
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
