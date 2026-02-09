# libfreenect2 Streamer/Recorder Toolbox

## Table of Contents

* [Description](README.md#description)
* [Maintainers](README.md#maintainers)
* [Installation](README.md#installation)
  * [macOS](README.md#macos)
* [Usage](README.md#usage)

## Description

Additional toolbox based off `Protonect` featuring:
- UDP streaming of Kinect captured images (``-streamer`` option)
- Recording of Kinect captured images to disk (``-recorder`` option)
- Replay of Kinect captured images from disk (``-replay`` option)

## Maintainers

* David Poirier-Quinot
* Serguei A. Mokhov

## Installation

### macOS

#### Requirements

- macOS 11+ (Big Sur or newer)
- Homebrew
- Xcode Command Line Tools

#### Install Dependencies

```bash
# Install OpenCV (opencv4 is recommended)
brew install opencv numpy
```

#### Build

```bash
# Start from the libfreenect2 root directory
mkdir build && cd build

# Configure build
# Note: Metal pipeline is recommended for Apple Silicon
cmake .. -DBUILD_STREAMER_RECORDER=ON -DENABLE_METAL=ON

# Build (use all available cores)
make -j$(sysctl -n hw.ncpu)

# Install (optional)
sudo make install
```

#### Apple Silicon Notes

- On Apple Silicon (M1/M2/M3/M4), the Metal pipeline provides optimal performance
- Homebrew defaults to arm64 architecture - ensure all dependencies match
- If building universal binaries, use: `-DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"`
- For Blender viewer with NumPy, ensure Python architecture matches:
  ```bash
  # Check Python architecture
  python3 -c "import platform; print(platform.machine())"
  
  # Should return 'arm64' on Apple Silicon with arm64 Homebrew
  ```

## Usage

The test program accepts all the same options as Protonect with 3 additional options:

```bash
# Build location (if not installed)
./bin/ProtonectSR [protonect-options]

# Installed location (if `make install` was run)
ProtonectSR [protonect-options]
```

### Options

- `ProtonectSR -record` -- Start recording frames
- `ProtonectSR -stream` -- Start streaming frames to a receiver application
- `ProtonectSR -replay` -- Start replaying recorded frames
- `ProtonectSR -replay -stream` -- Relay and stream recorded frames
- `ProtonectSR -record -stream` -- Record and stream frames simultaneously

### Examples

```bash
# Record frames with Metal pipeline
export LIBFREENECT2_PIPELINE=metal
ProtonectSR -record

# Stream frames over UDP
ProtonectSR -stream

# Replay previously recorded frames
ProtonectSR -replay

# Record and stream simultaneously
ProtonectSR -record -stream

# Use specific device (by serial number)
ProtonectSR -record -serial=012345678901
```

### Pipeline Selection

For best performance on macOS:

| Hardware | Recommended Pipeline |
|----------|---------------------|
| Apple Silicon (M1/M2/M3/M4) | Metal (`export LIBFREENECT2_PIPELINE=metal`) |
| Intel Mac (2016+) | OpenCL |
| Intel Mac (older) | OpenGL |

### Troubleshooting

**NumPy Import Errors in Blender:**

If you see `ImportError: numpy.core.multiarray failed to import`:
```bash
# Reinstall NumPy for the correct architecture
pip3 uninstall numpy
pip3 install numpy
```

**OpenCV Not Found:**
```bash
# Verify OpenCV installation
brew list opencv

# If missing, reinstall
brew reinstall opencv
```

**Performance Issues:**
- Use Metal pipeline on Apple Silicon
- Ensure USB 3.0 connection (no hubs if possible)
- Check CPU usage with Activity Monitor

## Notes

- Recorded frames are stored in a format compatible with Replay mode
- Streaming uses UDP for low-latency transmission
- Both recording and streaming can be used simultaneously
- Network configuration may be required for streaming across different machines
