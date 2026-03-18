# Redistributables

This repository provides automatically-built binaries of essential tools created by Other:

- **glslang** - GLSL to SPIRV compiler with optimizer support
  - Includes SPIRV-Tools (optimizer and validator)
  - Includes SPIRV-Headers (required headers)
- **SPIRV-Cross** - SPIRV to GLSL/HLSL/MSL/WGSL transpiler
- **DXC** - DirectX Shader Compiler (HLSL to SPIRV/DXIL)
- **Naga** - WebGPU shader compiler (WGSL to SPIRV)

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
  - DXC from Microsoft NuGet (Windows) and GitHub Releases (Linux)
  - glslang from KhronosGroup GitHub Releases
  - SPIRV-Cross from Vulkan SDK tags
  - Naga from wgpu releases
- Auto-creates releases when new versions are detected
- Version numbering automatically increments (e.g., v0.0.42 → v0.0.43)

### Build Process
- All platforms built from latest stable sources
- Windows uses official Microsoft DXC binaries from NuGet
- Linux/macOS build from source for maximum compatibility
- Releases include all binaries for all platforms

## Procurement and Materialization

### DXC (DirectX Shader Compiler)

**Windows:**
- Downloaded from official Microsoft NuGet package: `Microsoft.Direct3D.DXC`
- Latest version automatically queried from NuGet API
- AMD64 and ARM64 both available
- Licensed for redistribution
- Includes `dxc.exe`, `dxcompiler.dll`, and `dxil.dll`

**Linux:**
- Downloaded from Microsoft DirectXShaderCompiler GitHub Releases
- Latest release automatically detected

**macOS:**
- Built from source (Microsoft DirectXShaderCompiler main branch)
- Cross-compiled for both Intel and Apple Silicon

### glslang
- Built from latest GitHub release tag
- Includes SPIRV-Tools and SPIRV-Headers
- All platforms built from source

### SPIRV-Cross
- Built from latest Vulkan SDK tag
- All platforms built from source

### Naga
- Built from latest wgpu release
- Rust-based WGSL to SPIRV compiler
- All platforms built from source

## License

These are open-source projects which carry their licensure alongside them when requisitioned 
by `enigmatic` - this ensures we always produce the latest and most current licenses for each 
redistributable.  No binaries are held in the code, only in the releases fetched or built 
through requisitioning from stable official sources of truth.