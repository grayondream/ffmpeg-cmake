# FFmpeg-Cmake design

Date: 2026-11-05
Status: implemented for FFmpeg 9.1

## Intent

Provide a CMake build for FFmpeg that:

1. leaves the FFmpeg checkout untouched (no generated files, no patches);
2. does not shell out to `./configure`;
3. exposes configure-like configuration switches;
4. can build standalone or be consumed with `add_subdirectory`;
5. keeps version-specific knowledge in small, replaceable modules.

## Non-goals

* Re-implementing FFmpeg's `configure` checks byte-for-byte. The build must be
  functionally aligned, but feature probes may be conservative.
* Supporting MSVC (upstream FFmpeg does not support it either).
* Building FFmpeg's test suite.

## Architecture

```
            +-------------------------------+
            | upstream configure (read)     |
            |  HAVE_LIST, CONFIG_LIST,      |
            |  CONFIG_EXTRA, *_deps/select  |
            +---------------+---------------+
                            |
+---------------+   +-------v--------+   +------------------+
| upstream      |   | dependency     |   | generated        |
| Makefiles +   |-->| resolver       |-->| config.h etc.    |
| extern lists  |   | (CMake)        |   | *_list.c         |
+-------+-------+   +-------+--------+   +---------+--------+
        |                   ^                      |
        | object lists      | detection            |
        v                   |                      v
+-------+-------------------+----------------------+--------+
| CMake targets: libavutil ... libavdevice, ffmpeg/ffprobe |
+----------------------------------------------------------+
```

### Reading, not running

The engine parses the upstream `configure` text to obtain:

* `HAVE_LIST` (every `HAVE_*` macro that must exist, including zeros),
* `CONFIG_LIST` / `CONFIG_EXTRA` (non-component `CONFIG_*` macros),
* `ALL_COMPONENTS` (used as a sanity source; the registry is built from the
  `extern const` declarations instead),
* `<name>_deps`, `_deps_any`, `_select`, `_suggest`, `_conflict`, `_if`,
  `_if_any` dependency metadata,
* explicit `enable foo` / `disable foo` defaults.

Reading the script is deliberate: it keeps the version adapters small and
makes the dependency graph version-accurate without hardcoding thousands of
entries.

### Component registry

Components are discovered from the declarations upstream already ships:

* `libavcodec/allcodecs.c` (encoders/decoders),
* `libavcodec/parsers.c`, `bitstream_filters.c`, `hwaccels.h`,
* `libavformat/allformats.c`, `protocols.c`,
* `libavfilter/allfilters.c`,
* `libavdevice/alldevices.c`.

Each component gets a configure-style name (`h264_decoder`, `aac_parser`,
`mov_demuxer`, `scale_filter`, ...), a C symbol and a `CONFIG_*` macro.

### Object lists

Library object lists are evaluated from the upstream Makefiles:

* `OBJS`, `OBJS-$(CONFIG_...)`,
* `STLIBOBJS-$(...)` for static builds,
* `SHLIBOBJS-$(...)` for shared builds,
* `X86ASM-OBJS-$(...)` when nasm is enabled,
* nested `include $(SRC_PATH)/.../Makefile` files (aac, hevc, opus, vvc,
  vulkan, bsf) and `$(ARCH)/...` Makefiles,
* GNU make `$(if ...)` expressions,
* condition expressions such as `$(CONFIG_X)`, `$(!CONFIG_X)`,
  `$(HAVE_Y)`, `$(ARCH_Z)`.

No source file names are hardcoded in the engine.

### Dependency resolution

`FFmpegResolve.cmake` implements the same model as configure's `check_deps`:

* every `HAVE_*` feature is decided before resolution (default `no`),
* components default to `yes` unless `--disable-everything`,
* the fixpoint propagates `select`/`suggest`, then validates
  `deps`/`deps_any`/`select`, then evaluates `conflict`,
* explicit user choices (`ON`/`OFF`) are never overridden.

State values are `yes`, `no` and `unset`. `unset` means "only enable if
selected"; this prevents the oscillation that a plain yes/no fixpoint would
produce.

### Generation

Generated into `${FFMPEG_GEN_DIR}/include`:

* `config.h`: `ARCH_*`, all configure `HAVE_*`, non-component `CONFIG_*`,
* `config_components.h`: component `CONFIG_*`,
* `libavutil/avconfig.h`, `libavutil/ffversion.h`,
* `libavcodec/{codec,parser,bsf}_list.c`,
  `libavformat/{demuxer,muxer,protocol}_list.c`,
  `libavfilter/filter_list.c`,
  `libavdevice/{indev,outdev}_list.c`,
* `config.asm` and `config_components.asm` when x86 assembly is enabled,
* `libswscale/x86/uops_macros.gen.asm` (produced by running the C
  preprocessor over the upstream header, like the upstream Makefile does).

The FFmpeg source tree is never written to.

### SIMD and x86 assembly

The nasm path is probed, not assumed:

* nasm is looked up and a real snippet is assembled; if that fails the build
  falls back to C instead of failing later,
* `ASM_NASM` is enabled at file scope and configured with the source and
  generated include paths, `config.asm`, and per-x86-directory include paths,
* every `.asm` object depends on the generated `config*.asm` files,
* `HAVE_*_EXTERNAL` is set only for instruction sets the installed nasm can
  actually assemble (AVX-512ICL and friends are probed separately),
* `HAVE_*_INLINE` follows the compiler's inline-assembly probe,
* base extensions are enabled for x86 and chosen at runtime through CPUID,
  matching configure's `enable $ARCH_EXT_LIST` behaviour.

C sources are compiled with `-fPIC`/`-DPIC` (as configure does on ELF
targets), which is required by some inline-assembly paths and by shared
builds. ELF shared libraries are linked with `-Wl,-Bsymbolic`, matching
configure, so inline assembly may reference global constants directly.

### Version modules

`cmake/versions/9.1/version.cmake` contains declarative metadata; `detect.cmake`
contains release-specific probes. The loader tries `<major>.<minor>`, then
`<major>.x`, then `<major>`. Adding support for a new release is a data task,
not an engine change.

## Validation

* `config_components.h` matches upstream `./configure` exactly for the
  default configuration on Linux/x86-64 (1851 enabled entries), with nasm
  enabled and with `--disable-x86asm`.
* `config.h` has exactly the same 421 `HAVE_*` names as configure. With
  nasm enabled only `HAVE_RV_ZICBOP` differs (RISC-V-only, configure leaves
  it enabled on x86); with x86 assembly disabled it is the same single
  difference.
* The nasm-enabled build compiles all x86 assembly, links, and runs.
* `ffmpeg -version` and `ffmpeg -h full` work.

## Decisions and rationale

* **Read configure instead of running it** — keeps the build hermetic and
  cross-compilable while inheriting version-accurate dependency metadata.
* **Parse Makefiles instead of duplicating file lists** — files move between
  releases; parsing keeps the engine correct.
* **Conservative probe defaults** — an undefined/zero `HAVE_*` selects the
  portable path; a wrong `1` breaks the build. Missing optimizations are
  visible and fixable, wrong feature claims are not.
* **Tristate component options** — mirrors configure's "weak enable" model and
  avoids hardcoding component defaults.

## Future work

1. Wire up `compat/` objects for Windows and test MSVC-adjacent toolchains.
2. Enable external libraries beyond SDL2 by default when pkg-config finds
   them, and add their link flags to the owning library.
3. Shared-library symbol versioning (`libav*.ver`) for ABI parity.
4. Probe RISC-V/ARM extension flags instead of only x86.
