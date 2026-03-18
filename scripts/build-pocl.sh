#!/bin/bash
set -e

# Build script for POCL (Portable Computing Language)
# Outputs a relocatable package with libpocl.so and headers
# POCL is built with LLVM support for runtime kernel compilation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${BUILD_DIR:-$SCRIPT_DIR/../build}"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/../output}"

# Query GitHub for latest release if not specified
if [ -z "$POCL_VERSION" ]; then
    echo "Querying GitHub for latest POCL release..."
    POCL_VERSION=$(curl -s https://api.github.com/repos/pocl/pocl/releases/latest | grep '"tag_name"' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
    if [ -z "$POCL_VERSION" ]; then
        echo "Error: Could not determine latest POCL version, falling back to v5.0"
        POCL_VERSION="v5.0"
    else
        echo "Latest release: $POCL_VERSION"
    fi
fi

# Detect platform
if [[ "$OSTYPE" == "darwin"* ]]; then
    ARCH=$(uname -m)
    # Override with MACOS_ARCH if provided (for cross-compilation)
    if [ -n "$MACOS_ARCH" ]; then
        ARCH="$MACOS_ARCH"
    fi
    PLATFORM="darwin-$ARCH"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM="linux-$(uname -m)"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
    # Use CROSS_COMPILE_TARGET if set, otherwise detect from uname
    if [ -n "$CROSS_COMPILE_TARGET" ]; then
        ARCH="$CROSS_COMPILE_TARGET"
    else
        ARCH=$(uname -m)
    fi
    PLATFORM="windows-$ARCH"
fi

# Normalize architecture names
PLATFORM=$(echo "$PLATFORM" | sed 's/x86_64/amd64/g' | sed 's/aarch64/arm64/g')

echo "Building POCL $POCL_VERSION for $PLATFORM..."

# Detect number of CPU cores
if [[ "$OSTYPE" == "darwin"* ]]; then
    NCPU=$(sysctl -n hw.ncpu)
else
    NCPU=$(nproc)
fi

# Create build directories
mkdir -p "$BUILD_DIR/pocl"
mkdir -p "$OUTPUT_DIR"

cd "$BUILD_DIR/pocl"

# Clone POCL repository if not already present
if [ ! -d "pocl" ]; then
    echo "Cloning POCL repository..."
    git clone https://github.com/pocl/pocl.git
fi

cd pocl
git fetch --all --tags
git checkout "$POCL_VERSION"

# Update submodules if present
if [ -f .gitmodules ]; then
    git submodule update --init --recursive
fi

# Create build directory
rm -rf build
mkdir build
cd build

# Determine LLVM configuration
# POCL requires LLVM - we'll use system LLVM or download it
echo "Detecting LLVM installation..."

# Try to find LLVM via llvm-config
LLVM_CONFIG=""
for ver in 18 17 16 15 14 13 12 11 10; do
    if command -v llvm-config-$ver &> /dev/null; then
        LLVM_CONFIG="llvm-config-$ver"
        break
    fi
done

if [ -z "$LLVM_CONFIG" ] && command -v llvm-config &> /dev/null; then
    LLVM_CONFIG="llvm-config"
fi

if [ -z "$LLVM_CONFIG" ]; then
    echo "Warning: No LLVM installation found. POCL requires LLVM."
    echo "Please install LLVM:"
    echo "  Ubuntu/Debian: sudo apt install llvm-dev clang"
    echo "  macOS: brew install llvm"
    echo "  Fedora: sudo dnf install llvm-devel clang"
    exit 1
fi

LLVM_VERSION=$($LLVM_CONFIG --version)
echo "Found LLVM $LLVM_VERSION at $($LLVM_CONFIG --prefix)"

# Configure CMake build
# We want a relocatable shared library build with LLVM support
echo "Configuring POCL build..."

cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/pocl/install" \
    -DENABLE_LLVM=ON \
    -DLLVM_CONFIG="$LLVM_CONFIG" \
    -DBUILD_SHARED_LIBS=ON \
    -DENABLE_ICD=ON \
    -DINSTALL_OPENCL_HEADERS=ON \
    -DENABLE_TESTS=OFF \
    -DENABLE_EXAMPLES=OFF \
    ..

echo "Building POCL with $NCPU cores..."
cmake --build . --parallel $NCPU

echo "Installing POCL to temporary location..."
cmake --install .

# Package the installation
INSTALL_DIR="$BUILD_DIR/pocl/install"
PACKAGE_NAME="pocl-$PLATFORM"

echo "Creating relocatable package..."
cd "$BUILD_DIR/pocl"
rm -rf "$PACKAGE_NAME"
mkdir -p "$PACKAGE_NAME"

# Copy libraries
if [[ "$PLATFORM" == darwin-* ]]; then
    # macOS: .dylib files
    mkdir -p "$PACKAGE_NAME/lib"
    cp -r "$INSTALL_DIR/lib/"libpocl*.dylib* "$PACKAGE_NAME/lib/" 2>/dev/null || true
    cp -r "$INSTALL_DIR/lib/pocl" "$PACKAGE_NAME/lib/" 2>/dev/null || true
elif [[ "$PLATFORM" == linux-* ]]; then
    # Linux: .so files
    mkdir -p "$PACKAGE_NAME/lib"
    cp -r "$INSTALL_DIR/lib/"libpocl*.so* "$PACKAGE_NAME/lib/" 2>/dev/null || true
    cp -r "$INSTALL_DIR/lib/pocl" "$PACKAGE_NAME/lib/" 2>/dev/null || true

    # Also check lib64 on some Linux distros
    if [ -d "$INSTALL_DIR/lib64" ]; then
        cp -r "$INSTALL_DIR/lib64/"libpocl*.so* "$PACKAGE_NAME/lib/" 2>/dev/null || true
        cp -r "$INSTALL_DIR/lib64/pocl" "$PACKAGE_NAME/lib/" 2>/dev/null || true
    fi
elif [[ "$PLATFORM" == windows-* ]]; then
    # Windows: .dll files
    mkdir -p "$PACKAGE_NAME/bin"
    cp -r "$INSTALL_DIR/bin/"*.dll "$PACKAGE_NAME/bin/" 2>/dev/null || true
    mkdir -p "$PACKAGE_NAME/lib"
    cp -r "$INSTALL_DIR/lib/"*.lib "$PACKAGE_NAME/lib/" 2>/dev/null || true
fi

# Copy headers
if [ -d "$INSTALL_DIR/include" ]; then
    cp -r "$INSTALL_DIR/include" "$PACKAGE_NAME/"
fi

# Copy ICD configuration if present
if [ -d "$INSTALL_DIR/etc" ]; then
    mkdir -p "$PACKAGE_NAME/etc"
    cp -r "$INSTALL_DIR/etc/OpenCL" "$PACKAGE_NAME/etc/" 2>/dev/null || true
fi

# Create README
cat > "$PACKAGE_NAME/README.md" << EOF
# POCL (Portable Computing Language)

Version: $POCL_VERSION
Platform: $PLATFORM
Built: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
LLVM Version: $LLVM_VERSION

## What is POCL?

POCL is an open-source implementation of the OpenCL standard which can be used
to run OpenCL programs on CPUs. It includes LLVM-based runtime compilation
for OpenCL kernels.

## License

POCL is released under the MIT license. See https://github.com/pocl/pocl

## Usage

This package contains:
- libpocl shared library (OpenCL CPU runtime)
- OpenCL headers
- POCL runtime components

To use POCL, ensure the library is in your library path:

### Linux
\`\`\`bash
export LD_LIBRARY_PATH=\$(pwd)/lib:\$LD_LIBRARY_PATH
\`\`\`

### macOS
\`\`\`bash
export DYLD_LIBRARY_PATH=\$(pwd)/lib:\$DYLD_LIBRARY_PATH
\`\`\`

### Windows
Add the bin/ directory to your PATH.

## Testing

You can verify POCL is working by checking for OpenCL platforms:

\`\`\`bash
# Install clinfo (Ubuntu: sudo apt install clinfo)
clinfo
\`\`\`

POCL should appear as a CPU device in the platform list.

## More Information

- Project website: https://portablecl.org
- GitHub: https://github.com/pocl/pocl
- Documentation: https://portablecl.org/docs/html/
EOF

# Create version file
echo "$POCL_VERSION" > "$PACKAGE_NAME/VERSION"
echo "$LLVM_VERSION" > "$PACKAGE_NAME/LLVM_VERSION"

# Create tarball
echo "Creating tarball..."
tar -czf "$OUTPUT_DIR/$PACKAGE_NAME.tar.gz" "$PACKAGE_NAME"

# Calculate size
SIZE=$(du -h "$OUTPUT_DIR/$PACKAGE_NAME.tar.gz" | cut -f1)

echo ""
echo "=========================================="
echo "POCL build completed successfully!"
echo "=========================================="
echo "Version: $POCL_VERSION"
echo "Platform: $PLATFORM"
echo "LLVM Version: $LLVM_VERSION"
echo "Package: $OUTPUT_DIR/$PACKAGE_NAME.tar.gz"
echo "Size: $SIZE"
echo "=========================================="
