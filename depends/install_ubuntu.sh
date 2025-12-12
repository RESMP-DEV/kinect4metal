#!/bin/bash
#
# libfreenect2 Ubuntu dependency installer
# Supports Ubuntu 20.04, 22.04, and 24.04
#

set -e

echo "libfreenect2 Ubuntu Dependency Installer"
echo "========================================="

# Detect Ubuntu version
if [ -f /etc/os-release ]; then
    . /etc/os-release
    UBUNTU_VERSION=$VERSION_ID
else
    echo "Warning: Could not detect Ubuntu version"
    UBUNTU_VERSION="unknown"
fi

echo "Detected Ubuntu version: $UBUNTU_VERSION"

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    SUDO="sudo"
else
    SUDO=""
fi

echo ""
echo "Installing build tools..."
$SUDO apt-get update
$SUDO apt-get install -y build-essential cmake pkg-config

echo ""
echo "Installing core dependencies..."
$SUDO apt-get install -y libusb-1.0-0-dev

echo ""
echo "Installing TurboJPEG..."
$SUDO apt-get install -y libturbojpeg0-dev

echo ""
echo "Installing OpenGL dependencies (GLFW3)..."
$SUDO apt-get install -y libglfw3-dev

echo ""
echo "Installing optional OpenCL support..."
# Install OpenCL headers and ICD loader
$SUDO apt-get install -y ocl-icd-opencl-dev opencl-headers || echo "OpenCL packages not available, skipping..."

echo ""
echo "Installing optional VA-API support (Intel GPUs)..."
$SUDO apt-get install -y libva-dev libjpeg-dev || echo "VA-API packages not available, skipping..."

echo ""
echo "Installing optional OpenNI2 support..."
$SUDO apt-get install -y libopenni2-dev || echo "OpenNI2 packages not available, skipping..."

echo ""
echo "========================================="
echo "Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Clone libfreenect2 if you haven't:"
echo "     git clone https://github.com/OpenKinect/libfreenect2.git"
echo ""
echo "  2. Build libfreenect2:"
echo "     cd libfreenect2"
echo "     mkdir build && cd build"
echo "     cmake .. -DCMAKE_INSTALL_PREFIX=\$HOME/freenect2"
echo "     make -j\$(nproc)"
echo "     make install"
echo ""
echo "  3. Set up udev rules for device access:"
echo "     sudo cp ../platform/linux/udev/90-kinect2.rules /etc/udev/rules.d/"
echo "     sudo udevadm control --reload-rules && sudo udevadm trigger"
echo ""
echo "  4. Replug your Kinect v2 device"
echo ""
echo "For GPU-accelerated depth processing:"
echo "  - Intel GPU: Install Intel compute runtime from Intel's website"
echo "  - NVIDIA GPU: Install CUDA toolkit from NVIDIA's website"
echo "  - AMD GPU: Install ROCm or AMDGPU-PRO from AMD's website"
echo ""
