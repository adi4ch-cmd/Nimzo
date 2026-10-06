cmake_minimum_required(VERSION 3.22.1)
project(nimzo_vivox_bridge)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT DEFINED VIVOX_SDK_ROOT)
  message(FATAL_ERROR "VIVOX_SDK_ROOT is required")
endif()

file(GLOB_RECURSE VIVOX_HEADER_FILES
  "${VIVOX_SDK_ROOT}/Vxc.h"
  "${VIVOX_SDK_ROOT}/VxcTypes.h"
  "${VIVOX_SDK_ROOT}/VxcRequests.h"
  "${VIVOX_SDK_ROOT}/VxcResponses.h"
  "${VIVOX_SDK_ROOT}/VxcEvents.h"
)

list(LENGTH VIVOX_HEADER_FILES VIVOX_HEADER_COUNT)
if(VIVOX_HEADER_COUNT EQUAL 0)
  message(FATAL_ERROR "Vivox headers not found under ${VIVOX_SDK_ROOT}")
endif()

list(GET VIVOX_HEADER_FILES 0 VIVOX_MAIN_HEADER)
get_filename_component(VIVOX_INCLUDE_DIR "${VIVOX_MAIN_HEADER}" DIRECTORY)

file(GLOB_RECURSE VIVOX_LIB_FILES
  "${VIVOX_SDK_ROOT}/libvivox-sdk.so"
  "${VIVOX_SDK_ROOT}/libvivoxsdk.so"
)

set(VIVOX_LIBRARY "")
foreach(candidate IN LISTS VIVOX_LIB_FILES)
  if(candidate MATCHES "/${CMAKE_ANDROID_ARCH_ABI}/")
    set(VIVOX_LIBRARY "${candidate}")
    break()
  endif()
endforeach()

if(NOT VIVOX_LIBRARY AND VIVOX_LIB_FILES)
  list(GET VIVOX_LIB_FILES 0 VIVOX_LIBRARY)
endif()

if(NOT VIVOX_LIBRARY)
  message(FATAL_ERROR "Vivox native library not found under ${VIVOX_SDK_ROOT}")
endif()

add_library(vivox_bridge SHARED vivox_bridge.cpp)

target_include_directories(vivox_bridge PRIVATE "${VIVOX_INCLUDE_DIR}")

target_link_libraries(vivox_bridge
  "${VIVOX_LIBRARY}"
  log
)

message(STATUS "Vivox include directory: ${VIVOX_INCLUDE_DIR}")
message(STATUS "Vivox native library: ${VIVOX_LIBRARY}")
