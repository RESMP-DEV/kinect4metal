#!/bin/bash
#
# Build libusb from source
# This is typically not needed on modern Linux systems where
# libusb-1.0-0-dev from the package manager is sufficient.
#
# Use this script only if you need a specific version or custom build.
#
set -e

cd `dirname $0`
DEPENDS_DIR=`pwd`

# libusb - using latest stable release
LIBUSB_SOURCE_DIR=$DEPENDS_DIR/libusb_src
LIBUSB_INSTALL_DIR=$DEPENDS_DIR/libusb

# Check if libusb is already available system-wide
if pkg-config --exists libusb-1.0 2>/dev/null; then
    SYSTEM_VERSION=$(pkg-config --modversion libusb-1.0)
    echo "System libusb version: $SYSTEM_VERSION"
    echo "If this is >= 1.0.20, you may not need to build from source."
    echo ""
    read -p "Continue building from source? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted. Use system libusb instead."
        exit 0
    fi
fi

rm -rf $LIBUSB_SOURCE_DIR $LIBUSB_INSTALL_DIR

echo "Cloning libusb..."
git clone https://github.com/libusb/libusb.git $LIBUSB_SOURCE_DIR

cd $LIBUSB_SOURCE_DIR
# Use latest stable 1.0.x release
git checkout v1.0.27

echo "Building libusb..."
./bootstrap.sh
./configure --prefix=$LIBUSB_INSTALL_DIR
make -j$(nproc) && make install

cd $DEPENDS_DIR

echo ""
echo "libusb installed to: $LIBUSB_INSTALL_DIR"
echo ""
echo "To use this libusb with libfreenect2, configure cmake with:"
echo "  cmake .. -DLibUSB_ROOT=$LIBUSB_INSTALL_DIR"
echo ""
