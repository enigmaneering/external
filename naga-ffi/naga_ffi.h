/*
 * naga_ffi.h — C FFI for Naga WGSL ↔ SPIRV transpilation
 *
 * This header provides the C interface to the naga-ffi static library,
 * which wraps the Rust-based Naga shader compiler for use in non-Rust
 * projects (specifically libmental's Emscripten/WASM build).
 */

#ifndef NAGA_FFI_H
#define NAGA_FFI_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Compile WGSL source to SPIRV binary.
 *
 * Returns 0 on success, non-zero on failure.
 * On success, *spirv_out points to the SPIRV binary and *spirv_len is its size.
 * On failure, *spirv_out points to a UTF-8 error message and *spirv_len is its length.
 * The caller must free the returned buffer with naga_free().
 */
int naga_wgsl_to_spirv(const uint8_t *wgsl_source, uint32_t wgsl_len,
                        uint8_t **spirv_out, uint32_t *spirv_len);

/*
 * Convert SPIRV binary to WGSL source.
 *
 * Returns 0 on success, non-zero on failure.
 * On success, *wgsl_out points to a UTF-8 WGSL string and *wgsl_len is its length.
 * On failure, *wgsl_out points to a UTF-8 error message and *wgsl_len is its length.
 * The caller must free the returned buffer with naga_free().
 */
int naga_spirv_to_wgsl(const uint8_t *spirv_data, uint32_t spirv_len,
                        uint8_t **wgsl_out, uint32_t *wgsl_len);

/*
 * Free a buffer previously returned by naga_wgsl_to_spirv or naga_spirv_to_wgsl.
 */
void naga_free(uint8_t *ptr, uint32_t len);

#ifdef __cplusplus
}
#endif

#endif /* NAGA_FFI_H */
