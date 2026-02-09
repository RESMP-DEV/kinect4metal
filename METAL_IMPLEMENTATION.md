# Metal Depth Packet Processor Implementation

This implementation provides Apple Metal-based GPU acceleration for libfreenect2 depth processing.

## Files Created

### Core Implementation
- **src/metal_depth_packet_processor.mm** - Main Objective-C++ implementation using Metal API
- **src/metal_depth_processor_objc.h** - Objective-C++ header for the Metal processor class
- **src/metal_depth_packet_processor.cpp** - C++ wrapper integrating with libfreenect2 framework

### Metal Shaders
- **src/metal/depth_processing.metal** - Metal compute shader kernels

### Build Integration
- **CMakeLists.txt** - Updated to include Metal source files and shader compilation

## Metal API Components Used

### MTLDevice
- Acquired via `MTLCreateSystemDefaultDevice()`
- Provides default GPU device for Metal operations

### MTLCommandQueue
- Created via `[_device newCommandQueue]`
- Manages command buffer submission to GPU

### MTLBuffer
- **MTLStorageModeShared** - For CPU/GPU shared data (depth input, lookup tables)
- **MTLResourceStorageModePrivate** - For GPU-only data (intermediate processing)
- Buffers created for: depth data, P0 tables, X/Z tables, LUT, output

### MTLLibrary
- Loaded via `[_device newDefaultLibrary]` or `[_device newLibraryWithFile:]`
- Contains compiled Metal shader code

### MTLComputePipelineState
- Created via `[_device newComputePipelineStateWithFunction:]`
- Compiled compute pipeline for each kernel

## Key Methods Implemented

### Constructor
- `initWithWidth:height:` - Initializes Metal device, command queue, and buffers

### Data Loading
- `loadP0TablesFromCommandResponse:length:` - Uploads P0 calibration tables to GPU
- `loadXZTables:zTable:length:` - Uploads X/Z coordinate tables to GPU
- `loadLookupTable:length:` - Uploads depth lookup table to GPU

### Processing
- `processDepthData:outputTo:enableFilter:enableBilateral:` - Main processing pipeline:
  1. Uploads input data to GPU
  2. Encodes compute commands
  3. Dispatches kernels (optionally with filtering)
  4. Reads back processed depth data

### Utility
- `isReady` - Checks if processor is initialized and ready
- `device` - Returns underlying MTLDevice
- `commandQueue` - Returns underlying MTLCommandQueue

## Memory Management

### Autoreleasepool Blocks
- Used throughout for proper Objective-C memory management
- Ensures timely release of temporary objects

### ARC (Automatic Reference Counting)
- All Objective-C objects use ARC
- Compiler flag `-fobjc-arc` set in CMakeLists.txt

## Metal Compute Kernels

### processDepth
- Decodes raw depth data from Kinect v2
- Applies P0 table conversion
- Applies X/Z table corrections
- Applies LUT-based final correction

### filterDepth
- 3x3 median filter for noise reduction
- Handles edge pixels appropriately

### bilateralFilter
- Edge-preserving bilateral filter
- Combines spatial and depth-range weights
- 5x5 filter window

### edgeAwareSmooth
- Gradient-adaptive smoothing
- Preserves edges while smoothing flat regions
- 3x3 filter window with adaptive mixing

### holeFill
- Fills missing depth values
- Expanding radial search for valid depths
- Maximum 8-pixel radius

## Integration with libfreenect2

The C++ wrapper (`MetalDepthPacketProcessor`) follows the existing `DepthPacketProcessor` interface:
- Inherits from `libfreenect2::DepthPacketProcessor`
- Implements all virtual methods (setConfiguration, loadP0TablesFromCommandResponse, loadXZTables, loadLookupTable, ready, process, name)
- Uses Pimpl pattern to hide Objective-C++ implementation
- Provides graceful fallback when Metal is not available

## Build Configuration

### CMake Options
- `ENABLE_METAL` (default: ON) - Enables Metal support
- Automatically compiles Metal shaders to `.metallib` using `xcrun`
- Only available on Apple platforms (macOS 11.0+)

### Dependencies
- Metal.framework
- MetalKit.framework
- Foundation.framework
- CoreFoundation.framework

## Performance Characteristics

- **Zero-copy GPU memory** - Private buffers eliminate unnecessary copies
- **Parallel processing** - 16x16 thread groups for efficient GPU utilization
- **Batched operations** - Multiple kernel dispatches in single command buffer
- **Asynchronous execution** - Non-blocking GPU operations with wait-for-completion

## Usage Example

```cpp
#include <libfreenect2/metal_depth_packet_processor.h>

// Create processor
libfreenect2::MetalDepthPacketProcessor processor;

// Configure
libfreenect2::Freenect2Device::Config config;
config.EnableBilateralFilter = true;
processor.setConfiguration(config);

// Load calibration data
processor.loadP0TablesFromCommandResponse(p0Data, p0Size);
processor.loadXZTables(xTable, zTable);
processor.loadLookupTable(lut);

// Process depth packet
processor.process(depthPacket);
```

## Verification

Run validation script to verify implementation:
```bash
cd contrib/libfreenect2
bash validate_metal_impl.sh
```

Expected output:
- ✓ All required files exist
- ✓ Metal shader kernels found (5 kernels)
- ✓ Objective-C++ implementation methods (6 methods)
- ✓ Metal buffer storage modes found (Shared, Private)
- ✓ Autoreleasepool blocks found
- ✓ CMakeLists.txt integration complete
