CMAKE_MINIMUM_REQUIRED(VERSION 3.10)

SET(PROJECT_VER_MAJOR 0)
SET(PROJECT_VER_MINOR 2)
SET(PROJECT_VER_PATCH 1)
SET(PROJECT_VER "${PROJECT_VER_MAJOR}.${PROJECT_VER_MINOR}.${PROJECT_VER_PATCH}")
SET(PROJECT_APIVER "${PROJECT_VER_MAJOR}.${PROJECT_VER_MINOR}")

IF(NOT DEFINED CMAKE_BUILD_TYPE)
  # No effect for multi-configuration generators.
  SET(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "Choose: RelWithDebInfo Release Debug MinSizeRel None")
ENDIF()

PROJECT(libfreenect2)

# Apple Silicon support
IF(APPLE)
  SET(CMAKE_OSX_ARCHITECTURES "arm64;x86_64" CACHE STRING "Build architectures")
  SET(CMAKE_OSX_DEPLOYMENT_TARGET "11.0" CACHE STRING "Minimum macOS version")
ENDIF()

# Modern CMake policies
cmake_policy(SET CMP0042 NEW)  # MACOSX_RPATH enabled by default

SET(MY_DIR ${libfreenect2_SOURCE_DIR})
SET(DEPENDS_DIR "${MY_DIR}/depends" CACHE STRING "dependency directory must be set to 'false' if external deps are used")

OPTION(BUILD_SHARED_LIBS "Build shared (ON) or static (OFF) libraries" ON)
OPTION(BUILD_EXAMPLES "Build examples" ON)
OPTION(BUILD_OPENNI2_DRIVER "Build OpenNI2 driver" ON)
OPTION(ENABLE_OPENCL "Enable OpenCL support" ON)
OPTION(ENABLE_CUDA "Enable CUDA support" ON)
OPTION(ENABLE_OPENGL "Enable OpenGL support" ON)
OPTION(ENABLE_METAL "Enable Metal compute support" ON)
OPTION(ENABLE_PROFILING "Collect profiling stats (memory consuming)" OFF)

IF(ENABLE_PROFILING)
  SET(LIBFREENECT2_WITH_PROFILING 1)
ENDIF()

# Modern C++ standard - require C++17 (available on all modern compilers)
SET(CMAKE_CXX_STANDARD 17)
SET(CMAKE_CXX_STANDARD_REQUIRED ON)
SET(CMAKE_CXX_EXTENSIONS OFF)
IF(APPLE)
  # Ensure arm64 builds when not explicitly building a universal binary.
  IF(NOT CMAKE_OSX_ARCHITECTURES MATCHES "arm64" OR NOT CMAKE_OSX_ARCHITECTURES MATCHES "x86_64")
    SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -arch arm64")
  ENDIF()
ENDIF()
SET(LIBFREENECT2_WITH_CXX11_SUPPORT 1)
SET(HAVE_CXX11 yes)
# Also set flags for checks in threading setup
SET(COMPILER_SUPPORTS_CXX11 ON)

# macOS-focused compiler warnings.
SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall")

# additional cmake modules
LIST(APPEND CMAKE_MODULE_PATH ${MY_DIR}/cmake_modules)

# setup threading
INCLUDE(SetupLibfreenect2Threading)

INCLUDE(GenerateResources)

#set the default path for built executables to the "bin" directory
SET(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/bin)

#set the default path for built libraries to the "lib" directory
SET(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib)
SET(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib)

# dependencies
FIND_PACKAGE(LibUSB REQUIRED)

# Add includes
INCLUDE_DIRECTORIES(
  "${MY_DIR}/include"
  "${MY_DIR}/include/internal"
  ${PROJECT_BINARY_DIR} # for generated headers
  ${LIBFREENECT2_THREADING_INCLUDE_DIR}
  ${LibUSB_INCLUDE_DIRS}
)

SET(RESOURCES_INC_FILE "${PROJECT_BINARY_DIR}/resources.inc.h")

SET(SOURCES
  include/internal/libfreenect2/protocol/command.h
  include/internal/libfreenect2/protocol/command_transaction.h
  include/internal/libfreenect2/protocol/response.h
  include/internal/libfreenect2/protocol/usb_control.h

  include/internal/libfreenect2/usb/event_loop.h
  include/internal/libfreenect2/usb/transfer_pool.h

  include/libfreenect2/logger.h
  include/internal/libfreenect2/logging.h

  include/internal/libfreenect2/async_packet_processor.h
  include/internal/libfreenect2/depth_packet_processor.h
  include/internal/libfreenect2/depth_packet_stream_parser.h
  include/internal/libfreenect2/allocator.h
  include/libfreenect2/frame_listener.hpp
  include/libfreenect2/frame_listener_impl.h
  include/libfreenect2/libfreenect2.hpp
  include/libfreenect2/color_settings.h
  include/libfreenect2/led_settings.h
  include/libfreenect2/packet_pipeline.h
  include/internal/libfreenect2/packet_processor.h
  include/libfreenect2/registration.h
  include/internal/libfreenect2/resource.h
  include/internal/libfreenect2/rgb_packet_processor.h
  include/internal/libfreenect2/rgb_packet_stream_parser.h
  include/internal/libfreenect2/threading.h

  src/transfer_pool.cpp
  src/event_loop.cpp
  src/usb_control.cpp
  src/allocator.cpp
  src/frame_listener_impl.cpp
  src/packet_pipeline.cpp
  src/rgb_packet_stream_parser.cpp
  src/rgb_packet_processor.cpp
  src/depth_packet_stream_parser.cpp
  src/depth_packet_processor.cpp
  src/cpu_depth_packet_processor.cpp
  src/resource.cpp
  src/command_transaction.cpp
  src/registration.cpp
  src/logging.cpp
  src/libfreenect2.cpp

  ${LIBFREENECT2_THREADING_SOURCE}
  ${RESOURCES_INC_FILE}
  "${PROJECT_BINARY_DIR}/libfreenect2/config.h"
  "${PROJECT_BINARY_DIR}/libfreenect2/export.h"
)

SET(LIBRARIES
  ${LibUSB_LIBRARIES}
  ${LIBFREENECT2_THREADING_LIBRARIES}
)

SET(LIBFREENECT2_DLLS
  ${LibUSB_DLL}
)

SET(HAVE_VideoToolbox "no (Apple only)")
IF(APPLE)
  FIND_LIBRARY(VIDEOTOOLBOX_LIBRARY VideoToolbox)

  SET(HAVE_VideoToolbox no)
  IF(VIDEOTOOLBOX_LIBRARY)
    SET(LIBFREENECT2_WITH_VT_SUPPORT 1)
    SET(HAVE_VideoToolbox yes)

    FIND_LIBRARY(COREFOUNDATION_LIBRARY CoreFoundation REQUIRED)
    FIND_LIBRARY(COREMEDIA_LIBRARY CoreMedia REQUIRED)
    FIND_LIBRARY(COREVIDEO_LIBRARY CoreVideo REQUIRED)

    LIST(APPEND SOURCES
      src/vt_rgb_packet_processor.cpp
    )

    LIST(APPEND LIBRARIES
      ${VIDEOTOOLBOX_LIBRARY}
      ${COREFOUNDATION_LIBRARY}
      ${COREMEDIA_LIBRARY}
      ${COREVIDEO_LIBRARY}
    )
  ENDIF(VIDEOTOOLBOX_LIBRARY)
ENDIF(APPLE)

IF(LIBFREENECT2_WITH_VT_SUPPORT)
  FIND_PACKAGE(TurboJPEG)
ELSE()
  # VideoToolbox is preferred on macOS; TurboJPEG remains the required fallback.
  FIND_PACKAGE(TurboJPEG REQUIRED)
ENDIF()

SET(HAVE_TurboJPEG no)
IF(TurboJPEG_FOUND)
  SET(LIBFREENECT2_WITH_TURBOJPEG_SUPPORT 1)
  SET(HAVE_TurboJPEG yes)

  INCLUDE_DIRECTORIES(${TurboJPEG_INCLUDE_DIRS})

  LIST(APPEND SOURCES
    src/turbo_jpeg_rgb_packet_processor.cpp
  )

  LIST(APPEND LIBRARIES
    ${TurboJPEG_LIBRARIES}
  )

  LIST(APPEND LIBFREENECT2_DLLS
   ${TurboJPEG_DLL}
  )
ENDIF()

SET(HAVE_OpenGL disabled)
IF(ENABLE_OPENGL)
  FIND_PACKAGE(GLFW3)
  FIND_PACKAGE(OpenGL)
  SET(HAVE_OpenGL no)
  IF(GLFW3_FOUND AND OPENGL_FOUND)
    SET(LIBFREENECT2_WITH_OPENGL_SUPPORT 1)
    SET(HAVE_OpenGL yes)

    INCLUDE_DIRECTORIES(${GLFW3_INCLUDE_DIRS})

    LIST(APPEND LIBFREENECT2_DLLS ${GLFW3_DLL})
    LIST(APPEND LIBRARIES
      ${GLFW3_LIBRARIES}
      ${OPENGL_gl_LIBRARY}
    )
    LIST(APPEND SOURCES
      src/flextGL.cpp
      src/opengl_depth_packet_processor.cpp
    )

    LIST(APPEND RESOURCES
      src/shader/debug.fs
      src/shader/default.vs
      src/shader/filter1.fs
      src/shader/filter2.fs
      src/shader/stage1.fs
      src/shader/stage2.fs
    )
  ENDIF()
ENDIF(ENABLE_OPENGL)

SET(HAVE_OpenCL disabled)
IF(ENABLE_OPENCL)
  FIND_PACKAGE(OpenCL)

  SET(HAVE_OpenCL no)
  IF(OpenCL_FOUND)
    SET(LIBFREENECT2_WITH_OPENCL_SUPPORT 1)
    SET(HAVE_OpenCL yes)

    IF(APPLE)
      # Prefer Apple's OpenCL.framework headers from the SDK.
      # Keep bundled include/internal/CL/cl.hpp as a compatibility fallback.
      SET(OpenCL_INCLUDE_DIR "")
      SET(OpenCL_INCLUDE_DIRS "")
    ENDIF(APPLE)

    INCLUDE_DIRECTORIES(${OpenCL_INCLUDE_DIRS})

    LIST(APPEND SOURCES
      src/opencl_depth_packet_processor.cpp
      src/opencl_kde_depth_packet_processor.cpp
    )

    LIST(APPEND LIBRARIES
      ${OpenCL_LIBRARIES}
    )

    LIST(APPEND RESOURCES
      src/opencl_depth_packet_processor.cl
      src/opencl_kde_depth_packet_processor.cl
    )
  ENDIF(OpenCL_FOUND)
ENDIF(ENABLE_OPENCL)

SET(HAVE_Metal disabled)
IF(ENABLE_METAL AND APPLE)
  FIND_LIBRARY(METAL_LIBRARY Metal)
  FIND_LIBRARY(METALKIT_LIBRARY MetalKit)
  
  SET(HAVE_Metal no)
  IF(METAL_LIBRARY AND METALKIT_LIBRARY)
    SET(LIBFREENECT2_WITH_METAL_SUPPORT 1)
    SET(HAVE_Metal yes)
    
    LIST(APPEND SOURCES
      src/metal_depth_packet_processor.mm
      src/metal_depth_packet_processor.cpp
    )
    
    LIST(APPEND LIBRARIES
      ${METAL_LIBRARY}
      ${METALKIT_LIBRARY}
    )
    
    # Compile Metal shaders
    SET(METAL_SHADER_SOURCE ${MY_DIR}/src/metal/depth_processing.metal)
    SET(METAL_SHADER_AIR ${PROJECT_BINARY_DIR}/depth_processing.air)
    SET(METAL_SHADER_LIB ${PROJECT_BINARY_DIR}/depth_processing.metallib)
    
    ADD_CUSTOM_COMMAND(
      OUTPUT ${METAL_SHADER_AIR}
      COMMAND xcrun -sdk macosx metal -c ${METAL_SHADER_SOURCE} -o ${METAL_SHADER_AIR}
      DEPENDS ${METAL_SHADER_SOURCE}
      COMMENT "Compiling Metal shader to AIR"
    )
    
    ADD_CUSTOM_COMMAND(
      OUTPUT ${METAL_SHADER_LIB}
      COMMAND xcrun -sdk macosx metallib ${METAL_SHADER_AIR} -o ${METAL_SHADER_LIB}
      DEPENDS ${METAL_SHADER_AIR}
      COMMENT "Linking Metal shader library"
    )
    
    ADD_CUSTOM_TARGET(MetalShaders DEPENDS ${METAL_SHADER_LIB})
    ADD_DEPENDENCIES(freenect2 MetalShaders)
    
    INSTALL(FILES ${METAL_SHADER_LIB} DESTINATION lib)
  ENDIF(METAL_LIBRARY AND METALKIT_LIBRARY)
ENDIF(ENABLE_METAL AND APPLE)


SET(HAVE_CUDA disabled)
IF(ENABLE_CUDA)
  FIND_PACKAGE(CUDA)
  SET(HAVE_CUDA no)
  IF(CUDA_FOUND)
    # Require CUDA 10.0+ for modern C++ support
    IF(CUDA_VERSION VERSION_LESS 10.0)
      SET(HAVE_CUDA "no (CUDA 10.0+ required)")
      MESSAGE(WARNING "CUDA ${CUDA_VERSION} found but CUDA 10.0+ is required for C++17 support")
    ELSE()
      SET(LIBFREENECT2_WITH_CUDA_SUPPORT 1)
      SET(HAVE_CUDA yes)

      STRING(REPLACE "\\" "/" NVCUDASAMPLES_ROOT "$ENV{NVCUDASAMPLES_ROOT}")
      CUDA_INCLUDE_DIRECTORIES(
        "${MY_DIR}/include/"
        "${CUDA_TOOLKIT_ROOT_DIR}/samples/common/inc"
        "${NVCUDASAMPLES_ROOT}/common/inc"
      )
      SET(CUDA_FLAGS -use_fast_math)
      SET(CUDA_FLAGS "${CUDA_FLAGS} -Xcompiler -fPIC")
      # Use C++17 for CUDA (CUDA 10.0+ supports C++14, CUDA 12.0+ fully supports C++17)
      IF(CUDA_VERSION VERSION_GREATER_EQUAL 12.0)
        SET(CUDA_FLAGS "${CUDA_FLAGS} -std=c++17")
      ELSE()
        SET(CUDA_FLAGS "${CUDA_FLAGS} -std=c++14")
      ENDIF()

      CUDA_COMPILE(CUDA_OBJECTS
        src/cuda_depth_packet_processor.cu
        src/cuda_kde_depth_packet_processor.cu
        OPTIONS ${CUDA_FLAGS}
      )

      INCLUDE_DIRECTORIES(${CUDA_INCLUDE_DIRS})

      LIST(APPEND SOURCES
        ${CUDA_OBJECTS}
      )

      LIST(APPEND LIBRARIES
        ${CUDA_LIBRARIES}
      )
    ENDIF()
  ENDIF(CUDA_FOUND)
ENDIF(ENABLE_CUDA)

# RPATH handling for private libusb copies
# Users have two options:
# 1. Build libusb in depends/ and leave it there:
#      Do NOT set CMAKE_INSTALL_RPATH. It works by default.
# 2. Build libusb and install it somewhere:
#      Set CMAKE_INSTALL_RPATH to the libusb.so installation directory before compiling.
# Both command line -DCMAKE_INSTALL_RPATH=... and CMake GUI settings are accepted.
#
# Anyway if wrong versions of libusb is used, errors will be reported explicitly.
IF(NOT DEFINED CMAKE_INSTALL_RPATH AND NOT ${LibUSB_LIBDIR} MATCHES "^/usr/lib")
  SET(CMAKE_INSTALL_RPATH ${LibUSB_LIBDIR} CACHE STRING "Set RPATH for a private libusb")
ELSEIF(DEFINED CMAKE_INSTALL_RPATH)
  SET(CMAKE_INSTALL_RPATH ${CMAKE_INSTALL_RPATH} CACHE STRING "Set RPATH for a private libusb")
ENDIF()
IF(DEFINED CMAKE_INSTALL_RPATH)
  MESSAGE(STATUS "RPATH set to ${CMAKE_INSTALL_RPATH}")
ENDIF()

CONFIGURE_FILE("${MY_DIR}/include/libfreenect2/config.h.in" "${PROJECT_BINARY_DIR}/libfreenect2/config.h" @ONLY)
GENERATE_RESOURCES(${RESOURCES_INC_FILE} ${MY_DIR} ${RESOURCES})

ADD_DEFINITIONS(-DRESOURCES_INC)
ADD_LIBRARY(freenect2 ${SOURCES})
SET_TARGET_PROPERTIES(freenect2 PROPERTIES
  CXX_VISIBILITY_PRESET hidden
  VISIBILITY_INLINES_HIDDEN 1
  VERSION ${PROJECT_VER}
  SOVERSION ${PROJECT_APIVER}
)
IF(APPLE)
  OPTION(BUILD_FRAMEWORK "Build as macOS Framework" ON)
  IF(BUILD_FRAMEWORK)
    SET_TARGET_PROPERTIES(freenect2 PROPERTIES
      FRAMEWORK TRUE
      FRAMEWORK_VERSION A
      MACOSX_FRAMEWORK_IDENTIFIER org.openkinect.libfreenect2
      MACOSX_FRAMEWORK_SHORT_VERSION_STRING ${PROJECT_VER}
      MACOSX_FRAMEWORK_BUNDLE_VERSION ${PROJECT_VER}
      PUBLIC_HEADER "${MY_DIR}/include/libfreenect2/libfreenect2.hpp;${MY_DIR}/include/libfreenect2/frame_listener.hpp;${MY_DIR}/include/libfreenect2/frame_listener_impl.h;${MY_DIR}/include/libfreenect2/packet_pipeline.h;${MY_DIR}/include/libfreenect2/registration.h;${MY_DIR}/include/libfreenect2/logger.h;${MY_DIR}/include/libfreenect2/config.h;${PROJECT_BINARY_DIR}/libfreenect2/config.h;${PROJECT_BINARY_DIR}/libfreenect2/export.h"
    )
  ENDIF()
ENDIF()
INCLUDE(GenerateExportHeader)
GENERATE_EXPORT_HEADER(freenect2
  BASE_NAME libfreenect2
  EXPORT_FILE_NAME libfreenect2/export.h
)

STRING(REPLACE ";" "\n " LIBRARIES_STRING "${LIBRARIES}")
MESSAGE(STATUS "Linking with these libraries: \n ${LIBRARIES_STRING}")
TARGET_LINK_LIBRARIES(freenect2 ${LIBRARIES})

CONFIGURE_FILE(freenect2.cmake.in "${PROJECT_BINARY_DIR}/freenect2Config.cmake" @ONLY)
CONFIGURE_FILE(freenect2Version.cmake.in "${PROJECT_BINARY_DIR}/freenect2ConfigVersion.cmake" @ONLY)
CONFIGURE_FILE(freenect2.pc.in "${PROJECT_BINARY_DIR}/freenect2.pc" @ONLY)

INSTALL(TARGETS freenect2 DESTINATION lib RUNTIME DESTINATION bin)
INSTALL(DIRECTORY "${MY_DIR}/include/${PROJECT_NAME}" DESTINATION include PATTERN "*.in" EXCLUDE)
INSTALL(DIRECTORY "${PROJECT_BINARY_DIR}/${PROJECT_NAME}" DESTINATION include)
INSTALL(FILES "${PROJECT_BINARY_DIR}/freenect2Config.cmake" DESTINATION lib/cmake/freenect2/)
INSTALL(FILES "${PROJECT_BINARY_DIR}/freenect2ConfigVersion.cmake" DESTINATION lib/cmake/freenect2/)
INSTALL(FILES "${PROJECT_BINARY_DIR}/freenect2.pc" DESTINATION lib/pkgconfig/)

ADD_SUBDIRECTORY(${MY_DIR}/doc)

SET(HAVE_Examples disabled)
IF(BUILD_EXAMPLES)
  SET(HAVE_Examples yes)
  MESSAGE(STATUS "Configurating examples")
  ADD_SUBDIRECTORY(${MY_DIR}/examples)
ENDIF()

SET(HAVE_OpenNI2 disabled)
IF(BUILD_OPENNI2_DRIVER)
  FIND_PACKAGE(OpenNI2)
  SET(HAVE_OpenNI2 no)
  IF(OpenNI2_FOUND)
    SET(HAVE_OpenNI2 yes)
    FILE(GLOB OPENNI2_DRIVER_SOURCES src/openni2/*.cpp)
    ADD_LIBRARY(freenect2-openni2 ${OPENNI2_DRIVER_SOURCES} ${LIBFREENECT2_THREADING_SOURCE})
    TARGET_INCLUDE_DIRECTORIES(freenect2-openni2 PRIVATE ${OpenNI2_INCLUDE_DIRS})
    TARGET_LINK_LIBRARIES(freenect2-openni2 freenect2 ${LIBFREENECT2_THREADING_LIBRARIES})
    SET_TARGET_PROPERTIES(freenect2-openni2 PROPERTIES SOVERSION 0)
    IF(NOT ${CMAKE_INSTALL_PREFIX} MATCHES "^/usr")
      SET_TARGET_PROPERTIES(freenect2-openni2 PROPERTIES INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib")
    ENDIF()
    INSTALL(TARGETS freenect2-openni2 DESTINATION lib/OpenNI2/Drivers RUNTIME DESTINATION bin)
    ADD_CUSTOM_TARGET(install-openni2
      DEPENDS freenect2-openni2
      COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_INSTALL_PREFIX}/lib/OpenNI2/Drivers/" "${OpenNI2_LIBRARY_DIR}/OpenNI2/Drivers/"
      VERBATIM
    )
  ENDIF()
ENDIF()

OPTION(BUILD_STREAMER_RECORDER "Build streamer_recorder" OFF)
SET(HAVE_streamer_recorder disabled)
IF(BUILD_STREAMER_RECORDER)
  SET(HAVE_streamer_recorder yes)
  MESSAGE(STATUS "Configurating streamer_recorder")
  ADD_SUBDIRECTORY(${MY_DIR}/tools/streamer_recorder)
ENDIF()

# Tests
IF(EXISTS "${MY_DIR}/tests/CMakeLists.txt")
  ADD_SUBDIRECTORY(tests)
ENDIF()

GET_CMAKE_PROPERTY(vars VARIABLES)
MESSAGE(STATUS "Feature list:")
FOREACH(var ${vars})
  IF(var MATCHES ^HAVE_)
    STRING(REPLACE HAVE_ "" feature ${var})
    MESSAGE(STATUS "  ${feature}    ${${var}}")
  ENDIF()
ENDFOREACH()
