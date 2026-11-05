# =============================================================================
# Version detection and per-version module loading.
#
# The engine is version independent.  Everything that differs between
# FFmpeg releases lives in cmake/versions/<major>.<minor>/.
# =============================================================================

function(ffmpeg_detect_version)
    set(_src "${FFMPEG_SOURCE_DIR}")
    if(NOT EXISTS "${_src}/libavutil/version.h")
        message(FATAL_ERROR
            "FFMPEG_SOURCE_DIR='${_src}' does not look like an FFmpeg tree "
            "(libavutil/version.h missing). Point FFMPEG_SOURCE_DIR at the "
            "unmodified FFmpeg source checkout.")
    endif()

    set(_version "")
    if(EXISTS "${_src}/FF_VERSION")
        file(STRINGS "${_src}/FF_VERSION" _version LIMIT_COUNT 1)
        string(STRIP "${_version}" _version)
    endif()
    string(LENGTH "${_version}" _vlen2)
    if(_vlen2 EQUAL 0 AND EXISTS "${_src}/RELEASE")
        file(STRINGS "${_src}/RELEASE" _version LIMIT_COUNT 1)
        string(STRIP "${_version}" _version)
        string(REGEX REPLACE "\\.git$" "" _version "${_version}")
    endif()
    string(LENGTH "${_version}" _vlen)
    if(_vlen EQUAL 0)
        file(STRINGS "${_src}/libavutil/version.h" _ver_line
             REGEX "^#define LIBAVUTIL_VERSION_MAJOR")
        if(_ver_line MATCHES "([0-9]+)")
            set(_version "unknown-${CMAKE_MATCH_1}")
        else()
            set(_version "unknown")
        endif()
    endif()

    set(_major "")
    set(_minor "")
    if(_version MATCHES "^([0-9]+)\\.([0-9]+)")
        set(_major "${CMAKE_MATCH_1}")
        set(_minor "${CMAKE_MATCH_2}")
    elseif(_version MATCHES "^([0-9]+)")
        set(_major "${CMAKE_MATCH_1}")
        set(_minor "0")
    endif()

    set(FFMPEG_VERSION        "${_version}" PARENT_SCOPE)
    set(FFMPEG_VERSION_MAJOR  "${_major}"   PARENT_SCOPE)
    set(FFMPEG_VERSION_MINOR  "${_minor}"   PARENT_SCOPE)

    string(LENGTH "${_major}" _mlen)
    if(_mlen EQUAL 0)
        message(FATAL_ERROR
            "Unable to determine the FFmpeg version from '${_src}' "
            "(RELEASE/FF_VERSION missing or malformed).")
    endif()
endfunction()

function(ffmpeg_find_version_module)
    set(_versions_dir "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/versions")
    set(_candidates
        "${_versions_dir}/${FFMPEG_VERSION_MAJOR}.${FFMPEG_VERSION_MINOR}"
        "${_versions_dir}/${FFMPEG_VERSION_MAJOR}.x"
        "${_versions_dir}/${FFMPEG_VERSION_MAJOR}")

    set(_dir "")
    foreach(_c IN LISTS _candidates)
        if(EXISTS "${_c}/version.cmake")
            set(_dir "${_c}")
            break()
        endif()
    endforeach()

    string(LENGTH "${_dir}" _dlen)
    if(_dlen EQUAL 0)
        message(FATAL_ERROR
            "No CMake version module for FFmpeg ${FFMPEG_VERSION}.\n"
            "Create one at cmake/versions/${FFMPEG_VERSION_MAJOR}.${FFMPEG_VERSION_MINOR}/ "
            "(copy the closest module and adjust metadata).")
    endif()

    set(FFMPEG_VERSION_MODULE_DIR "${_dir}" PARENT_SCOPE)
    ffmpeg_status("FFmpeg ${FFMPEG_VERSION} (module: ${_dir})")
endfunction()
