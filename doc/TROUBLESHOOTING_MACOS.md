# macOS Troubleshooting Guide {#troubleshooting_macos}

This guide covers common issues and solutions when using libfreenect2 on macOS, with specific focus on Apple Silicon (M1/M2/M3/M4) and Intel Macs.

---

## Build Issues

### CMake cannot find dependencies

**Error:** `Could not find LIBUSB` or similar

**Solutions:**

```bash
# Install all dependencies via Homebrew
brew install libusb glfw jpeg-turbo cmake
```

If Homebrew libraries are not found automatically (common on Apple Silicon):

```bash
# Apple Silicon Homebrew path (/opt/homebrew)
cmake .. -DLIBUSB_1_INCLUDE_DIR=/opt/homebrew/include \
         -DLIBUSB_1_LIBRARY=/opt/homebrew/lib/libusb-1.0.dylib \
         -DTURBOJPEG_INCLUDE_DIR=/opt/homebrew/opt/jpeg-turbo/include \
         -DTURBOJPEG_LIBRARY=/opt/homebrew/opt/jpeg-turbo/lib/libturbojpeg.dylib \
         -DGLFW_INCLUDE_DIR=/opt/homebrew/include \
         -DGLFW_LIBRARY=/opt/homebrew/lib/libglfw.dylib

# Intel Mac Homebrew path (/usr/local)
cmake .. -DLIBUSB_1_INCLUDE_DIR=/usr/local/include \
         -DLIBUSB_1_LIBRARY=/usr/local/lib/libusb-1.0.dylib \
         -DTURBOJPEG_INCLUDE_DIR=/usr/local/opt/jpeg-turbo/include \
         -DTURBOJPEG_LIBRARY=/usr/local/opt/jpeg-turbo/lib/libturbojpeg.dylib
```

### Build fails on Apple Silicon

**Error:** Architecture mismatch or undefined symbols

**Solutions:**

```bash
# Clean build directory
rm -rf build && mkdir build && cd build

# Option 1: Apple Silicon native (best performance)
cmake .. -DCMAKE_OSX_ARCHITECTURES=arm64
make -j$(sysctl -n hw.ncpu)

# Option 2: Universal binary (default, works on both)
cmake .. -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"
make -j$(sysctl -n hw.ncpu)

# Option 3: Intel only (for testing compatibility)
cmake .. -DCMAKE_OSX_ARCHITECTURES=x86_64
make -j$(sysctl -n hw.ncpu)
```

### Architecture mismatch with Homebrew libraries

**Error:** `ld: symbol(s) not found for architecture x86_64` or `arm64`

**Cause:** Mixing Apple Silicon and Intel libraries

**Solution:** Ensure all dependencies match your target architecture:

```bash
# Check library architecture
lipo -info /opt/homebrew/lib/libusb-1.0.dylib  # Should show: arm64
lipo -info /usr/local/lib/libusb-1.0.dylib      # Should show: x86_64

# Reinstall for correct architecture
arch -arm64 brew reinstall libusb glfw jpeg-turbo
```

---

## USB Issues

### "failed to claim interface"

**Cause:** Another process has the USB device, or permissions issue.

**Solutions:**

1. Unplug and replug the Kinect

2. Kill any other Kinect applications:
   ```bash
   ps aux | grep -i protonect
   kill <pid>
   ```

3. For signed apps, ensure USB entitlement is set in `Entitlements.plist`:
   ```xml
   <key>com.apple.security.device.usb</key>
   <true/>
   ```

### "max iso packet size too small"

**Cause:** USB controller bandwidth issue or USB 2.0 connection.

**Solutions:**

1. Plug directly into Mac (no USB hubs)
2. Use USB 3.0 port (Thunderbolt USB adapters work well)
3. Disconnect other high-bandwidth USB 3.0 devices
4. Try a different USB port or controller

**Verify USB 3.0 connection:**
```bash
system_profiler SPUSBDataType | grep -A 5 "Xbox"
# Look for "Speed: Up to 5 Gb/s" (USB 3.0)
```

### Kinect not detected

**Solutions:**

1. Verify USB 3.0 connection (Kinect v2 requires USB 3.0)

2. Check System Information for device:
   ```bash
   system_profiler SPUSBDataType | grep -A 10 "Xbox NUI Sensor"
   ```

3. Reset USB stack:
   ```bash
   sudo killall -STOP usbd && sudo killall -CONT usbd
   ```

4. Try a different cable (Kinect cable can be flaky)

5. Check for USB power issues (Kinect draws significant power):
   - Use powered USB hub if on MacBook battery
   - Connect MacBook to power adapter

---

## Pipeline Issues

### Metal Pipeline Not Available

**Error:** Metal pipeline not listed or fails to initialize

**Diagnostics:**
```bash
# Verify Metal is compiled in
cmake -L .. | grep METAL

# Check Metal GPU support
system_profiler SPDisplaysDataType | grep Metal

# Check running architecture (Apple Silicon)
arch  # Should print: arm64
uname -m  # Should print: arm64
```

**Solutions:**

```bash
# Build with Metal support explicitly enabled
cmake .. -DENABLE_METAL=ON
make -j$(sysctl -n hw.ncpu)

# Force Metal pipeline
export LIBFREENECT2_PIPELINE=metal
./Protonect

# Verify pipeline selection
LIBFREENECT2_LOGGER_LEVEL=debug ./Protonect 2>&1 | grep -i pipeline
```

### OpenCL Deprecation Warnings on Apple Silicon

**Info:** Apple deprecated OpenCL but it still works via automatic Metal translation.

Expected warnings (safe to ignore):
```
warning: 'OpenCL' is deprecated: first deprecated in macOS 10.14
```

**Recommendation:** Use Metal pipeline for best performance:
```cpp
libfreenect2::MetalPacketPipeline* pipeline = 
    new libfreenect2::MetalPacketPipeline();
```

### OpenGL Pipeline Issues

**Cause:** OpenGL is deprecated on macOS.

**Solutions:**
- On Apple Silicon: **Use Metal pipeline** (strongly recommended)
- On Intel Macs: Use OpenCL instead (better performance and future-proof)

Disable OpenGL if causing issues:
```bash
cmake .. -DENABLE_OPENGL=OFF
```

---

## Apple Silicon (M1/M2/M3/M4) Specifics

### Rosetta 2 Issues

**Error:** Running under Rosetta causes performance issues or Metal failures

**Check:**
```bash
arch  # Should print: arm64 for native, i386 for Rosetta
```

**Solution:** Run natively:
```bash
# Ensure Terminal is not using Rosetta
# Right-click Terminal.app → Get Info → Uncheck "Open using Rosetta"

# Or explicitly run with arch
arch -arm64 ./Protonect
```

### Performance Optimization

**Best practices for Apple Silicon:**

1. **Always use Metal pipeline:**
   ```bash
   export LIBFREENECT2_PIPELINE=metal
   ```

2. **Build for arm64 only** (if you don't need Intel compatibility):
   ```bash
   cmake .. -DCMAKE_OSX_ARCHITECTURES=arm64
   ```

3. **VideoToolbox is automatic** for color image decoding (no configuration needed)

4. **Memory optimization** - release frames promptly:
   ```cpp
   listener->release(frames);  // Zero-copy on Apple Silicon
   ```

### Metal-Specific Issues

**"Failed to create Metal command queue"**

- Ensure macOS 11.0 or newer: `sw_vers -productVersion`
- Check GPU support: `system_profiler SPDisplaysDataType | grep Metal`
- Restart may help after GPU driver updates

**Low Metal performance**

- Check Activity Monitor → Window → GPU History
- Ensure no other Metal apps are competing for GPU
- Verify not running under Rosetta 2

---

## Multiple Kinects

macOS handles multiple Kinects well with these considerations:

- Each Kinect needs dedicated USB 3.0 bandwidth
- Use separate USB controllers if possible
- Thunderbolt docks with multiple USB 3.0 ports work well

**Test multiple devices:**
```bash
# List all Kinects
./Protonect list

# Open specific device in separate terminals
./Protonect <serial1>  # Terminal 1
./Protonect <serial2>  # Terminal 2
```

**Multi-device code:**
```cpp
libfreenect2::Freenect2 freenect2;
int numDevices = freenect2.enumerateDevices();

for (int i = 0; i < numDevices; i++) {
    std::string serial = freenect2.getDeviceSerialNumber(i);
    auto* dev = freenect2.openDevice(serial, 
        new libfreenect2::MetalPacketPipeline());
    // ... configure and start
}
```

---

## Framework Issues

### Framework not found in Xcode

**Solution:**
1. Build the framework:
   ```bash
   cmake .. -DBUILD_FRAMEWORK=ON
   make
   ```

2. In Xcode: 
   - Build Settings → Framework Search Paths → add `$(PROJECT_DIR)/libfreenect2/build/lib`
   - General → Frameworks, Libraries → add `freenect2.framework`

### Code signing issues with framework

**Solution:** Add to your app's entitlements:
```xml
<key>com.apple.security.device.usb</key>
<true/>
```

---

## Debugging

### Enable libusb debug output

```bash
export LIBUSB_DEBUG=3  # Levels 1-4 (4 is most verbose)
./Protonect
```

### Enable libfreenect2 debug logging

In code:
```cpp
libfreenect2::setGlobalLogger(
    libfreenect2::createConsoleLogger(libfreenect2::Logger::Debug)
);
```

Or via environment:
```bash
export LIBFREENECT2_LOGGER_LEVEL=debug
./Protonect
```

### Log to file

```bash
./Protonect 2>&1 | tee freenect2.log
```

### Verify Pipeline Selection

```bash
# Check which pipeline is actually being used
LIBFREENECT2_LOGGER_LEVEL=debug ./Protonect 2>&1 | grep -i pipeline
```

### System Information

Gather diagnostic info:
```bash
# macOS version
sw_vers

# Hardware info
system_profiler SPHardwareDataType

# GPU info
system_profiler SPDisplaysDataType

# USB devices
system_profiler SPUSBDataType | grep -A 10 "Xbox"

# Running architecture
arch
uname -m
```

---

## Known Limitations

| Feature | Status | Notes |
|---------|--------|-------|
| Audio | ⚠️ Partial | Raw USB audio accessible, no directional audio processing |
| Firmware upload | ❌ Not supported | Use Windows PC for firmware updates |
| Multiple Kinects | ✅ Supported | Separate USB controllers recommended |
| Metal compute | ✅ Supported | Native on Apple Silicon |
| OpenCL | ⚠️ Deprecated | Works via Metal translation, emits warnings |
| OpenGL | ⚠️ Legacy | Deprecated by Apple, avoid on new projects |

---

## Getting Help

If issues persist:

1. Check [GitHub Issues](https://github.com/RESMP-DEV/libfreenect2/issues)

2. Include diagnostic output:
   ```bash
   # Create diagnostic report
   {
     echo "=== macOS Version ==="
     sw_vers
     echo ""
     echo "=== Hardware ==="
     system_profiler SPHardwareDataType
     echo ""
     echo "=== GPU ==="
     system_profiler SPDisplaysDataType
     echo ""
     echo "=== USB ==="
     system_profiler SPUSBDataType | grep -A 10 "Xbox"
     echo ""
     echo "=== Build Info ==="
     cmake -L .. 2>/dev/null | grep -E "(METAL|OPENCL|OPENGL)"
     echo ""
     echo "=== Runtime Log ==="
     LIBFREENECT2_LOGGER_LEVEL=debug timeout 10 ./Protonect 2>&1 || true
   } > diagnostic.txt
   ```

3. Report macOS version and hardware:
   - macOS version: `sw_vers -productVersion`
   - Hardware: `system_profiler SPHardwareDataType | grep "Model Identifier"`
   - Architecture: `uname -m`
