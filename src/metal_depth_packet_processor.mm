/*
 * This file is part of the OpenKinect Project. http://www.openkinect.org
 *
 * Copyright (c) 2024 individual OpenKinect contributors. See the CONTRIB file
 * for details.
 *
 * This code is licensed to you under the terms of the Apache License, version
 * 2.0, or, at your option, the terms of the GNU General Public License,
 * version 2.0. See the APACHE20 and GPL2 files for the text of the licenses,
 * or the following URLs:
 * http://www.apache.org/licenses/LICENSE-2.0
 * http://www.gnu.org/licenses/gpl-2.0.txt
 */

/** @file metal_depth_packet_processor.mm Depth processor implementation using Metal. */

#import "metal_depth_processor_objc.h"
#include <libfreenect2/protocol/response.h>
#include <libfreenect2/logging.h>

#include <iostream>
#include <cstring>
#include <algorithm>

#define _USE_MATH_DEFINES
#include <math.h>

#pragma mark - MetalDepthPacketProcessor Implementation

@implementation MetalDepthPacketProcessor {
    // Metal objects
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
    id<MTLLibrary> _shaderLibrary;
    
    // Pipeline states
    id<MTLComputePipelineState> _pipelineProcessDepth;
    id<MTLComputePipelineState> _pipelineBilateralFilter;
    id<MTLComputePipelineState> _pipelineEdgeAwareSmooth;
    
    // Buffers
    id<MTLBuffer> _bufferP0Table;
    id<MTLBuffer> _bufferXTable;
    id<MTLBuffer> _bufferZTable;
    id<MTLBuffer> _bufferLut;
    id<MTLBuffer> _bufferPacket;
    
    id<MTLBuffer> _bufferIntermediate;
    id<MTLBuffer> _bufferOutput;
    
    // Dimensions
    int _width;
    int _height;
    int _imageSize;
    
    // State
    BOOL _initialized;
}

- (instancetype)initWithWidth:(int)width height:(int)height {
    self = [super init];
    if (self) {
        _width = width;
        _height = height;
        _imageSize = width * height;
        _initialized = NO;
        
        if (![self initializeMetal]) {
            return nil;
        }
        
        if (![self initializePipelines]) {
            return nil;
        }
        
        if (![self initializeBuffers]) {
            return nil;
        }
        
        _initialized = YES;
    }
    return self;
}

- (BOOL)initializeMetal {
    // Acquire default GPU device
    _device = MTLCreateSystemDefaultDevice();
    if (!_device) {
        LOG_ERROR << "Metal: Failed to acquire default GPU device";
        return NO;
    }
    
    // Create command queue for command submission
    _commandQueue = [_device newCommandQueue];
    if (!_commandQueue) {
        LOG_ERROR << "Metal: Failed to create command queue";
        return NO;
    }
    
    // Load compiled Metal shaders
    NSError *error = nil;
    _shaderLibrary = [_device newDefaultLibrary];
    if (!_shaderLibrary) {
        // Fallback: try to load from a specific file if bundled
        NSString *path = [[NSBundle mainBundle] pathForResource:@"depth_processing" ofType:@"metallib"];
        if (path) {
            _shaderLibrary = [_device newLibraryWithFile:path error:&error];
        }
        
        if (!_shaderLibrary) {
            LOG_ERROR << "Metal: Failed to load shader library. Ensure depth_processing.metallib is available.";
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)initializePipelines {
    NSError *error = nil;
    
    // Helper to create compute pipeline
    auto createPipeline = [&](NSString *name) -> id<MTLComputePipelineState> {
        id<MTLFunction> function = [_shaderLibrary newFunctionWithName:name];
        if (!function) {
            LOG_ERROR << "Metal: Function " << [name UTF8String] << " not found in library";
            return nil;
        }
        id<MTLComputePipelineState> pso = [_device newComputePipelineStateWithFunction:function error:&error];
        if (!pso) {
            LOG_ERROR << "Metal: Failed to create pipeline for " << [name UTF8String] << ": " << [[error localizedDescription] UTF8String];
            return nil;
        }
        return pso;
    };
    
    _pipelineProcessDepth = createPipeline(@"processDepth");
    _pipelineBilateralFilter = createPipeline(@"bilateralFilter");
    _pipelineEdgeAwareSmooth = createPipeline(@"edgeAwareSmooth");
    
    return (_pipelineProcessDepth && _pipelineBilateralFilter && _pipelineEdgeAwareSmooth);
}

- (BOOL)initializeBuffers {
    MTLResourceOptions sharedOptions = MTLResourceStorageModeShared;
    MTLResourceOptions privateOptions = MTLResourceStorageModePrivate;
    
    // Calibration and lookup tables
    _bufferP0Table = [_device newBufferWithLength:_imageSize * sizeof(float) options:sharedOptions];
    _bufferXTable = [_device newBufferWithLength:_imageSize * sizeof(float) options:sharedOptions];
    _bufferZTable = [_device newBufferWithLength:_imageSize * sizeof(float) options:sharedOptions];
    _bufferLut = [_device newBufferWithLength:2048 * 2048 * sizeof(float) options:sharedOptions];
    
    // Input packet buffer (sized for raw depth packets)
    _bufferPacket = [_device newBufferWithLength:_imageSize * 2 options:sharedOptions];
    
    // Intermediate and output depth data
    _bufferIntermediate = [_device newBufferWithLength:_imageSize * sizeof(float) options:privateOptions];
    _bufferOutput = [_device newBufferWithLength:_imageSize * sizeof(float) options:sharedOptions];
    
    if (!_bufferP0Table || !_bufferXTable || !_bufferZTable || !_bufferLut || 
        !_bufferPacket || !_bufferIntermediate || !_bufferOutput) {
        LOG_ERROR << "Metal: Failed to allocate GPU buffers";
        return NO;
    }
    
    return YES;
}

#pragma mark - Calibration Data Loading

- (void)loadP0TablesFromCommandResponse:(const unsigned char *)data length:(size_t)length {
    if (!_initialized || !data) return;
    
    @autoreleasepool {
        const libfreenect2::protocol::P0TablesResponse *p0table = 
            (const libfreenect2::protocol::P0TablesResponse *)data;
        
        float *p0_mapped = (float *)[_bufferP0Table contents];
        
        // Extract first table and convert to float multipliers for simplified shader
        for (int i = 0; i < _imageSize; ++i) {
            p0_mapped[i] = (float)p0table->p0table0[i] * 0.000031f * (float)M_PI;
        }
    }
}

- (void)loadXZTables:(const float *)xTable zTable:(const float *)zTable length:(size_t)length {
    if (!_initialized || !xTable || !zTable) return;
    
    @autoreleasepool {
        memcpy([_bufferXTable contents], xTable, std::min(length, (size_t)_imageSize) * sizeof(float));
        memcpy([_bufferZTable contents], zTable, std::min(length, (size_t)_imageSize) * sizeof(float));
    }
}

- (void)loadLookupTable:(const float *)lut length:(size_t)length {
    if (!_initialized || !lut) return;
    
    @autoreleasepool {
        memcpy([_bufferLut contents], lut, std::min(length, (size_t)(2048 * 2048)) * sizeof(float));
    }
}

#pragma mark - Depth Processing

- (void)processDepthData:(const unsigned char *)inputData
                outputTo:(float *)outputData
            enableFilter:(BOOL)enableFilter
         enableBilateral:(BOOL)enableBilateral {
    if (!_initialized || !inputData || !outputData) return;
    
    @autoreleasepool {
        // Copy raw packet to GPU buffer
        memcpy([_bufferPacket contents], inputData, _imageSize * 2);
        
        id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
        MTLSize gridSize = MTLSizeMake(512, 424, 1);
        MTLSize threadGroupSize = MTLSizeMake(16, 16, 1);
        
        // 1. Process Depth
        {
            id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];
            [encoder setComputePipelineState:_pipelineProcessDepth];
            [encoder setBuffer:_bufferPacket offset:0 atIndex:0];
            [encoder setBuffer:_bufferP0Table offset:0 atIndex:1];
            [encoder setBuffer:_bufferXTable offset:0 atIndex:2];
            [encoder setBuffer:_bufferZTable offset:0 atIndex:3];
            [encoder setBuffer:_bufferLut offset:0 atIndex:4];
            [encoder setBuffer:_bufferIntermediate offset:0 atIndex:5];
            [encoder dispatchThreads:gridSize threadsPerThreadgroup:threadGroupSize];
            [encoder endEncoding];
        }
        
        id<MTLBuffer> currentInput = _bufferIntermediate;
        id<MTLBuffer> currentOutput = _bufferOutput;
        
        // 2. Bilateral Filter
        if (enableBilateral) {
            id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];
            [encoder setComputePipelineState:_pipelineBilateralFilter];
            [encoder setBuffer:currentInput offset:0 atIndex:0];
            [encoder setBuffer:currentOutput offset:0 atIndex:1];
            [encoder dispatchThreads:gridSize threadsPerThreadgroup:threadGroupSize];
            [encoder endEncoding];
            
            // Swap buffers for next stage if needed
            std::swap(currentInput, currentOutput);
        }
        
        // 3. Edge Aware Smoothing
        if (enableFilter) {
            id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];
            [encoder setComputePipelineState:_pipelineEdgeAwareSmooth];
            [encoder setBuffer:currentInput offset:0 atIndex:0];
            [encoder setBuffer:currentOutput offset:0 atIndex:1];
            [encoder dispatchThreads:gridSize threadsPerThreadgroup:threadGroupSize];
            [encoder endEncoding];
            
            currentInput = currentOutput; // currentInput now points to result
        }
        
        // Final copy if the result is in the intermediate buffer
        if (currentInput == _bufferIntermediate) {
            id<MTLBlitCommandEncoder> blit = [commandBuffer blitCommandEncoder];
            [blit copyFromBuffer:_bufferIntermediate sourceOffset:0 toBuffer:_bufferOutput destinationOffset:0 size:_imageSize * sizeof(float)];
            [blit endEncoding];
        }
        
        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];
        
        // Read back result
        memcpy(outputData, [_bufferOutput contents], _imageSize * sizeof(float));
    }
}

#pragma mark - Accessors

- (id<MTLDevice>)device {
    return _device;
}

- (id<MTLCommandQueue>)commandQueue {
    return _commandQueue;
}

- (BOOL)isReady {
    return _initialized;
}

@end