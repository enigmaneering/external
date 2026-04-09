# Redistributables

This repository provides automatically-built binaries of essential tools created by Other:

- **[glslang](https://github.com/KhronosGroup/glslang)** - GLSL to SPIRV compiler with optimizer support
  - Includes [SPIRV-Tools](https://github.com/KhronosGroup/SPIRV-Tools) (optimizer and validator)
  - Includes [SPIRV-Headers](https://github.com/KhronosGroup/SPIRV-Headers) (required headers)
- **[SPIRV-Cross](https://github.com/KhronosGroup/SPIRV-Cross)** - SPIRV to GLSL/HLSL/MSL/WGSL transpiler
- **[DXC](https://github.com/microsoft/DirectXShaderCompiler)** - DirectX Shader Compiler (HLSL to SPIRV/DXIL)
- **[Naga](https://github.com/gfx-rs/wgpu/tree/trunk/naga)** - WebGPU shader compiler (WGSL to SPIRV)
- **[wgpu-native](https://github.com/gfx-rs/wgpu-native)** - Cross-platform WebGPU implementation (GPU compute via Metal/Vulkan/D3D12/OpenGL)

## Supported Platforms

- macOS ARM64 (Apple Silicon)
- macOS x86_64 (Intel)
- Linux x86_64
- Linux ARM64
- Windows x86_64
- Windows ARM64

GitHub Actions will automatically build and release all platforms.

## Usage

### Using the `e` CLI Tool (Recommended)

The easiest way to download and manage these redistributables is via [enigmatic (`e`)](https://git.enigmaneering.org/enigmatic) -

```bash
# Install latest toolchain
e fetch

# Install specific version
e fetch -version v0.0.42

# Install to custom directory
e fetch -dir /opt/shaders
```

### Using the Go Module

Automatically download and manage toolchain binaries in your Go projects:

```go
import "git.enigmaneering.org/enigmatic/gpu"

func main() {
    // Downloads and extracts latest toolchain to ./external/
    if err := gpu.EnsureLibraries(); err != nil {
        log.Fatal(err)
    }
}
```

Install:
```bash
go get git.enigmaneering.org/enigmatic@latest
```

## Automatic Updates

This repository features a fully automated release pipeline:

### Daily Version Checks
- Automated workflow runs daily at 2 AM UTC
- Queries upstream sources for latest stable releases:
  - DXC from [Microsoft NuGet](https://www.nuget.org/packages/Microsoft.Direct3D.DXC) (Windows) and [GitHub Releases](https://github.com/microsoft/DirectXShaderCompiler/releases) (Linux)
  - glslang from [KhronosGroup GitHub Releases](https://github.com/KhronosGroup/glslang/releases)
  - SPIRV-Cross from [Vulkan SDK tags](https://github.com/KhronosGroup/SPIRV-Cross/tags)
  - Naga from [wgpu releases](https://github.com/gfx-rs/wgpu/releases)
  - wgpu-native from [gfx-rs/wgpu-native GitHub Releases](https://github.com/gfx-rs/wgpu-native/releases)
- Auto-creates releases when new versions are detected
- Version numbering automatically increments (e.g., v0.0.42 → v0.0.43)

### Build Process
- All platforms built from latest stable sources
- Windows uses official Microsoft DXC binaries from [NuGet](https://www.nuget.org/packages/Microsoft.Direct3D.DXC)
- Linux/macOS build from source for maximum compatibility
- Releases include all binaries for all platforms

## Procurement and Materialization

### DXC (DirectX Shader Compiler)

**Windows:**
- Downloaded from official [Microsoft NuGet package](https://www.nuget.org/packages/Microsoft.Direct3D.DXC): `Microsoft.Direct3D.DXC`
- Latest version automatically queried from NuGet API
- AMD64 and ARM64 both available
- Licensed for redistribution
- Includes `dxc.exe`, `dxcompiler.dll`, and `dxil.dll`

**Linux:**
- Downloaded from [Microsoft DirectXShaderCompiler GitHub Releases](https://github.com/microsoft/DirectXShaderCompiler/releases)
- Latest release automatically detected

**macOS:**
- Built from source ([Microsoft DirectXShaderCompiler](https://github.com/microsoft/DirectXShaderCompiler) main branch)
- Cross-compiled for both Intel and Apple Silicon

### glslang
- Built from latest [GitHub release tag](https://github.com/KhronosGroup/glslang/releases)
- Includes [SPIRV-Tools](https://github.com/KhronosGroup/SPIRV-Tools) and [SPIRV-Headers](https://github.com/KhronosGroup/SPIRV-Headers)
- All platforms built from source

### SPIRV-Cross
- Built from latest [Vulkan SDK tag](https://github.com/KhronosGroup/SPIRV-Cross/tags)
- All platforms built from source

### Naga
- Built from latest [wgpu release](https://github.com/gfx-rs/wgpu/releases)
- Rust-based WGSL to SPIRV compiler
- All platforms built from source

### wgpu-native
- Downloaded from latest [gfx-rs/wgpu-native GitHub Release](https://github.com/gfx-rs/wgpu-native/releases)
- Cross-platform WebGPU implementation backed by Vulkan, Metal, D3D12, and OpenGL
- Provides headers (`webgpu.h`, `wgpu.h`) and libraries (static + dynamic)
- Runtime-loaded by libmental via dlopen — no link-time dependency
- Dual-licensed: MIT + Apache 2.0
- All 6 platforms provided as prebuilt binaries

## License

These are open-source projects which carry their licensure alongside them when requisitioned
by `enigmatic` - this ensures we always produce the latest and most current licenses for each
redistributable.  No binaries are held in the code, only in the releases fetched or built
through requisitioning from stable official sources of truth.
