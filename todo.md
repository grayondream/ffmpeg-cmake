# todo

## 背景

仓库 `FFMpeg-Cmake` 只有一个未修改的 FFmpeg 9.1 子模块(`third_party/ffmpeg`),
目标是用纯 CMake 编译 FFmpeg,配置项对齐 `./configure`,并保证不对 FFmpeg
源码做任何修改。需要模块化,方便后续兼容其他 FFmpeg 版本。

## 目标

- [x] 纯 CMake 构建,不调用 `./configure`
- [x] 不修改 `third_party/ffmpeg`(生成物全部放在构建目录)
- [x] 组件开关对齐 configure 语义(`--disable-everything`、`--enable-x`)
- [x] 从上游 Makefile 读取对象列表,避免硬编码源文件
- [x] 依赖解析(deps / deps_any / select / suggest / conflict)
- [x] 生成 config.h / config_components.h / avconfig.h / ffversion.h / *_list.c
- [x] 静态库 + ffmpeg/ffprobe 可执行文件
- [x] 版本模块化(`cmake/versions/9.1/`)
- [x] 独立构建 + `add_subdirectory` + `FFmpeg::<lib>` 别名
- [x] 安装规则(库 / 头文件 / 程序)
- [x] 与参考 configure 的组件配置对齐验证(1851 项,0 差异)
- [x] SIMD 探测(SSE/AVX/AVX-512/AES/CLMUL 等)并与参考 configure 对比验证
- [x] nasm 自动探测、ASM_NASM 接入、config.asm/config_components.asm 生成
- [x] 消除 `COMPAT_OBJS` / `EMMS_OBJS` 的 make 变量警告

## 待办 / 后续

- [ ] Windows `compat/` 对象与平台验证
- [ ] 外部库(SDL2 之外)默认自动探测与链接
- [ ] 共享库符号版本脚本(libav*.ver)
- [ ] RISC-V / ARM 扩展指令探测
- [ ] 更多版本模块(9.x 之外的 FFmpeg)
