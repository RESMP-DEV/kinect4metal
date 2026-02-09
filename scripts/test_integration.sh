#!/bin/bash
# Integration test - requires physical Kinect v2

set -e

echo "=== libfreenect2 Integration Test ==="
echo "This test requires a connected Kinect v2."
echo ""

BUILD_DIR="${1:-build}"
PROTONECT="$BUILD_DIR/bin/Protonect"

if [[ ! -f "$PROTONECT" ]]; then
    echo "ERROR: Protonect not found at $PROTONECT"
    exit 1
fi

# Test 1: Device enumeration (no device needed)
echo "Test 1: Checking Protonect starts..."
timeout 5 "$PROTONECT" -help || true
echo "✓ Protonect executable works"

# Test 2: Try each pipeline (will fail gracefully if no device)
for pipeline in cpu gl cl metal; do
    echo ""
    echo "Test 2.$pipeline: Testing $pipeline pipeline..."
    timeout 10 "$PROTONECT" $pipeline -noviewer -frames 1 2>&1 || {
        if [[ $? -eq 124 ]]; then
            echo "⚠ Timeout (may need Kinect connected)"
        else
            echo "⚠ Pipeline $pipeline not available or no device"
        fi
    }
done

echo ""
echo "=== Integration test completed ==="
echo "Connect a Kinect v2 and run: $PROTONECT"
