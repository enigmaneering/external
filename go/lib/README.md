# External - Go Module

Go package for shader compilation toolchain binaries with embedded support.

## Features

- **Embedded binaries** - no network requests, no GitHub API calls
- **Automatic extraction** - binaries extracted to `./external/` on first use
- **Platform detection** - automatically selects correct binaries for your OS/architecture
- **Version tracking** - prevents redundant extractions
- **Freeze mechanism** - create `external/FREEZE` file to disable automatic extraction

## Usage

```go
import external "github.com/enigmaneering/external/go/lib"

func main() {
    // Extract embedded binaries if not already present
    if err := external.EnsureLibraries(); err != nil {
        log.Fatal(err)
    }

    // Libraries now available in ./external/
    // - external/glslang/
    // - external/spirv-cross/
    // - external/dxc/
    // - external/naga/
}
```

## How It Works

1. **Embedded** - All platform binaries (~292MB total) embedded using `//go:embed`
2. **Platform detection** - Detects your OS and architecture at runtime
3. **Extraction** - Extracts only the ~30MB of binaries for your platform
4. **Caching** - Writes `.version` file to avoid re-extracting

## Module Size

The Go module download is **~292MB** because it includes binaries for all platforms:
- darwin-amd64, darwin-arm64
- linux-amd64, linux-arm64
- windows-amd64, windows-arm64

But only **~30MB** is extracted for your specific platform.

## Freezing Versions

To prevent automatic extraction checks, create a `FREEZE` file:

```bash
touch external/FREEZE
```

When the `FREEZE` file exists:
- `EnsureLibraries()` becomes a no-op if libraries are already present
- No version checks are performed
- Message displayed: `External libraries frozen at version v0.0.44`

To re-enable automatic checks:

```bash
rm external/FREEZE
```

**Note**: The `FREEZE` file should not be committed to version control.

## Configuration

Set the `EXTERNAL_DIR` environment variable to change the installation directory:

```bash
export EXTERNAL_DIR=/path/to/custom/external
```

## Supported Platforms

| OS      | Architecture | Status |
|---------|--------------|--------|
| macOS   | amd64 (Intel)| ✅     |
| macOS   | arm64 (Apple Silicon) | ✅ |
| Linux   | amd64        | ✅     |
| Linux   | arm64        | ✅     |
| Windows | amd64        | ✅     |
| Windows | arm64        | ✅     |

## Included Libraries

- **glslang**: GLSL to SPIRV compiler with optimizer
- **SPIRV-Cross**: SPIRV transpiler (GLSL/HLSL/MSL/WGSL)
- **DXC**: DirectX Shader Compiler (HLSL to SPIRV/DXIL)
- **Naga**: WebGPU shader compiler (WGSL to SPIRV)

## Version

Current embedded version: **v0.0.44**

Includes latest stable releases from:
- glslang (KhronosGroup)
- SPIRV-Cross (Vulkan SDK)
- DXC (Microsoft DirectXShaderCompiler)
- Naga (wgpu project)
