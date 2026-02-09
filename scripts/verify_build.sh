#!/bin/bash
set -e

echo "=== libfreenect2 Build Verification ==="

cd "$(dirname "$0")/.."
BUILD_DIR="${1:-build}"

echo "Build directory: $BUILD_DIR"

# Check library exists
if [[ -f "$BUILD_DIR/lib/libfreenect2.dylib" ]]; then
    echo "✓ Dynamic library built"
elif [[ -d "$BUILD_DIR/lib/freenect2.framework" ]]; then
    echo "✓ Framework built"
else
    echo "✗ No library found!"
    exit 1
fi

# Check Protonect built
if [[ -f "$BUILD_DIR/bin/Protonect" ]]; then
    echo "✓ Protonect example built"
else
    echo "✗ Protonect not found!"
    exit 1
fi

# Check for Metal shader library (if Metal enabled)
if [[ -f "$BUILD_DIR/depth_processing.metallib" ]]; then
    echo "✓ Metal shaders compiled"
else
    echo "⚠ Metal shaders not found (may be disabled)"
fi

# Verify library dependencies
echo ""
echo "Library dependencies:"
otool -L "$BUILD_DIR/lib/libfreenect2.dylib" 2>/dev/null || \
    otool -L "$BUILD_DIR/lib/freenect2.framework/freenect2" 2>/dev/null

# Architecture check
echo ""
echo "Architecture:"
lipo -info "$BUILD_DIR/lib/libfreenect2.dylib" 2>/dev/null || \
    lipo -info "$BUILD_DIR/lib/freenect2.framework/freenect2" 2>/dev/null

echo ""
echo "=== Build verification passed ==="
