#!/bin/sh
#
# Build GLFW from source
# This is typically not needed on modern Linux systems where
# libglfw3-dev from the package manager is sufficient.
#
# Use this script only if you need a specific version or custom build.
#
set -e

cd `dirname $0`
DEPENDS_DIR=`pwd`

# GLFW - using latest stable release
GLFW_SOURCE_DIR=$DEPENDS_DIR/glfw_src
GLFW_INSTALL_DIR=$DEPENDS_DIR/glfw

# Check if GLFW is already available system-wide
if pkg-config --exists glfw3 2>/dev/null; then
    SYSTEM_VERSION=$(pkg-config --modversion glfw3)
    echo "System GLFW version: $SYSTEM_VERSION"
    echo ""
    read -p "Continue building from source? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted. Use system GLFW instead."
        exit 0
    fi
fi

rm -rf $GLFW_SOURCE_DIR $GLFW_INSTALL_DIR

echo "Cloning GLFW..."
git clone https://github.com/glfw/glfw.git $GLFW_SOURCE_DIR

cd $GLFW_SOURCE_DIR
# Use latest stable 3.x release
git checkout 3.4

echo "Building GLFW..."
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=$GLFW_INSTALL_DIR \
      -DBUILD_SHARED_LIBS=TRUE \
      -DGLFW_BUILD_EXAMPLES=OFF \
      -DGLFW_BUILD_TESTS=OFF \
      -DGLFW_BUILD_DOCS=OFF \
      ..
make -j$(nproc) && make install

cd $DEPENDS_DIR

echo ""
echo "GLFW installed to: $GLFW_INSTALL_DIR"
echo ""
echo "To use this GLFW with libfreenect2, configure cmake with:"
echo "  cmake .. -DGLFW_ROOT=$GLFW_INSTALL_DIR"
echo ""
