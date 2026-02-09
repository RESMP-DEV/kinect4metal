#!/bin/bash
# Install libfreenect2 dependencies on macOS

set -e

echo "=== libfreenect2 macOS Dependency Installer ==="

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "Installing dependencies via Homebrew..."
brew update
brew install libusb glfw jpeg-turbo cmake pkg-config

# Optional: OpenNI2
read -p "Install OpenNI2 support? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    brew install openni2
    echo "export OPENNI2_REDIST=/opt/homebrew/lib/ni2" >> ~/.zshrc
    echo "export OPENNI2_INCLUDE=/opt/homebrew/include/ni2" >> ~/.zshrc
    echo "Note: OpenNI2 env vars added to ~/.zshrc (restart terminal to apply)"
fi

echo ""
echo "=== Dependencies installed! ==="
echo "Now build libfreenect2:"
echo "  mkdir build && cd build"
echo "  cmake .."
echo "  make -j\$(sysctl -n hw.ncpu)"
echo "  sudo make install"