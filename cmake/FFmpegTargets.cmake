# =============================================================================
# Library target creation.
#
# Object lists are read from the upstream Makefiles and evaluated with the
# resolved configuration state; the compilation itself is pure CMake.
# =============================================================================

# Map an object file to an existing source file.
function(ffmpeg_object_source basedir obj out)
    get_filename_component(_abs "${basedir}/${obj}" ABSOLUTE)
    string(REGEX REPLACE "\\.o$" "" _stem "${_abs}")
    foreach(_ext .c .S .cpp .m .asm)
        if(EXISTS "${_stem}${_ext}")
            set(${out} "${_stem}${_ext}" PARENT_SCOPE)
            return()
        endif()
    endforeach()
    set(${out} "" PARENT_SCOPE)
endfunction()

function(ffmpeg_library_makefiles lib out)
    set(_dir "${FFMPEG_SOURCE_DIR}/lib${lib}")
    set(_main "${_dir}/Makefile")
    set(_files "")
    set(_queue "")
    if(EXISTS "${_main}")
        list(APPEND _queue "${_main}")
    endif()
    if(NOT FFMPEG_ARCH STREQUAL "unknown" AND EXISTS "${_dir}/${FFMPEG_ARCH}/Makefile")
        list(APPEND _queue "${_dir}/${FFMPEG_ARCH}/Makefile")
    endif()

    set(_guard 0)
    while(_queue)
        math(EXPR _guard "${_guard}+1")
        if(_guard GREATER 100)
            break()
        endif()
        list(GET _queue 0 _mk)
        list(REMOVE_AT _queue 0)
        list(FIND _files "${_mk}" _seen)
        if(NOT _seen EQUAL -1)
            continue()
        endif()
        list(APPEND _files "${_mk}")

        ffmpeg_read_makefile("${_mk}" _content)
        ffmpeg_makefile_lines("${_content}" _lines)
        foreach(_line IN LISTS _lines)
            string(STRIP "${_line}" _sline)
            string(FIND "${_sline}" "include" _inc_pos)
            if(_inc_pos EQUAL 0 OR (_inc_pos EQUAL 1 AND _sline MATCHES "^-include"))
                string(FIND "${_sline}" "$(SRC_PATH)/" _sp)
                if(NOT _sp EQUAL -1)
                    string(LENGTH "$(SRC_PATH)/" _sp_len)
                    math(EXPR _rel_start "${_sp}+${_sp_len}")
                    string(SUBSTRING "${_sline}" ${_rel_start} -1 _rel)
                    string(STRIP "${_rel}" _rel)
                    string(REPLACE "$(ARCH)" "${FFMPEG_ARCH}" _rel "${_rel}")
                    set(_inc "${FFMPEG_SOURCE_DIR}/${_rel}")
                    if(EXISTS "${_inc}")
                        list(APPEND _queue "${_inc}")
                    endif()
                endif()
            endif()
        endforeach()
    endwhile()

    set(${out} "${_files}" PARENT_SCOPE)
endfunction()

function(ffmpeg_collect_library_sources lib out)
    set(_basedir "${FFMPEG_SOURCE_DIR}/lib${lib}")
    ffmpeg_library_makefiles("${lib}" _makefiles)

    set(_sources "")
    foreach(_mk IN LISTS _makefiles)
        ffmpeg_read_makefile("${_mk}" _content)
        ffmpeg_makefile_lines("${_content}" _lines)
        foreach(_line IN LISTS _lines)
            ffmpeg_parse_assignment("${_line}" _var _cond _value _ok)
            if(NOT _ok)
                continue()
            endif()

            if(_var STREQUAL "OBJS")
                # always
            elseif(_var STREQUAL "STLIBOBJS")
                if(NOT FFMPEG_ENABLE_STATIC)
                    continue()
                endif()
            elseif(_var STREQUAL "SHLIBOBJS")
                if(NOT FFMPEG_ENABLE_SHARED)
                    continue()
                endif()
            elseif(_var STREQUAL "X86ASM-OBJS")
                if(NOT FFMPEG_X86ASM_AVAILABLE)
                    continue()
                endif()
            else()
                continue()
            endif()

            ffmpeg_make_condition("${_cond}" _cond_ok)
            if(NOT _cond_ok)
                continue()
            endif()

            ffmpeg_expand_make_value("${_value}" _items)
            foreach(_item IN LISTS _items)
                if(NOT _item MATCHES "\\.o$")
                    continue()
                endif()
                ffmpeg_object_source("${_basedir}" "${_item}" _src)
                string(LENGTH "${_src}" _src_len)
                if(_src_len EQUAL 0)
                    ffmpeg_warn("lib${lib}: no source for object '${_item}'")
                    continue()
                endif()
                if(_src MATCHES "\\.asm$")
                    set_source_files_properties("${_src}" PROPERTIES
                        LANGUAGE ASM_NASM
                        OBJECT_DEPENDS
                        "${FFMPEG_GEN_DIR}/config.asm;${FFMPEG_GEN_DIR}/config_components.asm")
                endif()
                list(APPEND _sources "${_src}")
            endforeach()
        endforeach()
    endforeach()

    list(REMOVE_DUPLICATES _sources)
    set(${out} "${_sources}" PARENT_SCOPE)
endfunction()

function(ffmpeg_collect_headers lib out)
    set(_dir "${FFMPEG_SOURCE_DIR}/lib${lib}")
    ffmpeg_library_makefiles("${lib}" _makefiles)
    set(_headers "")
    foreach(_mk IN LISTS _makefiles)
        ffmpeg_read_makefile("${_mk}" _content)
        ffmpeg_makefile_lines("${_content}" _lines)
        foreach(_line IN LISTS _lines)
            ffmpeg_parse_assignment("${_line}" _var _cond _value _ok)
            if(NOT _ok)
                continue()
            endif()
            if(NOT (_var STREQUAL "HEADERS" OR _var MATCHES "-HEADERS$"))
                continue()
            endif()
            ffmpeg_make_condition("${_cond}" _cond_ok)
            if(NOT _cond_ok)
                continue()
            endif()
            ffmpeg_expand_make_value("${_value}" _items)
            foreach(_h IN LISTS _items)
                if(_h MATCHES "\\.h$" AND EXISTS "${_dir}/${_h}")
                    list(APPEND _headers "${_dir}/${_h}")
                endif()
            endforeach()
        endforeach()
    endforeach()
    list(REMOVE_DUPLICATES _headers)
    set(${out} "${_headers}" PARENT_SCOPE)
endfunction()

function(ffmpeg_library_versions lib out_version out_soversion)
    string(TOUPPER "lib${lib}" _prefix)
    set(_hdr "${FFMPEG_SOURCE_DIR}/lib${lib}/version.h")
    set(_major 0)
    set(_minor 0)
    set(_micro 0)
    set(_major_hdr "${FFMPEG_SOURCE_DIR}/lib${lib}/version_major.h")
    if(EXISTS "${_major_hdr}")
        file(STRINGS "${_major_hdr}" _maj REGEX "^#define ${_prefix}_VERSION_MAJOR")
    endif()
    if(EXISTS "${_hdr}")
        if(NOT _maj)
            file(STRINGS "${_hdr}" _maj REGEX "^#define ${_prefix}_VERSION_MAJOR")
        endif()
        file(STRINGS "${_hdr}" _min REGEX "^#define ${_prefix}_VERSION_MINOR")
        file(STRINGS "${_hdr}" _mic REGEX "^#define ${_prefix}_VERSION_MICRO")
        if(_maj MATCHES "([0-9]+)")
            set(_major "${CMAKE_MATCH_1}")
        endif()
        if(_min MATCHES "([0-9]+)")
            set(_minor "${CMAKE_MATCH_1}")
        endif()
        if(_mic MATCHES "([0-9]+)")
            set(_micro "${CMAKE_MATCH_1}")
        endif()
    endif()
    set(${out_version} "${_major}.${_minor}.${_micro}" PARENT_SCOPE)
    set(${out_soversion} "${_major}" PARENT_SCOPE)
endfunction()

# Common compile settings shared by libraries and programs.
# HAVE_AV_CONFIG_H is only defined for libraries: the ffmpeg/ffprobe sources
# are built exactly like upstream does, i.e. without it, so that the public
# headers pull in codec_desc.h/version.h.
function(ffmpeg_apply_shared_link_options target)
    # configure adds -Wl,-Bsymbolic for ELF shared libraries.  Without it,
    # inline assembly that references global constants (for example
    # ff_pw_53 in vc1dsp_mmx.c) produces non-PIC relocations and the link
    # fails with "recompile with -fPIC".
    if(UNIX AND NOT APPLE)
        target_link_options(${target} PRIVATE "-Wl,-Bsymbolic")
    endif()
endfunction()

function(ffmpeg_apply_compile_settings target)
    target_compile_definitions(${target} PRIVATE
        _ISOC11_SOURCE
        _FILE_OFFSET_BITS=64
        _LARGEFILE_SOURCE
        _POSIX_C_SOURCE=200112
        _XOPEN_SOURCE=600)
    target_compile_definitions(${target} PRIVATE HAVE_AV_CONFIG_H)

    target_include_directories(${target} PUBLIC
        "$<BUILD_INTERFACE:${FFMPEG_SOURCE_DIR}>"
        "$<BUILD_INTERFACE:${FFMPEG_INCLUDE_DIR}>")
    get_property(_extra_incs GLOBAL PROPERTY FFMPEG_EXTRA_INCLUDE_DIRS)
    if(_extra_incs)
        target_include_directories(${target} PRIVATE ${_extra_incs})
    endif()

    if(FFMPEG_ENABLE_DEBUG)
        target_compile_options(${target} PRIVATE
            "$<$<COMPILE_LANGUAGE:C,CXX>:-g>")
    else()
        target_compile_options(${target} PRIVATE
            "$<$<COMPILE_LANGUAGE:C,CXX>:-O3>")
    endif()
    if(NOT MSVC)
        foreach(_opt -fno-math-errno -fno-signed-zeros
                     -fno-trapping-math -Wno-unused-const-variable -fPIC)
            target_compile_options(${target} PRIVATE
                "$<$<COMPILE_LANGUAGE:C,CXX>:${_opt}>")
        endforeach()
        target_compile_definitions(${target} PRIVATE PIC)
    endif()

    if(FFMPEG_X86ASM_AVAILABLE)
        foreach(_flag IN LISTS FFMPEG_NASM_FLAGS)
            target_compile_options(${target} PRIVATE
                "$<$<COMPILE_LANGUAGE:ASM_NASM>:${_flag}>")
        endforeach()
    endif()

    set_target_properties(${target} PROPERTIES
        C_STANDARD 17
        C_STANDARD_REQUIRED ON
        C_EXTENSIONS ON)

    if(MSVC)
        # FFmpeg upstream does not support MSVC; keep the knobs explicit.
        target_compile_options(${target} PRIVATE /W3)
    endif()
endfunction()

function(ffmpeg_apply_program_compile_settings target)
    target_compile_definitions(${target} PRIVATE
        _ISOC11_SOURCE
        _FILE_OFFSET_BITS=64
        _LARGEFILE_SOURCE
        _POSIX_C_SOURCE=200112
        _XOPEN_SOURCE=600)

    target_include_directories(${target} PUBLIC
        "$<BUILD_INTERFACE:${FFMPEG_SOURCE_DIR}>"
        "$<BUILD_INTERFACE:${FFMPEG_INCLUDE_DIR}>")
    get_property(_extra_incs GLOBAL PROPERTY FFMPEG_EXTRA_INCLUDE_DIRS)
    if(_extra_incs)
        target_include_directories(${target} PRIVATE ${_extra_incs})
    endif()

    if(FFMPEG_ENABLE_DEBUG)
        target_compile_options(${target} PRIVATE -g)
    else()
        target_compile_options(${target} PRIVATE -O3)
    endif()
    if(NOT MSVC)
        target_compile_options(${target} PRIVATE
            -fno-math-errno -fno-signed-zeros -fno-trapping-math
            -Wno-unused-const-variable)
    endif()
    set_target_properties(${target} PROPERTIES
        C_STANDARD 17 C_STANDARD_REQUIRED ON C_EXTENSIONS ON)
endfunction()

function(ffmpeg_add_libraries)
    foreach(_lib IN LISTS FFMPEG_LIBRARY_LIST)
        ffmpeg_state_get("${_lib}" _st)
        if(NOT _st STREQUAL "yes")
            ffmpeg_status("skipping lib${_lib} (disabled)")
            continue()
        endif()
        set(_dir "${FFMPEG_SOURCE_DIR}/lib${_lib}")
        if(NOT EXISTS "${_dir}")
            ffmpeg_warn("lib${_lib} not present in this FFmpeg version")
            continue()
        endif()

        ffmpeg_collect_library_sources("${_lib}" _sources)
        string(LENGTH "${_sources}" _nsrc)
        if(_nsrc EQUAL 0)
            ffmpeg_warn("lib${_lib}: empty source list")
            continue()
        endif()

        ffmpeg_library_versions("${_lib}" _version _soversion)

        set(_target "ffmpeg_${_lib}")
        if(FFMPEG_ENABLE_SHARED AND NOT FFMPEG_ENABLE_STATIC)
            add_library(${_target} SHARED ${_sources})
            set_target_properties(${_target} PROPERTIES
                OUTPUT_NAME "${_lib}"
                VERSION "${_version}"
                SOVERSION "${_soversion}")
            ffmpeg_apply_shared_link_options(${_target})
        elseif(FFMPEG_ENABLE_SHARED AND FFMPEG_ENABLE_STATIC)
            add_library(${_target} STATIC ${_sources})
            add_library("${_target}_shared" SHARED ${_sources})
            set_target_properties("${_target}_shared" PROPERTIES
                OUTPUT_NAME "${_lib}"
                VERSION "${_version}"
                SOVERSION "${_soversion}")
            ffmpeg_apply_compile_settings("${_target}_shared")
            ffmpeg_apply_shared_link_options("${_target}_shared")
        else()
            add_library(${_target} STATIC ${_sources})
        endif()

        set_target_properties(${_target} PROPERTIES OUTPUT_NAME "${_lib}")
        ffmpeg_apply_compile_settings(${_target})
        add_library("FFmpeg::${_lib}" ALIAS ${_target})

        # Link dependencies (static link order matters, keep it).
        set(_link_deps "${FFMPEG_LINK_DEPS_${_lib}}")
        foreach(_dep IN LISTS _link_deps)
            if(TARGET "ffmpeg_${_dep}")
                target_link_libraries(${_target} PUBLIC "ffmpeg_${_dep}")
                if(TARGET "${_target}_shared")
                    target_link_libraries("${_target}_shared" PUBLIC "ffmpeg_${_dep}")
                endif()
            endif()
        endforeach()

        # System libraries.
        set(_syslibs "")
        if(TARGET Threads::Threads)
            list(APPEND _syslibs Threads::Threads)
        endif()
        if(NOT WIN32)
            list(APPEND _syslibs ${CMAKE_DL_LIBS} m)
        endif()
        ffmpeg_state_get("zlib" _zlib_st)
        if(TARGET ZLIB::ZLIB AND _zlib_st STREQUAL "yes")
            list(APPEND _syslibs ZLIB::ZLIB)
        endif()
        get_property(_extra_libs GLOBAL PROPERTY FFMPEG_EXTRA_SYSTEM_LIBS)
        if(_extra_libs)
            list(APPEND _syslibs ${_extra_libs})
        endif()
        target_link_libraries(${_target} PUBLIC ${_syslibs})
        if(TARGET "${_target}_shared")
            target_link_libraries("${_target}_shared" PUBLIC ${_syslibs})
        endif()

        # Optional external libraries.
        ffmpeg_link_external_libraries(${_target})
        if(TARGET "${_target}_shared")
            ffmpeg_link_external_libraries("${_target}_shared")
        endif()

        if(FFMPEG_INSTALL)
            set(_install_targets ${_target})
            if(TARGET "${_target}_shared")
                list(APPEND _install_targets "${_target}_shared")
            endif()
            install(TARGETS ${_install_targets}
                RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
                ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
                LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}")
            ffmpeg_collect_headers("${_lib}" _headers)
            if(_headers)
                install(FILES ${_headers}
                    DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/lib${_lib}")
            endif()
        endif()

        list(LENGTH _sources _n)
        ffmpeg_status("lib${_lib}: ${_n} source files (${_version})")
    endforeach()
endfunction()

function(ffmpeg_link_external_libraries target)
    set(_extlibs "")
    get_property(_extlibs GLOBAL PROPERTY FFMPEG_EXTERNAL_PKG_NAMES)
    foreach(_name IN LISTS _extlibs)
        ffmpeg_state_get("${_name}" _st)
        if(NOT _st STREQUAL "yes")
            continue()
        endif()
        string(TOUPPER "${_name}" _up)
        if(TARGET "PkgConfig::PC_${_up}")
            target_link_libraries(${target} PUBLIC "PkgConfig::PC_${_up}")
        endif()
    endforeach()
endfunction()
