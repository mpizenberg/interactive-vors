
let wasm;

let WASM_VECTOR_LEN = 0;

let cachedTextEncoder = new TextEncoder('utf-8');

let cachegetUint8Memory = null;
function getUint8Memory() {
    if (cachegetUint8Memory === null || cachegetUint8Memory.buffer !== wasm.memory.buffer) {
        cachegetUint8Memory = new Uint8Array(wasm.memory.buffer);
    }
    return cachegetUint8Memory;
}

let passStringToWasm;
if (typeof cachedTextEncoder.encodeInto === 'function') {
    passStringToWasm = function(arg) {


        let size = arg.length;
        let ptr = wasm.__wbindgen_malloc(size);
        let offset = 0;
        {
            const mem = getUint8Memory();
            for (; offset < arg.length; offset++) {
                const code = arg.charCodeAt(offset);
                if (code > 0x7F) break;
                mem[ptr + offset] = code;
            }
        }

        if (offset !== arg.length) {
            arg = arg.slice(offset);
            ptr = wasm.__wbindgen_realloc(ptr, size, size = offset + arg.length * 3);
            const view = getUint8Memory().subarray(ptr + offset, ptr + size);
            const ret = cachedTextEncoder.encodeInto(arg, view);

            offset += ret.written;
        }
        WASM_VECTOR_LEN = offset;
        return ptr;
    };
} else {
    passStringToWasm = function(arg) {


        let size = arg.length;
        let ptr = wasm.__wbindgen_malloc(size);
        let offset = 0;
        {
            const mem = getUint8Memory();
            for (; offset < arg.length; offset++) {
                const code = arg.charCodeAt(offset);
                if (code > 0x7F) break;
                mem[ptr + offset] = code;
            }
        }

        if (offset !== arg.length) {
            const buf = cachedTextEncoder.encode(arg.slice(offset));
            ptr = wasm.__wbindgen_realloc(ptr, size, size = offset + buf.length);
            getUint8Memory().set(buf, ptr + offset);
            offset += buf.length;
        }
        WASM_VECTOR_LEN = offset;
        return ptr;
    };
}

const heap = new Array(32);

heap.fill(undefined);

heap.push(undefined, null, true, false);

let heap_next = heap.length;

function addHeapObject(obj) {
    if (heap_next === heap.length) heap.push(heap.length + 1);
    const idx = heap_next;
    heap_next = heap[idx];

    heap[idx] = obj;
    return idx;
}

function _assertClass(instance, klass) {
    if (!(instance instanceof klass)) {
        throw new Error(`expected instance of ${klass.name}`);
    }
    return instance.ptr;
}

function getObject(idx) { return heap[idx]; }

function dropObject(idx) {
    if (idx < 36) return;
    heap[idx] = heap_next;
    heap_next = idx;
}

function takeObject(idx) {
    const ret = getObject(idx);
    dropObject(idx);
    return ret;
}

let cachegetInt32Memory = null;
function getInt32Memory() {
    if (cachegetInt32Memory === null || cachegetInt32Memory.buffer !== wasm.memory.buffer) {
        cachegetInt32Memory = new Int32Array(wasm.memory.buffer);
    }
    return cachegetInt32Memory;
}

let cachedTextDecoder = new TextDecoder('utf-8');

function getStringFromWasm(ptr, len) {
    return cachedTextDecoder.decode(getUint8Memory().subarray(ptr, ptr + len));
}

function handleError(e) {
    wasm.__wbindgen_exn_store(addHeapObject(e));
}

let cachegetUint32Memory = null;
function getUint32Memory() {
    if (cachegetUint32Memory === null || cachegetUint32Memory.buffer !== wasm.memory.buffer) {
        cachegetUint32Memory = new Uint32Array(wasm.memory.buffer);
    }
    return cachegetUint32Memory;
}

function debugString(val) {
    // primitive types
    const type = typeof val;
    if (type == 'number' || type == 'boolean' || val == null) {
        return  `${val}`;
    }
    if (type == 'string') {
        return `"${val}"`;
    }
    if (type == 'symbol') {
        const description = val.description;
        if (description == null) {
            return 'Symbol';
        } else {
            return `Symbol(${description})`;
        }
    }
    if (type == 'function') {
        const name = val.name;
        if (typeof name == 'string' && name.length > 0) {
            return `Function(${name})`;
        } else {
            return 'Function';
        }
    }
    // objects
    if (Array.isArray(val)) {
        const length = val.length;
        let debug = '[';
        if (length > 0) {
            debug += debugString(val[0]);
        }
        for(let i = 1; i < length; i++) {
            debug += ', ' + debugString(val[i]);
        }
        debug += ']';
        return debug;
    }
    // Test for built-in
    const builtInMatches = /\[object ([^\]]+)\]/.exec(toString.call(val));
    let className;
    if (builtInMatches.length > 1) {
        className = builtInMatches[1];
    } else {
        // Failed to match the standard '[object ClassName]'
        return toString.call(val);
    }
    if (className == 'Object') {
        // we're a user defined class or Object
        // JSON.stringify avoids problems with cycles, and is generally much
        // easier than looping through ownProperties of `val`.
        try {
            return 'Object(' + JSON.stringify(val) + ')';
        } catch (_) {
            return 'Object';
        }
    }
    // errors
    if (val instanceof Error) {
        return `${val.name}: ${val.message}\n${val.stack}`;
    }
    // TODO we could test for more things here, like `Set`s and `Map`s.
    return className;
}
/**
*/
export class CameraPath {

    static __wrap(ptr) {
        const obj = Object.create(CameraPath.prototype);
        obj.ptr = ptr;

        return obj;
    }

    free() {
        const ptr = this.ptr;
        this.ptr = 0;

        wasm.__wbg_camerapath_free(ptr);
    }
    /**
    * @param {number} nb_frames
    * @returns {CameraPath}
    */
    static new(nb_frames) {
        const ret = wasm.camerapath_new(nb_frames);
        return CameraPath.__wrap(ret);
    }
    /**
    * @returns {number}
    */
    poses() {
        const ret = wasm.camerapath_poses(this.ptr);
        return ret;
    }
    /**
    * @param {number} id
    * @returns {number}
    */
    index_kf(id) {
        const ret = wasm.camerapath_index_kf(this.ptr, id);
        return ret >>> 0;
    }
    /**
    * Reset CameraPath as if the given keyframe was the last one (not included).
    * Return the id of the last tracked frame.
    * @param {number} kf_id
    * @returns {number}
    */
    reset_kf(kf_id) {
        const ret = wasm.camerapath_reset_kf(this.ptr, kf_id);
        return ret >>> 0;
    }
    /**
    * @param {WasmTracker} wasm_tracker
    */
    tick(wasm_tracker) {
        _assertClass(wasm_tracker, WasmTracker);
        wasm.camerapath_tick(this.ptr, wasm_tracker.ptr);
    }
}
/**
*/
export class PointCloud {

    static __wrap(ptr) {
        const obj = Object.create(PointCloud.prototype);
        obj.ptr = ptr;

        return obj;
    }

    free() {
        const ptr = this.ptr;
        this.ptr = 0;

        wasm.__wbg_pointcloud_free(ptr);
    }
    /**
    * @param {number} nb_points
    * @returns {PointCloud}
    */
    static new(nb_points) {
        const ret = wasm.pointcloud_new(nb_points);
        return PointCloud.__wrap(ret);
    }
    /**
    * @param {number} frame
    * @returns {Section}
    */
    section(frame) {
        const ret = wasm.pointcloud_section(this.ptr, frame);
        return Section.__wrap(ret);
    }
    /**
    * @returns {number}
    */
    points() {
        const ret = wasm.pointcloud_points(this.ptr);
        return ret;
    }
    /**
    * Reset point cloud as if given keyframe was the last one.
    * Return the limit of valid points in buffer.
    * @param {number} kf_id
    * @returns {number}
    */
    reset_kf(kf_id) {
        const ret = wasm.pointcloud_reset_kf(this.ptr, kf_id);
        return ret >>> 0;
    }
    /**
    * @param {WasmTracker} wasm_tracker
    * @returns {number}
    */
    tick(wasm_tracker) {
        _assertClass(wasm_tracker, WasmTracker);
        const ret = wasm.pointcloud_tick(this.ptr, wasm_tracker.ptr);
        return ret >>> 0;
    }
}
/**
*/
export class Section {

    static __wrap(ptr) {
        const obj = Object.create(Section.prototype);
        obj.ptr = ptr;

        return obj;
    }

    free() {
        const ptr = this.ptr;
        this.ptr = 0;

        wasm.__wbg_section_free(ptr);
    }
    /**
    * @returns {number}
    */
    get start() {
        const ret = wasm.__wbg_get_section_start(this.ptr);
        return ret >>> 0;
    }
    /**
    * @param {number} arg0
    */
    set start(arg0) {
        wasm.__wbg_set_section_start(this.ptr, arg0);
    }
    /**
    * @returns {number}
    */
    get end() {
        const ret = wasm.__wbg_get_section_end(this.ptr);
        return ret >>> 0;
    }
    /**
    * @param {number} arg0
    */
    set end(arg0) {
        wasm.__wbg_set_section_end(this.ptr, arg0);
    }
}
/**
*/
export class WasmTracker {

    static __wrap(ptr) {
        const obj = Object.create(WasmTracker.prototype);
        obj.ptr = ptr;

        return obj;
    }

    free() {
        const ptr = this.ptr;
        this.ptr = 0;

        wasm.__wbg_wasmtracker_free(ptr);
    }
    /**
    * @returns {boolean}
    */
    get change_keyframe() {
        const ret = wasm.__wbg_get_wasmtracker_change_keyframe(this.ptr);
        return ret !== 0;
    }
    /**
    * @param {boolean} arg0
    */
    set change_keyframe(arg0) {
        wasm.__wbg_set_wasmtracker_change_keyframe(this.ptr, arg0);
    }
    /**
    * @returns {WasmTracker}
    */
    static new() {
        const ret = wasm.wasmtracker_new();
        return WasmTracker.__wrap(ret);
    }
    /**
    * @param {number} length
    */
    allocate(length) {
        wasm.wasmtracker_allocate(this.ptr, length);
    }
    /**
    * @returns {number}
    */
    memory_pos() {
        const ret = wasm.wasmtracker_memory_pos(this.ptr);
        return ret;
    }
    /**
    * @returns {number}
    */
    reference_keyframe_data() {
        const ret = wasm.wasmtracker_reference_keyframe_data(this.ptr);
        return ret;
    }
    /**
    * @returns {number}
    */
    current_keyframe_data() {
        const ret = wasm.wasmtracker_current_keyframe_data(this.ptr);
        return ret;
    }
    /**
    */
    build_entries_map() {
        wasm.wasmtracker_build_entries_map(this.ptr);
    }
    /**
    * @param {string} camera_id
    * @returns {number}
    */
    init(camera_id) {
        const ret = wasm.wasmtracker_init(this.ptr, passStringToWasm(camera_id), WASM_VECTOR_LEN);
        return ret >>> 0;
    }
    /**
    * @param {number} index
    */
    pick_reference_kf_data(index) {
        wasm.wasmtracker_pick_reference_kf_data(this.ptr, index);
    }
    /**
    * @param {number} index
    */
    pick_current_kf_data(index) {
        wasm.wasmtracker_pick_current_kf_data(this.ptr, index);
    }
    /**
    * @param {number} base_frame_id
    * @param {number} last_tracked_frame_id
    * @param {number} keyframe_id
    */
    reset_at(base_frame_id, last_tracked_frame_id, keyframe_id) {
        wasm.wasmtracker_reset_at(this.ptr, base_frame_id, last_tracked_frame_id, keyframe_id);
    }
    /**
    * @param {number} base_frame_id
    * @param {number} last_tracked_frame_id
    * @param {any} p3p_ref_points
    * @param {any} p3p_key_points
    * @param {PointCloud} point_cloud
    * @returns {any}
    */
    p3p_visualize(base_frame_id, last_tracked_frame_id, p3p_ref_points, p3p_key_points, point_cloud) {
        _assertClass(point_cloud, PointCloud);
        const ret = wasm.wasmtracker_p3p_visualize(this.ptr, base_frame_id, last_tracked_frame_id, addHeapObject(p3p_ref_points), addHeapObject(p3p_key_points), point_cloud.ptr);
        return takeObject(ret);
    }
    /**
    * @param {number} id
    * @param {number} base_frame_id
    * @returns {number}
    */
    choose_p3p_initial(id, base_frame_id) {
        const ret = wasm.wasmtracker_choose_p3p_initial(this.ptr, id, base_frame_id);
        return ret >>> 0;
    }
    /**
    * @param {number} frame_id
    * @param {boolean} force_keyframe
    * @returns {string}
    */
    track(frame_id, force_keyframe) {
        const retptr = 8;
        const ret = wasm.wasmtracker_track(retptr, this.ptr, frame_id, force_keyframe);
        const memi32 = getInt32Memory();
        const v0 = getStringFromWasm(memi32[retptr / 4 + 0], memi32[retptr / 4 + 1]).slice();
        wasm.__wbindgen_free(memi32[retptr / 4 + 0], memi32[retptr / 4 + 1] * 1);
        return v0;
    }
}

function init(module) {
    if (typeof module === 'undefined') {
        module = import.meta.url.replace(/\.js$/, '_bg.wasm');
    }
    let result;
    const imports = {};
    imports.wbg = {};
    imports.wbg.__wbg_log_ee3b113870819b07 = function(arg0, arg1) {
        console.log(getStringFromWasm(arg0, arg1));
    };
    imports.wbg.__wbindgen_object_drop_ref = function(arg0) {
        takeObject(arg0);
    };
    imports.wbg.__wbindgen_number_new = function(arg0) {
        const ret = arg0;
        return addHeapObject(ret);
    };
    imports.wbg.__wbindgen_is_null = function(arg0) {
        const ret = getObject(arg0) === null;
        return ret;
    };
    imports.wbg.__wbindgen_is_undefined = function(arg0) {
        const ret = getObject(arg0) === undefined;
        return ret;
    };
    imports.wbg.__wbindgen_is_object = function(arg0) {
        const val = getObject(arg0);
        const ret = typeof(val) === 'object' && val !== null;
        return ret;
    };
    imports.wbg.__wbindgen_is_function = function(arg0) {
        const ret = typeof(getObject(arg0)) === 'function';
        return ret;
    };
    imports.wbg.__wbg_next_22f035a51306f355 = function(arg0) {
        const ret = getObject(arg0).next;
        return addHeapObject(ret);
    };
    imports.wbg.__wbg_next_b5ef4a59f7f3545e = function(arg0) {
        try {
            const ret = getObject(arg0).next();
            return addHeapObject(ret);
        } catch (e) {
            handleError(e)
        }
    };
    imports.wbg.__wbg_done_aa0321348f9b119f = function(arg0) {
        const ret = getObject(arg0).done;
        return ret;
    };
    imports.wbg.__wbg_value_fa24df8bfb78b31f = function(arg0) {
        const ret = getObject(arg0).value;
        return addHeapObject(ret);
    };
    imports.wbg.__wbg_iterator_9f01936cc2c8bc93 = function() {
        const ret = Symbol.iterator;
        return addHeapObject(ret);
    };
    imports.wbg.__wbg_get_003e1b80a63de7c5 = function(arg0, arg1) {
        try {
            const ret = Reflect.get(getObject(arg0), getObject(arg1));
            return addHeapObject(ret);
        } catch (e) {
            handleError(e)
        }
    };
    imports.wbg.__wbg_call_4499dca0c553c196 = function(arg0, arg1) {
        try {
            const ret = getObject(arg0).call(getObject(arg1));
            return addHeapObject(ret);
        } catch (e) {
            handleError(e)
        }
    };
    imports.wbg.__wbg_new_f802c5ff9d449d95 = function() {
        const ret = new Array();
        return addHeapObject(ret);
    };
    imports.wbg.__wbg_isArray_400c310267077da6 = function(arg0) {
        const ret = Array.isArray(getObject(arg0));
        return ret;
    };
    imports.wbg.__wbg_push_4ba6b2636acd5f79 = function(arg0, arg1) {
        const ret = getObject(arg0).push(getObject(arg1));
        return ret;
    };
    imports.wbg.__wbg_instanceof_ArrayBuffer_ba00e3749ffdb575 = function(arg0) {
        const ret = getObject(arg0) instanceof ArrayBuffer;
        return ret;
    };
    imports.wbg.__wbg_values_7ed05322ff1c068d = function(arg0) {
        const ret = getObject(arg0).values();
        return addHeapObject(ret);
    };
    imports.wbg.__wbg_new_2e9dc2ca6bd84218 = function(arg0, arg1) {
        const ret = new Error(getStringFromWasm(arg0, arg1));
        return addHeapObject(ret);
    };
    imports.wbg.__wbg_buffer_d31feadf69cb45fc = function(arg0) {
        const ret = getObject(arg0).buffer;
        return addHeapObject(ret);
    };
    imports.wbg.__wbg_length_b6e0c5630f641946 = function(arg0) {
        const ret = getObject(arg0).length;
        return ret;
    };
    imports.wbg.__wbg_new_ed7079cf157e44d5 = function(arg0) {
        const ret = new Uint8Array(getObject(arg0));
        return addHeapObject(ret);
    };
    imports.wbg.__wbg_set_2aae8dbe165bf1a3 = function(arg0, arg1, arg2) {
        getObject(arg0).set(getObject(arg1), arg2 >>> 0);
    };
    imports.wbg.__wbg_instanceof_Uint8Array_f0660464bcd7a91a = function(arg0) {
        const ret = getObject(arg0) instanceof Uint8Array;
        return ret;
    };
    imports.wbg.__wbg_byteLength_31959bd9ccac8d4a = function(arg0) {
        const ret = getObject(arg0).byteLength;
        return ret;
    };
    imports.wbg.__wbindgen_number_get = function(arg0, arg1) {
        const obj = getObject(arg0);
        if (typeof(obj) === 'number') return obj;
        getUint8Memory()[arg1] = 1;
        const ret = 0;
        return ret;
    };
    imports.wbg.__wbindgen_string_get = function(arg0, arg1) {
        const obj = getObject(arg0);
        if (typeof(obj) !== 'string') return 0;
        const ptr = passStringToWasm(obj);
        getUint32Memory()[arg1 / 4] = WASM_VECTOR_LEN;
        const ret = ptr;
        return ret;
    };
    imports.wbg.__wbindgen_boolean_get = function(arg0) {
        const v = getObject(arg0);
        const ret = typeof(v) === 'boolean' ? (v ? 1 : 0) : 2;
        return ret;
    };
    imports.wbg.__wbindgen_debug_string = function(arg0, arg1) {
        const ret = debugString(getObject(arg1));
        const ret0 = passStringToWasm(ret);
        const ret1 = WASM_VECTOR_LEN;
        getInt32Memory()[arg0 / 4 + 0] = ret0;
        getInt32Memory()[arg0 / 4 + 1] = ret1;
    };
    imports.wbg.__wbindgen_throw = function(arg0, arg1) {
        throw new Error(getStringFromWasm(arg0, arg1));
    };
    imports.wbg.__wbindgen_memory = function() {
        const ret = wasm.memory;
        return addHeapObject(ret);
    };

    if ((typeof URL === 'function' && module instanceof URL) || typeof module === 'string' || (typeof Request === 'function' && module instanceof Request)) {

        const response = fetch(module);
        if (typeof WebAssembly.instantiateStreaming === 'function') {
            result = WebAssembly.instantiateStreaming(response, imports)
            .catch(e => {
                return response
                .then(r => {
                    if (r.headers.get('Content-Type') != 'application/wasm') {
                        console.warn("`WebAssembly.instantiateStreaming` failed because your server does not serve wasm with `application/wasm` MIME type. Falling back to `WebAssembly.instantiate` which is slower. Original error:\n", e);
                        return r.arrayBuffer();
                    } else {
                        throw e;
                    }
                })
                .then(bytes => WebAssembly.instantiate(bytes, imports));
            });
        } else {
            result = response
            .then(r => r.arrayBuffer())
            .then(bytes => WebAssembly.instantiate(bytes, imports));
        }
    } else {

        result = WebAssembly.instantiate(module, imports)
        .then(result => {
            if (result instanceof WebAssembly.Instance) {
                return { instance: result, module };
            } else {
                return result;
            }
        });
    }
    return result.then(({instance, module}) => {
        wasm = instance.exports;
        init.__wbindgen_wasm_module = module;

        return wasm;
    });
}

export default init;

