import { PointCloud, WasmTracker, default as init } from "./wasm-pkg/wasm_vors.js";

// WASM stuff ##################################################################

let wasm;
let camera;
let scene;
let controls;
let point_cloud;
let geometry;
let renderer;
let pos_buffer_attr;
let col_buffer_attr;

let nb_particles = 1000000;
let end_valid = 0;

// Prepare WebGL context with THREE.
camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 0.01, 100);
camera.position.z = 10;
scene = new THREE.Scene();
scene.background = new THREE.Color( 0x050505 );

// Perpare visualization.
geometry = new THREE.BufferGeometry();
geometry.setDrawRange(0, end_valid);

// Run Forest!
load_wasm();

async function load_wasm() {
	// Initialize the wasm module.
	wasm = await init("./wasm-pkg/wasm_vors_bg.wasm");
	const wasm_tracker = WasmTracker.new();
	point_cloud = PointCloud.new(nb_particles);

	// Bind geometry to THREE buffers.
	pos_buffer_attr = new THREE.BufferAttribute(getPosMemBuffer(), 3).setDynamic(true);
	col_buffer_attr = new THREE.BufferAttribute(getColMemBuffer(), 3).setDynamic(true);
	geometry.addAttribute("position", pos_buffer_attr);
	geometry.addAttribute("color", col_buffer_attr);
	let material = new THREE.PointsMaterial({size: 0.01, vertexColors: THREE.VertexColors});
	let particles = new THREE.Points(geometry, material);
	particles.frustumCulled = false;
	scene.add(particles);

	// Setup the renderer.
	renderer = new THREE.WebGLRenderer();
	renderer.setPixelRatio(window.devicePixelRatio);
	renderer.setSize(window.innerWidth, window.innerHeight);
	// renderer.render(scene, camera);
	controls = new THREE.OrbitControls(camera, renderer.domElement);
	controls.update();

	// // Transfer archive data to wasm when the file is loaded.
	// file_reader.onload = () => {
	// 	console.log("Transfering tar data to wasm memory ...");
	// 	transferContent(file_reader.result, wasm_tracker, wasm);
	// 	console.log("Initializing tracker with first image ...");
	// 	const nb_frames = wasm_tracker.init("icl");
	// 	console.log("Rendering first frame point cloud ...");
	// 	let start_valid = end_valid;
	// 	end_valid = point_cloud.tick(wasm_tracker);
	// 	updateGeometry(start_valid, end_valid);
	// 	renderer.render(scene, camera);
	// 	console.log("Starting animation frame loop ...");
	// 	window.requestAnimationFrame(() => track(wasm_tracker, 1, nb_frames));
	// 	file_reader = null; // Free memory.
	// };
}

function getPosMemBuffer() {
	return new Float32Array(wasm.memory.buffer, point_cloud.points(), 3 * nb_particles);
}

function getColMemBuffer() {
	return new Float32Array(wasm.memory.buffer, point_cloud.colors(), 3 * nb_particles);
}

// Transfer archive data to wasm when the file is loaded.
function transferContent(arrayBuffer, wasm_tracker, wasm) {
	wasm_tracker.allocate(arrayBuffer.byteLength);
	const wasm_buffer = new Uint8Array(wasm.memory.buffer);
	const start = wasm_tracker.memory_pos();
	let file_buffer = new Uint8Array(arrayBuffer);
	wasm_buffer.set(file_buffer, start);
	file_buffer = null; arrayBuffer = null; // Free memory.
	console.log("Building entries hash map ...");
	wasm_tracker.build_entries_map();
}

function track(wasm_tracker, frame_id, nb_frames) {
	if (frame_id < nb_frames) {
		const frame_pose = wasm_tracker.track(frame_id);
		console.log(frame_pose);
		let start_valid = end_valid;
		end_valid = point_cloud.tick(wasm_tracker);
		updateGeometry(start_valid, end_valid);
	}
	controls.update();
	renderer.render(scene, camera);
	// window.requestAnimationFrame(() =>
	// 	track(wasm_tracker, frame_id + 1, nb_frames)
	// );
}

function updateGeometry(start_valid, end_valid) {
	let nb_update = end_valid - start_valid;
	if (nb_update > 0) {
		geometry.setDrawRange(0, end_valid);

		// Update buffers because wasm memory might grow.
		pos_buffer_attr.setArray(getPosMemBuffer());
		col_buffer_attr.setArray(getColMemBuffer());

		pos_buffer_attr.updateRange.offset = start_valid;
		pos_buffer_attr.updateRange.count = end_valid - start_valid;
		pos_buffer_attr.needsUpdate = true;
		col_buffer_attr.updateRange.offset = start_valid;
		col_buffer_attr.updateRange.count = end_valid - start_valid;
		col_buffer_attr.needsUpdate = true;
	}
}

// function onWindowResize() {
// 	camera.aspect = window.innerWidth / window.innerHeight;
// 	camera.updateProjectionMatrix();
// 	renderer.setSize(window.innerWidth, window.innerHeight);
// }


// WEB COMPONENT stuff #########################################################

const template = document.createElement('template');
template.innerHTML = "<span id=content><span>";

class Renderer extends HTMLElement {
	constructor() {
		super();
		this.max = 0;
		this.value = 0;
		this.attachShadow({ mode: 'open' });
		this.shadowRoot.appendChild(template.content.cloneNode(true));
		this.content = this.shadowRoot.getElementById("content");
	}

	static get observedAttributes() {
		return ['value', 'trigger-compute'];
	}

	attributeChangedCallback(name, oldValue, newValue) {
		switch (name) {
			case 'value':
				if (newValue === oldValue) break;
				console.log(`value changed from ${oldValue} to ${newValue}`);
				this.value = +newValue;
				this.updateContent();
				break;
			case 'trigger-compute':
				console.log(`trigger-compute changed from ${oldValue} to ${newValue}`);
				this.max += 1;
				this.updateContent();
				break;
		}
	}

	updateContent() {
		this.content.innerHTML = `value: ${this.value}, max: ${this.max}`
	}

	connectedCallback() {
		console.log("connected");
	}

	disconnectedCallback() {
		console.log("disconnected");
	}
}

window.customElements.define("custom-renderer", Renderer);
