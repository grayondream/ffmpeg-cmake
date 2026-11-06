# =============================================================================
# Platform / feature / external library detection.
# =============================================================================

include(CheckIncludeFile)
include(CheckSymbolExists)
include(CheckLibraryExists)
include(CheckTypeSize)
include(CheckCSourceCompiles)
include(CheckCSourceRuns)
include(TestBigEndian)
include(CMakePushCheckState)

function(ffmpeg_add_have_name name)
    get_property(_names GLOBAL PROPERTY FFMPEG_HAVE_NAMES)
    list(FIND _names "${name}" _idx)
    if(_idx EQUAL -1)
        set_property(GLOBAL APPEND PROPERTY FFMPEG_HAVE_NAMES "${name}")
    endif()
endfunction()

function(ffmpeg_set_feature name value)
    ffmpeg_state_set("${name}" "${value}")
    ffmpeg_add_have_name("${name}")
    ffmpeg_add_resolve_name("${name}")
endfunction()

# ---------------------------------------------------------------------------
# nasm probing (x86 external assembly).
# ---------------------------------------------------------------------------
function(ffmpeg_nasm_try_assemble nasm format code out)
    set(_dir "${CMAKE_BINARY_DIR}/CMakeFiles")
    file(MAKE_DIRECTORY "${_dir}")
    set(_src "${_dir}/ffmpeg-nasm-probe.asm")
    set(_obj "${_dir}/ffmpeg-nasm-probe.o")
    file(WRITE "${_src}" "${code}\n")
    file(REMOVE "${_obj}")
    execute_process(
        COMMAND "${nasm}" -f "${format}" -Werror -o "${_obj}" "${_src}"
        RESULT_VARIABLE _rc OUTPUT_QUIET ERROR_QUIET)
    if(_rc EQUAL 0 AND EXISTS "${_obj}")
        set(${out} TRUE PARENT_SCOPE)
    else()
        set(${out} FALSE PARENT_SCOPE)
    endif()
endfunction()

function(ffmpeg_nasm_object_format out)
    if(WIN32)
        if(CMAKE_SIZEOF_VOID_P EQUAL 8)
            set(_fmt win64)
        else()
            set(_fmt win32)
        endif()
    elseif(APPLE)
        if(CMAKE_SIZEOF_VOID_P EQUAL 8)
            set(_fmt macho64)
        else()
            set(_fmt macho32)
        endif()
    else()
        if(CMAKE_SIZEOF_VOID_P EQUAL 8)
            set(_fmt elf64)
        else()
            set(_fmt elf32)
        endif()
    endif()
    set(${out} "${_fmt}" PARENT_SCOPE)
endfunction()

# Configure the nasm toolchain and decide whether x86 assembly can be used.
function(ffmpeg_detect_x86asm)
    set(_available FALSE)
    set(_flags "")

    if(FFMPEG_ENABLE_X86ASM AND FFMPEG_ARCH STREQUAL "x86")
        find_program(FFMPEG_NASM_EXECUTABLE nasm)
        if(FFMPEG_NASM_EXECUTABLE)
            ffmpeg_nasm_object_format(_format)
            ffmpeg_nasm_try_assemble("${FFMPEG_NASM_EXECUTABLE}" "${_format}"
                "SECTION .text\nmovbe ecx, [eax]" _can_assemble)
            if(_can_assemble)
                set(_available TRUE)
                set(CMAKE_ASM_NASM_COMPILER "${FFMPEG_NASM_EXECUTABLE}"
                    CACHE FILEPATH "nasm assembler" FORCE)
                set(CMAKE_ASM_NASM_OBJECT_FORMAT "${_format}" CACHE STRING "" FORCE)
                set(_flags
                    "-I${FFMPEG_SOURCE_DIR}"
                    "-I${FFMPEG_GEN_DIR}"
                    "-P${FFMPEG_GEN_DIR}/config.asm"
                    "-I${FFMPEG_SOURCE_DIR}/libavutil/x86"
                    "-I${FFMPEG_SOURCE_DIR}/libavcodec/x86"
                    "-I${FFMPEG_SOURCE_DIR}/libavformat/x86"
                    "-I${FFMPEG_SOURCE_DIR}/libavfilter/x86"
                    "-I${FFMPEG_SOURCE_DIR}/libavdevice/x86"
                    "-I${FFMPEG_SOURCE_DIR}/libswscale/x86"
                    "-I${FFMPEG_SOURCE_DIR}/libswresample/x86")
                if(FFMPEG_ENABLE_DEBUG)
                    list(APPEND _flags "-g")
                endif()
            else()
                ffmpeg_warn("nasm found but unusable, building without x86 assembly")
            endif()
        endif()
    endif()

    if(_available)
        ffmpeg_set_feature("x86asm" yes)
    else()
        ffmpeg_set_feature("x86asm" no)
    endif()
    set(FFMPEG_X86ASM_AVAILABLE "${_available}" PARENT_SCOPE)
    set(FFMPEG_NASM_FLAGS "${_flags}" PARENT_SCOPE)
endfunction()

# x86 SIMD capabilities.  Base features mirror configure's
# `enable $ARCH_EXT_LIST`: they are available when targeting x86 and are
# selected at runtime through CPUID.  The _inline variants need inline asm
# support; the _external variants additionally need a working nasm.
function(ffmpeg_detect_x86_capabilities)
    if(NOT FFMPEG_ARCH STREQUAL "x86")
        return()
    endif()

    set(_simd
        amd3dnow amd3dnowext
        mmx mmxext
        sse sse2 sse3 ssse3 sse4 sse42
        avx avx2 avx512 avx512icl
        aesni clmul fma3 fma4 xop)

    ffmpeg_state_get("inline_asm" _inline)
    ffmpeg_state_get("x86asm" _x86asm)

    foreach(_f IN LISTS _simd)
        ffmpeg_set_feature("${_f}" yes)
    endforeach()

    # AVX-512 is opt-in through the existing knob.
    if(NOT FFMPEG_ENABLE_AVX512)
        ffmpeg_set_feature("avx512" no)
        ffmpeg_set_feature("avx512icl" no)
    endif()

    foreach(_f IN LISTS _simd)
        ffmpeg_state_get("${_f}" _base)
        if(_base STREQUAL "yes")
            if(_inline STREQUAL "yes")
                ffmpeg_set_feature("${_f}_inline" yes)
            else()
                ffmpeg_set_feature("${_f}_inline" no)
            endif()
            if(_x86asm STREQUAL "yes")
                ffmpeg_set_feature("${_f}_external" yes)
            else()
                ffmpeg_set_feature("${_f}_external" no)
            endif()
        else()
            ffmpeg_set_feature("${_f}_inline" no)
            ffmpeg_set_feature("${_f}_external" no)
        endif()
    endforeach()

    # configure leaves the 3DNow! implementation flags off: they are the
    # first entries in the extension list and end up depending on a literal
    # "_external"/"_inline" feature that does not exist.
    ffmpeg_set_feature("amd3dnow_external" no)
    ffmpeg_set_feature("amd3dnow_inline" no)
    ffmpeg_set_feature("amd3dnowext_external" no)
    ffmpeg_set_feature("amd3dnowext_inline" no)

    # Instructions that older nasm releases cannot assemble.
    if(_x86asm STREQUAL "yes")
        ffmpeg_nasm_object_format(_format)
        foreach(_probe
                "avx512|vmovdqa32 [eax]{k1}{z}, zmm0"
                "avx512icl|vpdpwssds zmm31{k1}{z}, zmm29, zmm28"
                "avx2|vextracti128 xmm0, ymm0, 0"
                "xop|vpmacsdd xmm0, xmm1, xmm2, xmm3"
                "fma4|vfmaddps ymm0, ymm1, ymm2, ymm3"
                "avx|vpermilpd ymm0, ymm1, 0x72")
            string(REPLACE "|" ";" _p "${_probe}")
            list(GET _p 0 _f)
            list(GET _p 1 _code)
            ffmpeg_state_get("${_f}" _base)
            if(_base STREQUAL "yes")
                ffmpeg_nasm_try_assemble("${FFMPEG_NASM_EXECUTABLE}"
                    "${_format}" "${_code}" _ok)
                if(NOT _ok)
                    ffmpeg_set_feature("${_f}_external" no)
                endif()
            endif()
        endforeach()
    endif()

    # Compiler intrinsic support (config.h HAVE_INTRINSICS_*).
    check_c_source_compiles("
        #include <emmintrin.h>
        int main(void) { __m128i v = _mm_setzero_si128(); (void)v; return 0; }"
        FFMPEG_CHECK_INTRINSICS_SSE2)
    if(FFMPEG_CHECK_INTRINSICS_SSE2)
        ffmpeg_set_feature("intrinsics_sse2" yes)
    else()
        ffmpeg_set_feature("intrinsics_sse2" no)
    endif()

    # Inline assembly feature checks.
    if(_inline STREQUAL "yes")
        ffmpeg_set_feature("inline_asm_direct_symbol_refs" yes)
        ffmpeg_set_feature("inline_asm_nonlocal_labels" yes)
        ffmpeg_set_feature("xmm_clobbers" yes)
        ffmpeg_set_feature("mm_empty" yes)
        ffmpeg_set_feature("x86_6regs" yes)
        ffmpeg_state_get("x86_64" _is_64)
        if(_is_64 STREQUAL "yes")
            ffmpeg_set_feature("x86_7regs" yes)
            ffmpeg_set_feature("ebx_available" yes)
        else()
            ffmpeg_set_feature("x86_7regs" no)
        endif()
    else()
        ffmpeg_set_feature("inline_asm_direct_symbol_refs" no)
        ffmpeg_set_feature("inline_asm_nonlocal_labels" no)
        ffmpeg_set_feature("xmm_clobbers" no)
        ffmpeg_set_feature("mm_empty" no)
        ffmpeg_set_feature("x86_6regs" no)
        ffmpeg_set_feature("x86_7regs" no)
    endif()
endfunction()

# ---------------------------------------------------------------------------
# Architecture / OS.
# ---------------------------------------------------------------------------
function(ffmpeg_detect_environment)
    string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" _proc)
    string(LENGTH "${_proc}" _proc_len)
    if(_proc_len EQUAL 0)
        set(_proc "unknown")
    endif()

    set(FFMPEG_ARCH "")
    set(_arch_states "")
    foreach(_entry IN LISTS FFMPEG_ARCH_MAP)
        string(REPLACE "|" ";" _p "${_entry}")
        list(GET _p 0 _pattern)
        list(GET _p 1 _dir)
        list(GET _p 2 _states)
        if(_proc MATCHES "^${_pattern}")
            set(FFMPEG_ARCH "${_dir}")
            string(REPLACE "," ";" _arch_states "${_states}")
            break()
        endif()
    endforeach()

    string(LENGTH "${FFMPEG_ARCH}" _arch_len)
    if(_arch_len EQUAL 0)
        ffmpeg_warn("unknown processor '${CMAKE_SYSTEM_PROCESSOR}', SIMD/assembly disabled")
        set(FFMPEG_ARCH "unknown")
    endif()

    foreach(_a IN LISTS FFMPEG_ARCH_LIST)
        ffmpeg_state_set("${_a}" no)
    endforeach()
    foreach(_a IN LISTS _arch_states)
        ffmpeg_state_set("${_a}" yes)
    endforeach()

    set(FFMPEG_ARCH "${FFMPEG_ARCH}" PARENT_SCOPE)
    set(FFMPEG_ARCH_STATES "${_arch_states}" PARENT_SCOPE)
    ffmpeg_status("architecture: ${FFMPEG_ARCH} (${_arch_states})")

    # Operating system feature names used in *_deps strings.
    foreach(_os linux darwin windows mingw32 cygwin freebsd openbsd netbsd
                android sunos aix haiku os2 wasm)
        ffmpeg_state_set("${_os}" no)
    endforeach()
    if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
        if(ANDROID)
            ffmpeg_state_set("android" yes)
        else()
            ffmpeg_state_set("linux" yes)
        endif()
    elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
        ffmpeg_state_set("darwin" yes)
    elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
        ffmpeg_state_set("windows" yes)
        if(MINGW)
            ffmpeg_state_set("mingw32" yes)
        endif()
    elseif(CMAKE_SYSTEM_NAME STREQUAL "Android")
        ffmpeg_state_set("android" yes)
    elseif(CMAKE_SYSTEM_NAME STREQUAL "FreeBSD")
        ffmpeg_state_set("freebsd" yes)
    elseif(CMAKE_SYSTEM_NAME STREQUAL "OpenBSD")
        ffmpeg_state_set("openbsd" yes)
    elseif(CMAKE_SYSTEM_NAME STREQUAL "NetBSD")
        ffmpeg_state_set("netbsd" yes)
    elseif(CMAKE_SYSTEM_NAME STREQUAL "SunOS")
        ffmpeg_state_set("sunos" yes)
    elseif(CMAKE_SYSTEM_NAME STREQUAL "AIX")
        ffmpeg_state_set("aix" yes)
    elseif(CMAKE_SYSTEM_NAME STREQUAL "Haiku")
        ffmpeg_state_set("haiku" yes)
    elseif(CMAKE_SYSTEM_NAME STREQUAL "CYGWIN")
        ffmpeg_state_set("cygwin" yes)
    endif()

    # License / build mode switches.
    if(FFMPEG_ENABLE_GPL)
        ffmpeg_set_feature("gpl" yes)
    else()
        ffmpeg_set_feature("gpl" no)
    endif()
    if(FFMPEG_ENABLE_VERSION3)
        ffmpeg_set_feature("version3" yes)
    else()
        ffmpeg_set_feature("version3" no)
    endif()
    if(FFMPEG_ENABLE_NONFREE)
        ffmpeg_set_feature("nonfree" yes)
    else()
        ffmpeg_set_feature("nonfree" no)
    endif()
    if(FFMPEG_ENABLE_SMALL)
        ffmpeg_set_feature("small" yes)
    else()
        ffmpeg_set_feature("small" no)
    endif()
    if(FFMPEG_ENABLE_DEBUG)
        ffmpeg_set_feature("debug" yes)
    else()
        ffmpeg_set_feature("debug" no)
    endif()
    # AArch64 assembly uses CONFIG_PIC in movrel; x86 nasm uses it too.
    # Android static archives are routinely linked into PIE/shared objects,
    # so keep them PIC even when only .a files are produced.
    if(FFMPEG_ENABLE_SHARED OR ANDROID)
        ffmpeg_set_feature("pic" yes)
    else()
        ffmpeg_set_feature("pic" no)
    endif()

    # x86 assembly availability (nasm toolchain probe).
    ffmpeg_detect_x86asm()
    set(FFMPEG_X86ASM_AVAILABLE "${FFMPEG_X86ASM_AVAILABLE}" PARENT_SCOPE)
    set(FFMPEG_NASM_FLAGS "${FFMPEG_NASM_FLAGS}" PARENT_SCOPE)

    # Threading.
    set(THREADS_PREFER_PTHREAD_FLAG ON)
    find_package(Threads QUIET)
    if(Threads_FOUND)
        ffmpeg_set_feature("threads" yes)
        if(WIN32)
            ffmpeg_set_feature("w32threads" yes)
            ffmpeg_set_feature("pthreads" no)
        else()
            ffmpeg_set_feature("pthreads" yes)
            ffmpeg_set_feature("w32threads" no)
        endif()
    else()
        ffmpeg_set_feature("threads" no)
        ffmpeg_set_feature("pthreads" no)
        ffmpeg_set_feature("w32threads" no)
    endif()

    # Endianness.
    test_big_endian(FFMPEG_BIG_ENDIAN)
    if(FFMPEG_BIG_ENDIAN)
        ffmpeg_set_feature("bigendian" yes)
    else()
        ffmpeg_set_feature("bigendian" no)
    endif()

    # Baseline CPU features needed by the dependency graph.  SIMD extension
    # support stays "no" unless we actually probe the compiler for it.
    if(FFMPEG_ARCH STREQUAL "x86")
        ffmpeg_set_feature("i686" yes)
        ffmpeg_set_feature("fast_cmov" yes)
        ffmpeg_set_feature("cmov" yes)
    elseif(FFMPEG_ARCH STREQUAL "aarch64")
        ffmpeg_set_feature("armv8" yes)
        ffmpeg_set_feature("neon" yes)
    elseif(FFMPEG_ARCH STREQUAL "arm")
        ffmpeg_set_feature("armv5te" yes)
    endif()

    # 64-bit register width / alignment.
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        ffmpeg_set_feature("fast_64bit" yes)
    else()
        ffmpeg_set_feature("fast_64bit" no)
    endif()
    if(FFMPEG_ARCH MATCHES "^(x86|aarch64|ppc|riscv|loongarch|s390|mips)$")
        ffmpeg_set_feature("simd_align_64" yes)
    else()
        ffmpeg_set_feature("simd_align_64" no)
    endif()
    if(FFMPEG_ARCH MATCHES "^(x86|aarch64|ppc|riscv|loongarch)$")
        ffmpeg_set_feature("simd_align_32" yes)
        ffmpeg_set_feature("simd_align_16" yes)
    else()
        ffmpeg_set_feature("simd_align_32" no)
        ffmpeg_set_feature("simd_align_16" no)
    endif()
    if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
        ffmpeg_set_feature("aligned_stack" yes)
        ffmpeg_set_feature("pragma_deprecated" yes)
    else()
        ffmpeg_set_feature("aligned_stack" no)
        ffmpeg_set_feature("pragma_deprecated" no)
    endif()
    ffmpeg_state_get("x86_64" _is_x86_64)
    if(_is_x86_64 STREQUAL "yes")
        ffmpeg_set_feature("ebx_available" yes)
        ffmpeg_set_feature("x86_6regs" yes)
    else()
        ffmpeg_set_feature("ebx_available" no)
        ffmpeg_set_feature("x86_6regs" no)
    endif()
    if(ANDROID)
        # configure's android branch enables section_data_rel_ro and
        # explicitly disables symver.
        ffmpeg_set_feature("section_data_rel_ro" yes)
        ffmpeg_set_feature("symver" no)
        ffmpeg_set_feature("symver_gnu_asm" no)
    elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
        ffmpeg_set_feature("section_data_rel_ro" yes)
        ffmpeg_set_feature("symver" yes)
        ffmpeg_set_feature("symver_gnu_asm" yes)
    else()
        ffmpeg_set_feature("section_data_rel_ro" no)
        ffmpeg_set_feature("symver" no)
        ffmpeg_set_feature("symver_gnu_asm" no)
    endif()

    # Tools used by optional features.
    find_program(FFMPEG_GZIP_EXECUTABLE gzip)
    find_program(FFMPEG_PERL_EXECUTABLE perl)
    find_program(FFMPEG_POD2MAN_EXECUTABLE pod2man)
    if(FFMPEG_GZIP_EXECUTABLE)
        ffmpeg_set_feature("gzip" yes)
    else()
        ffmpeg_set_feature("gzip" no)
    endif()
    if(FFMPEG_PERL_EXECUTABLE)
        ffmpeg_set_feature("perl" yes)
    else()
        ffmpeg_set_feature("perl" no)
    endif()
    if(FFMPEG_POD2MAN_EXECUTABLE)
        ffmpeg_set_feature("pod2man" yes)
    else()
        ffmpeg_set_feature("pod2man" no)
    endif()

    find_program(FFMPEG_XMLLINT_EXECUTABLE xmllint)
    if(FFMPEG_XMLLINT_EXECUTABLE)
        ffmpeg_set_feature("xmllint" yes)
    else()
        ffmpeg_set_feature("xmllint" no)
    endif()

    find_program(FFMPEG_RSYNC_EXECUTABLE rsync)
    set(_rsync_contimeout no)
    if(FFMPEG_RSYNC_EXECUTABLE)
        execute_process(COMMAND "${FFMPEG_RSYNC_EXECUTABLE}" --help
            OUTPUT_VARIABLE _rsync_help ERROR_QUIET)
        if(_rsync_help MATCHES "contimeout=")
            set(_rsync_contimeout yes)
        endif()
    endif()
    ffmpeg_set_feature("rsync_contimeout" "${_rsync_contimeout}")

    # Unaligned access is native on the common targets.
    if(FFMPEG_ARCH MATCHES "^(x86|aarch64|ppc|riscv|loongarch|s390)$")
        ffmpeg_set_feature("fast_unaligned" yes)
    else()
        ffmpeg_set_feature("fast_unaligned" no)
    endif()
endfunction()

# ---------------------------------------------------------------------------
# Feature probes (headers, functions, types, libraries).
# ---------------------------------------------------------------------------
function(ffmpeg_detect_features)
    # Cache entries created before the probe was improved must be refreshed.
    foreach(_stale pthread_setaffinity_np pthread_getaffinity_np
                   sched_getaffinity prctl)
        unset("FFMPEG_CHECK_FUNC_${_stale}" CACHE)
    endforeach()

    # --- headers ---------------------------------------------------------
    foreach(_entry IN LISTS FFMPEG_CHECK_HEADERS)
        string(REPLACE "|" ";" _p "${_entry}")
        list(GET _p 0 _name)
        list(GET _p 1 _header)
        check_include_file("${_header}" "FFMPEG_CHECK_${_name}")
        if(FFMPEG_CHECK_${_name})
            ffmpeg_set_feature("${_name}" yes)
        else()
            ffmpeg_set_feature("${_name}" no)
        endif()
    endforeach()

    # --- functions -------------------------------------------------------
    foreach(_entry IN LISTS FFMPEG_CHECK_FUNCS)
        string(REPLACE "|" ";" _p "${_entry}")
        list(GET _p 0 _name)
        list(GET _p 1 _func)
        list(GET _p 2 _headers)
        string(REPLACE "," ";" _headers "${_headers}")
        cmake_push_check_state()
        if(_name MATCHES "^(pthread_setaffinity_np|pthread_getaffinity_np|sched_getaffinity|prctl)$")
            set(CMAKE_REQUIRED_DEFINITIONS "-D_GNU_SOURCE")
        endif()
        check_symbol_exists("${_func}" "${_headers}" "FFMPEG_CHECK_FUNC_${_name}")
        cmake_pop_check_state()
        if(FFMPEG_CHECK_FUNC_${_name})
            ffmpeg_set_feature("${_name}" yes)
        else()
            ffmpeg_set_feature("${_name}" no)
        endif()
    endforeach()

    # --- libraries -------------------------------------------------------
    foreach(_entry IN LISTS FFMPEG_CHECK_LIBS)
        string(REPLACE "|" ";" _p "${_entry}")
        list(GET _p 0 _name)
        list(GET _p 1 _lib)
        list(GET _p 2 _func)
        check_library_exists("${_lib}" "${_func}" "" "FFMPEG_CHECK_LIB_${_name}")
        if(FFMPEG_CHECK_LIB_${_name})
            ffmpeg_set_feature("${_name}" yes)
        else()
            ffmpeg_set_feature("${_name}" no)
        endif()
    endforeach()

    # --- types -----------------------------------------------------------
    foreach(_entry IN LISTS FFMPEG_CHECK_TYPES)
        string(REPLACE "|" ";" _p "${_entry}")
        list(GET _p 0 _name)
        list(GET _p 1 _type)
        list(GET _p 2 _headers)
        string(REPLACE "," ";" _headers "${_headers}")
        set(CMAKE_REQUIRED_INCLUDES "")
        set(CMAKE_REQUIRED_DEFINITIONS "")
        set(CMAKE_REQUIRED_QUIET TRUE)
        cmake_push_check_state(RESET)
        foreach(_h IN LISTS _headers)
            check_include_file("${_h}" "FFMPEG_HAVE_${_name}_hdr_${_h}")
            if(NOT FFMPEG_HAVE_${_name}_hdr_${_h})
                set(_type_ok FALSE)
            endif()
        endforeach()
        cmake_pop_check_state()

        set(_src "")
        foreach(_h IN LISTS _headers)
            string(APPEND _src "#include <${_h}>\n")
        endforeach()
        string(APPEND _src "int main(void) { ${_type} v; (void)v; return 0; }\n")
        check_c_source_compiles("${_src}" "FFMPEG_CHECK_TYPE_${_name}")
        if(FFMPEG_CHECK_TYPE_${_name})
            ffmpeg_set_feature("${_name}" yes)
        else()
            ffmpeg_set_feature("${_name}" no)
        endif()
    endforeach()

    # --- compiler / platform features -----------------------------------
    check_c_source_compiles("
        int main(void) {
            __asm__ volatile(\"\" ::: \"memory\");
            return 0;
        }" FFMPEG_CHECK_INLINE_ASM)
    if(FFMPEG_CHECK_INLINE_ASM)
        ffmpeg_set_feature("inline_asm" yes)
    else()
        ffmpeg_set_feature("inline_asm" no)
    endif()

    check_c_source_compiles("
        #include <stdatomic.h>
        int main(void) {
            _Atomic int x = 0;
            atomic_fetch_add(&x, 1);
            return atomic_load(&x) - 1;
        }" FFMPEG_CHECK_ATOMICS_NATIVE)
    if(FFMPEG_CHECK_ATOMICS_NATIVE)
        ffmpeg_set_feature("atomics_native" yes)
    else()
        ffmpeg_set_feature("atomics_native" no)
    endif()

    check_c_source_compiles("
        int main(void) {
            int x = 0;
            __sync_fetch_and_add(&x, 1);
            return __sync_val_compare_and_swap(&x, 1, 2) - 2;
        }" FFMPEG_CHECK_ATOMICS_GCC)
    if(FFMPEG_CHECK_ATOMICS_GCC)
        ffmpeg_set_feature("atomics_gcc" yes)
    else()
        ffmpeg_set_feature("atomics_gcc" no)
    endif()

    check_c_source_compiles("
        int main(void) { return __builtin_clz(1) + __builtin_ctz(1); }"
        FFMPEG_CHECK_BUILTIN_CLZ)
    if(FFMPEG_CHECK_BUILTIN_CLZ)
        ffmpeg_set_feature("builtin_clz" yes)
        ffmpeg_set_feature("builtin_ctz" yes)
        ffmpeg_set_feature("fast_clz" yes)
    else()
        ffmpeg_set_feature("builtin_clz" no)
        ffmpeg_set_feature("builtin_ctz" no)
    endif()

    check_c_source_compiles("
        int main(void) {
            int r;
            __builtin_add_overflow(1, 2, &r);
            return r;
        }" FFMPEG_CHECK_BUILTIN_OVERFLOW)
    if(FFMPEG_CHECK_BUILTIN_OVERFLOW)
        ffmpeg_set_feature("builtin_add_overflow" yes)
        ffmpeg_set_feature("builtin_mul_overflow" yes)
    else()
        ffmpeg_set_feature("builtin_add_overflow" no)
        ffmpeg_set_feature("builtin_mul_overflow" no)
    endif()

    check_c_source_compiles("
        #include <math.h>
        int main(void) { double x = NAN; return x == x; }"
        FFMPEG_CHECK_CONST_NAN)
    if(FFMPEG_CHECK_CONST_NAN)
        ffmpeg_set_feature("const_nan" yes)
    else()
        ffmpeg_set_feature("const_nan" no)
    endif()

    if(COMMAND ffmpeg_detect_version_features)
        ffmpeg_detect_version_features()
    endif()

    # SIMD / inline assembly / nasm capabilities.
    ffmpeg_detect_x86_capabilities()

    # Explicit defaults from the version module.
    foreach(_entry IN LISTS FFMPEG_DEFAULT_FEATURES)
        string(REPLACE "=" ";" _p "${_entry}")
        list(GET _p 0 _name)
        list(GET _p 1 _value)
        ffmpeg_set_feature("${_name}" "${_value}")
    endforeach()

endfunction()

# ---------------------------------------------------------------------------
# Optional external libraries via pkg-config.
# ---------------------------------------------------------------------------
function(ffmpeg_detect_external_libraries)
    find_package(PkgConfig QUIET)

    # On Android, host pkg-config would happily return /usr/lib libraries built
    # for the build machine.  Only honour an explicit FFMPEG_ENABLE_<NAME>=ON
    # there; AUTO stays conservative and uses the NDK sysroot via CMake's
    # find_package(ZLIB/Threads/...) instead.
    set(_auto_names sdl2 vdpau libxcb libxcb_shm libxcb_shape libxcb_xfixes)
    if(ANDROID)
        set(_auto_names "")
    endif()

    foreach(_spec IN LISTS FFMPEG_EXTERNAL_PKGS)
        string(REPLACE "|" ";" _p "${_spec}")
        list(GET _p 0 _name)
        list(GET _p 1 _pkg)

        ffmpeg_option_name("${_name}" _opt)
        set(_want "${${_opt}}")

        set(_found FALSE)
        set(_query_pc TRUE)
        if(_want STREQUAL "OFF")
            set(_query_pc FALSE)
        elseif(ANDROID AND NOT _want STREQUAL "ON")
            set(_query_pc FALSE)
        endif()

        if(PkgConfig_FOUND AND _query_pc)
            string(TOUPPER "${_name}" _upper)
            pkg_check_modules("PC_${_upper}" QUIET IMPORTED_TARGET "${_pkg}")
            if(PC_${_upper}_FOUND)
                set(_found TRUE)
                set_property(GLOBAL APPEND PROPERTY FFMPEG_EXTERNAL_PKG_NAMES "${_name}")
                set_property(GLOBAL PROPERTY "FFMPEG_EXTLIB_${_name}_LIBRARIES" "${PC_${_upper}_LIBRARIES}")
                set_property(GLOBAL PROPERTY "FFMPEG_EXTLIB_${_name}_LIBRARY_DIRS" "${PC_${_upper}_LIBRARY_DIRS}")
                set_property(GLOBAL PROPERTY "FFMPEG_EXTLIB_${_name}_INCLUDE_DIRS" "${PC_${_upper}_INCLUDE_DIRS}")
                set_property(GLOBAL PROPERTY "FFMPEG_EXTLIB_${_name}_LDFLAGS" "${PC_${_upper}_LDFLAGS}")
            endif()
        endif()

        if(_want STREQUAL "OFF")
            ffmpeg_state_set("${_name}" no)
        elseif(_want STREQUAL "ON")
            if(_found)
                ffmpeg_state_set("${_name}" yes)
            else()
                ffmpeg_warn("${_name} requested but not found, disabling it")
                ffmpeg_state_set("${_name}" no)
            endif()
        else()
            # AUTO: only a conservative set is enabled automatically until the
            # per-library plumbing (headers, shaders, link flags) is verified.
            list(FIND _auto_names "${_name}" _auto_idx)
            if(_found AND NOT _auto_idx EQUAL -1)
                ffmpeg_state_set("${_name}" yes)
            else()
                ffmpeg_state_set("${_name}" no)
            endif()
        endif()
        ffmpeg_add_resolve_name("${_name}")
    endforeach()

    # Features used by configure's *_suggest lists must be decided here so
    # that a suggestion never enables something that is not available.
    ffmpeg_set_feature("cuda_nvcc" no)
    ffmpeg_set_feature("cuda_llvm" no)
    ffmpeg_set_feature("stdatomic" no)
    ffmpeg_state_get("atomics_native" _atomic_native)
    if(_atomic_native STREQUAL "yes")
        ffmpeg_state_set("stdatomic" yes)
    endif()
    ffmpeg_set_feature("int128" yes)

    ffmpeg_state_get("vdpau" _vdpau)
    if(_vdpau STREQUAL "yes")
        find_package(X11 QUIET)
        if(X11_FOUND)
            ffmpeg_set_feature("vdpau_x11" yes)
            set_property(GLOBAL PROPERTY FFMPEG_EXTRA_SYSTEM_LIBS "${X11_LIBRARIES}")
            set_property(GLOBAL PROPERTY FFMPEG_EXTRA_INCLUDE_DIRS "${X11_INCLUDE_DIR}")
        else()
            ffmpeg_set_feature("vdpau_x11" no)
            ffmpeg_state_set("vdpau" no)
        endif()
    endif()

    # zlib is special-cased by FFmpeg's configure.
    find_package(ZLIB QUIET)
    if(ZLIB_FOUND)
        ffmpeg_state_set("zlib" yes)
        ffmpeg_set_feature("zlib_gzip" yes)
    else()
        ffmpeg_state_set("zlib" no)
        ffmpeg_set_feature("zlib_gzip" no)
    endif()
    ffmpeg_add_resolve_name("zlib")
endfunction()
