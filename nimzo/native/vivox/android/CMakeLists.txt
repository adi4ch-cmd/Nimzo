cmake_minimum_required(VERSION 3.22.1)
project(nimzo_vivox_bridge)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT DEFINED VIVOX_SDK_ROOT)
  message(FATAL_ERROR "VIVOX_SDK_ROOT is required (point to the exact SDK directory)")
endif()
if(NOT CMAKE_ANDROID_ARCH_ABI)
  message(FATAL_ERROR "An explicit Android ABI is required for Vivox")
endif()

# Vivox 5.28.0 contains four builds of libvivox-sdk.so per ABI:
# Release, Debug, Stripped/Release and Stripped/Debug.
# The sdk-release.aar bundles ONLY Libraries/Stripped/Release.
# Never glob every matching .so: that makes CMake select multiple ABIs/builds.
set(VIVOX_INCLUDE_DIR "${VIVOX_SDK_ROOT}/include")
set(VIVOX_LIBRARY
  "${VIVOX_SDK_ROOT}/Libraries/Stripped/Release/${CMAKE_ANDROID_ARCH_ABI}/libvivox-sdk.so"
)
foreach(header Vxc.h VxcTypes.h VxcErrors.h VxcRequests.h VxcResponses.h VxcEvents.h)
  if(NOT EXISTS "${VIVOX_INCLUDE_DIR}/${header}")
    message(FATAL_ERROR "Vivox SDK 5.28.0 header not found: ${VIVOX_INCLUDE_DIR}/${header}")
  endif()
endforeach()
if(NOT EXISTS "${VIVOX_LIBRARY}")
  message(FATAL_ERROR "Vivox SDK AAR-matched Stripped/Release library missing for ${CMAKE_ANDROID_ARCH_ABI}")
endif()

add_library(vivox_bridge SHARED vivox_bridge.cpp)
target_include_directories(vivox_bridge PRIVATE "${VIVOX_INCLUDE_DIR}")
target_link_libraries(vivox_bridge "${VIVOX_LIBRARY}" log)

message(STATUS "Vivox 5.28.0 headers: ${VIVOX_INCLUDE_DIR}")
message(STATUS "Vivox 5.28.0 AAR-matched native: ${VIVOX_LIBRARY}")
