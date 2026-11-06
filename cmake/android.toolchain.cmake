# =============================================================================
# Android NDK toolchain wrapper.
#
# Usage:
#   cmake -S . -B build-android -G Ninja \
#     -DCMAKE_TOOLCHAIN_FILE=cmake/android.toolchain.cmake \
#     -DANDROID_ABI=arm64-v8a \
#     -DANDROID_PLATFORM=android-24
#
# The NDK root is taken from (in order):
#   -DFFMPEG_ANDROID_NDK=...
#   $NAK_HOME
#   $NDK_HOME
#   $ANDROID_NDK_ROOT
#   $ANDROID_NDK_HOME
# =============================================================================

# CMake may load a toolchain file twice during the first configure.
if(FFMPEG_ANDROID_TOOLCHAIN_INCLUDED)
    return()
endif()
set(FFMPEG_ANDROID_TOOLCHAIN_INCLUDED TRUE)

set(_ffmpeg_ndk "")
if(DEFINED FFMPEG_ANDROID_NDK AND NOT "${FFMPEG_ANDROID_NDK}" STREQUAL "")
    set(_ffmpeg_ndk "${FFMPEG_ANDROID_NDK}")
else()
    foreach(_var NAK_HOME NDK_HOME ANDROID_NDK_ROOT ANDROID_NDK_HOME)
        set(_env_value "$ENV{${_var}}")
        if(NOT "${_env_value}" STREQUAL "")
            set(_ffmpeg_ndk "${_env_value}")
            break()
        endif()
    endforeach()
endif()

if("${_ffmpeg_ndk}" STREQUAL "")
    message(FATAL_ERROR
        "Android NDK not found. Set NAK_HOME, NDK_HOME or ANDROID_NDK_ROOT, "
        "or pass -DFFMPEG_ANDROID_NDK=/path/to/ndk")
endif()

get_filename_component(_ffmpeg_ndk "${_ffmpeg_ndk}" ABSOLUTE)
set(_ffmpeg_ndk_toolchain
    "${_ffmpeg_ndk}/build/cmake/android.toolchain.cmake")
if(NOT EXISTS "${_ffmpeg_ndk_toolchain}")
    message(FATAL_ERROR
        "No Android NDK toolchain at '${_ffmpeg_ndk_toolchain}'. "
        "Check NAK_HOME/NDK_HOME/ANDROID_NDK_ROOT.")
endif()

# Convenience aliases; the canonical NDK variables remain ANDROID_ABI and
# ANDROID_PLATFORM.
if((NOT DEFINED ANDROID_ABI OR "${ANDROID_ABI}" STREQUAL "")
   AND DEFINED FFMPEG_ANDROID_ABI)
    set(ANDROID_ABI "${FFMPEG_ANDROID_ABI}" CACHE STRING "Android ABI" FORCE)
endif()
if(NOT DEFINED ANDROID_ABI OR "${ANDROID_ABI}" STREQUAL "")
    set(ANDROID_ABI "arm64-v8a" CACHE STRING "Android ABI")
endif()
if((NOT DEFINED ANDROID_PLATFORM OR "${ANDROID_PLATFORM}" STREQUAL "")
   AND DEFINED FFMPEG_ANDROID_PLATFORM)
    set(ANDROID_PLATFORM "${FFMPEG_ANDROID_PLATFORM}"
        CACHE STRING "Android API level" FORCE)
endif()
if(NOT DEFINED ANDROID_PLATFORM OR "${ANDROID_PLATFORM}" STREQUAL "")
    set(ANDROID_PLATFORM "android-24" CACHE STRING "Android API level")
endif()

message(STATUS "FFmpeg-Cmake: using Android NDK ${_ffmpeg_ndk}")
message(STATUS "FFmpeg-Cmake: Android ABI ${ANDROID_ABI}, platform ${ANDROID_PLATFORM}")

include("${_ffmpeg_ndk_toolchain}")
