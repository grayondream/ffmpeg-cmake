# =============================================================================
# Component / configuration metadata discovery.
#
# Everything here is read from the *unmodified* upstream tree at configure
# time.  Nothing is written into it.
# =============================================================================

function(ffmpeg_add_resolve_name name)
    string(TOLOWER "${name}" name)
    set(_has "")
    get_property(_has GLOBAL PROPERTY "FFMPEG_RESOLVE_HAS_${name}")
    if(NOT _has)
        set_property(GLOBAL PROPERTY "FFMPEG_RESOLVE_HAS_${name}" TRUE)
        set_property(GLOBAL APPEND PROPERTY FFMPEG_RESOLVE_NAMES "${name}")
    endif()
endfunction()

function(ffmpeg_add_config_name name)
    set(_has "")
    get_property(_has GLOBAL PROPERTY "FFMPEG_CONFIG_HAS_${name}")
    if(NOT _has)
        set_property(GLOBAL PROPERTY "FFMPEG_CONFIG_HAS_${name}" TRUE)
        set_property(GLOBAL APPEND PROPERTY FFMPEG_CONFIG_NAMES "${name}")
    endif()
endfunction()

# ---------------------------------------------------------------------------
# Component registry from the "extern const ... ff_foo_bar;" declarations.
# ---------------------------------------------------------------------------
function(ffmpeg_scan_components)
    set(_all "")
    foreach(_spec IN LISTS FFMPEG_COMPONENT_SPECS)
        string(REPLACE "|" ";" _parts "${_spec}")
        list(GET _parts 0 _kind)
        list(GET _parts 1 _file)
        list(GET _parts 2 _regex)
        list(GET _parts 3 _name_tmpl)
        list(GET _parts 4 _sym_tmpl)

        set(_path "${FFMPEG_SOURCE_DIR}/${_file}")
        if(NOT EXISTS "${_path}")
            ffmpeg_warn("component source '${_file}' not found, kind '${_kind}' skipped")
            continue()
        endif()

        file(STRINGS "${_path}" _lines REGEX "extern")
        set(_found "")
        foreach(_line IN LISTS _lines)
            if(_line MATCHES "${_regex}")
                set(_g1 "${CMAKE_MATCH_1}")
                set(_g2 "${CMAKE_MATCH_2}")
                set(_name "${_name_tmpl}")
                string(REPLACE "{2}" "${_g2}" _name "${_name}")
                string(REPLACE "{1}" "${_g1}" _name "${_name}")
                set(_sym "${_sym_tmpl}")
                string(REPLACE "{2}" "${_g2}" _sym "${_sym}")
                string(REPLACE "{1}" "${_g1}" _sym "${_sym}")
                string(TOUPPER "${_name}" _cfg)
                set(_cfg "CONFIG_${_cfg}")

                set_property(GLOBAL PROPERTY "FFMPEG_COMPONENT_SYMBOL_${_name}" "${_sym}")
                set_property(GLOBAL PROPERTY "FFMPEG_COMPONENT_CONFIG_${_name}" "${_cfg}")
                set_property(GLOBAL PROPERTY "FFMPEG_COMPONENT_KIND_${_name}" "${_kind}")
                list(APPEND _found "${_name}")
                list(APPEND _all "${_name}")
                ffmpeg_add_config_name("${_name}")
                ffmpeg_add_resolve_name("${_name}")
            endif()
        endforeach()
        list(REMOVE_DUPLICATES _found)
        set_property(GLOBAL PROPERTY "FFMPEG_COMPONENTS_${_kind}" "${_found}")
        ffmpeg_status("components ${_kind}: ${_found}")
    endforeach()
    list(REMOVE_DUPLICATES _all)
    set_property(GLOBAL PROPERTY FFMPEG_ALL_COMPONENTS "${_all}")
endfunction()

# ---------------------------------------------------------------------------
# All CONFIG_* symbols referenced by the upstream makefiles.
# ---------------------------------------------------------------------------
function(ffmpeg_scan_config_names)
    set(_makefiles "")

    if(FFMPEG_ARCH)
        file(GLOB _libs RELATIVE "${FFMPEG_SOURCE_DIR}" "${FFMPEG_SOURCE_DIR}/lib*/Makefile")
        foreach(_rel IN LISTS _libs)
            list(APPEND _makefiles "${_rel}")
        endforeach()
        file(GLOB _arch_mks RELATIVE "${FFMPEG_SOURCE_DIR}"
             "${FFMPEG_SOURCE_DIR}/lib*/${FFMPEG_ARCH}/Makefile")
        foreach(_rel IN LISTS _arch_mks)
            list(APPEND _makefiles "${_rel}")
        endforeach()
    else()
        file(GLOB _libs RELATIVE "${FFMPEG_SOURCE_DIR}" "${FFMPEG_SOURCE_DIR}/lib*/Makefile")
        list(APPEND _makefiles ${_libs})
    endif()

    foreach(_extra fftools/Makefile fftools/resources/Makefile compat/Makefile)
        if(EXISTS "${FFMPEG_SOURCE_DIR}/${_extra}")
            list(APPEND _makefiles "${_extra}")
        endif()
    endforeach()

    foreach(_rel IN LISTS _makefiles)
        file(STRINGS "${FFMPEG_SOURCE_DIR}/${_rel}" _lines)
        foreach(_line IN LISTS _lines)
            string(REGEX MATCHALL "CONFIG_[A-Z0-9_]+" _matches "${_line}")
            foreach(_m IN LISTS _matches)
                string(REGEX REPLACE "^CONFIG_" "" _n "${_m}")
                string(TOLOWER "${_n}" _n)
                ffmpeg_add_config_name("${_n}")
                ffmpeg_add_resolve_name("${_n}")
            endforeach()
        endforeach()
    endforeach()
endfunction()

# ---------------------------------------------------------------------------
# Dependency metadata: foo_deps / foo_select / foo_deps_any / ...
# ---------------------------------------------------------------------------
function(ffmpeg_scan_dependency_metadata)
    file(STRINGS "${FFMPEG_SOURCE_DIR}/configure" _lines
         REGEX "^[a-z0-9_]+_(deps|deps_any|select|suggest|conflict|if|if_any)=")

    foreach(_line IN LISTS _lines)
        if(_line MATCHES "^([a-z0-9_]+)_(deps|deps_any|select|suggest|conflict|if|if_any)=\"(.*)\"$")
            set(_name "${CMAKE_MATCH_1}")
            set(_type "${CMAKE_MATCH_2}")
            set(_value "${CMAKE_MATCH_3}")
            string(STRIP "${_value}" _value)
            separate_arguments(_value UNIX_COMMAND "${_value}")
            set_property(GLOBAL PROPERTY "FFMPEG_DEP_${_name}_${_type}" "${_value}")
            ffmpeg_add_resolve_name("${_name}")
            foreach(_dep IN LISTS _value)
                if(NOT _dep MATCHES "^!")
                    ffmpeg_add_resolve_name("${_dep}")
                endif()
            endforeach()
        endif()
    endforeach()
endfunction()
