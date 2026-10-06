cmake_minimum_required(VERSION 3.22.1)
project(nimzo_vivox)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT VIVOX_SDK_ROOT)
  message(FATAL_ERROR "VIVOX_SDK_ROOT is required")
endif()
file(GLOB_RECURSE VIVOX_LIBS CONFIGURE_DEPENDS
  "${VIVOX_SDK_ROOT}/*/${ANDROID_ABI}/libvivox-sdk.so"
  "${VIVOX_SDK_ROOT}/*/${ANDROID_ABI}/libvivoxsdk.so"
  "${VIVOX_SDK_ROOT}/SDK/*/${ANDROID_ABI}/libvivox-sdk.so"
  "${VIVOX_SDK_ROOT}/SDK/*/${ANDROID_ABI}/libvivoxsdk.so")
list(LENGTH VIVOX_LIBS VIVOX_LIB_COUNT)
if(VIVOX_LIB_COUNT EQUAL 0)
  message(FATAL_ERROR "Could not locate Vivox native library for ABI ${ANDROID_ABI}")
endif()
list(GET VIVOX_LIBS 0 VIVOX_LIB)
add_library(vivox_bridge SHARED vivox_bridge.cpp)
target_include_directories(vivox_bridge PRIVATE "${VIVOX_SDK_ROOT}/SDK/include")
add_library(vivox_sdk SHARED IMPORTED)
set_target_properties(vivox_sdk PROPERTIES IMPORTED_LOCATION "${VIVOX_LIB}")
find_library(log-lib log)
find_library(android-lib android)
target_link_libraries(vivox_bridge vivox_sdk ${log-lib} ${android-lib})
