#include <catch2/catch_test_macros.hpp>
#include <catch2/matchers/catch_matchers_floating_point.hpp>
#include <libfreenect2/registration.h>

using namespace libfreenect2;
using Catch::Matchers::WithinRel;

TEST_CASE("Registration initialization", "[registration]") {
    // Default camera params
    Freenect2Device::IrCameraParams ir_params = {
        365.456f, 365.456f,  // fx, fy
        254.878f, 205.395f,  // cx, cy
        0.0f, 0.0f, 0.0f,    // k1, k2, k3
        0.0f, 0.0f           // p1, p2
    };
    
    Freenect2Device::ColorCameraParams color_params = {
        1081.37f, 1081.37f,  // fx, fy
        959.5f, 539.5f,      // cx, cy
        0.0f,                // shift_d
        0.0f,                // shift_m
        0.0f, 0.0f, 0.0f, 0.0f, 0.0f,  // mx_x3y0...
        0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f  // mx_x2y0...
    };
    
    SECTION("Can create registration object") {
        Registration reg(ir_params, color_params);
        // Should not crash
        REQUIRE(true);
    }
    
    SECTION("Point cloud at zero depth") {
        Registration reg(ir_params, color_params);
        float x, y, z;
        reg.getPointXYZ(nullptr, 0, 256, 212, x, y, z);
        // Zero depth should give zero coordinates
        REQUIRE(x == 0.0f);
        REQUIRE(y == 0.0f);
        REQUIRE(z == 0.0f);
    }
}
