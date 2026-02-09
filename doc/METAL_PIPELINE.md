# Metal Pipeline for macOS {#metal_pipeline}

## Overview

The Metal pipeline provides the highest-performance depth processing for Kinect v2 on macOS. It uses Apple's Metal compute shaders to perform depth decoding directly on the GPU with optimal memory efficiency.

On Apple Silicon Macs, the Metal pipeline takes full advantage of the unified memory architecture, eliminating expensive GPU→CPU memory copies that are required with traditional pipelines.

## Requirements

| Component | Requirement |
|-----------|-------------|
| macOS | 11.0 (Big Sur) or newer |
| GPU | Metal-capable (all Apple Silicon, Intel Iris/AMD 2015+) |
| Build Tools | Xcode 12+ or Command Line Tools |

## Architecture

### Data Flow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Kinect v2     │────▶│   USB Layer     │────▶│  Depth Packet   │
│   (USB 3.0)     │     │   (libusb)      │     │    Decoder      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                        │
                                                        ▼
                                               ┌─────────────────┐
                                               │  Metal Compute  │
                                               │    Pipeline     │
                                               │                 │
                                               │ • Phase unwrap  │
                                               │ • Depth decode  │
                                               │ • Edge filter   │
                                               └─────────────────┘
                                                        │
                                                        ▼
                                               ┌─────────────────┐
                                               │   Frame Output  │
                                               │  (GPU memory)   │
                                               └─────────────────┘
```

### Apple Silicon Memory Model

**Traditional Pipeline (OpenCL/OpenGL/CPU on discrete GPU systems):**
```
GPU Memory → CPU Memory (copy) → Application
   ↓                              ↑
   └──────── PCI/Thunderbolt ─────┘
```

**Metal Pipeline on Apple Silicon:**
```
Unified Memory (Shared CPU/GPU) → Application
         ↑
    Zero-copy access
```

Apple Silicon's unified memory architecture allows the GPU to write depth frames directly to memory that the CPU can access without copying. This provides:
- Lower latency (~5-10ms savings per frame)
- Reduced power consumption
- Higher overall throughput

## Building with Metal

Metal support is enabled by default on macOS when building on Apple Silicon or when a Metal-capable GPU is detected.

### Standard Build

```bash
mkdir build && cd build
cmake ..
make -j$(sysctl -n hw.ncpu)
```

### Verify Metal is Enabled

```bash
cmake -L .. | grep METAL
# ENABLE_METAL:BOOL=ON
```

### Explicit Control

```bash
# Force Metal support (useful for CI/CD)
cmake .. -DENABLE_METAL=ON

# Disable Metal (fallback to OpenCL/CPU)
cmake .. -DENABLE_METAL=OFF
```

## Using the Metal Pipeline

### C++ API

```cpp
#include <libfreenect2/packet_pipeline.h>
#include <libfreenect2/libfreenect2.hpp>

libfreenect2::Freenect2 freenect2;

// Create Metal pipeline
libfreenect2::MetalPacketPipeline* pipeline = 
    new libfreenect2::MetalPacketPipeline();

// Enumerate and open device
freenect2.enumerateDevices();
std::string serial = freenect2.getDeviceSerialNumber(0);
libfreenect2::Freenect2Device* dev = 
    freenect2.openDevice(serial, pipeline);

// Start streaming
dev->start();
```

### Environment Variable

```bash
# Set default pipeline to Metal for all libfreenect2 applications
export LIBFREENECT2_PIPELINE=metal
./Protonect
```

Add to your `~/.zshrc` for permanent setting:
```bash
echo 'export LIBFREENECT2_PIPELINE=metal' >> ~/.zshrc
```

### Protonect Example

```bash
# Run with Metal pipeline explicitly
./Protonect metal

# Run with default (will select Metal on Apple Silicon)
./Protonect
```

## Pipeline Auto-Selection

When no pipeline is explicitly specified, libfreenect2 selects the best available:

1. **Metal** (macOS 11+, Apple Silicon or Metal-capable Intel)
2. **OpenCL** (if available and Metal unavailable)
3. **OpenGL** (legacy fallback)
4. **CPU** (always available, slowest)

Override with:
```bash
LIBFREENECT2_LOGGER_LEVEL=debug ./Protonect 2>&1 | grep -i pipeline
```

## Performance

### Apple Silicon Performance

| Pipeline | Frame Rate | Latency | Power | Notes |
|----------|------------|---------|-------|-------|
| Metal | ~30 fps | ~16ms | Low | Native compute, unified memory |
| OpenCL | ~25 fps | ~20ms | Medium | Translates to Metal on Apple Silicon |
| OpenGL | ~20 fps | ~25ms | Medium | Legacy, not optimized |
| CPU | ~15 fps | ~33ms | High | Uses all cores |

*Measured on M1 MacBook Pro, 512x424 depth processing*

### Intel Mac Performance

| Pipeline | Frame Rate | Notes |
|----------|------------|-------|
| OpenCL | ~30 fps | Best on Intel |
| Metal | ~28 fps | If GPU supports Metal |
| OpenGL | ~25 fps | Deprecated but functional |
| CPU | ~15 fps | Fallback |

## Implementation Details

### Depth Processing Stages

1. **P0 Table Application** (0.2ms)
   - Apply factory calibration tables via compute shader
   
2. **Phase Unwrapping** (0.5ms)
   - Convert raw phase measurements to depth
   - Uses optimized threadgroup layout (16x16 threads)
   
3. **Edge-Aware Filtering** (0.3ms)
   - Bilateral filter preserving depth edges
   - Configurable filter parameters

### Metal Compute Kernels

The pipeline uses the following `.metal` shaders:

| Kernel | File | Purpose |
|--------|------|---------|
| `depth_decode` | `depth_processing.metal` | Main depth decoding |
| `phase_unwrap` | `depth_processing.metal` | Phase unwrapping algorithm |
| `apply_p0_table` | `depth_processing.metal` | Calibration table application |

Source location: `src/metal/depth_processing.metal`

### Threadgroup Configuration

- **Threadgroup size**: 16×16 (256 threads)
- **Grid alignment**: 512×424 (depth frame dimensions)
- **Occupancy**: Optimized for Apple Silicon GPU core count

## Debugging

### Enable Metal Validation

```bash
# Enable Metal API validation (catches GPU errors)
export METAL_DEVICE_WRAPPER_TYPE=1
./Protonect metal
```

### Metal Frame Capture

Using Xcode's Metal Frame Capture for profiling:

1. Build with debug symbols:
   ```bash
   cmake .. -DCMAKE_BUILD_TYPE=Debug
   make -j$(sysctl -n hw.ncpu)
   ```

2. Open `examples/Protonect.cpp` in Xcode

3. Run with Metal Frame Capture enabled

4. Analyze GPU timeline and shader performance

### Performance Profiling

```bash
# Record Metal performance trace
xcrun xctrace record --template "Metal System Trace" --launch ./Protonect

# View in Xcode when complete
open Trace.trace
```

### Verify Pipeline Selection

```bash
# Check which pipeline is actually being used
LIBFREENECT2_LOGGER_LEVEL=debug ./Protonect 2>&1 | grep -i "pipeline\|metal"
```

## Troubleshooting

### "Metal pipeline not available"

**Check compilation:**
```bash
cmake -L .. | grep METAL
# Should show: ENABLE_METAL:BOOL=ON
```

**Check architecture (Apple Silicon):**
```bash
uname -m  # Should print: arm64
```

**Check Metal GPU support:**
```bash
system_profiler SPDisplaysDataType | grep Metal
# Should list Metal support for your GPU
```

### "Failed to create Metal device"

1. Verify macOS version:
   ```bash
   sw_vers -productVersion  # Should be 11.0+
   ```

2. Check Metal capability:
   ```bash
   system_profiler SPDisplaysDataType | grep Metal
   ```

3. Ensure not running in Rosetta (Apple Silicon):
   ```bash
   arch  # Should print: arm64
   ```

### Performance Lower Than Expected

**Checklist:**
- [ ] Verify Metal pipeline is selected (not OpenCL fallback)
- [ ] Check Activity Monitor for GPU utilization
- [ ] Ensure not running under Rosetta 2
- [ ] Verify USB 3.0 connection (not USB 2.0 hub)
- [ ] Close other GPU-intensive applications

**Diagnostic commands:**
```bash
# Check actual pipeline in use
LIBFREENECT2_LOGGER_LEVEL=debug ./Protonect 2>&1 | grep -i pipeline

# Monitor GPU usage (in separate terminal)
while true; do
  top -l 1 -stats pid,command,cpu,gpu_time | head -20
  sleep 1
done
```

## API Reference

### MetalPacketPipeline

```cpp
namespace libfreenect2 {

class MetalPacketPipeline : public PacketPipeline {
public:
    /// Create Metal pipeline with optional device selection
    /// @param deviceId Metal device index (-1 for default)
    MetalPacketPipeline(int deviceId = -1);
    
    virtual ~MetalPacketPipeline();
    
    /// Check if Metal pipeline is supported on this system
    static bool isSupported();
};

} // namespace libfreenect2
```

Header: `#include <libfreenect2/packet_pipeline.h>`

## Future Enhancements

Planned improvements to the Metal pipeline:

- [ ] Triple buffering for reduced latency
- [ ] Metal Performance Shaders integration for advanced filtering
- [ ] Async GPU readback for improved CPU/GPU parallelism
- [ ] HDR depth mode support for extended range

## See Also

- [mainpage.dox](mainpage.dox) - Complete API documentation
- [TROUBLESHOOTING_MACOS.md](TROUBLESHOOTING_MACOS.md) - macOS-specific issues
- [packet_pipeline.h](../include/libfreenect2/packet_pipeline.h) - Pipeline API
- [metal_depth_packet_processor.h](../include/internal/libfreenect2/metal_depth_packet_processor.h) - Internal Metal interface
