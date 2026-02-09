# libfreenect2

## Table of Contents

* [Description](README.md#description)
* [Requirements](README.md#requirements)
* [Troubleshooting](README.md#troubleshooting-and-reporting-bugs)
* [Maintainers](README.md#maintainers)
* [Installation](README.md#installation)
  * [Windows / Visual Studio](README.md#windows--visual-studio)
  * [MacOS](README.md#macos)
  * [Linux](README.md#linux)
* [API Documentation (external)](https://openkinect.github.io/libfreenect2/)

## Description

Driver for Kinect for Windows v2 (K4W2) devices (release and developer preview).

Note: libfreenect2 does not do anything for either Kinect for Windows v1 or Kinect for Xbox 360 sensors. Use libfreenect1 for those sensors.

If you are using libfreenect2 in an academic context, please cite our work using the following DOI: [![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.50641.svg)](https://doi.org/10.5281/zenodo.50641)



If you use the KDE depth unwrapping algorithm implemented in the library, please also cite this ECCV 2016 [paper](http://users.isy.liu.se/cvl/perfo/abstracts/jaremo16.html).

This driver supports:
* RGB image transfer
* IR and depth image transfer
* registration of RGB and depth images

Missing features:
* firmware updates (see [issue #460](https://github.com/OpenKinect/libfreenect2/issues/460) for WiP)

Watch the OpenKinect wiki at www.openkinect.org and the mailing list at https://groups.google.com/forum/#!forum/openkinect for the latest developments and more information about the K4W2 USB protocol.

The API reference documentation is provided here https://openkinect.github.io/libfreenect2/.

## Requirements

### Hardware requirements

* USB 3.0 controller. USB 2 is not supported.

Intel and NEC USB 3.0 host controllers are known to work. ASMedia controllers are known to not work.

Virtual machines likely do not work, because USB 3.0 isochronous transfer is quite delicate.

##### Requirements for multiple Kinects

It has been reported to work for up to 5 devices on a high-end PC using multiple separate PCI Express USB3 expansion cards (with NEC controller chip). If you're using Linux, you may have to [increase USBFS memory buffers](https://github.com/OpenKinect/libfreenect2/wiki/Troubleshooting#multiple-kinects-try-increasing-usbfs-buffer-size). Depending on the number of Kinects, you may need to use an even larger buffer size. If you're using an expansion card, make sure it's not plugged into an PCI-E x1 slot. A single lane doesn't have enough bandwidth. x8 or x16 slots usually work.

### Operating system requirements

* Windows 10, Windows 11 (Windows 7/8/8.1 may work but are unsupported)
* Linux: Ubuntu 20.04, 22.04, 24.04, Debian 11+, and other modern Linux distributions
* macOS 11+ (Big Sur and newer)

### Requirements for optional features

* OpenGL depth processing: OpenGL 3.1 (Windows, Linux, macOS). OpenGL ES is not supported at the moment.
* OpenCL depth processing: OpenCL 1.2+ (Intel, AMD, or NVIDIA runtime)
* CUDA depth processing: CUDA 10.0+ (NVIDIA GPUs only)
* VAAPI JPEG decoding: Intel (Ivy Bridge or newer) and Linux only
* VideoToolbox JPEG decoding: macOS only
* OpenNI2 integration: OpenNI2 2.2.0.33 (optional, for OpenNI2-based applications)
* NVIDIA Jetson: JetPack 4.x or newer

## Troubleshooting and reporting bugs

First, check https://github.com/OpenKinect/libfreenect2/wiki/Troubleshooting for known issues.

When you report USB issues, please attach relevant debug log from running the program with environment variable `LIBUSB_DEBUG=3`, and relevant log from `dmesg`. Also include relevant hardware information `lspci` and `lsusb -t`.

## Maintainers

* Joshua Blake <joshblake@gmail.com>
* Florian Echtler
* Christian Kerl
* Lingzhu Xiang (development/master branch)

## Installation

### Windows / Visual Studio

* Install UsbDk driver

    1. (Windows 7) You must first install Microsoft Security Advisory 3033929 otherwise your USB keyboards and mice will stop working!
    2. Download the latest x64 installer from https://github.com/daynix/UsbDk/releases, install it.
    3. If UsbDk somehow does not work, uninstall UsbDk and follow the libusbK instructions.

    This doesn't interfere with the Microsoft SDK. Do not install both UsbDK and libusbK drivers
* (Alternatively) Install libusbK driver

    You don't need the Kinect for Windows v2 SDK to build and install libfreenect2, though it doesn't hurt to have it too. You don't need to uninstall the SDK or the driver before doing this procedure.

    Install the libusbK backend driver for libusb. Please follow the steps exactly:

    1. Download Zadig from http://zadig.akeo.ie/.
    2. Run Zadig and in options, check "List All Devices" and uncheck "Ignore Hubs or Composite Parents"
    3. Select the "Xbox NUI Sensor (composite parent)" from the drop-down box. (Important: Ignore the "NuiSensor Adaptor" varieties, which are the adapter, NOT the Kinect) The current driver will list usbccgp. USB ID is VID 045E, PID 02C4 or 02D8.
    4. Select libusbK (v3.0.7.0 or newer) from the replacement driver list.
    5. Click the "Replace Driver" button. Click yes on the warning about replacing a system driver. (This is because it is a composite parent.)

    To uninstall the libusbK driver (and get back the official SDK driver, if installed):

    1. Open "Device Manager"
    2. Under "libusbK USB Devices" tree, right click the "Xbox NUI Sensor (Composite Parent)" device and select uninstall.
    3. Important: Check the "Delete the driver software for this device." checkbox, then click OK.

    If you already had the official SDK driver installed and you want to use it:

    4. In Device Manager, in the Action menu, click "Scan for hardware changes."

    This will enumerate the Kinect sensor again and it will pick up the K4W2 SDK driver, and you should be ready to run KinectService.exe again immediately.

    You can go back and forth between the SDK driver and the libusbK driver very quickly and easily with these steps.

* Install libusb

    Download the latest build (.7z file) from https://github.com/libusb/libusb/releases, and extract as `depends/libusb` (rename folder `libusb-1.x.y` to `libusb` if any).
* Install TurboJPEG

    Download the `-vc64.exe` installer from http://sourceforge.net/projects/libjpeg-turbo/files, extract it to `c:\libjpeg-turbo64` (the installer's default) or `depends/libjpeg-turbo64`, or anywhere as specified by the environment variable `TurboJPEG_ROOT`.
* Install GLFW

    Download from http://www.glfw.org/download.html (64-bit), extract as `depends/glfw` (rename `glfw-3.x.x.bin.WIN64` to `glfw`), or anywhere as specified by the environment variable `GLFW_ROOT`.
* Install OpenCL (optional)
    1. Intel GPU: Download "Intel® SDK for OpenCL™ Applications 2016" from https://software.intel.com/en-us/intel-opencl (requires free registration) and install it.
* Install CUDA (optional, Nvidia only)
    1. Download CUDA Toolkit and install it. You MUST install the samples too.
* Install OpenNI2 (optional)

    Download OpenNI 2.2.0.33 (x64) from http://structure.io/openni, install it to default locations (`C:\Program Files...`).
* Build

    The default installation path is `install`, you may change it by editing `CMAKE_INSTALL_PREFIX`.
    ```
    mkdir build && cd build
    cmake .. -G "Visual Studio 17 2022" -A x64
    cmake --build . --config RelWithDebInfo --target install
    ```
    Or for older Visual Studio versions:
    - VS 2019: `-G "Visual Studio 16 2019" -A x64`
    - VS 2017: `-G "Visual Studio 15 2017" -A x64`
* Run the test program: `.\install\bin\Protonect.exe`, or start debugging in Visual Studio.
* Test OpenNI2 (optional)

    Copy freenect2-openni2.dll, and other dll files (libusb-1.0.dll, glfw.dll, etc.) in `install\bin` to `C:\Program Files\OpenNI2\Tools\OpenNI2\Drivers`. Then run `C:\Program Files\OpenNI\Tools\NiViewer.exe`. Environment variable `LIBFREENECT2_PIPELINE` can be set to `cl`, `cuda`, etc to specify the pipeline.

### Windows / vcpkg

You can download and install libfreenect2 using the [vcpkg](https://github.com/Microsoft/vcpkg) dependency manager:
```
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
./vcpkg integrate install
vcpkg install libfreenect2
```
The libfreenect2 port in vcpkg is kept up to date by Microsoft team members and community contributors. If the version is out of date, please [create an issue or pull request](https://github.com/Microsoft/vcpkg) on the vcpkg repository.

### MacOS

Use your favorite package managers (brew, ports, etc.) to install most if not all dependencies:

* Make sure these build tools are available: wget, git, cmake, pkg-config. Xcode may provide some of them. Install the rest via package managers.
* Download libfreenect2 source
    ```
    git clone https://github.com/OpenKinect/libfreenect2.git
    cd libfreenect2
    ```
* Install dependencies: libusb, GLFW
    ```
    brew update
    brew install libusb
    brew install glfw3
    ```
* Install TurboJPEG (optional)
    ```
    brew install jpeg-turbo
    ```
* Install CUDA (optional): TODO
* Install OpenNI2 (optional)
    ```
    brew tap brewsci/science
    brew install openni2
    export OPENNI2_REDIST=/usr/local/lib/ni2
    export OPENNI2_INCLUDE=/usr/local/include/ni2
    ```
* Build
    ```
    mkdir build && cd build
    cmake ..
    make
    make install
    ```
* Run the test program: `./bin/Protonect`
* Test OpenNI2. `make install-openni2` (may need sudo), then run `NiViewer`. Environment variable `LIBFREENECT2_PIPELINE` can be set to `cl`, `cuda`, etc to specify the pipeline.

### Linux

Supported distributions: Ubuntu 20.04+, Debian 11+, and other modern Linux distributions.

#### Quick Install (Ubuntu 20.04/22.04/24.04)

Run the automated installer script:
```bash
git clone https://github.com/OpenKinect/libfreenect2.git
cd libfreenect2
cd depends && ./install_ubuntu.sh
```

#### Manual Installation

* Download libfreenect2 source
    ```bash
    git clone https://github.com/OpenKinect/libfreenect2.git
    cd libfreenect2
    ```
* Install build tools
    ```bash
    sudo apt-get install build-essential cmake pkg-config
    ```
* Install libusb (version 1.0.20+ required)
    ```bash
    sudo apt-get install libusb-1.0-0-dev
    ```
* Install TurboJPEG
    ```bash
    sudo apt-get install libturbojpeg0-dev
    ```
* Install OpenGL (GLFW3)
    ```bash
    sudo apt-get install libglfw3-dev
    ```
* Install OpenCL (optional) - for GPU-accelerated depth processing
    ```bash
    # Install OpenCL headers and ICD loader
    sudo apt-get install ocl-icd-opencl-dev opencl-headers

    # Then install the appropriate OpenCL runtime for your GPU:
    # - Intel GPU: Install Intel Compute Runtime from Intel's website
    # - AMD GPU: Install ROCm or AMDGPU-PRO drivers
    # - NVIDIA GPU: Install CUDA (includes OpenCL support)

    # Verify OpenCL installation:
    sudo apt-get install clinfo && clinfo
    ```
* Install CUDA (optional, NVIDIA only):
    - Download CUDA Toolkit from https://developer.nvidia.com/cuda-downloads
    - Follow NVIDIA's installation instructions for your Ubuntu version
    - CUDA 10.0+ is required for C++17 support
* Install VAAPI (optional, Intel only)
    ```bash
    sudo apt-get install libva-dev libjpeg-dev
    ```
* Install OpenNI2 (optional)
    ```bash
    sudo apt-get install libopenni2-dev
    ```
* Build
    ```bash
    mkdir build && cd build
    cmake .. -DCMAKE_INSTALL_PREFIX=$HOME/freenect2
    make -j$(nproc)
    make install
    ```
    You need to specify `cmake -Dfreenect2_DIR=$HOME/freenect2/lib/cmake/freenect2` for CMake-based third-party applications to find libfreenect2.
* Set up udev rules for device access:
    ```bash
    sudo cp ../platform/linux/udev/90-kinect2.rules /etc/udev/rules.d/
    sudo udevadm control --reload-rules && sudo udevadm trigger
    ```
    Then replug the Kinect.
* Run the test program: `./bin/Protonect`
* Run OpenNI2 test (optional): `sudo apt-get install openni2-utils && sudo make install-openni2 && NiViewer2`. Environment variable `LIBFREENECT2_PIPELINE` can be set to `cl`, `cuda`, etc to specify the pipeline.
