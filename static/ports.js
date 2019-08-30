// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import * as Renderer from "./Renderer.js"

export function activatePorts(app, containerSize) {
	// Inform the Elm app when its container div gets resized.
	window.addEventListener("resize", () =>
		app.ports.resizes.send(containerSize())
	);

	// Replace elm Browser.onAnimationFrameDelta
	startAnimationFrameLoop(app.ports.animationFrame);

	app.ports.track.subscribe( () => {
		Renderer.track();
		if (Renderer.wasm_tracker.change_keyframe) {
			app.ports.newKeyFrame.send(0);
		}
	});

	app.ports.exportObj.subscribe( () => {
		let obj_vec = [];
		let pos_buffer = Renderer.getPosMemBuffer(Renderer.point_cloud, Renderer.nb_particles);
		for (let i = 0; i < Renderer.end_valid; i += 3) {
			obj_vec.push(`v ${pos_buffer[i]} ${pos_buffer[i+1]} ${pos_buffer[i+2]}`);
		}
		let obj = obj_vec.join('\n');
		download('point_cloud.obj', obj);
	});
	
	// Set up file reader.
	let file_reader = new FileReader();
	file_reader.onload = () => {
		console.log("Transfering tar data to wasm memory ...");
		transferContent(file_reader.result);
		console.log("Initializing tracker with first image ...");
		const nb_frames = Renderer.wasm_tracker.init("icl");
		console.log("Rendering first frame point cloud ...");
		// Update point cloud.
		let start_valid = Renderer.end_valid;
		let end_valid = Renderer.point_cloud.tick(Renderer.wasm_tracker);
		Renderer.set_end_valid(end_valid);
		Renderer.geometry.setDrawRange(start_valid, end_valid / 3);
		Renderer.updateGeometry(start_valid, Renderer.end_valid);
		// Update camera path.
		Renderer.camera_path.tick(Renderer.wasm_tracker);
		Renderer.camera_path_geometry.setDrawRange(0, 1);
		Renderer.updateCameraGeometry(0, 3);
		// Render.
		Renderer.renderer.render(Renderer.scene, Renderer.camera);
		app.ports.datasetLoaded.send(nb_frames);
		file_reader = null; // Free memory.
	}

	// Transfer archive data to wasm when the file is loaded.
	app.ports.loadDataset.subscribe(archive => {
		console.log("Loading tar archive ...");
		file_reader.readAsArrayBuffer(archive);
	});

	// Transfer archive data to wasm when the file is loaded.
	function transferContent(arrayBuffer) {
		Renderer.wasm_tracker.allocate(arrayBuffer.byteLength);
		const wasm_buffer = new Uint8Array(Renderer.wasm.memory.buffer);
		const start = Renderer.wasm_tracker.memory_pos();
		let file_buffer = new Uint8Array(arrayBuffer);
		wasm_buffer.set(file_buffer, start);
		file_buffer = null; arrayBuffer = null; // Free memory.
		console.log("Building entries hash map ...");
		Renderer.wasm_tracker.build_entries_map();
	}
};

function startAnimationFrameLoop(port) {
	let timestamp = performance.now();
	let loop = (time) => {
		window.requestAnimationFrame(loop);
		let delta = time - timestamp;
		timestamp = time;
		port.send(delta);
	}
	loop();
}

function download(filename, text) {
	var element = document.createElement('a');
	element.setAttribute('href', 'data:text/plain;charset=utf-8,' + encodeURIComponent(text));
	element.setAttribute('download', filename);
	element.style.display = 'none';
	document.body.appendChild(element);
	element.click();
	document.body.removeChild(element);
}
