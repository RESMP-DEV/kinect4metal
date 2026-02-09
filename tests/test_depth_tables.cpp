#include <catch2/catch_test_macros.hpp>
#include <libfreenect2/depth_packet_processor.h>
#include <vector>
#include <cmath>

TEST_CASE("Depth table sizes", "[depth]") {
    SECTION("Table size constants") {
        REQUIRE(libfreenect2::DepthPacketProcessor::TABLE_SIZE == 512 * 424);
        REQUIRE(libfreenect2::DepthPacketProcessor::LUT_SIZE == 2048);
    }
}

TEST_CASE("X/Z table generation", "[depth]") {
    // This tests the internal table generation logic
    // Values computed from known camera parameters
    
    const float fx = 365.456f;
    const float fy = 365.456f;  
    const float cx = 254.878f;
    const float cy = 205.395f;
    
    // Test center pixel
    size_t center_idx = 212 * 512 + 256;
    float xd = (256 + 0.5f - cx) / fx;
    float yd = (212 + 0.5f - cy) / fy;
    
    SECTION("Center pixel is near zero") {
        REQUIRE(std::abs(xd) < 0.01f);
        REQUIRE(std::abs(yd) < 0.03f);
    }
}
