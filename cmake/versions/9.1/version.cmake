# =============================================================================
# FFmpeg 9.1 specific metadata.
#
# Keep this file declarative: it describes *where* the information lives in
# the upstream tree and *what* the ABI structs are called.  All behaviour
# lives in the generic engine under cmake/.
# =============================================================================

# ---------------------------------------------------------------------------
# Architectures known to ./configure and their ARCH_* macros.
# ---------------------------------------------------------------------------
set(FFMPEG_ARCH_LIST
    aarch64 arm ia64 loongarch loongarch32 loongarch64 m68k mips mips64
    parisc ppc ppc64 riscv s390 sparc sparc64 tilegx tilepro wasm x86
    x86_32 x86_64)

# processor (lowercase) | arch directory | arch state names separated by ,
set(FFMPEG_ARCH_MAP
    "x86_64|x86|x86,x86_64"
    "amd64|x86|x86,x86_64"
    "i386|x86|x86,x86_32"
    "i486|x86|x86,x86_32"
    "i586|x86|x86,x86_32"
    "i686|x86|x86,x86_32"
    "aarch64|aarch64|aarch64"
    "arm64|aarch64|aarch64"
    "arm|arm|arm"
    "armv7l|arm|arm"
    "armv6l|arm|arm"
    "ppc64le|ppc|ppc,ppc64"
    "ppc64|ppc|ppc,ppc64"
    "ppc|ppc|ppc"
    "mips64|mips|mips,mips64"
    "mips|mips|mips"
    "riscv64|riscv|riscv"
    "riscv|riscv|riscv"
    "loongarch64|loongarch|loongarch,loongarch64"
    "s390x|s390|s390"
    "sparc64|sparc|sparc,sparc64")

# ---------------------------------------------------------------------------
# Component discovery.
#
# kind | file | extern regex | name template | symbol template
#
# {1}, {2} are regex capture groups.  The resulting "name" is the identifier
# used by ./configure (and therefore by *_deps / *_select metadata).
# ---------------------------------------------------------------------------
set(FFMPEG_COMPONENT_SPECS
    "decoder|libavcodec/allcodecs.c|^extern const FFCodec ff_([A-Za-z0-9_]+)_decoder|{1}_decoder|ff_{1}_decoder"
    "encoder|libavcodec/allcodecs.c|^extern const FFCodec ff_([A-Za-z0-9_]+)_encoder|{1}_encoder|ff_{1}_encoder"
    "parser|libavcodec/parsers.c|^extern const FFCodecParser ff_([A-Za-z0-9_]+)_parser|{1}_parser|ff_{1}_parser"
    "bsf|libavcodec/bitstream_filters.c|^extern const FFBitStreamFilter ff_([A-Za-z0-9_]+)_bsf|{1}_bsf|ff_{1}_bsf"
    "hwaccel|libavcodec/hwaccels.h|^extern const .*FFHWAccel ff_([A-Za-z0-9_]+)_hwaccel|{1}_hwaccel|ff_{1}_hwaccel"
    "demuxer|libavformat/allformats.c|^extern const FFInputFormat +ff_([A-Za-z0-9_]+)_demuxer|{1}_demuxer|ff_{1}_demuxer"
    "muxer|libavformat/allformats.c|^extern const FFOutputFormat +ff_([A-Za-z0-9_]+)_muxer|{1}_muxer|ff_{1}_muxer"
    "protocol|libavformat/protocols.c|^extern const URLProtocol +ff_([A-Za-z0-9_]+)_protocol|{1}_protocol|ff_{1}_protocol"
    "filter|libavfilter/allfilters.c|^extern const FFFilter ff_([avfsinkrc][avfsinkrc][avfsinkrc]?[avfsinkrc]?[avfsinkrc]?)_([A-Za-z0-9_]+)|{2}_filter|ff_{1}_{2}"
    "indev|libavdevice/alldevices.c|^extern const FFInputFormat +ff_([A-Za-z0-9_]+)_demuxer|{1}_indev|ff_{1}_demuxer"
    "outdev|libavdevice/alldevices.c|^extern const FFOutputFormat +ff_([A-Za-z0-9_]+)_muxer|{1}_outdev|ff_{1}_muxer")

# ---------------------------------------------------------------------------
# Generated registration arrays.
#
# key | output file | element type | array name | kinds (comma separated)
# ---------------------------------------------------------------------------
set(FFMPEG_LIST_SPECS
    "codecs|libavcodec/codec_list.c|FFCodec|codec_list|encoder,decoder"
    "parsers|libavcodec/parser_list.c|FFCodecParser|parser_list|parser"
    "bsfs|libavcodec/bsf_list.c|FFBitStreamFilter|bitstream_filters|bsf"
    "demuxers|libavformat/demuxer_list.c|FFInputFormat|demuxer_list|demuxer"
    "muxers|libavformat/muxer_list.c|FFOutputFormat|muxer_list|muxer"
    "protocols|libavformat/protocol_list.c|URLProtocol|url_protocols|protocol"
    "filters|libavfilter/filter_list.c|FFFilter|filter_list|filter"
    "indevs|libavdevice/indev_list.c|FFInputFormat|indev_list|indev"
    "outdevs|libavdevice/outdev_list.c|FFOutputFormat|outdev_list|outdev")

# Components that are always registered in addition to the configured ones.
set(FFMPEG_LIST_EXTRA_filters "ff_asrc_abuffer;ff_vsrc_buffer;ff_asink_abuffer;ff_vsink_buffer")
set(FFMPEG_LIST_EXTRA_bsfs    "ff_source_bsf;ff_sink_bsf")

# ---------------------------------------------------------------------------
# Libraries, in link order (dependants first).
# ---------------------------------------------------------------------------
set(FFMPEG_LIBRARY_LIST avdevice avcodec avfilter avformat avutil swresample swscale)

# Link time dependencies (dependant -> dependencies), taken from a
# configure run of this release.  Used for the CMake INTERFACE link order.
set(FFMPEG_LINK_DEPS_avdevice  avfilter swscale avformat avcodec swresample avutil)
set(FFMPEG_LINK_DEPS_avfilter  swscale avformat avcodec swresample avutil)
set(FFMPEG_LINK_DEPS_avformat  avcodec swresample avutil)
set(FFMPEG_LINK_DEPS_avcodec   swresample avutil)
set(FFMPEG_LINK_DEPS_swscale   avutil)
set(FFMPEG_LINK_DEPS_swresample avutil)
set(FFMPEG_LINK_DEPS_avutil    "")

# ---------------------------------------------------------------------------
# Programs.
# ---------------------------------------------------------------------------
set(FFMPEG_PROGRAM_LIST ffmpeg ffplay ffprobe)

# ---------------------------------------------------------------------------
# pkg-config names for optional external libraries.
# ffmpeg-name|pkg-config-name
# ---------------------------------------------------------------------------
set(FFMPEG_EXTERNAL_PKGS
    "libx264|x264"
    "libx265|x265"
    "libx262|x262"
    "libvpx|vpx"
    "libvorbis|vorbis"
    "libtheora|theora"
    "libopus|opus"
    "libdav1d|dav1d"
    "libaom|aom"
    "libsvtav1|SvtAv1Enc"
    "librav1e|rav1e"
    "libdavs2|davs2"
    "libxavs2|xavs2"
    "libmp3lame|lame"
    "libshine|shine"
    "libfdk_aac|fdk-aac"
    "libtwolame|twolame"
    "libwebp|libwebp"
    "libzimg|zimg"
    "libspeex|speex"
    "libopencore_amrnb|opencore-amrnb"
    "libopencore_amrwb|opencore-amrwb"
    "libgsm|gsm"
    "libilbc|ilbc"
    "libbs2b|libbs2b"
    "libcaca|caca"
    "libcdio|cdio"
    "libcdio_paranoia|cdio_paranoia"
    "libchromaprint|libchromaprint"
    "libdrm|libdrm"
    "libjack|jack"
    "libmodplug|libmodplug"
    "libopenal|openal"
    "libopengl|gl"
    "libopenh264|openh264"
    "libopenmpt|libopenmpt"
    "libpulse|libpulse"
    "librabbitmq|librabbitmq"
    "librubberband|rubberband"
    "libsmbclient|smbclient"
    "libsnappy|snappy"
    "libsoxr|soxr"
    "libssh|libssh"
    "libtesseract|tesseract"
    "libvidstab|vidstab"
    "libvo_amrwbenc|vo-amrwbenc"
    "libvpl|vpl"
    "libxml2|libxml-2.0"
    "libzvbi|zvbi"
    "libzimg|zimg"
    "libcodec2|libcodec2"
    "sdl2|sdl2"
    "ffnvcodec|ffnvcodec"
    "libxcb|xcb"
    "libxcb_shm|xcb-shm"
    "libxcb_shape|xcb-shape"
    "libxcb_xfixes|xcb-xfixes"
    "gnutls|gnutls"
    "openssl|openssl"
    "gcrypt|gcrypt"
    "libjxl|libjxl"
    "libjxl_threads|libjxl_threads"
    "libplacebo|libplacebo"
    "libqrencode|libqrencode"
    "libvvenc|vvenc"
    "libxevd|xevd"
    "libxeve|xeve"
    "liblcevc_dec|lcevc_dec"
    "vulkan|vulkan"
    "vaapi|libva"
    "vdpau|vdpau"
    "libmfx|libmfx"
    "amf|amf"
    "opencl|OpenCL"
    "shaderc|shaderc")
