#!/bin/bash
set -e

# Build script for DXC (DirectX Shader Compiler) — WebAssembly target
# Clones upstream DXC, applies Emscripten compatibility patches, and builds
# a dxc.js + dxc.wasm pair that can be invoked via Node.js.
#
# Requires: Emscripten SDK (emcmake/emmake on PATH)
#
# The Emscripten patches are derived from Devsh Graphics Programming's work
# (commit 7b909ab0 on their DXC wasm branch). The patches are mechanical
# build-system and compatibility changes — no algorithmic modifications.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${BUILD_DIR:-$SCRIPT_DIR/../build}"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/../output}"
PLATFORM="wasm"

# Query GitHub for latest stable DXC release if version not specified
if [ -z "$DXC_VERSION" ]; then
    echo "Querying GitHub for latest DXC release..."
    DXC_VERSION=$(curl -s https://api.github.com/repos/microsoft/DirectXShaderCompiler/releases/latest \
        | grep '"tag_name"' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
    if [ -z "$DXC_VERSION" ]; then
        echo "Warning: Could not determine latest version, falling back to v1.8.2407"
        DXC_VERSION="v1.8.2407"
    fi
fi

echo "Building DXC $DXC_VERSION for WebAssembly..."

# Verify Emscripten is available
if ! command -v emcmake &> /dev/null; then
    echo "Error: emcmake not found. Install the Emscripten SDK first."
    exit 1
fi

# DXC/LLVM is massive — limit parallelism to avoid OOM
NCPU=2

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Clone DXC
if [ ! -d "dxc-wasm-src" ]; then
    echo "Cloning DirectXShaderCompiler $DXC_VERSION..."
    git clone --depth 1 --branch "$DXC_VERSION" \
        https://github.com/microsoft/DirectXShaderCompiler.git dxc-wasm-src
fi

cd dxc-wasm-src

# Initialize submodules
if [ ! -f "external/SPIRV-Headers/README.md" ]; then
    echo "Initializing submodules..."
    GIT_TERMINAL_PROMPT=0 git submodule update --init --recursive --depth 1
fi

# Verify license exists (fail fast)
echo "Verifying license file..."
if [ ! -f "LICENSE.TXT" ] && [ ! -f "LICENSE.txt" ] && [ ! -f "LICENSE" ]; then
    echo "Error: LICENSE not found in DXC repository"
    exit 1
fi
echo "License file verified"

# Patch CMakeLists.txt for newer CMake compatibility (same as native build)
echo "Patching for CMake compatibility..."
sed -i.bak '/cmake_policy(SET CMP0051 OLD)/d' CMakeLists.txt
if [ -f tools/clang/CMakeLists.txt ]; then
    sed -i.bak 's/cmake_minimum_required(VERSION [0-9.]*)/cmake_minimum_required(VERSION 3.5)/' tools/clang/CMakeLists.txt
fi

# Apply Emscripten compatibility patches
# These are derived from Devsh Graphics Programming's DXC wasm branch (commit 7b909ab0).
# All changes are build-system/compatibility fixes — no functional modifications to DXC.
echo "Applying Emscripten compatibility patches..."
git apply --whitespace=nowarn <<'EMSCRIPTEN_PATCH'
diff --git a/CMakeLists.txt b/CMakeLists.txt
index 238bb39d7d..200e9cff62 100644
--- a/CMakeLists.txt
+++ b/CMakeLists.txt
@@ -433,7 +433,7 @@ if(LLVM_DISABLE_LLVM_DYLIB_ATEXIT)
 endif()

 option(LLVM_OPTIMIZED_TABLEGEN "Force TableGen to be built with optimization" OFF)
-if(CMAKE_CROSSCOMPILING OR (LLVM_OPTIMIZED_TABLEGEN AND LLVM_ENABLE_ASSERTIONS))
+if((CMAKE_CROSSCOMPILING OR (LLVM_OPTIMIZED_TABLEGEN AND LLVM_ENABLE_ASSERTIONS)) AND NOT DEFINED LLVM_USE_HOST_TOOLS)
   set(LLVM_USE_HOST_TOOLS ON)
 endif()

diff --git a/cmake/modules/CrossCompile.cmake b/cmake/modules/CrossCompile.cmake
index 76a3078a54..e99884332e 100644
--- a/cmake/modules/CrossCompile.cmake
+++ b/cmake/modules/CrossCompile.cmake
@@ -1,4 +1,4 @@
-function(llvm_create_cross_target_internal target_name toochain buildtype)
+function(llvm_create_cross_target_internal target_name toolchain buildtype)

   if(NOT DEFINED LLVM_${target_name}_BUILD)
     set(LLVM_${target_name}_BUILD "${CMAKE_BINARY_DIR}/${target_name}")
@@ -12,12 +12,45 @@ function(llvm_create_cross_target_internal target_name toochain buildtype)
         CACHE STRING "Toolchain file for ${target_name}")
   endif()

+  set(_native_compiler_flags_${target_name})
+  set(_native_config_flags_${target_name})
+  if(${target_name} STREQUAL "NATIVE")
+    if(NOT LLVM_NATIVE_C_COMPILER)
+      find_program(LLVM_NATIVE_C_COMPILER NAMES clang gcc cc)
+    endif()
+    if(NOT LLVM_NATIVE_CXX_COMPILER)
+      find_program(LLVM_NATIVE_CXX_COMPILER NAMES clang++ g++ c++)
+    endif()
+    if(LLVM_NATIVE_C_COMPILER)
+      list(APPEND _native_compiler_flags_${target_name} -DCMAKE_C_COMPILER=${LLVM_NATIVE_C_COMPILER})
+    endif()
+    if(LLVM_NATIVE_CXX_COMPILER)
+      list(APPEND _native_compiler_flags_${target_name} -DCMAKE_CXX_COMPILER=${LLVM_NATIVE_CXX_COMPILER})
+    endif()
+    list(APPEND _native_config_flags_${target_name}
+      -DLLVM_INCLUDE_TESTS=OFF
+      -DHLSL_INCLUDE_TESTS=OFF
+      -DSPIRV_BUILD_TESTS=OFF
+      -DLLVM_INCLUDE_EXAMPLES=OFF)
+    if(DEFINED LLVM_ENABLE_EH)
+      list(APPEND _native_config_flags_${target_name} -DLLVM_ENABLE_EH=${LLVM_ENABLE_EH})
+    endif()
+    if(DEFINED LLVM_ENABLE_RTTI)
+      list(APPEND _native_config_flags_${target_name} -DLLVM_ENABLE_RTTI=${LLVM_ENABLE_RTTI})
+    endif()
+    if(DEFINED ENABLE_SPIRV_CODEGEN)
+      list(APPEND _native_config_flags_${target_name} -DENABLE_SPIRV_CODEGEN=${ENABLE_SPIRV_CODEGEN})
+    endif()
+  endif()

   add_custom_command(OUTPUT ${LLVM_${target_name}_BUILD}
     COMMAND ${CMAKE_COMMAND} -E make_directory ${LLVM_${target_name}_BUILD}
     COMMENT "Creating ${LLVM_${target_name}_BUILD}...")

   add_custom_command(OUTPUT ${LLVM_${target_name}_BUILD}/CMakeCache.txt
     COMMAND ${CMAKE_COMMAND} -G "${CMAKE_GENERATOR}"
+        ${_native_compiler_flags_${target_name}}
+        ${_native_config_flags_${target_name}}
         ${CROSS_TOOLCHAIN_FLAGS_${target_name}} ${CMAKE_SOURCE_DIR}
     WORKING_DIRECTORY ${LLVM_${target_name}_BUILD}
     DEPENDS ${LLVM_${target_name}_BUILD}
@@ -42,6 +75,8 @@ function(llvm_create_cross_target_internal target_name toochain buildtype)
     endif()
     execute_process(COMMAND ${CMAKE_COMMAND} ${build_type_flags}
         -G "${CMAKE_GENERATOR}" -DLLVM_TARGETS_TO_BUILD=${LLVM_TARGETS_TO_BUILD}
+        ${_native_compiler_flags_${target_name}}
+        ${_native_config_flags_${target_name}}
         ${CROSS_TOOLCHAIN_FLAGS_${target_name}} ${CMAKE_SOURCE_DIR}
       WORKING_DIRECTORY ${LLVM_${target_name}_BUILD} )
   endif(NOT IS_DIRECTORY ${LLVM_${target_name}_BUILD})
diff --git a/cmake/modules/GetHostTriple.cmake b/cmake/modules/GetHostTriple.cmake
index 671a8ce7d7..c6d0b05bd5 100644
--- a/cmake/modules/GetHostTriple.cmake
+++ b/cmake/modules/GetHostTriple.cmake
@@ -8,22 +8,40 @@ function( get_host_triple var )
     else()
       set( value "i686-pc-win32" )
     endif()
+  elseif( CMAKE_SYSTEM_NAME STREQUAL "Emscripten" )
+    set( value "wasm32-unknown-emscripten" )
   elseif( MINGW AND NOT MSYS )
     if( CMAKE_SIZEOF_VOID_P EQUAL 8 )
       set( value "x86_64-w64-mingw32" )
     else()
       set( value "i686-pc-mingw32" )
     endif()
+  elseif( CMAKE_HOST_WIN32 )
+    string(TOLOWER "${CMAKE_HOST_SYSTEM_PROCESSOR}" _host_proc)
+    if( _host_proc MATCHES "amd64|x86_64" )
+      set( value "x86_64-pc-windows-msvc" )
+    elseif( _host_proc MATCHES "arm64|aarch64" )
+      set( value "aarch64-pc-windows-msvc" )
+    else()
+      set( value "i686-pc-windows-msvc" )
+    endif()
   else( MSVC )
     set(config_guess ${LLVM_MAIN_SRC_DIR}/autoconf/config.guess)
-    execute_process(COMMAND sh ${config_guess}
-      RESULT_VARIABLE TT_RV
-      OUTPUT_VARIABLE TT_OUT
-      OUTPUT_STRIP_TRAILING_WHITESPACE)
-    if( NOT TT_RV EQUAL 0 )
-      message(FATAL_ERROR "Failed to execute ${config_guess}")
-    endif( NOT TT_RV EQUAL 0 )
-    set( value ${TT_OUT} )
+    find_program(_host_sh NAMES sh)
+    if( _host_sh AND EXISTS ${config_guess} )
+      execute_process(COMMAND ${_host_sh} ${config_guess}
+        RESULT_VARIABLE TT_RV
+        OUTPUT_VARIABLE TT_OUT
+        OUTPUT_STRIP_TRAILING_WHITESPACE)
+      if( TT_RV EQUAL 0 )
+        set( value ${TT_OUT} )
+      else()
+        message(FATAL_ERROR "Failed to execute ${config_guess}")
+      endif()
+    else()
+      set( value "${CMAKE_HOST_SYSTEM_PROCESSOR}-unknown-${CMAKE_HOST_SYSTEM_NAME}" )
+      string(TOLOWER "${value}" value)
+    endif()
   endif( MSVC )
   set( ${var} ${value} PARENT_SCOPE )
   message(STATUS "Target triple: ${value}")
diff --git a/include/dxc/Support/dxcapi.use.h b/include/dxc/Support/dxcapi.use.h
index d7fe9681e1..b7d6b3bf64 100644
--- a/include/dxc/Support/dxcapi.use.h
+++ b/include/dxc/Support/dxcapi.use.h
@@ -83,6 +83,12 @@ class SpecificDllLoader : public DllLoader {
       return hr;
     }
 #else
+#ifdef __EMSCRIPTEN__
+    m_dll = reinterpret_cast<HMODULE>(this);
+    m_createFn = &DxcCreateInstance;
+    m_createFn2 = &DxcCreateInstance2;
+    return S_OK;
+#endif
     m_dll = ::dlopen(
         dllName, RTLD_LAZY);

@@ -170,8 +176,13 @@ class SpecificDllLoader : public DllLoader {
       m_createFn2 = nullptr;
 #ifdef _WIN32
       FreeLibrary(m_dll);
+#else
+#ifdef __EMSCRIPTEN__
+      // Emscripten path binds directly to in-module DxcCreateInstance* symbols.
+      // There is no runtime-loaded dynamic library to close.
 #else
       ::dlclose(m_dll);
+#endif
 #endif
       m_dll = nullptr;
     }
diff --git a/include/llvm/ADT/StringRef.h b/include/llvm/ADT/StringRef.h
index c103fdbf3b..416dcea3e6 100644
--- a/include/llvm/ADT/StringRef.h
+++ b/include/llvm/ADT/StringRef.h
@@ -574,6 +574,7 @@ namespace llvm {
 // StringRef provides an operator string; that trips up the std::pair noexcept specification,
 // which (a) enables the moves constructor (because conversion is allowed), but (b)
 // misclassifies the the construction as nothrow.
+#if !defined(__EMSCRIPTEN__)
 namespace std {
   template<>
   struct is_nothrow_constructible <std::string, llvm::StringRef>
@@ -588,6 +589,7 @@ namespace std {
     : std::false_type {
   };
 }
+#endif
 // HLSL Change Ends

 #endif
diff --git a/lib/DxcSupport/dxcmem.cpp b/lib/DxcSupport/dxcmem.cpp
index 70eabfbc87..f4527132c6 100644
--- a/lib/DxcSupport/dxcmem.cpp
+++ b/lib/DxcSupport/dxcmem.cpp
@@ -67,7 +67,7 @@ IMalloc *DxcGetThreadMallocNoRef() throw() {
     // And if you're overriding the `new`&`delete` operators globally,
     // its nice to not have them depend on global state or deference nullptrs.
     if (!g_pDefaultMalloc)
-      CoGetMalloc(1, &g_pDefaultMalloc);
+      DxcCoGetMalloc(1, &g_pDefaultMalloc);
     return g_pDefaultMalloc;
   }

diff --git a/tools/clang/lib/Frontend/Rewrite/RewriteObjC.cpp b/tools/clang/lib/Frontend/Rewrite/RewriteObjC.cpp
index 204820b304..f48b0d4aa6 100644
--- a/tools/clang/lib/Frontend/Rewrite/RewriteObjC.cpp
+++ b/tools/clang/lib/Frontend/Rewrite/RewriteObjC.cpp
@@ -483,7 +483,8 @@ namespace {
         result =  Context->getObjCIdType();
       FunctionProtoType::ExtProtoInfo fpi;
       fpi.Variadic = variadic;
-      return Context->getFunctionType(result, args, fpi);
+      return Context->getFunctionType(result, args, fpi,
+                                      ArrayRef<hlsl::ParameterModifier>());
     }

diff --git a/tools/clang/tools/dxc/CMakeLists.txt b/tools/clang/tools/dxc/CMakeLists.txt
index 9df8da3463..6961696507 100644
--- a/tools/clang/tools/dxc/CMakeLists.txt
+++ b/tools/clang/tools/dxc/CMakeLists.txt
@@ -41,6 +41,10 @@ include_directories(${LLVM_SOURCE_DIR}/tools/clang/tools)

 add_dependencies(dxc dxclib dxcompiler)

+if(EMSCRIPTEN)
+  target_link_options(dxc PRIVATE "SHELL:-sNODERAWFS=1")
+endif()
+
 if(UNIX)
   set(CLANGXX_LINK_OR_COPY create_symlink)
 # Create a relative symlink
diff --git a/tools/clang/utils/TableGen/CMakeLists.txt b/tools/clang/utils/TableGen/CMakeLists.txt
index 9762ac4ee4..37713c6b19 100644
--- a/tools/clang/utils/TableGen/CMakeLists.txt
+++ b/tools/clang/utils/TableGen/CMakeLists.txt
@@ -11,3 +11,7 @@ add_tablegen(clang-tblgen CLANG
   NeonEmitter.cpp
   TableGen.cpp
   )
+
+if(EMSCRIPTEN)
+  target_link_options(clang-tblgen PRIVATE "SHELL:-sNODERAWFS=1")
+endif()
diff --git a/tools/llvm-config/CMakeLists.txt b/tools/llvm-config/CMakeLists.txt
index edbd8c950d..18d192c1ae 100644
--- a/tools/llvm-config/CMakeLists.txt
+++ b/tools/llvm-config/CMakeLists.txt
@@ -37,7 +37,7 @@ add_definitions(-DCMAKE_CFG_INTDIR="${CMAKE_CFG_INTDIR}")
 # Add the dependency on the generation step.
 add_file_dependencies(${CMAKE_CURRENT_SOURCE_DIR}/llvm-config.cpp ${BUILDVARIABLES_OBJPATH})

-if(CMAKE_CROSSCOMPILING)
+if(CMAKE_CROSSCOMPILING AND LLVM_USE_HOST_TOOLS)
   set(${project}_LLVM_CONFIG_EXE "${LLVM_NATIVE_BUILD}/bin/llvm-config")
   set(${project}_LLVM_CONFIG_EXE ${${project}_LLVM_CONFIG_EXE} PARENT_SCOPE)

diff --git a/utils/TableGen/CMakeLists.txt b/utils/TableGen/CMakeLists.txt
index 6b9168c000..7f5454c1cd 100644
--- a/utils/TableGen/CMakeLists.txt
+++ b/utils/TableGen/CMakeLists.txt
@@ -36,3 +36,7 @@ add_tablegen(llvm-tblgen LLVM
   TableGen.cpp
   CTagsEmitter.cpp
   )
+
+if(EMSCRIPTEN)
+  target_link_options(llvm-tblgen PRIVATE "SHELL:-sNODERAWFS=1")
+endif()
EMSCRIPTEN_PATCH

echo "Emscripten patches applied successfully"

# Configure DXC for WebAssembly
mkdir -p build
cd build

echo "Configuring DXC for WebAssembly..."
emcmake cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_USE_HOST_TOOLS=OFF \
    -DENABLE_SPIRV_CODEGEN=ON \
    -DSPIRV_BUILD_TESTS=OFF \
    -DCLANG_ENABLE_ARCMT=OFF \
    -DCLANG_ENABLE_STATIC_ANALYZER=OFF \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLVM_TARGETS_TO_BUILD="" \
    -DHLSL_ENABLE_ANALYZE=OFF \
    -DHLSL_BUILD_DXILCONV=OFF \
    -DHLSL_INCLUDE_TESTS=OFF \
    -DCLANG_INCLUDE_TESTS=OFF \
    -DHAVE_CXX_ATOMICS_WITHOUT_LIB=TRUE \
    -DHAVE_CXX_ATOMICS64_WITHOUT_LIB=TRUE

echo "Building DXC for WebAssembly (this may take 20-40 minutes)..."
emmake cmake --build . --config Release --target dxc -j$NCPU

# Package output
PACKAGE_DIR="$OUTPUT_DIR/dxc-$PLATFORM"
mkdir -p "$PACKAGE_DIR/bin"

echo "Packaging DXC WASM..."
# Emscripten produces a .js loader and .wasm binary
find bin -name "dxc.js" -exec cp {} "$PACKAGE_DIR/bin/" \; 2>/dev/null || true
find bin -name "dxc.wasm" -exec cp {} "$PACKAGE_DIR/bin/" \; 2>/dev/null || true

# Verify we got the outputs
if [ ! -f "$PACKAGE_DIR/bin/dxc.js" ] || [ ! -f "$PACKAGE_DIR/bin/dxc.wasm" ]; then
    echo "Error: Expected dxc.js and dxc.wasm not found in build output"
    echo "Build output contents:"
    find bin -type f -name "dxc*" 2>/dev/null || echo "  (no dxc files found in bin/)"
    ls -la bin/ 2>/dev/null || true
    exit 1
fi

# Copy licenses - preserve structure from source repo
echo "Packaging licenses..."
cd "$BUILD_DIR/dxc-wasm-src"
mkdir -p "$PACKAGE_DIR/licenses/dxc/LICENSES"

# Main license
if [ -f "LICENSE.TXT" ]; then
    cp "LICENSE.TXT" "$PACKAGE_DIR/licenses/dxc/LICENSE.TXT"
elif [ -f "LICENSE.txt" ]; then
    cp "LICENSE.txt" "$PACKAGE_DIR/licenses/dxc/LICENSE.txt"
else
    cp "LICENSE" "$PACKAGE_DIR/licenses/dxc/LICENSE"
fi

# Additional component licenses
if [ -f "lib/DxilCompression/LICENSE.TXT" ]; then
    cp "lib/DxilCompression/LICENSE.TXT" "$PACKAGE_DIR/licenses/dxc/LICENSES/DxilCompression-LICENSE.TXT"
fi

# Create archive
cd "$OUTPUT_DIR"
tar -czf "dxc-${PLATFORM}.tar.gz" "dxc-$PLATFORM"
echo "Created: dxc-${PLATFORM}.tar.gz"

echo "Build complete!"
