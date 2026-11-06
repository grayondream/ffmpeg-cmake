# =============================================================================
# FFmpeg-Cmake
#
# A CMake-native build system for FFmpeg.  It does NOT modify the FFmpeg
# source tree and does NOT invoke FFmpeg's ./configure script.
#
# Layout:
#   cmake/                     generic engine (version independent)
#   cmake/versions/<ver>/      per-version metadata / adapters
#   third_party/ffmpeg/        unmodified upstream submodule
#
# Usage (standalone):
#   cmake -S . -B build -G Ninja
#   cmake --build build
#
# Usage (as a subproject):
#   add_subdirectory(FFMpeg-Cmake)
#   target_link_libraries(myapp PRIVATE FFmpeg::avcodec FFmpeg::avformat)
# =============================================================================

cmake_minimum_required(VERSION 3.20)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    project(ffmpeg-cmake VERSION 0.1.0 LANGUAGES C CXX)
    set(FFMPEG_CMAKE_STANDALONE ON)
else()
    set(FFMPEG_CMAKE_STANDALONE OFF)
    enable_language(C)
    enable_language(CXX)
endif()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")
include(GNUInstallDirs)

# ---------------------------------------------------------------------------
# User facing knobs (mirror the most common ./configure switches)
# ---------------------------------------------------------------------------
set(FFMPEG_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/third_party/ffmpeg"
    CACHE PATH "Path to the unmodified FFmpeg source tree")
set(FFMPEG_GEN_DIR "${CMAKE_CURRENT_BINARY_DIR}/ffmpeg-gen"
    CACHE PATH "Directory for generated FFmpeg headers/sources")

# Platform defaults: Android applications normally package shared libraries,
# while a desktop build defaults to the traditional static archive.
if(ANDROID)
    set(_ffmpeg_default_static   OFF)
    set(_ffmpeg_default_shared   ON)
    set(_ffmpeg_default_programs OFF)
else()
    set(_ffmpeg_default_static   ON)
    set(_ffmpeg_default_shared   OFF)
    set(_ffmpeg_default_programs ON)
endif()

option(FFMPEG_ENABLE_STATIC   "Build static FFmpeg libraries" ${_ffmpeg_default_static})
option(FFMPEG_ENABLE_SHARED   "Build shared FFmpeg libraries" ${_ffmpeg_default_shared})
option(FFMPEG_ENABLE_PROGRAMS "Build the ffmpeg/ffprobe/ffplay programs" ${_ffmpeg_default_programs})

# Single, discoverable selector.  AUTO keeps the two legacy switches above
# authoritative; the other values override them for this configure run.
set(FFMPEG_LIBRARY_TYPE "AUTO" CACHE STRING
    "FFmpeg library type: AUTO, STATIC, SHARED or BOTH")
set_property(CACHE FFMPEG_LIBRARY_TYPE PROPERTY STRINGS AUTO STATIC SHARED BOTH)

if(NOT FFMPEG_LIBRARY_TYPE MATCHES "^(AUTO|STATIC|SHARED|BOTH)$")
    message(FATAL_ERROR
        "FFMPEG_LIBRARY_TYPE must be AUTO, STATIC, SHARED or BOTH "
        "(got '${FFMPEG_LIBRARY_TYPE}')")
endif()
if(NOT FFMPEG_LIBRARY_TYPE STREQUAL "AUTO")
    if(FFMPEG_LIBRARY_TYPE STREQUAL "STATIC")
        set(FFMPEG_ENABLE_STATIC ON)
        set(FFMPEG_ENABLE_SHARED OFF)
    elseif(FFMPEG_LIBRARY_TYPE STREQUAL "SHARED")
        set(FFMPEG_ENABLE_STATIC OFF)
        set(FFMPEG_ENABLE_SHARED ON)
    else()
        set(FFMPEG_ENABLE_STATIC ON)
        set(FFMPEG_ENABLE_SHARED ON)
    endif()
endif()
if(NOT FFMPEG_ENABLE_STATIC AND NOT FFMPEG_ENABLE_SHARED)
    message(FATAL_ERROR
        "At least one of FFMPEG_ENABLE_STATIC / FFMPEG_ENABLE_SHARED must be ON")
endif()

if(ANDROID)
    option(FFMPEG_ENABLE_JNI "Enable JNI support (Android)" ON)
    option(FFMPEG_ENABLE_MEDIACODEC "Enable Android MediaCodec hwaccel" ON)
endif()

set(FFMPEG_ANDROID_NDK "" CACHE PATH
    "Android NDK root (defaults to NAK_HOME, NDK_HOME or ANDROID_NDK_ROOT)")
option(FFMPEG_DISABLE_EVERYTHING "Disable all FFmpeg components (like --disable-everything)" OFF)
option(FFMPEG_ENABLE_GPL      "Allow GPL licensed parts (--enable-gpl)" OFF)
option(FFMPEG_ENABLE_VERSION3 "Allow (L)GPLv3 parts (--enable-version3)" OFF)
option(FFMPEG_ENABLE_NONFREE  "Allow nonfree parts (--enable-nonfree)" OFF)
option(FFMPEG_ENABLE_DEBUG    "Compile with debug information" OFF)
option(FFMPEG_ENABLE_SMALL    "Optimize for size (--enable-small)" OFF)
option(FFMPEG_ENABLE_X86ASM   "Enable x86 assembly (nasm) when available" ON)
option(FFMPEG_ENABLE_AVX512   "Enable AVX-512 optimizations" ON)
option(FFMPEG_ENABLE_DOC      "Build documentation" OFF)
option(FFMPEG_INSTALL         "Generate install rules" ON)

# Escape hatch: raw configure style flags mapped onto the CMake options.
# e.g. -DFFMPEG_CONFIGURE_FLAGS="--disable-everything;--enable-h264_decoder"
set(FFMPEG_CONFIGURE_FLAGS "" CACHE STRING
    "Semicolon or space separated configure-style flags (subset)")

include(FFmpegUtils)
include(FFmpegVersion)

# Version detection must happen before anything reads source metadata.
ffmpeg_detect_version()

include(FFmpegComponents)
include(FFmpegOptions)
include(FFmpegDetect)
include(FFmpegMetadata)
include(FFmpegResolve)
include(FFmpegGenerate)
include(FFmpegTargets)

ffmpeg_find_version_module()

# version.cmake: static metadata (arch list, extern patterns, list types)
include("${FFMPEG_VERSION_MODULE_DIR}/version.cmake")
# detect.cmake: platform/feature probes specific to this release
if(EXISTS "${FFMPEG_VERSION_MODULE_DIR}/detect.cmake")
    include("${FFMPEG_VERSION_MODULE_DIR}/detect.cmake")
endif()

ffmpeg_scan_components()
ffmpeg_declare_options()
ffmpeg_detect_environment()
ffmpeg_scan_config_names()
ffmpeg_scan_dependency_metadata()
ffmpeg_collect_metadata()
ffmpeg_detect_features()

if(ANDROID)
    include(FFmpegAndroid)
    ffmpeg_android_detect()
endif()

# ASM_NASM must be enabled in file scope.  Detection only marks it available
# when nasm is present and can assemble FFmpeg's instructions.
if(FFMPEG_X86ASM_AVAILABLE AND NOT CMAKE_ASM_NASM_COMPILER_LOADED)
    enable_language(ASM_NASM)
endif()

# ARM/AArch64 (and the other GNU-style architectures) ship preprocessed .S
# sources.  They are compiled through the C compiler's assembler-with-cpp
# mode, so the ASM language must be enabled before add_library().
if(NOT MSVC AND NOT CMAKE_ASM_COMPILER_LOADED
   AND FFMPEG_ARCH MATCHES "^(arm|aarch64|ppc|ppc64|mips|mips64|riscv|loongarch|s390|sparc|sparc64)$")
    enable_language(ASM)
endif()

ffmpeg_detect_external_libraries()

ffmpeg_resolve_configuration()
ffmpeg_generate_headers()
ffmpeg_generate_component_lists()

ffmpeg_add_libraries()

if(FFMPEG_ENABLE_PROGRAMS)
    include(FFmpegPrograms)
    ffmpeg_add_programs()
endif()

ffmpeg_summary()
