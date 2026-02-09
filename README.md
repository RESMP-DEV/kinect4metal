# libfreenect2 for macOS

**Driver for Kinect v2 (K4W2) on Apple Silicon and Intel Macs**

This is a macOS-focused fork of libfreenect2, optimized for modern macOS versions and Apple Silicon hardware.

## Features

- **Native Metal Support**: Hardware-accelerated depth processing using Metal compute shaders (recommended for M1/M2/M3/M4).
- **Apple Silicon Native**: Full arm64 support without Rosetta 2.
- **VideoToolbox Integration**: Hardware-accelerated JPEG/ProRes decoding.
- **Modern CMake**: streamlined build system for macOS.

## Requirements

- **macOS 11.0 (Big Sur)** or newer
- **USB 3.0** port (Thunderbolt adapters work fine)
- **Homebrew** for dependencies

## Quick Install

### 1. Install Dependencies

```bash
brew install libusb glfw jpeg-turbo cmake pkg-config
```

### 2. Build

```bash
git clone https://github.com/RESMP-DEV/libfreenect2.git
cd libfreenect2
mkdir build && cd build
cmake ..
make -j$(sysctl -n hw.ncpu)
sudo make install
```

### 3. Run Protonect Example

```bash
./bin/Protonect metal
```

## Build Options

The build system automatically detects macOS features. Key options:

- `ENABLE_METAL` (Default: ON): Enable Metal compute support.
- `ENABLE_OPENCL` (Default: ON): Enable OpenCL support (via Metal translation layer).
- `ENABLE_OPENGL` (Default: ON): Enable OpenGL viewer support.
- `BUILD_FRAMEWORK` (Default: ON): Build as `freenect2.framework`.

To build the framework specifically:

```bash
cmake .. -DBUILD_FRAMEWORK=ON
make
# Framework located at build/lib/freenect2.framework
```

## Troubleshooting

### USB Permissions

On macOS 10.15+, applications accessing USB cameras need permission.
- If you run from Terminal, Terminal needs Camera/USB permission.
- Signed applications need the `com.apple.security.device.usb` entitlement.

### Multiple Kinects

Each Kinect v2 requires significant USB bandwidth.
- Connect each Kinect to a separate USB root hub if possible.
- Thunderbolt docks generally handle bandwidth well.

### Apple Silicon Notes

- The **Metal pipeline** (`Protonect metal`) is highly recommended for performance and efficiency.
- OpenCL is supported but deprecated by Apple and runs via translation.

## License

Dual licensed under [Apache License 2.0](APACHE20) and [GPL v2](GPL2).
See `LICENSE` file for details.