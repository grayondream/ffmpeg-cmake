# progress

## 2026-11-05

### 完成

1. 工程骨架
   - `CMakeLists.txt`:独立构建 / `add_subdirectory` 双模式。
   - `cmake/` 通用引擎:版本、元数据、组件、选项、探测、依赖解析、
     生成、库目标、程序目标、工具函数。
   - `cmake/versions/9.1/`:版本元数据与特性探测。

2. 配置模型
   - 只读解析上游 `configure`:HAVE_LIST / CONFIG_LIST / CONFIG_EXTRA /
     `_deps` `_select` `_deps_any` `_suggest` `_conflict` `_if`。
   - 组件从上游 `extern const` 声明自动发现。
   - 状态机 `yes/no/unset` + 不动点迭代,支持 select 传播、依赖校验、
     conflict 后置校验,避免顺序导致的误禁用。
   - 支持 `FFMPEG_DISABLE_EVERYTHING`、逐组件
     `FFMPEG_ENABLE_<NAME>=AUTO/ON/OFF`、`FFMPEG_CONFIGURE_FLAGS`。

3. 编译系统
   - 解析 `OBJS` / `STLIBOBJS` / `SHLIBOBJS` / `X86ASM-OBJS`,
     条件表达式、GNU make `$(if ...)`、嵌套 Makefile 与 `$(ARCH)`。
   - 生成 `config.h`、`config_components.h`、`avconfig.h`、
     `ffversion.h`、`*_list.c`、`config.asm`(按需)。
   - 静态库目标 `FFmpeg::avutil` 等;ffmpeg/ffprobe 可执行文件。
   - 安装规则、SDL2 自动探测、VDPAU/X11、v4l2-m2m 探测。

4. 验证
   - 干净构建通过:`ffmpeg`、`ffprobe` 生成并可运行。
   - 与同机 `./configure` 参考结果对比:
     `config_components.h` 1851 个启用组件完全一致(0 缺失 / 0 多余);
     `config.h` 421 个 HAVE_ 名称完全一致,46 个值保守为 0(SSE/AVX/
     inline asm/部分工具探测)。
   - 版本号、`ffmpeg -h full` 正常。
   - 共享库构建通过(`libavcodec.so.63.22.100` 等,SONAME 正确)。
   - `add_subdirectory` 父工程测试通过(链接 `FFmpeg::avutil`/`avcodec`)。
   - `cmake --install` 测试通过(7 个静态库、144 个头文件、2 个程序)。
   - 最小配置测试通过:
     `-DFFMPEG_DISABLE_EVERYTHING=ON -DFFMPEG_ENABLE_H264_DECODER=ON
      -DFFMPEG_ENABLE_MOV_DEMUXER=ON -DFFMPEG_ENABLE_FFMPEG=ON`
     生成 3.8 MB 的 ffmpeg,AAC 等未启用组件保持 0。

### 已知限制

- SIMD intrinsics / nasm 汇编未启用,使用可移植 C 路径。
- 外部库默认只自动启用 SDL2;其余需 `-DFFMPEG_ENABLE_<NAME>=ON`。
- Windows/macOS 探测代码存在但未在真机验证;`COMPAT_OBJS` 未接入。
- 共享库符号版本脚本尚未实现。

### 文件

- `README.md` — 使用说明、目录结构、兼容性
- `docs/superpowers/specs/2026-11-05-ffmpeg-cmake-design.md` — 设计文档
- `todo.md` — 任务清单

## 2026-11-05(第二轮)

### 完成

1. nasm / x86 汇编自动接入
   - `FFMPEG_ENABLE_X86ASM` 保持默认 ON;探测 nasm 并实际汇编
     `movbe` 片段,失败则安全回退到 C。
   - 文件作用域 `enable_language(ASM_NASM)`,设置 `CMAKE_ASM_NASM_*`;
     为每个 `.asm` 源设置语言和 `config.asm` 依赖。
   - 生成 `config.asm`(ARCH/HAVE/CONFIG)和 `config_components.asm`,
     并为 libswscale 生成 `uops_macros.gen.asm`。
   - 带 x86 汇编的全量构建通过,`ffmpeg`/`ffprobe` 可运行。

2. SIMD intrinsics 自动探测
   - x86 基线扩展(MMX/SSE/AVX/AVX-512/AES/CLMUL/FMA/XOP 等)按
     configure 语义启用;`_INLINE` 跟随内联汇编探测,`_EXTERNAL` 跟随
     nasm 及指令支持探测。
   - `intrinsics_sse2` 通过实际编译探测;补齐 `x86_7regs`、
     `xmm_clobbers`、`zlib_gzip`、`xmllint`、`rsync_contimeout`。
   - 新增 `--enable/disable-avx512` 映射;`-fPIC`/`-DPIC` 与 configure
     对齐,修复 x86 汇编 + PIE 链接失败。

3. 警告修复
   - `ffmpeg_expand_make_value` 实现 `$(VAR)`、`${VAR}`、
     `$(VAR:%=...)` 展开;未定义变量按 GNU make 语义展开为空,
     `COMPAT_OBJS` / `EMMS_OBJS_*` 两条警告消失。

### 验证

- 与启用 nasm 的官方 configure 对比:`HAVE_*` 421 个名称一致,
  仅 `HAVE_RV_ZICBOP`(RISC-V 专用)不同;组件配置 0 差异。
- `-DFFMPEG_ENABLE_X86ASM=OFF` 构建通过,对比 `--disable-x86asm`
  同样只剩 `HAVE_RV_ZICBOP` 一处差异。
- 全新构建目录配置无 CMake Warning,静态库 + 程序链接成功。
- 共享库 + x86 汇编构建通过:`libavcodec.so.63.22.100` 等生成,
  `ffmpeg`/`ffprobe` 可运行;ELF 共享库按 configure 加 `-Wl,-Bsymbolic`。
- `--disable-avx512` 选项映射验证通过(`HAVE_AVX512=0`)。
