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

option(FFMPEG_ENABLE_STATIC   "Build static FFmpeg libraries" ON)
option(FFMPEG_ENABLE_SHARED   "Build shared FFmpeg libraries" OFF)
option(FFMPEG_ENABLE_PROGRAMS "Build the ffmpeg/ffprobe/ffplay programs" ON)
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

# ASM_NASM must be enabled in file scope.  Detection only marks it available
# when nasm is present and can assemble FFmpeg's instructions.
if(FFMPEG_X86ASM_AVAILABLE AND NOT CMAKE_ASM_NASM_COMPILER_LOADED)
    enable_language(ASM_NASM)
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
