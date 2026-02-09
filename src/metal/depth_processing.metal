//
//  depth_processing.metal
//  libfreenect2
//
//  Metal compute kernels for depth packet processing
//

#include <metal_stdlib>
using namespace metal;

// Process depth kernel
kernel void processDepth(
    device const unsigned char* inputData [[buffer(0)]],
    device const float* p0Table [[buffer(1)]],
    device const float* xTable [[buffer(2)]],
    device const float* zTable [[buffer(3)]],
    device const float* lut [[buffer(4)]],
    device float* outputData [[buffer(5)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint x = gid.x;
    uint y = gid.y;
    
    if (x >= 512 || y >= 424) {
        return;
    }
    
    uint idx = y * 512 + x;
    
    // Decode raw depth data
    uint16_t depthRaw = (inputData[idx * 2] << 8) | inputData[idx * 2 + 1];
    
    if (depthRaw == 0) {
        outputData[idx] = 0.0f;
        return;
    }
    
    // Convert to float depth using P0 table
    float p0 = p0Table[idx];
    float depth = (float)depthRaw * p0;
    
    // Apply X/Z table corrections
    float xCorrection = xTable[idx];
    float zCorrection = zTable[idx];
    depth = depth * zCorrection;
    
    // Apply LUT (lookup table) for final correction
    uint lutIdx = (uint)(depth * 1000.0f);
    lutIdx = lutIdx < (2048 * 2048) ? lutIdx : (2048 * 2048 - 1);
    float lutValue = lut[lutIdx];
    
    // Combine all corrections
    outputData[idx] = depth * lutValue;
}

// Simple spatial filter kernel
kernel void filterDepth(
    device const float* inputData [[buffer(0)]],
    device float* outputData [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint x = gid.x;
    uint y = gid.y;
    
    if (x >= 512 || y >= 424 || x < 1 || y < 1 || x >= 511 || y >= 423) {
        outputData[y * 512 + x] = inputData[y * 512 + x];
        return;
    }
    
    uint idx = y * 512 + x;
    
    // 3x3 median filter
    float window[9] = {
        inputData[(y - 1) * 512 + (x - 1)],
        inputData[(y - 1) * 512 + x],
        inputData[(y - 1) * 512 + (x + 1)],
        inputData[y * 512 + (x - 1)],
        inputData[y * 512 + x],
        inputData[y * 512 + (x + 1)],
        inputData[(y + 1) * 512 + (x - 1)],
        inputData[(y + 1) * 512 + x],
        inputData[(y + 1) * 512 + (x + 1)]
    };
    
    // Simple bubble sort for median
    for (int i = 0; i < 9; i++) {
        for (int j = i + 1; j < 9; j++) {
            if (window[i] > window[j]) {
                float temp = window[i];
                window[i] = window[j];
                window[j] = temp;
            }
        }
    }
    
    outputData[idx] = window[4]; // Median
}

// Bilateral filter kernel
kernel void bilateralFilter(
    device const float* inputData [[buffer(0)]],
    device float* outputData [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint x = gid.x;
    uint y = gid.y;
    
    if (x >= 512 || y >= 424) {
        return;
    }
    
    uint idx = y * 512 + x;
    float centerDepth = inputData[idx];
    
    if (centerDepth == 0.0f) {
        outputData[idx] = 0.0f;
        return;
    }
    
    // Bilateral filter parameters
    const float sigmaSpace = 2.0f;
    const float sigmaDepth = 0.05f; // 5cm
    
    float sum = 0.0f;
    float weightSum = 0.0f;
    
    // 5x5 window
    int radius = 2;
    for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
            int nx = (int)x + dx;
            int ny = (int)y + dy;
            
            if (nx < 0 || nx >= 512 || ny < 0 || ny >= 424) {
                continue;
            }
            
            uint nidx = ny * 512 + nx;
            float neighborDepth = inputData[nidx];
            
            if (neighborDepth == 0.0f) {
                continue;
            }
            
            // Spatial weight
            float distSpace = sqrt((float)(dx * dx + dy * dy));
            float weightSpace = exp(-(distSpace * distSpace) / (2.0f * sigmaSpace * sigmaSpace));
            
            // Range (depth) weight
            float distDepth = abs(centerDepth - neighborDepth);
            float weightDepth = exp(-(distDepth * distDepth) / (2.0f * sigmaDepth * sigmaDepth));
            
            float totalWeight = weightSpace * weightDepth;
            sum += neighborDepth * totalWeight;
            weightSum += totalWeight;
        }
    }
    
    outputData[idx] = (weightSum > 0.0f) ? (sum / weightSum) : centerDepth;
}

// Edge-preserving smoothing kernel
kernel void edgeAwareSmooth(
    device const float* inputData [[buffer(0)]],
    device float* outputData [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint x = gid.x;
    uint y = gid.y;
    
    if (x >= 512 || y >= 424 || x == 0 || y == 0 || x == 511 || y == 423) {
        outputData[y * 512 + x] = inputData[y * 512 + x];
        return;
    }
    
    uint idx = y * 512 + x;
    float center = inputData[idx];
    
    // Calculate gradients
    float gx = inputData[y * 512 + (x + 1)] - inputData[y * 512 + (x - 1)];
    float gy = inputData[(y + 1) * 512 + x] - inputData[(y - 1) * 512 + x];
    float gradient = sqrt(gx * gx + gy * gy);
    
    // Adaptive smoothing based on gradient
    float threshold = 0.02f; // 2cm
    float alpha = smoothstep(0.0f, threshold, gradient);
    
    // Apply weighted average
    float sum = center;
    float count = 1.0f;
    
    const int radius = 1;
    for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
            if (dx == 0 && dy == 0) continue;
            
            uint nx = x + dx;
            uint ny = y + dy;
            uint nidx = ny * 512 + nx;
            
            sum += inputData[nidx];
            count += 1.0f;
        }
    }
    
    float smoothed = sum / count;
    outputData[idx] = mix(smoothed, center, alpha);
}

// Hole filling kernel
kernel void holeFill(
    device const float* inputData [[buffer(0)]],
    device float* outputData [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint x = gid.x;
    uint y = gid.y;
    
    if (x >= 512 || y >= 424) {
        return;
    }
    
    uint idx = y * 512 + x;
    
    if (inputData[idx] != 0.0f) {
        outputData[idx] = inputData[idx];
        return;
    }
    
    // Find nearest valid depth
    float minDepth = FLT_MAX;
    const int maxRadius = 8;
    
    for (int r = 1; r <= maxRadius; r++) {
        for (int dy = -r; dy <= r; dy++) {
            for (int dx = -r; dx <= r; dx++) {
                if (abs(dx) != r && abs(dy) != r) continue; // Only check perimeter
                
                int nx = (int)x + dx;
                int ny = (int)y + dy;
                
                if (nx < 0 || nx >= 512 || ny < 0 || ny >= 424) {
                    continue;
                }
                
                uint nidx = ny * 512 + nx;
                float depth = inputData[nidx];
                
                if (depth > 0.0f && depth < minDepth) {
                    minDepth = depth;
                }
            }
        }
        
        if (minDepth != FLT_MAX) {
            break;
        }
    }
    
    outputData[idx] = (minDepth != FLT_MAX) ? minDepth : 0.0f;
}
