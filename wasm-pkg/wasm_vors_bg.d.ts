/* tslint:disable */
export const memory: WebAssembly.Memory;
export function __wbg_wasmtracker_free(a: number): void;
export function __wbg_get_wasmtracker_change_keyframe(a: number): number;
export function __wbg_set_wasmtracker_change_keyframe(a: number, b: number): void;
export function wasmtracker_new(): number;
export function wasmtracker_allocate(a: number, b: number): void;
export function wasmtracker_memory_pos(a: number): number;
export function wasmtracker_reference_keyframe_data(a: number): number;
export function wasmtracker_current_keyframe_data(a: number): number;
export function wasmtracker_build_entries_map(a: number): void;
export function wasmtracker_init(a: number, b: number, c: number): number;
export function wasmtracker_pick_reference_kf_data(a: number, b: number): void;
export function wasmtracker_pick_current_kf_data(a: number, b: number): void;
export function wasmtracker_reset_at(a: number, b: number, c: number, d: number): void;
export function wasmtracker_p3p_visualize(a: number, b: number, c: number, d: number, e: number, f: number): number;
export function wasmtracker_choose_p3p_initial(a: number, b: number, c: number): number;
export function wasmtracker_track(a: number, b: number, c: number, d: number): void;
export function __wbg_camerapath_free(a: number): void;
export function camerapath_new(a: number): number;
export function camerapath_poses(a: number): number;
export function camerapath_index_kf(a: number, b: number): number;
export function camerapath_reset_kf(a: number, b: number): number;
export function camerapath_tick(a: number, b: number): void;
export function __wbg_pointcloud_free(a: number): void;
export function __wbg_section_free(a: number): void;
export function __wbg_get_section_start(a: number): number;
export function __wbg_set_section_start(a: number, b: number): void;
export function __wbg_get_section_end(a: number): number;
export function __wbg_set_section_end(a: number, b: number): void;
export function pointcloud_new(a: number): number;
export function pointcloud_section(a: number, b: number): number;
export function pointcloud_points(a: number): number;
export function pointcloud_reset_kf(a: number, b: number): number;
export function pointcloud_tick(a: number, b: number): number;
export function atou8_range(a: number, b: number): number;
export function atou16_range(a: number, b: number): number;
export function atou32_range(a: number, b: number): number;
export function atou64_range(a: number, b: number): number;
export function atousize_range(a: number, b: number): number;
export function atoi8_range(a: number, b: number): number;
export function atoi16_range(a: number, b: number): number;
export function atoi32_range(a: number, b: number): number;
export function atoi64_range(a: number, b: number): number;
export function atoisize_range(a: number, b: number): number;
export function try_atou8_range(a: number, b: number, c: number): void;
export function try_atou16_range(a: number, b: number, c: number): void;
export function try_atou32_range(a: number, b: number, c: number): void;
export function try_atou64_range(a: number, b: number, c: number): void;
export function try_atoi8_range(a: number, b: number, c: number): void;
export function try_atoi16_range(a: number, b: number, c: number): void;
export function try_atoi32_range(a: number, b: number, c: number): void;
export function try_atoi64_range(a: number, b: number, c: number): void;
export function atou128_range(a: number, b: number, c: number): void;
export function atoi128_range(a: number, b: number, c: number): void;
export function try_atou128_range(a: number, b: number, c: number): void;
export function try_atoi128_range(a: number, b: number, c: number): void;
export function try_atoisize_range(a: number, b: number, c: number): void;
export function try_atousize_range(a: number, b: number, c: number): void;
export function is_success(a: number, b: number): number;
export function is_overflow(a: number, b: number): number;
export function is_invalid_digit(a: number, b: number): number;
export function is_empty(a: number, b: number): number;
export function get_nan_string_ffi(a: number, b: number): number;
export function set_nan_string_ffi(a: number, b: number): number;
export function get_inf_string_ffi(a: number, b: number): number;
export function set_inf_string_ffi(a: number, b: number): number;
export function get_infinity_string_ffi(a: number, b: number): number;
export function set_infinity_string_ffi(a: number, b: number): number;
export function f32toa_range(a: number, b: number, c: number): number;
export function f64toa_range(a: number, b: number, c: number): number;
export function u8toa_range(a: number, b: number, c: number): number;
export function u16toa_range(a: number, b: number, c: number): number;
export function u32toa_range(a: number, b: number, c: number): number;
export function u64toa_range(a: number, b: number, c: number): number;
export function usizetoa_range(a: number, b: number, c: number): number;
export function i8toa_range(a: number, b: number, c: number): number;
export function i16toa_range(a: number, b: number, c: number): number;
export function i32toa_range(a: number, b: number, c: number): number;
export function i64toa_range(a: number, b: number, c: number): number;
export function isizetoa_range(a: number, b: number, c: number): number;
export function u128toa_range(a: number, b: number, c: number, d: number): number;
export function i128toa_range(a: number, b: number, c: number, d: number): number;
export function atof32_range(a: number, b: number): number;
export function atof64_range(a: number, b: number): number;
export function atof32_lossy_range(a: number, b: number): number;
export function atof64_lossy_range(a: number, b: number): number;
export function try_atof32_range(a: number, b: number, c: number): void;
export function try_atof64_range(a: number, b: number, c: number): void;
export function try_atof32_lossy_range(a: number, b: number, c: number): void;
export function try_atof64_lossy_range(a: number, b: number, c: number): void;
export function __wbindgen_exn_store(a: number): void;
export function __wbindgen_malloc(a: number): number;
export function __wbindgen_realloc(a: number, b: number, c: number): number;
export function __wbindgen_free(a: number, b: number): void;
