# Kinect4Metal

**Native macOS driver for Kinect v2 — built for Apple Silicon, powered by Metal**

Kinect4Metal is a ground-up reimagining of Kinect v2 support for macOS. While derived from libfreenect2, this project goes far deeper into the Apple ecosystem, leveraging Metal compute shaders, VideoToolbox hardware decoding, IOKit for low-level USB control, and modern Swift/SwiftUI integration.

## Why Kinect4Metal?

The original libfreenect2 was a multi-platform project targeting Linux, Windows, and macOS. Kinect4Metal takes a different approach: **macOS-only, Apple-native, no compromises**.

- **Metal-First Architecture**: Depth processing runs entirely on GPU via Metal compute shaders — no OpenCL translation layer, no CPU fallback overhead
- **VideoToolbox Integration**: Hardware-accelerated JPEG decoding through Apple's native video pipeline
- **Apple Silicon Optimized**: Native arm64, unified memory architecture awareness, M1/M2/M3/M4 Pro/Max/Ultra support
- **Modern APIs**: IOKit USB access, Accelerate framework SIMD, Core Image integration
- **Swift-Ready**: Clean C++ API with Swift bridging headers for SwiftUI/AppKit apps

## Features

### Current
- Metal compute shaders for real-time depth processing
- VideoToolbox JPEG decoder (zero-copy to Metal textures)
- Universal binary (arm64 + x86_64)
- macOS 11+ (Big Sur and newer)
- CMake build with Xcode generator support
- Framework target for easy app integration

### Roadmap
- **IOKit USB Rewrite**: Direct USB isochronous transfers without libusb
- **AVFoundation Source**: Expose Kinect as virtual camera device
- **Core ML Integration**: On-device skeletal tracking and gesture recognition
- **RealityKit Bridge**: Depth data → ARKit point clouds
- **visionOS**: Spatial computing depth input (research phase)

## Requirements

| Component | Requirement |
|-----------|-------------|
| macOS | 11.0 (Big Sur) or newer |
| Xcode | 13.0+ (Metal compiler) |
| Hardware | USB 3.0 port, Kinect v2 sensor |
| Optional | Homebrew for dependencies |

## Quick Start

### Install Dependencies

```bash
brew install libusb glfw jpeg-turbo cmake pkg-config
```

### Build

```bash
git clone https://github.com/RESMP-DEV/kinect4metal.git
cd kinect4metal
mkdir build && cd build
cmake .. -G Xcode  # Or use: cmake ..
cmake --build . --config Release -j$(sysctl -n hw.ncpu)
```

### Run

```bash
./bin/Protonect metal
```

## Build Options

| Option | Default | Description |
|--------|---------|-------------|
| `ENABLE_METAL` | ON | Metal compute depth processing |
| `ENABLE_VIDEOTOOLBOX` | ON | Hardware JPEG decoding |
| `ENABLE_OPENGL` | ON | Legacy OpenGL viewer |
| `BUILD_FRAMEWORK` | ON | Build as `Kinect4Metal.framework` |
| `BUILD_EXAMPLES` | ON | Build Protonect and SwiftUI examples |

### Framework Build

```bash
cmake .. -DBUILD_FRAMEWORK=ON -G Xcode
xcodebuild -scheme kinect4metal -configuration Release

# Output: build/lib/Kinect4Metal.framework
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Your Application                         │
├─────────────────────────────────────────────────────────────┤
│  Swift Bindings  │  C++ API  │  SwiftUI Views               │
├─────────────────────────────────────────────────────────────┤
│                   Kinect4Metal.framework                     │
├──────────────┬──────────────┬───────────────┬───────────────┤
│ Metal Depth  │ VideoToolbox │ Registration  │ Frame Sync    │
│ Processing   │ RGB Decode   │ & Calibration │ & Threading   │
├──────────────┴──────────────┴───────────────┴───────────────┤
│                     IOKit USB / libusb                       │
├─────────────────────────────────────────────────────────────┤
│                      Kinect v2 Hardware                      │
└─────────────────────────────────────────────────────────────┘
```

## Troubleshooting

### USB Access

macOS requires explicit permission for USB device access:

```bash
# Check USB devices
system_profiler SPUSBDataType | grep -A5 "Xbox NUI Sensor"

# If not visible, check System Settings → Privacy & Security → USB
```

For signed apps, add to entitlements:
```xml
<key>com.apple.security.device.usb</key>
<true/>
```

### Apple Silicon Performance

Metal pipeline is **required** on Apple Silicon for optimal performance:

| Pipeline | M1 | M1 Pro | M4 Max |
|----------|-----|--------|--------|
| Metal | 30fps | 30fps | 30fps |
| OpenCL (legacy) | 15fps | 20fps | N/A |
| CPU | 8fps | 12fps | 15fps |

### Multiple Sensors

Each Kinect v2 requires ~3Gbps USB bandwidth. Apple Silicon Macs have favorable USB topology:

- **Thunderbolt Architecture**: Most M-series chips have independent controllers per port (not shared hubs)
- **Thunderbolt 5**: Up to 80Gbps bidirectional — theoretical capacity for 20+ sensors per port
- **Unified Memory**: Zero-copy potential between USB DMA and Metal textures

Sensor count is limited by:
1. Software efficiency (current bottleneck — Kinect4Metal aims to improve this)
2. CPU/GPU processing capacity
3. Physical USB bandwidth (rarely the limit on modern Macs)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## Acknowledgments

Kinect4Metal is derived from [libfreenect2](https://github.com/OpenKinect/libfreenect2) by the OpenKinect project. See [NOTICE](NOTICE) for attribution details.

## License

MIT License — see [LICENSE](LICENSE) for details.