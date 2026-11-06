# =============================================================================
# ffmpeg / ffprobe / ffplay executables.
# =============================================================================

function(ffmpeg_bin2c input symbol output)
    file(READ "${input}" _hex HEX)
    string(REGEX REPLACE "(..)" "0x\\1, " _bytes "${_hex}")
    string(LENGTH "${_hex}" _hexlen)
    math(EXPR _len "${_hexlen}/2")
    file(WRITE "${output}"
"/* Generated from ${input} by ffmpeg-cmake */
const unsigned char ff_${symbol}_data[] = { ${_bytes}0x00 };
const unsigned int ff_${symbol}_len = ${_len};
")
endfunction()

function(ffmpeg_program_sources prog out)
    ffmpeg_read_makefile("${FFMPEG_SOURCE_DIR}/fftools/Makefile" _content)
    ffmpeg_makefile_lines("${_content}" _lines)

    set(_objects "")
    foreach(_line IN LISTS _lines)
        if(_line MATCHES "^OBJS-${prog}[ \t]*\\+?=[ \t]*(.*)$")
            set(_value "${CMAKE_MATCH_1}")
            separate_arguments(_value UNIX_COMMAND "${_value}")
            foreach(_item IN LISTS _value)
                if(_item MATCHES "OBJS-resman")
                    list(APPEND _objects "fftools/resources/resman.o")
                elseif(_item MATCHES "RESOBJS")
                    list(APPEND _objects
                        "fftools/resources/graph.html.o"
                        "fftools/resources/graph.css.o")
                elseif(_item MATCHES "COMPAT_OBJS")
                    # configure adds compat/android/binder.o to ffmpeg when
                    # MediaCodec (and therefore JNI) is enabled.
                    if(_prog STREQUAL "ffmpeg" AND ANDROID)
                        ffmpeg_state_get("mediacodec" _mc_state)
                        if(_mc_state STREQUAL "yes")
                            list(APPEND _objects "compat/android/binder.o")
                        endif()
                    endif()
                elseif(_item MATCHES "\\.o$")
                    list(APPEND _objects "${_item}")
                endif()
            endforeach()
        endif()
    endforeach()

    # Added by the DOFFTOOL macro in fftools/Makefile.
    list(APPEND _objects
        "fftools/cmdutils.o"
        "fftools/opt_common.o"
        "fftools/${prog}.o")

    # Generated resources.
    set(_gen "${FFMPEG_GEN_DIR}/fftools/resources")
    file(MAKE_DIRECTORY "${_gen}")
    if(EXISTS "${FFMPEG_SOURCE_DIR}/fftools/resources/graph.html")
        ffmpeg_bin2c("${FFMPEG_SOURCE_DIR}/fftools/resources/graph.html"
                     "graph_html" "${_gen}/graph.html.c")
    endif()
    if(EXISTS "${FFMPEG_SOURCE_DIR}/fftools/resources/graph.css")
        ffmpeg_bin2c("${FFMPEG_SOURCE_DIR}/fftools/resources/graph.css"
                     "graph_css" "${_gen}/graph.css.c")
    endif()

    set(_sources "")
    foreach(_obj IN LISTS _objects)
        if(_obj MATCHES "fftools/resources/graph\\.html\\.o$")
            list(APPEND _sources "${_gen}/graph.html.c")
            continue()
        elseif(_obj MATCHES "fftools/resources/graph\\.css\\.o$")
            list(APPEND _sources "${_gen}/graph.css.c")
            continue()
        endif()
        ffmpeg_object_source("${FFMPEG_SOURCE_DIR}" "${_obj}" _src)
        string(LENGTH "${_src}" _src_len)
        if(_src_len EQUAL 0)
            ffmpeg_warn("${prog}: no source for object '${_obj}'")
            continue()
        endif()
        list(APPEND _sources "${_src}")
    endforeach()

    list(REMOVE_DUPLICATES _sources)
    set(${out} "${_sources}" PARENT_SCOPE)
endfunction()

function(ffmpeg_link_program_dependencies prog target)
    # ffplay is the only tool with a direct external dependency (SDL2).
    # configure puts sdl2_cflags into CFLAGS-ffplay; the pkg-config imported
    # target carries both the include directories and the link libraries.
    if(prog STREQUAL "ffplay")
        ffmpeg_state_get("sdl2" _sdl_state)
        if(_sdl_state STREQUAL "yes")
            if(TARGET PkgConfig::PC_SDL2)
                target_link_libraries(${target} PRIVATE PkgConfig::PC_SDL2)
            else()
                get_property(_sdl_incs GLOBAL PROPERTY FFMPEG_EXTLIB_sdl2_INCLUDE_DIRS)
                get_property(_sdl_libs GLOBAL PROPERTY FFMPEG_EXTLIB_sdl2_LIBRARIES)
                get_property(_sdl_ldflags GLOBAL PROPERTY FFMPEG_EXTLIB_sdl2_LDFLAGS)
                if(_sdl_incs)
                    target_include_directories(${target} PRIVATE ${_sdl_incs})
                endif()
                if(_sdl_libs OR _sdl_ldflags)
                    target_link_libraries(${target} PRIVATE ${_sdl_libs} ${_sdl_ldflags})
                endif()
            endif()
        endif()
    endif()
endfunction()

function(ffmpeg_add_programs)
    foreach(_prog IN LISTS FFMPEG_PROGRAM_LIST)
        ffmpeg_state_get("${_prog}" _st)
        if(NOT _st STREQUAL "yes")
            set(_ffplay_forced_off FALSE)
            if(_prog STREQUAL "ffplay"
               AND DEFINED FFMPEG_ENABLE_FFPLAY
               AND FFMPEG_ENABLE_FFPLAY STREQUAL "OFF")
                set(_ffplay_forced_off TRUE)
            endif()
            if(_prog STREQUAL "ffplay" AND NOT _ffplay_forced_off)
                ffmpeg_state_get("sdl2" _sdl_state)
                if(NOT _sdl_state STREQUAL "yes")
                    ffmpeg_status("skipping program ffplay "
                        "(SDL2 development files not found; install libsdl2-dev "
                        "or set PKG_CONFIG_PATH)")
                else()
                    ffmpeg_status("skipping program ffplay (disabled by dependencies)")
                endif()
            else()
                ffmpeg_status("skipping program ${_prog} (disabled)")
            endif()
            continue()
        endif()

        ffmpeg_program_sources("${_prog}" _sources)
        string(LENGTH "${_sources}" _nsrc)
        if(_nsrc EQUAL 0)
            ffmpeg_warn("program ${_prog}: no sources found")
            continue()
        endif()

        set(_target "ffmpeg_tool_${_prog}")
        add_executable(${_target} ${_sources})
        set_target_properties(${_target} PROPERTIES OUTPUT_NAME "${_prog}")
        ffmpeg_apply_program_compile_settings(${_target})

        set(_libs "")
        foreach(_lib avdevice avfilter avformat avcodec swresample swscale avutil)
            if(TARGET "ffmpeg_${_lib}")
                list(APPEND _libs "ffmpeg_${_lib}")
            endif()
        endforeach()
        target_link_libraries(${_target} PRIVATE ${_libs})
        ffmpeg_link_program_dependencies("${_prog}" ${_target})

        if(FFMPEG_INSTALL)
            install(TARGETS ${_target} RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
        endif()

        list(LENGTH _sources _n)
        ffmpeg_status("program ${_prog}: ${_n} source files")
    endforeach()
endfunction()
