cmake_minimum_required(VERSION 3.22.1)
project(nimzo_vivox_bridge)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT DEFINED VIVOX_SDK_ROOT)
  message(FATAL_ERROR "VIVOX_SDK_ROOT is required")
endif()

file(GLOB_RECURSE VIVOX_HEADER_FILES
  "${VIVOX_SDK_ROOT}/Vxc.h"
)

list(LENGTH VIVOX_HEADER_FILES VIVOX_HEADER_COUNT)
if(NOT VIVOX_HEADER_COUNT EQUAL 1)
  message(FATAL_ERROR "Expected exactly one Vxc.h under ${VIVOX_SDK_ROOT}; choose one SDK release")
endif()

list(GET VIVOX_HEADER_FILES 0 VIVOX_MAIN_HEADER)
get_filename_component(VIVOX_INCLUDE_DIR "${VIVOX_MAIN_HEADER}" DIRECTORY)
foreach(header VxcTypes.h VxcErrors.h VxcRequests.h VxcResponses.h VxcEvents.h)
  if(NOT EXISTS "${VIVOX_INCLUDE_DIR}/${header}")
    message(FATAL_ERROR "Missing Vivox sibling header: ${header}")
  endif()
endforeach()

file(GLOB_RECURSE VIVOX_LIB_FILES
  "${VIVOX_SDK_ROOT}/libvivox-sdk.so"
  "${VIVOX_SDK_ROOT}/libvivoxsdk.so"
)

if(NOT CMAKE_ANDROID_ARCH_ABI)
  message(FATAL_ERROR "An explicit Android ABI is required for Vivox")
endif()
set(VIVOX_MATCHING_LIBRARIES "")
foreach(candidate IN LISTS VIVOX_LIB_FILES)
  if(candidate MATCHES "/${CMAKE_ANDROID_ARCH_ABI}/")
    list(APPEND VIVOX_MATCHING_LIBRARIES "${candidate}")
  endif()
endforeach()

list(LENGTH VIVOX_MATCHING_LIBRARIES VIVOX_LIBRARY_COUNT)
if(NOT VIVOX_LIBRARY_COUNT EQUAL 1)
  message(FATAL_ERROR "Expected exactly one Vivox library for ${CMAKE_ANDROID_ARCH_ABI}; no cross-ABI fallback is permitted")
endif()
list(GET VIVOX_MATCHING_LIBRARIES 0 VIVOX_LIBRARY)

add_library(vivox_bridge SHARED vivox_bridge.cpp)

target_include_directories(vivox_bridge PRIVATE "${VIVOX_INCLUDE_DIR}")

target_link_libraries(vivox_bridge
  "${VIVOX_LIBRARY}"
  log
)

message(STATUS "Vivox include directory: ${VIVOX_INCLUDE_DIR}")
message(STATUS "Vivox native library: ${VIVOX_LIBRARY}")
