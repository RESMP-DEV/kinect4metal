# SetupLibfreenect2Threading.cmake
# Modern C++ standard (C++17) always provides std::thread support

# Verify std::thread support (should always work with C++17)
INCLUDE(CheckCXXSourceCompiles)

CHECK_CXX_SOURCE_COMPILES("
#include <thread>
#include <mutex>
#include <condition_variable>
#include <chrono>

int main(int argc, char** argv) {
  std::thread thread;
  std::mutex mutex;
  std::lock_guard<std::mutex> lock_guard(mutex);
  std::unique_lock<std::mutex> unique_lock(mutex);
  std::condition_variable condition_variable;

  return 0;
}
" LIBFREENECT2_THREADING_STDLIB)

IF(NOT LIBFREENECT2_THREADING_STDLIB)
  MESSAGE(FATAL_ERROR "C++17 std::thread support is required but not available. Please use a modern C++ compiler.")
ENDIF()

# Always use standard library threading (C++17 guarantees this)
SET(LIBFREENECT2_THREADING "stdlib")
SET(LIBFREENECT2_THREADING_INCLUDE_DIR "")
SET(LIBFREENECT2_THREADING_SOURCE "")
SET(LIBFREENECT2_THREADING_LIBRARIES "")
SET(LIBFREENECT2_THREADING_STDLIB 1)
SET(HAVE_Threading std::thread)

MESSAGE(STATUS "Using std::thread for threading (C++17 standard library)")
