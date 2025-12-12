# FindTurboJPEG.cmake
# Uses environment variable TurboJPEG_ROOT as backup
# - TurboJPEG_FOUND
# - TurboJPEG_INCLUDE_DIRS
# - TurboJPEG_LIBRARIES

FIND_PATH(TurboJPEG_INCLUDE_DIRS
  turbojpeg.h
  DOC "Found TurboJPEG include directory"
  PATHS
    "${DEPENDS_DIR}/libjpeg_turbo"
    "${DEPENDS_DIR}/libjpeg-turbo64"
    "/usr/local/opt/jpeg-turbo" # homebrew (Intel)
    "/opt/homebrew/opt/jpeg-turbo" # homebrew (Apple Silicon)
    "/opt/local" # macports
    "C:/libjpeg-turbo64"
    "/opt/libjpeg-turbo"
    ENV TurboJPEG_ROOT
  PATH_SUFFIXES
    include
)

# Library names by distribution:
# Ubuntu 17.10+ / Debian 9+: libturbojpeg0-dev provides libturbojpeg.so.0
# Ubuntu 24.04: libturbojpeg0-dev (libturbojpeg.so.0)
# Older Ubuntu (14.04-16.04): libjpeg-turbo8-dev provides libturbojpeg.so.1
FIND_LIBRARY(TurboJPEG_LIBRARIES
  NAMES turbojpeg libturbojpeg.so.0 libturbojpeg.so.1
  DOC "Found TurboJPEG library path"
  PATHS
    "${DEPENDS_DIR}/libjpeg_turbo"
    "${DEPENDS_DIR}/libjpeg-turbo64"
    "/usr/local/opt/jpeg-turbo" # homebrew (Intel)
    "/opt/homebrew/opt/jpeg-turbo" # homebrew (Apple Silicon)
    "/opt/local" # macports
    "C:/libjpeg-turbo64"
    "/opt/libjpeg-turbo"
    ENV TurboJPEG_ROOT
  PATH_SUFFIXES
    lib
    lib64
    lib/x86_64-linux-gnu  # Ubuntu/Debian multiarch
    lib/aarch64-linux-gnu # ARM64 multiarch
)

IF(WIN32)
FIND_FILE(TurboJPEG_DLL
  turbojpeg.dll
  DOC "Found TurboJPEG DLL path"
  PATHS
    "${DEPENDS_DIR}/libjpeg_turbo"
    "${DEPENDS_DIR}/libjpeg-turbo64"
    "C:/libjpeg-turbo64"
    ENV TurboJPEG_ROOT
  PATH_SUFFIXES
    bin
)
ENDIF()

IF(TurboJPEG_INCLUDE_DIRS AND TurboJPEG_LIBRARIES)
INCLUDE(CheckCSourceCompiles)
set(CMAKE_REQUIRED_INCLUDES ${TurboJPEG_INCLUDE_DIRS})
set(CMAKE_REQUIRED_LIBRARIES ${TurboJPEG_LIBRARIES})
check_c_source_compiles("#include <turbojpeg.h>\nint main(void) { tjhandle h=tjInitCompress(); return 0; }" TURBOJPEG_WORKS)
set(CMAKE_REQUIRED_DEFINITIONS)
set(CMAKE_REQUIRED_INCLUDES)
set(CMAKE_REQUIRED_LIBRARIES)
ENDIF()

INCLUDE(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(TurboJPEG FOUND_VAR TurboJPEG_FOUND
  REQUIRED_VARS TurboJPEG_LIBRARIES TurboJPEG_INCLUDE_DIRS TURBOJPEG_WORKS)
