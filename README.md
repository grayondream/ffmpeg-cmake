# FFmpeg-Cmake

A CMake-native build system for FFmpeg that does **not** modify the FFmpeg
source tree and does **not** invoke FFmpeg's `./configure` script.

The repository itself is a thin project around the unmodified upstream
`third_party/ffmpeg` submodule (currently FFmpeg **9.1**).

## Why

FFmpeg's own build is driven by a shell `configure` script that is hard to
use from CMake-based projects and from IDEs. This project re-implements the
configuration model in CMake:

* component configuration follows `./configure` names and semantics
  (`--disable-everything`, `--enable-h264_decoder`, ...);
* the generated `config.h`, `config_components.h`, `avconfig.h`,
  `ffversion.h` and the `*_list.c` registration tables are produced by CMake;
* object lists are read from the upstream `Makefile`s, so new/removed files
  are picked up automatically;
* compilation, archiving and linking are native CMake targets.

Version-specific differences (struct names, component locations, feature
probes) are isolated in `cmake/versions/<major>.<minor>/`. Supporting a new
FFmpeg release means adding a version directory, not touching the engine.

## Requirements

* CMake >= 3.20
* A C17 compiler (GCC or Clang; FFmpeg does not support MSVC)
* GNU Make is **not** required
* `nasm` is optional and detected automatically (x86 assembly)
* `pkg-config` is optional (external libraries)

## Quick start

```sh
git submodule update --init --recursive

cmake -S . -B build -G Ninja
cmake --build build -j
./build/ffmpeg -version
```

Static libraries and the `ffmpeg`/`ffprobe`/`ffplay` programs (when their
dependencies are available) are produced in the build directory.

If `nasm` is found, x86 assembly is enabled automatically (and probed with a
real assembly snippet). Force the portable C path with
`-DFFMPEG_ENABLE_X86ASM=OFF`.

### Static / shared / both

`FFMPEG_LIBRARY_TYPE` selects the library flavour:

```sh
# default on desktop: static archives
cmake -S . -B build -G Ninja -DFFMPEG_LIBRARY_TYPE=STATIC

# shared libraries only
cmake -S . -B build-shared -G Ninja -DFFMPEG_LIBRARY_TYPE=SHARED

# both libavcodec.a and libavcodec.so
cmake -S . -B build-both -G Ninja -DFFMPEG_LIBRARY_TYPE=BOTH
```

`AUTO` (the default) keeps the legacy switches authoritative. The legacy
switches still work and are the low-level knobs behind `AUTO`:

```sh
cmake -S . -B build-shared -G Ninja \
  -DFFMPEG_ENABLE_SHARED=ON -DFFMPEG_ENABLE_STATIC=OFF
```

On Android the defaults are `SHARED` (via `AUTO`) and programs disabled,
because that is what an APK normally consumes.

Install with `cmake --install build --prefix /usr/local` (libraries, public
headers and programs).

### As a sub-project

```cmake
add_subdirectory(FFMpeg-Cmake)

add_executable(myapp main.c)
target_link_libraries(myapp PRIVATE
    FFmpeg::avformat
    FFmpeg::avcodec
    FFmpeg::avutil)
```

## Android

Android builds use the NDK's own CMake toolchain through a small wrapper.
The NDK root is taken from `NAK_HOME` first, then `NDK_HOME`,
`ANDROID_NDK_ROOT`, `ANDROID_NDK_HOME`, or an explicit
`-DFFMPEG_ANDROID_NDK=/path/to/ndk`.

```sh
cmake -S . -B build-android -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$PWD/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-24 \
  -DFFMPEG_LIBRARY_TYPE=SHARED

cmake --build build-android -j
```

Or use the checked-in presets:

```sh
cmake --preset android-arm64-shared
cmake --build build-android-arm64-shared -j
```

The Android build adds:

* `arm64-v8a` (ARMv8-A/AArch64) by default, with API 24;
* AArch64 `.S` assembly (`ARMV8-OBJS`, `NEON-OBJS`) and the generated
  `libswscale/aarch64/ops_neon.gen.S`;
* plain `libavcodec.so` names (no version suffix/symlink chain), matching
  FFmpeg's own `target_os=android` rule;
* JNI + MediaCodec + Camera2 detection from the NDK sysroot
  (`FFMPEG_ENABLE_JNI`, `FFMPEG_ENABLE_MEDIACODEC`);
* PIE executables and `CONFIG_PIC=1` for AArch64 `movrel`;
* no host pkg-config leakage: automatic external-library discovery is
  disabled on Android; an explicit `-DFFMPEG_ENABLE_<NAME>=ON` still uses
  pkg-config if you provide an Android `.pc` path.

`ffplay` on Android still needs an SDL2 built for Android; it is skipped if
SDL2 is not found.

## Configuration

The CMake options intentionally mirror `./configure`:

| CMake option | configure equivalent |
|---|---|
| `-DFFMPEG_DISABLE_EVERYTHING=ON` | `--disable-everything` |
| `-DFFMPEG_ENABLE_H264_DECODER=ON` | `--enable-h264_decoder` |
| `-DFFMPEG_ENABLE_LIBX264=ON` | `--enable-libx264` |
| `-DFFMPEG_ENABLE_GPL=ON` | `--enable-gpl` |
| `-DFFMPEG_LIBRARY_TYPE=STATIC/SHARED/BOTH` | `--disable-shared` / `--enable-shared` |
| `-DFFMPEG_ENABLE_SHARED=ON` | `--enable-shared` (legacy, used by `AUTO`) |
| `-DFFMPEG_ENABLE_STATIC=OFF` | `--disable-static` (legacy, used by `AUTO`) |
| `-DFFMPEG_ENABLE_PROGRAMS=OFF` | `--disable-programs` |
| `-DFFMPEG_ENABLE_X86ASM=ON/OFF` | `--enable/disable-x86asm` |
| `-DFFMPEG_ENABLE_AVX512=ON/OFF` | `--enable/disable-avx512` |

Every component gets an `FFMPEG_ENABLE_<NAME>` switch with three states:
`AUTO` (default), `ON`, `OFF`.

Raw configure-style flags are also accepted and mapped onto these options:

```sh
cmake -S . -B build \
  -DFFMPEG_CONFIGURE_FLAGS="--disable-everything;--enable-h264_decoder;--enable-ffmpeg"
```

A minimal build:

```sh
cmake -S . -B build-min \
  -DFFMPEG_DISABLE_EVERYTHING=ON \
  -DFFMPEG_ENABLE_H264_DECODER=ON \
  -DFFMPEG_ENABLE_MOV_DEMUXER=ON \
  -DFFMPEG_ENABLE_FFMPEG=ON
cmake --build build-min -j
```

## Layout

```
CMakeLists.txt                  entry point (standalone or add_subdirectory)
cmake/
  FFmpegVersion.cmake           version detection + module loading
  FFmpegMetadata.cmake          reads HAVE_LIST/CONFIG_LIST from configure
  FFmpegComponents.cmake        component registry from upstream externs
  FFmpegOptions.cmake           configure-style option surface
  FFmpegDetect.cmake            platform / feature / library detection
  FFmpegResolve.cmake           dependency resolution (deps/select/conflict)
  FFmpegGenerate.cmake          config headers + registration arrays
  FFmpegTargets.cmake           library targets from Makefile object lists
  FFmpegPrograms.cmake          ffmpeg/ffprobe/ffplay targets
  FFmpegAndroid.cmake           NDK-specific features + system libraries
  FFmpegUtils.cmake             state, Makefile parsing, condition evaluation
  android.toolchain.cmake       NDK lookup wrapper (NAK_HOME/NDK_HOME/...)
  versions/9.1/                 FFmpeg 9.1 metadata and probes
third_party/ffmpeg/             unmodified upstream submodule
CMakePresets.json               linux-* / android-arm64-* presets
docs/                           design notes
```

### Adding another FFmpeg version

1. Copy `cmake/versions/9.1` to `cmake/versions/<major>.<minor>`.
2. Adjust:
   * `FFMPEG_COMPONENT_SPECS` (where the `extern const` declarations live and
     how the ABI structs are called),
   * `FFMPEG_LIST_SPECS` (generated registration arrays),
   * `FFMPEG_LIBRARY_LIST`, link order,
   * `detect.cmake` probes.
3. Configure; the engine reads everything else (object lists, dependency
   metadata, `HAVE_*`/`CONFIG_*` names) from the upstream tree.

The loader falls back from `9.2` to `9.x` to `9` if an exact module does not
exist, so patch releases usually need no new directory.

## Verification

On Linux/x86-64 with the same compiler, `config_components.h` produced by
this project matches the one produced by upstream `./configure` exactly
(1851 enabled components, 0 missing, 0 extra) for both of these reference
builds:

* default configuration (`nasm` enabled),
* `--disable-x86asm`.

`config.h` contains exactly the same 421 `HAVE_*` names as configure. With
nasm available the only value difference is `HAVE_RV_ZICBOP` (a RISC-V-only
feature that configure leaves enabled on x86 as a quirk); with
`-DFFMPEG_ENABLE_X86ASM=OFF` it is the same single difference.

SIMD support is selected the same way configure does it:

* base extensions (`SSE`, `SSE2`, `AVX2`, `AESNI`, ...) are enabled when the
  target is x86; runtime CPUID dispatch selects the actual implementation,
* `*_INLINE` is enabled when the compiler supports inline assembly,
* `*_EXTERNAL` is enabled only when nasm is present and can assemble the
  instruction set in question,
* AVX-512 can be switched off with `-DFFMPEG_ENABLE_AVX512=OFF`;
* on AArch64, `ARMV8-OBJS`/`NEON-OBJS` are compiled and runtime CPU feature
  dispatch is used.

Android validation performed with NDK r30 (30.0.16248370), `arm64-v8a`,
API 24:

* shared build: `libavcodec.so` (plain SONAME), `libavutil.so`, ... all link
  with `--no-undefined`; `libavcodec.so` is ELF64 AArch64 with
  `SONAME=libavcodec.so`;
* static build: `libavcodec.a`, ... produced with PIC;
* `ffmpeg`/`ffprobe` are PIE executables with an Android linker interpreter;
* `CONFIG_JNI=1`, `CONFIG_MEDIACODEC=1`,
  `CONFIG_H264_MEDIACODEC_DECODER=1`,
  `CONFIG_ANDROID_CAMERA_INDEV=1`.

## Known limitations

* Only a conservative set of external libraries (`sdl2`, `vdpau`, `xcb*`)
  is auto-detected on desktop. Other external libraries must be requested
  explicitly with `-DFFMPEG_ENABLE_<NAME>=ON` (their pkg-config package is
  then used). Android disables automatic pkg-config lookup to avoid linking
  host libraries.
* Windows/macOS detection exists but those platforms are untested.
* Windows `compat/` objects are not wired up yet; Android's
  `compat/android/binder.o` is wired up for MediaCodec.
* `ffplay` needs SDL2; it is skipped automatically when SDL2 is absent
  (including Android unless an Android SDL2 is provided).
