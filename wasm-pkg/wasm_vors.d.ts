/* tslint:disable */
/**
*/
export class CameraPath {
  free(): void;
/**
* @param {number} nb_frames 
* @returns {CameraPath} 
*/
  static new(nb_frames: number): CameraPath;
/**
* @returns {number} 
*/
  poses(): number;
/**
* @param {number} id 
* @returns {number} 
*/
  index_kf(id: number): number;
/**
* Reset CameraPath as if the given keyframe was the last one (not included).
* Return the id of the last tracked frame.
* @param {number} kf_id 
* @returns {number} 
*/
  reset_kf(kf_id: number): number;
/**
* @param {WasmTracker} wasm_tracker 
*/
  tick(wasm_tracker: WasmTracker): void;
}
/**
*/
export class PointCloud {
  free(): void;
/**
* @param {number} nb_points 
* @returns {PointCloud} 
*/
  static new(nb_points: number): PointCloud;
/**
* @param {number} frame 
* @returns {Section} 
*/
  section(frame: number): Section;
/**
* @returns {number} 
*/
  points(): number;
/**
* Reset point cloud as if given keyframe was the last one.
* Return the limit of valid points in buffer.
* @param {number} kf_id 
* @returns {number} 
*/
  reset_kf(kf_id: number): number;
/**
* @param {WasmTracker} wasm_tracker 
* @returns {number} 
*/
  tick(wasm_tracker: WasmTracker): number;
}
/**
*/
export class Section {
  free(): void;
  end: number;
  start: number;
}
/**
*/
export class WasmTracker {
  free(): void;
/**
* @returns {WasmTracker} 
*/
  static new(): WasmTracker;
/**
* @param {number} length 
*/
  allocate(length: number): void;
/**
* @returns {number} 
*/
  memory_pos(): number;
/**
* @returns {number} 
*/
  reference_keyframe_data(): number;
/**
* @returns {number} 
*/
  current_keyframe_data(): number;
/**
*/
  build_entries_map(): void;
/**
* @param {string} camera_id 
* @returns {number} 
*/
  init(camera_id: string): number;
/**
* @param {number} index 
*/
  pick_reference_kf_data(index: number): void;
/**
* @param {number} index 
*/
  pick_current_kf_data(index: number): void;
/**
* @param {number} base_frame_id 
* @param {number} last_tracked_frame_id 
* @param {number} keyframe_id 
*/
  reset_at(base_frame_id: number, last_tracked_frame_id: number, keyframe_id: number): void;
/**
* @param {number} base_frame_id 
* @param {number} last_tracked_frame_id 
* @param {any} p3p_ref_points 
* @param {any} p3p_key_points 
* @param {PointCloud} point_cloud 
* @returns {any} 
*/
  p3p_visualize(base_frame_id: number, last_tracked_frame_id: number, p3p_ref_points: any, p3p_key_points: any, point_cloud: PointCloud): any;
/**
* @param {number} id 
* @param {number} base_frame_id 
* @returns {number} 
*/
  choose_p3p_initial(id: number, base_frame_id: number): number;
/**
* @param {number} frame_id 
* @param {boolean} force_keyframe 
* @returns {string} 
*/
  track(frame_id: number, force_keyframe: boolean): string;
  change_keyframe: boolean;
}

/**
* If `module_or_path` is {RequestInfo}, makes a request and
* for everything else, calls `WebAssembly.instantiate` directly.
*
* @param {RequestInfo | BufferSource | WebAssembly.Module} module_or_path
*
* @returns {Promise<any>}
*/
export default function init (module_or_path?: RequestInfo | BufferSource | WebAssembly.Module): Promise<any>;
        