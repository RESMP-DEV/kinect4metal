#!/bin/bash
# Validation script for Metal depth packet processor implementation

echo "Validating Metal depth packet processor implementation..."

# Check if all required files exist
echo ""
echo "Checking file existence..."

files=(
    "src/metal_depth_packet_processor.mm"
    "src/metal_depth_packet_processor.cpp"
    "src/metal_depth_processor_objc.h"
    "src/metal/depth_processing.metal"
    "include/internal/libfreenect2/metal_depth_packet_processor.h"
)

all_files_exist=true
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ $file exists"
    else
        echo "✗ $file missing"
        all_files_exist=false
    fi
done

# Check if Metal shader has required kernels
echo ""
echo "Checking Metal shader kernels..."

kernels=("processDepth" "filterDepth" "bilateralFilter" "holeFill" "edgeAwareSmooth")
shader_file="src/metal/depth_processing.metal"

for kernel in "${kernels[@]}"; do
    if grep -q "kernel void $kernel" "$shader_file"; then
        echo "✓ Kernel $kernel found"
    else
        echo "✗ Kernel $kernel missing"
    fi
done

# Check if Objective-C++ file has required methods
echo ""
echo "Checking Objective-C++ implementation methods..."

methods=(
    "initWithWidth:height:"
    "loadP0TablesFromCommandResponse:length:"
    "loadXZTables:zTable:length:"
    "loadLookupTable:length:"
    "processDepthData:outputTo:enableFilter:enableBilateral:"
    "isReady"
)

objc_file="src/metal_depth_packet_processor.mm"
header_file="src/metal_depth_processor_objc.h"

for method in "${methods[@]}"; do
    if grep -q "$method" "$header_file"; then
        echo "✓ Method $method declared in header"
    else
        echo "✗ Method $method not declared in header"
    fi
done

# Check Metal buffer storage modes
echo ""
echo "Checking Metal buffer storage modes..."

if grep -q "MTLStorageModeShared" "$objc_file"; then
    echo "✓ MTLStorageModeShared found"
else
    echo "✗ MTLStorageModeShared not found"
fi

if grep -q "MTLResourceStorageModePrivate" "$objc_file"; then
    echo "✓ MTLResourceStorageModePrivate found"
else
    echo "✗ MTLResourceStorageModePrivate not found"
fi

# Check for autoreleasepool usage
echo ""
echo "Checking autoreleasepool usage..."

if grep -q "@autoreleasepool" "$objc_file"; then
    echo "✓ autoreleasepool blocks found"
else
    echo "✗ autoreleasepool blocks not found"
fi

# Check CMakeLists.txt integration
echo ""
echo "Checking CMakeLists.txt integration..."

if grep -q "src/metal_depth_packet_processor.mm" "CMakeLists.txt"; then
    echo "✓ metal_depth_packet_processor.mm added to SOURCES"
else
    echo "✗ metal_depth_packet_processor.mm not in SOURCES"
fi

if grep -q "src/metal_depth_packet_processor.cpp" "CMakeLists.txt"; then
    echo "✓ metal_depth_packet_processor.cpp added to SOURCES"
else
    echo "✗ metal_depth_packet_processor.cpp not in SOURCES"
fi

# Summary
echo ""
echo "======================================="
if [ "$all_files_exist" = true ]; then
    echo "✓ All required files exist"
else
    echo "✗ Some files are missing"
fi
echo "======================================="
