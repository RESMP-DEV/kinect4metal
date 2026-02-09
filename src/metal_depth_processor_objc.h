#pragma once

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

/**
 * MetalDepthPacketProcessor - Objective-C++ implementation of depth packet processing
 * using Apple Metal compute shaders.
 * 
 * This class interfaces between the C++ libfreenect2 pipeline and the Metal GPU
 * compute pipeline for high-performance depth processing on macOS.
 */
@interface MetalDepthPacketProcessor : NSObject

/**
 * Initialize the processor with specified dimensions.
 * @param width Image width (typically 512)
 * @param height Image height (typically 424)
 */
- (instancetype)initWithWidth:(int)width height:(int)height;

/**
 * Load P0 calibration tables from device command response.
 * @param data Raw command response data containing P0TablesResponse structure
 * @param length Data length in bytes
 */
- (void)loadP0TablesFromCommandResponse:(const unsigned char*)data length:(size_t)length;

/**
 * Load X and Z coordinate tables for depth conversion.
 * @param xTable X coordinate lookup table (512*424 floats)
 * @param zTable Z coordinate lookup table (512*424 floats)
 * @param length Table length in elements
 */
- (void)loadXZTables:(const float*)xTable zTable:(const float*)zTable length:(size_t)length;

/**
 * Load lookup table for depth processing.
 * @param lut Lookup table data (2048 float values)
 * @param length Table length in elements
 */
- (void)loadLookupTable:(const float*)lut length:(size_t)length;

/**
 * Process depth data through GPU pipeline.
 * 
 * This method encodes compute commands to:
 * 1. Stage 1: Decode depth packet and compute IR values
 * 2. Filter Stage 1: Apply bilateral filtering
 * 3. Stage 2: Calculate depth from phase
 * 4. Filter Stage 2: Apply edge-aware filtering
 * 
 * @param inputData Raw depth packet data from Kinect device
 * @param outputData Processed depth output buffer (512*424 floats)
 * @param enableFilter Enable edge-aware filtering stage
 * @param enableBilateral Enable bilateral filtering stage
 */
- (void)processDepthData:(const unsigned char*)inputData
               outputTo:(float*)outputData
           enableFilter:(BOOL)enableFilter
        enableBilateral:(BOOL)enableBilateral;

/**
 * Get the underlying Metal device (for advanced usage).
 * @return The MTLDevice used by this processor
 */
- (id<MTLDevice>)device;

/**
 * Get the command queue (for custom operations).
 * @return The MTLCommandQueue used by this processor
 */
- (id<MTLCommandQueue>)commandQueue;

/**
 * Check if the processor is ready for processing.
 * @return YES if Metal device, shaders, and buffers are initialized
 */
- (BOOL)isReady;

@end
