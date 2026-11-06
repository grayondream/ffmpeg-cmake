# =============================================================================
# Generation of config.h / config_components.h / avconfig.h / ffversion.h
# and the component registration arrays.
# =============================================================================

function(ffmpeg_bool_of name out)
    ffmpeg_state_get("${name}" _st)
    if(_st STREQUAL "yes")
        set(${out} 1 PARENT_SCOPE)
    else()
        set(${out} 0 PARENT_SCOPE)
    endif()
endfunction()

function(ffmpeg_license out)
    if(FFMPEG_ENABLE_NONFREE)
        set(_l "nonfree and unredistributable")
    elseif(FFMPEG_ENABLE_GPL AND FFMPEG_ENABLE_VERSION3)
        set(_l "GPL version 3 or later")
    elseif(FFMPEG_ENABLE_GPL)
        set(_l "GPL version 2 or later")
    elseif(FFMPEG_ENABLE_VERSION3)
        set(_l "LGPL version 3 or later")
    else()
        set(_l "LGPL version 2.1 or later")
    endif()
    set(${out} "${_l}" PARENT_SCOPE)
endfunction()

function(ffmpeg_os_name out)
    if(WIN32)
        set(_o "windows")
    elseif(APPLE)
        set(_o "darwin")
    elseif(ANDROID)
        set(_o "android")
    elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
        set(_o "linux")
    elseif(CMAKE_SYSTEM_NAME STREQUAL "FreeBSD")
        set(_o "freebsd")
    elseif(CMAKE_SYSTEM_NAME STREQUAL "OpenBSD")
        set(_o "openbsd")
    elseif(CMAKE_SYSTEM_NAME STREQUAL "NetBSD")
        set(_o "netbsd")
    else()
        string(TOLOWER "${CMAKE_SYSTEM_NAME}" _o)
    endif()
    set(${out} "${_o}" PARENT_SCOPE)
endfunction()

function(ffmpeg_slibsuf out)
    if(WIN32)
        set(_s ".dll")
    elseif(APPLE)
        set(_s ".dylib")
    else()
        set(_s ".so")
    endif()
    set(${out} "${_s}" PARENT_SCOPE)
endfunction()

# libswscale/aarch64 builds a small host tool (ops_static) and runs it to
# emit ops_neon.gen.S.  The output stays in the build tree: the upstream
# source tree is never modified.
function(ffmpeg_generate_aarch64_ops include_dir)
    ffmpeg_state_get("unstable" _unstable)
    if(NOT _unstable STREQUAL "yes")
        return()
    endif()

    if(CMAKE_CROSSCOMPILING)
        find_program(FFMPEG_HOST_CC NAMES cc gcc clang)
    else()
        set(FFMPEG_HOST_CC "${CMAKE_C_COMPILER}")
    endif()
    if(NOT FFMPEG_HOST_CC)
        message(FATAL_ERROR
            "A host C compiler is required to generate "
            "libswscale/aarch64/ops_neon.gen.S")
    endif()

    set(_gen_dir "${FFMPEG_GEN_DIR}/libswscale/aarch64")
    file(MAKE_DIRECTORY "${_gen_dir}")
    set(_host_exe "${_gen_dir}/ops_static")
    if(CMAKE_HOST_WIN32)
        string(APPEND _host_exe ".exe")
    endif()
    set(_src "${FFMPEG_SOURCE_DIR}/libswscale/aarch64/ops_static.c")
    set(_out "${_gen_dir}/ops_neon.gen.S")

    execute_process(
        COMMAND "${FFMPEG_HOST_CC}" -std=gnu11
                "-I${FFMPEG_SOURCE_DIR}" "-I${include_dir}"
                -o "${_host_exe}" "${_src}"
        RESULT_VARIABLE _cc_rc OUTPUT_QUIET ERROR_VARIABLE _cc_err)
    if(NOT _cc_rc EQUAL 0)
        message(FATAL_ERROR
            "Failed to build host tool ops_static:\n${_cc_err}")
    endif()

    execute_process(
        COMMAND "${_host_exe}"
        RESULT_VARIABLE _run_rc
        OUTPUT_FILE "${_out}.tmp"
        ERROR_VARIABLE _run_err)
    if(NOT _run_rc EQUAL 0)
        file(REMOVE "${_out}.tmp")
        message(FATAL_ERROR
            "Failed to generate ${_out}:\n${_run_err}")
    endif()
    file(RENAME "${_out}.tmp" "${_out}")
    ffmpeg_status("generated libswscale/aarch64/ops_neon.gen.S")
endfunction()

function(ffmpeg_generate_headers)
    set(_inc "${FFMPEG_GEN_DIR}/include")
    file(MAKE_DIRECTORY "${_inc}/libavutil")

    ffmpeg_license(_license)
    ffmpeg_os_name(_os)
    ffmpeg_slibsuf(_slibsuf)

    set(_year 2026)
    if(CMAKE_C_COMPILER_ID)
        set(_cc_ident "${CMAKE_C_COMPILER_ID} ${CMAKE_C_COMPILER_VERSION}")
    else()
        set(_cc_ident "unknown")
    endif()

    set(_config "#ifndef FFMPEG_CONFIG_H\n#define FFMPEG_CONFIG_H\n")
    string(APPEND _config "#define FFMPEG_CONFIGURATION \"${FFMPEG_CONFIGURE_FLAGS}\"\n")
    string(APPEND _config "#define FFMPEG_LICENSE \"${_license}\"\n")
    string(APPEND _config "#define CONFIG_THIS_YEAR ${_year}\n")
    string(APPEND _config "#define FFMPEG_DATADIR \"${CMAKE_INSTALL_PREFIX}/share/ffmpeg\"\n")
    string(APPEND _config "#define AVCONV_DATADIR \"${CMAKE_INSTALL_PREFIX}/share/ffmpeg\"\n")
    string(APPEND _config "#define CC_IDENT \"${_cc_ident}\"\n")
    string(APPEND _config "#define OS_NAME ${_os}\n")
    string(APPEND _config "#define EXTERN_PREFIX \"\"\n")
    string(APPEND _config "#define EXTERN_ASM\n")
    string(APPEND _config "#define BUILDSUF \"\"\n")
    string(APPEND _config "#define SLIBSUF \"${_slibsuf}\"\n")
    string(APPEND _config "#define SWS_MAX_FILTER_SIZE 256\n")

    # ARCH_*
    set(_archs "${FFMPEG_ARCH_LIST}")
    list(SORT _archs)
    foreach(_a IN LISTS _archs)
        ffmpeg_bool_of("${_a}" _v)
        string(TOUPPER "${_a}" _up)
        string(APPEND _config "#define ARCH_${_up} ${_v}\n")
    endforeach()

    # HAVE_*: every name known to configure (default 0) plus everything we
    # actually detected.
    get_property(_have_all GLOBAL PROPERTY FFMPEG_ALL_HAVE_NAMES)
    set(_haves ${_have_all})
    string(LENGTH "${_haves}" _haves_len)
    if(_haves_len EQUAL 0)
        get_property(_haves GLOBAL PROPERTY FFMPEG_HAVE_NAMES)
    endif()
    list(REMOVE_DUPLICATES _haves)
    list(SORT _haves)
    foreach(_h IN LISTS _haves)
        ffmpeg_bool_of("${_h}" _v)
        string(TOUPPER "${_h}" _up)
        string(APPEND _config "#define HAVE_${_up} ${_v}\n")
    endforeach()

    # CONFIG_* for non-component ("extra") switches.
    get_property(_configs GLOBAL PROPERTY FFMPEG_CONFIG_NAMES)
    get_property(_config_all GLOBAL PROPERTY FFMPEG_ALL_CONFIG_NAMES)
    list(APPEND _configs ${_config_all})
    list(REMOVE_DUPLICATES _configs)
    list(SORT _configs)
    foreach(_c IN LISTS _configs)
        set(_kind "")
        get_property(_kind GLOBAL PROPERTY "FFMPEG_COMPONENT_KIND_${_c}")
        string(LENGTH "${_kind}" _kind_len)
        if(NOT _kind_len EQUAL 0)
            continue()
        endif()
        ffmpeg_bool_of("${_c}" _v)
        string(TOUPPER "${_c}" _up)
        string(APPEND _config "#define CONFIG_${_up} ${_v}\n")
    endforeach()

    string(APPEND _config "#endif /* FFMPEG_CONFIG_H */\n")
    file(WRITE "${_inc}/config.h" "/* Automatically generated by ffmpeg-cmake - do not modify! */\n${_config}")

    # config_components.h
    get_property(_components GLOBAL PROPERTY FFMPEG_ALL_COMPONENTS)
    list(REMOVE_DUPLICATES _components)
    list(SORT _components)
    set(_comp "#ifndef FFMPEG_CONFIG_COMPONENTS_H\n#define FFMPEG_CONFIG_COMPONENTS_H\n")
    foreach(_c IN LISTS _components)
        ffmpeg_bool_of("${_c}" _v)
        string(TOUPPER "${_c}" _up)
        string(APPEND _comp "#define CONFIG_${_up} ${_v}\n")
    endforeach()
    string(APPEND _comp "#endif /* FFMPEG_CONFIG_COMPONENTS_H */\n")
    file(WRITE "${_inc}/config_components.h" "/* Automatically generated by ffmpeg-cmake - do not modify! */\n${_comp}")

    # avconfig.h
    ffmpeg_bool_of("bigendian" _be)
    ffmpeg_bool_of("fast_unaligned" _fu)
    file(WRITE "${_inc}/libavutil/avconfig.h"
"/* Generated by ffmpeg-cmake */
#ifndef AVUTIL_AVCONFIG_H
#define AVUTIL_AVCONFIG_H
#define AV_HAVE_BIGENDIAN ${_be}
#define AV_HAVE_FAST_UNALIGNED ${_fu}
#endif /* AVUTIL_AVCONFIG_H */
")

    # ffversion.h
    file(WRITE "${_inc}/libavutil/ffversion.h"
"/* Automatically generated by ffmpeg-cmake, do not edit! */
#ifndef AVUTIL_FFVERSION_H
#define AVUTIL_FFVERSION_H
#define FFMPEG_VERSION \"${FFMPEG_VERSION}\"
#endif /* AVUTIL_FFVERSION_H */
")

    # config.asm / config_components.asm (nasm preprocessor includes).
    # Mirrors configure's print_config(): ARCH_*, HAVE_*, and the
    # non-component CONFIG_* switches go into config.asm; component switches
    # go into config_components.asm, which a few .asm files include directly.
    if(FFMPEG_X86ASM_AVAILABLE)
        set(_asm "; Automatically generated by ffmpeg-cmake - do not modify!\n")

        set(_archs "${FFMPEG_ARCH_LIST}")
        list(SORT _archs)
        foreach(_a IN LISTS _archs)
            ffmpeg_bool_of("${_a}" _v)
            string(TOUPPER "${_a}" _up)
            string(APPEND _asm "%define ARCH_${_up} ${_v}\n")
        endforeach()

        get_property(_haves GLOBAL PROPERTY FFMPEG_ALL_HAVE_NAMES)
        list(REMOVE_DUPLICATES _haves)
        list(SORT _haves)
        foreach(_h IN LISTS _haves)
            ffmpeg_bool_of("${_h}" _v)
            string(TOUPPER "${_h}" _up)
            string(APPEND _asm "%define HAVE_${_up} ${_v}\n")
        endforeach()

        set(_configs "${FFMPEG_CONFIG_NAMES}")
        get_property(_config_all GLOBAL PROPERTY FFMPEG_ALL_CONFIG_NAMES)
        list(APPEND _configs ${_config_all})
        list(REMOVE_DUPLICATES _configs)
        list(SORT _configs)

        # Defining every switch in config.asm as well keeps nasm 3.x happy:
        # unlike older releases it rejects undefined symbols in %if.
        foreach(_c IN LISTS _configs)
            ffmpeg_bool_of("${_c}" _v)
            string(TOUPPER "${_c}" _up)
            string(APPEND _asm "%define CONFIG_${_up} ${_v}\n")
        endforeach()

        get_property(_components GLOBAL PROPERTY FFMPEG_ALL_COMPONENTS)
        list(REMOVE_DUPLICATES _components)
        list(SORT _components)
        set(_components_asm
            "; Automatically generated by ffmpeg-cmake - do not modify!\n")
        foreach(_c IN LISTS _components)
            ffmpeg_bool_of("${_c}" _v)
            string(TOUPPER "${_c}" _up)
            string(APPEND _components_asm "%define CONFIG_${_up} ${_v}\n")
        endforeach()

        file(WRITE "${FFMPEG_GEN_DIR}/config.asm" "${_asm}")
        file(WRITE "${FFMPEG_GEN_DIR}/config_components.asm"
             "${_components_asm}")

        # libswscale's NASM sources include a file generated by running the
        # C preprocessor over uops_macros.asm.h (see upstream Makefile).
        set(_uops_dir "${FFMPEG_GEN_DIR}/libswscale/x86")
        file(MAKE_DIRECTORY "${_uops_dir}")
        execute_process(
            COMMAND "${CMAKE_C_COMPILER}" -E -P
                    -o "${_uops_dir}/uops_macros.gen.asm"
                    "${FFMPEG_SOURCE_DIR}/libswscale/x86/uops_macros.asm.h"
            RESULT_VARIABLE _uops_rc OUTPUT_QUIET ERROR_QUIET)
        if(NOT _uops_rc EQUAL 0)
            ffmpeg_warn("failed to generate libswscale uops_macros.gen.asm")
        endif()
    endif()

    if(FFMPEG_ARCH STREQUAL "aarch64")
        ffmpeg_state_get("neon" _neon)
        if(_neon STREQUAL "yes")
            ffmpeg_generate_aarch64_ops("${_inc}")
        endif()
    endif()

    set(FFMPEG_INCLUDE_DIR "${_inc}" PARENT_SCOPE)
    ffmpeg_status("generated headers in ${_inc}")
endfunction()

# ---------------------------------------------------------------------------
# Registration arrays.
# ---------------------------------------------------------------------------
function(ffmpeg_generate_component_lists)
    set(_inc "${FFMPEG_GEN_DIR}/include")

    foreach(_spec IN LISTS FFMPEG_LIST_SPECS)
        string(REPLACE "|" ";" _p "${_spec}")
        list(GET _p 0 _key)
        list(GET _p 1 _file)
        list(GET _p 2 _type)
        list(GET _p 3 _array)
        list(GET _p 4 _kinds)

        set(_symbols "")
        string(REPLACE "," ";" _kinds "${_kinds}")
        foreach(_kind IN LISTS _kinds)
            get_property(_names GLOBAL PROPERTY "FFMPEG_COMPONENTS_${_kind}")
            foreach(_name IN LISTS _names)
                ffmpeg_state_get("${_name}" _st)
                if(_st STREQUAL "yes")
                    get_property(_sym GLOBAL PROPERTY "FFMPEG_COMPONENT_SYMBOL_${_name}")
                    list(APPEND _symbols "${_sym}")
                endif()
            endforeach()
        endforeach()

        get_property(_extra GLOBAL PROPERTY "FFMPEG_LIST_EXTRA_${_key}")
        # Version modules currently provide these as ordinary variables
        # (e.g. FFMPEG_LIST_EXTRA_filters).  Accept both forms.
        set(_extra_var "FFMPEG_LIST_EXTRA_${_key}")
        if(DEFINED ${_extra_var})
            list(APPEND _extra ${${_extra_var}})
        endif()
        foreach(_e IN LISTS _extra)
            list(APPEND _symbols "${_e}")
        endforeach()

        set(_out "static const ${_type} * const ${_array}[] = {\n")
        foreach(_sym IN LISTS _symbols)
            string(APPEND _out "    &${_sym},\n")
        endforeach()
        string(APPEND _out "    NULL };\n")

        get_filename_component(_dir "${_file}" DIRECTORY)
        file(MAKE_DIRECTORY "${_inc}/${_dir}")
        file(WRITE "${_inc}/${_file}"
            "/* Automatically generated by ffmpeg-cmake - do not modify! */\n${_out}")
    endforeach()
endfunction()

function(ffmpeg_summary)
    get_property(_haves GLOBAL PROPERTY FFMPEG_HAVE_NAMES)
    get_property(_configs GLOBAL PROPERTY FFMPEG_CONFIG_NAMES)
    ffmpeg_status("FFmpeg version : ${FFMPEG_VERSION}")
    ffmpeg_status("source        : ${FFMPEG_SOURCE_DIR}")
    ffmpeg_status("generated     : ${FFMPEG_GEN_DIR}")
    if(FFMPEG_ENABLE_STATIC AND FFMPEG_ENABLE_SHARED)
        set(_libtype "both (static + shared)")
    elseif(FFMPEG_ENABLE_SHARED)
        set(_libtype "shared")
    else()
        set(_libtype "static")
    endif()
    ffmpeg_status("library type  : ${_libtype} (requested: ${FFMPEG_LIBRARY_TYPE})")
    ffmpeg_status("x86 assembly  : ${FFMPEG_X86ASM_AVAILABLE}")
    if(ANDROID)
        ffmpeg_status("android       : ABI ${ANDROID_ABI}, API ${ANDROID_PLATFORM}")
    endif()
endfunction()
