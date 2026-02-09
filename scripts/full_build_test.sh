#!/bin/bash
set -e

echo "=== Full Build Test ==="
cd "$(dirname "$0")/.."

# Clean
rm -rf build-test

# Configure
mkdir build-test
cd build-test
cmake .. \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DENABLE_METAL=ON \
  -DENABLE_OPENCL=ON \
  -DENABLE_OPENGL=ON \
  -DBUILD_FRAMEWORK=ON \
  -DBUILD_TESTS=ON \
  -DBUILD_EXAMPLES=ON

# Build
make -j$(sysctl -n hw.ncpu)

# Test
ctest --output-on-failure

# Verify
../scripts/verify_build.sh .

echo ""
echo "=== Full build test PASSED ==="
