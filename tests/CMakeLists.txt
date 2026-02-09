OPTION(BUILD_TESTS "Build unit tests" ON)

IF(BUILD_TESTS)
  ENABLE_TESTING()
  
  # Find or download Catch2
  FIND_PACKAGE(Catch2 3 QUIET)
  IF(NOT Catch2_FOUND)
    INCLUDE(FetchContent)
    FetchContent_Declare(
      Catch2
      GIT_REPOSITORY https://github.com/catchorg/Catch2.git
      GIT_TAG v3.4.0
    )
    FetchContent_MakeAvailable(Catch2)
  ENDIF()
  
  ADD_EXECUTABLE(freenect2_tests
    test_registration.cpp
    test_depth_tables.cpp
  )
  TARGET_LINK_LIBRARIES(freenect2_tests PRIVATE freenect2 Catch2::Catch2WithMain)
  ADD_TEST(NAME freenect2_tests COMMAND freenect2_tests)
ENDIF()
