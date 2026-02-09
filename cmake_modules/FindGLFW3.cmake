# - Try to find GLFW3
#
# If no pkgconfig, define GLFW_ROOT to installation tree
# Will define the following:
# GLFW3_FOUND
# GLFW3_INCLUDE_DIRS
# GLFW3_LIBRARIES

# Homebrew paths for macOS
IF(APPLE)
  LIST(APPEND CMAKE_PREFIX_PATH "/opt/homebrew" "/usr/local")
ENDIF()

IF(PKG_CONFIG_FOUND)
  IF(APPLE)
    # homebrew or macports pkgconfig locations
    SET(ENV{PKG_CONFIG_PATH} "/opt/homebrew/opt/glfw/lib/pkgconfig:/opt/homebrew/opt/glfw3/lib/pkgconfig:/opt/homebrew/lib/pkgconfig:/usr/local/opt/glfw/lib/pkgconfig:/usr/local/opt/glfw3/lib/pkgconfig:/usr/local/lib/pkgconfig:/opt/local/lib/pkgconfig:$ENV{PKG_CONFIG_PATH}")
  ENDIF()
  SET(ENV{PKG_CONFIG_PATH} "${DEPENDS_DIR}/glfw/lib/pkgconfig:$ENV{PKG_CONFIG_PATH}")
  PKG_CHECK_MODULES(GLFW3 glfw3)

  FIND_LIBRARY(GLFW3_LIBRARY
    NAMES ${GLFW3_LIBRARIES}
    HINTS ${GLFW3_LIBRARY_DIRS}
  )
  SET(GLFW3_LIBRARIES ${GLFW3_LIBRARY})

  RETURN()
ENDIF()

FIND_PATH(GLFW3_INCLUDE_DIRS
  GLFW/glfw3.h
  DOC "GLFW include directory "
  PATHS
    "${DEPENDS_DIR}/glfw"
    "$ENV{ProgramW6432}/glfw"
    ENV GLFW_ROOT
  PATH_SUFFIXES
    include
)

# directories in the official binary package
IF(MINGW)
  # Detect 32-bit vs 64-bit MINGW for correct GLFW package suffix
  IF(CMAKE_SIZEOF_VOID_P EQUAL 8)
    SET(_SUFFIX lib-mingw-w64)
  ELSE()
    SET(_SUFFIX lib-mingw)
  ENDIF()
ELSEIF(MSVC_VERSION GREATER_EQUAL 1930)
  SET(_SUFFIX lib-vc2022)
ELSEIF(MSVC_VERSION GREATER_EQUAL 1920)
  SET(_SUFFIX lib-vc2019)
ELSEIF(MSVC_VERSION GREATER_EQUAL 1910)
  SET(_SUFFIX lib-vc2017)
ELSEIF(MSVC14)
  SET(_SUFFIX lib-vc2015)
ELSEIF(MSVC12)
  SET(_SUFFIX lib-vc2013)
ELSEIF(MSVC)
  SET(_SUFFIX lib-vc2019)
ENDIF()

FIND_LIBRARY(GLFW3_LIBRARIES
  NAMES glfw3dll glfw3
  PATHS
    "${DEPENDS_DIR}/glfw"
    "$ENV{ProgramW6432}/glfw"
    ENV GLFW_ROOT
  PATH_SUFFIXES
    lib
    ${_SUFFIX}
)

IF(WIN32)
FIND_FILE(GLFW3_DLL
  glfw3.dll
  PATHS
    "${DEPENDS_DIR}/glfw"
    "$ENV{ProgramW6432}/glfw"
    ENV GLFW_ROOT
  PATH_SUFFIXES
    ${_SUFFIX}
)
ENDIF()

INCLUDE(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(GLFW3 FOUND_VAR GLFW3_FOUND
  REQUIRED_VARS GLFW3_LIBRARIES GLFW3_INCLUDE_DIRS)
