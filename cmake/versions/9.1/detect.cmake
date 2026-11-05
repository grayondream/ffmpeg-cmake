# =============================================================================
# FFmpeg 9.1 feature probes.
#
# Lists consumed by cmake/FFmpegDetect.cmake.  Names are the bare identifiers
# used by FFmpeg (HAVE_<UPPER(name)>).
# =============================================================================

# name | header
set(FFMPEG_CHECK_HEADERS
    "unistd_h|unistd.h"
    "fcntl_h|fcntl.h"
    "errno_h|errno.h"
    "malloc_h|malloc.h"
    "memory_h|memory.h"
    "math_h|math.h"
    "signal_h|signal.h"
    "stdatomic_h|stdatomic.h"
    "stdbit_h|stdbit.h"
    "stdint_h|stdint.h"
    "stdlib_h|stdlib.h"
    "string_h|string.h"
    "strings_h|strings.h"
    "dirent_h|dirent.h"
    "dlfcn_h|dlfcn.h"
    "pthread_h|pthread.h"
    "semaphore_h|semaphore.h"
    "sched_h|sched.h"
    "iconv_h|iconv.h"
    "elf_h|elf.h"
    "endian_h|endian.h"
    "byteswap_h|byteswap.h"
    "sys_mman_h|sys/mman.h"
    "sys_time_h|sys/time.h"
    "sys_ioctl_h|sys/ioctl.h"
    "sys_select_h|sys/select.h"
    "sys_stat_h|sys/stat.h"
    "sys_types_h|sys/types.h"
    "sys_sysctl_h|sys/sysctl.h"
    "sys_soundcard_h|sys/soundcard.h"
    "sys_un_h|sys/un.h"
    "sys_wait_h|sys/wait.h"
    "sys_resource_h|sys/resource.h"
    "sys_hwprobe_h|sys/hwprobe.h"
    "sys_auxv_h|sys/auxv.h"
    "sys_videoio_h|sys/videoio.h"
    "sys_socket_h|sys/socket.h"
    "sys_poll_h|sys/poll.h"
    "poll_h|poll.h"
    "netdb_h|netdb.h"
    "netinet_in_h|netinet/in.h"
    "netinet_tcp_h|netinet/tcp.h"
    "arpa_inet_h|arpa/inet.h"
    "ifaddrs_h|ifaddrs.h"
    "net_if_h|net/if.h"
    "netinet_sctp_h|netinet/sctp.h"
    "glob_h|glob.h"
    "setjmp_h|setjmp.h"
    "sys_prctl_h|sys/prctl.h"
    "sys_random_h|sys/random.h"
    "asm_types_h|asm/types.h"
    "sys_param_h|sys/param.h"
    "termios_h|termios.h"
    "valgrind_memcheck_h|valgrind/memcheck.h"
    "valgrind_valgrind_h|valgrind/valgrind.h"
    "sys_auxv_h|sys/auxv.h"
    "soundcard_h|soundcard.h"
    "linux_perf_event_h|linux/perf_event.h"
    "linux_dma_buf_h|linux/dma-buf.h"
    "linux_videodev2_h|linux/videodev2.h"
    "linux_v4l2_common_h|linux/v4l2-common.h"
    "linux_fb_h|linux/fb.h"
    "linux_userfaultfd_h|linux/userfaultfd.h"
    "mach_mach_time_h|mach/mach_time.h"
    "mach_mach_h|mach/mach.h"
    "mach_vm_h|mach/vm.h"
    "mach_vm_region_h|mach/vm_region.h"
    "mach_o_dyld_h|mach-o/dyld.h"
    "mach_thread_act_h|mach/thread_act.h"
    "windows_h|windows.h"
    "io_h|io.h"
    "d3d11_h|d3d11.h"
    "d3d12_h|d3d12.h"
    "dxgi_h|dxgi.h"
    "dxgi1_6_h|dxgi1_6.h"
    "dxva2_h|dxva2.h"
    "d3d9_h|d3d9.h"
    "shlobj_h|shlobj.h"
    "ws2tcpip_h|ws2tcpip.h"
    "mstcpip_h|mstcpip.h"
    "iptypes_h|iptypes.h"
    "iphlpapi_h|iphlpapi.h"
    "bcrypt_h|bcrypt.h"
    "direct_h|direct.h"
    "va_va_h|va/va.h"
    "va_va_dec_h|va/va_dec_hevc.h"
    "va_va_enc_h|va/va_enc_h264.h"
    "vaapi_va_h|va/va.h"
    "vdpau_vdpau_h|vdpau/vdpau.h"
    "vulkan_vulkan_h|vulkan/vulkan.h"
    "libdrm_drm_h|libdrm/drm.h"
    "libdrm_drm_mode_h|libdrm/drm_mode.h"
    "libdrm_drm_fourcc_h|libdrm/drm_fourcc.h"
    "opencl_cl_h|CL/cl.h"
    "AMF_core_Factory_h|AMF/core/Factory.h"
    "AMF_core_Surface_h|AMF/core/Surface.h"
    "AMF_components_VideoDecoder_h|AMF/components/VideoDecoder.h"
    "AMF_components_VideoEncoder_h|AMF/components/VideoEncoder.h"
    "AMF_components_VideoConverter_h|AMF/components/VideoConverter.h"
    "emscripten_emscripten_h|emscripten/emscripten.h"
    "emscripten_html5_h|emscripten/html5.h"
    "emscripten_keyboard_h|emscripten/keyboard.h")

# name | function | comma separated headers
set(FFMPEG_CHECK_FUNCS
    "mmap|mmap|sys/mman.h,sys/types.h"
    "munmap|munmap|sys/mman.h"
    "mprotect|mprotect|sys/mman.h"
    "dlopen|dlopen|dlfcn.h"
    "dlsym|dlsym|dlfcn.h"
    "dlclose|dlclose|dlfcn.h"
    "clock_gettime|clock_gettime|time.h"
    "gettimeofday|gettimeofday|sys/time.h"
    "localtime_r|localtime_r|time.h"
    "gmtime_r|gmtime_r|time.h"
    "lstat|lstat|sys/stat.h"
    "access|access|unistd.h"
    "mkstemp|mkstemp|stdlib.h"
    "mkdir|mkdir|sys/stat.h"
    "isatty|isatty|unistd.h"
    "ioctl|ioctl|sys/ioctl.h"
    "fcntl|fcntl|fcntl.h"
    "getauxval|getauxval|sys/auxv.h"
    "elf_aux_info|elf_aux_info|sys/auxv.h"
    "pthread_setname_np|pthread_setname_np|pthread.h"
    "pthread_getname_np|pthread_getname_np|pthread.h"
    "pthread_setaffinity_np|pthread_setaffinity_np|pthread.h"
    "pthread_getaffinity_np|pthread_getaffinity_np|pthread.h"
    "sched_getaffinity|sched_getaffinity|sched.h"
    "setenv|setenv|stdlib.h"
    "unsetenv|unsetenv|stdlib.h"
    "posix_memalign|posix_memalign|stdlib.h"
    "memalign|memalign|stdlib.h,malloc.h"
    "aligned_alloc|aligned_alloc|stdlib.h"
    "strtod|strtod|stdlib.h"
    "strtol|strtol|stdlib.h"
    "strerror_r|strerror_r|string.h"
    "getrlimit|getrlimit|sys/resource.h"
    "setrlimit|setrlimit|sys/resource.h"
    "sysconf|sysconf|unistd.h"
    "getenv|getenv|stdlib.h"
    "getpagesize|getpagesize|unistd.h"
    "getpid|getpid|unistd.h"
    "usleep|usleep|unistd.h"
    "nanosleep|nanosleep|time.h"
    "fstat|fstat|sys/stat.h"
    "lseek|lseek|unistd.h"
    "open|open|fcntl.h"
    "close|close|unistd.h"
    "read|read|unistd.h"
    "write|write|unistd.h"
    "mach_absolute_time|mach_absolute_time|mach/mach_time.h"
    "sysctl|sysctl|sys/sysctl.h"
    "getifaddrs|getifaddrs|ifaddrs.h"
    "inet_aton|inet_aton|arpa/inet.h"
    "inet_pton|inet_pton|arpa/inet.h"
    "getaddrinfo|getaddrinfo|netdb.h"
    "sched_getaffinity|sched_getaffinity|sched.h"
    "sem_timedwait|sem_timedwait|semaphore.h"
    "getopt|getopt|unistd.h"
    "getopt_long|getopt_long|getopt.h"
    "getrusage|getrusage|sys/resource.h"
    "glob|glob|glob.h"
    "realpath|realpath|stdlib.h"
    "sigaction|sigaction|signal.h"
    "siglongjmp|siglongjmp|setjmp.h"
    "prctl|prctl|sys/prctl.h"
    "tempnam|tempnam|stdio.h")

# name | library | function
set(FFMPEG_CHECK_LIBS
    "libm|m|pow"
    "libdl|dl|dlopen"
    "libpthread|pthread|pthread_create"
    "librt|rt|clock_gettime"
    "libsocket|socket|socket"
    "libz|z|inflate")

# name | type | comma separated headers
set(FFMPEG_CHECK_TYPES
    "socklen_t|socklen_t|sys/socket.h,sys/types.h"
    "struct_addrinfo|struct addrinfo|netdb.h"
    "struct_pollfd|struct pollfd|poll.h"
    "struct_sockaddr_in6|struct sockaddr_in6|netinet/in.h,sys/socket.h"
    "struct_sockaddr_storage|struct sockaddr_storage|sys/socket.h"
    "struct_sockaddr_un|struct sockaddr_un|sys/un.h,sys/socket.h"
    "struct_rusage_ru_maxrss|struct rusage|sys/resource.h"
    "struct_stat_st_mtim_tv_nsec|struct stat|sys/stat.h"
    "struct_group_source_req|struct group_source_req|netinet/in.h"
    "struct_ipv6_mreq|struct ipv6_mreq|netinet/in.h"
    "struct_ip_mreq_source|struct ip_mreq_source|netinet/in.h"
    "struct_msghdr_msg_flags|struct msghdr|sys/socket.h"
    "struct_v4l2_frmivalenum_discrete|struct v4l2_frmivalenum|linux/videodev2.h"
    "vdppictureinfohevc|VdpPictureInfoHEVC|vdpau/vdpau.h"
    "vdppictureinfovp9|VdpPictureInfoVP9|vdpau/vdpau.h"
    "vdppictureinfoav1|VdpPictureInfoAV1|vdpau/vdpau.h")

# Checks that need literal source snippets rather than a header/function list.
function(ffmpeg_detect_version_features)
    ffmpeg_state_get("linux_videodev2_h" _v4l2_hdr)
    ffmpeg_state_get("sem_timedwait" _sem_timedwait)
    if(_v4l2_hdr STREQUAL "yes" AND _sem_timedwait STREQUAL "yes")
        check_c_source_compiles("
            #include <linux/videodev2.h>
            int main(void) {
                int i = V4L2_CAP_VIDEO_M2M_MPLANE | V4L2_CAP_VIDEO_M2M | V4L2_BUF_FLAG_LAST;
                return i;
            }" FFMPEG_CHECK_V4L2_M2M)
        if(FFMPEG_CHECK_V4L2_M2M)
            ffmpeg_set_feature("v4l2_m2m" yes)
            foreach(_pair
                    "h263_v4l2_m2m|V4L2_PIX_FMT_H263"
                    "h264_v4l2_m2m|V4L2_CID_STATELESS_H264_SPS"
                    "hevc_v4l2_m2m|V4L2_CID_STATELESS_HEVC_SPS"
                    "mpeg1_v4l2_m2m|V4L2_PIX_FMT_MPEG1"
                    "mpeg2_v4l2_m2m|V4L2_PIX_FMT_MPEG2"
                    "mpeg4_v4l2_m2m|V4L2_PIX_FMT_MPEG4"
                    "vc1_v4l2_m2m|V4L2_PIX_FMT_VC1_ANNEX_G"
                    "vp8_v4l2_m2m|V4L2_PIX_FMT_VP8_FRAME"
                    "vp9_v4l2_m2m|V4L2_CID_STATELESS_VP9_FRAME")
                string(REPLACE "|" ";" _p "${_pair}")
                list(GET _p 0 _name)
                list(GET _p 1 _const)
                string(TOUPPER "${_name}" _upper)
                check_c_source_compiles("
                    #include <linux/videodev2.h>
                    int main(void) { int i = ${_const}; return i; }"
                    "FFMPEG_CHECK_${_upper}")
                if(FFMPEG_CHECK_${_upper})
                    ffmpeg_set_feature("${_name}" yes)
                else()
                    ffmpeg_set_feature("${_name}" no)
                endif()
            endforeach()
        else()
            ffmpeg_set_feature("v4l2_m2m" no)
        endif()
    else()
        ffmpeg_set_feature("v4l2_m2m" no)
    endif()
endfunction()

# Explicit defaults that are not probed (name=yes/no).
set(FFMPEG_DEFAULT_FEATURES
    "network=yes"
    "hardcoded_tables=no"
    "ossfuzz=no"
    "ftrapv=no"
    "gprof=no"
    "memory_poisoning=no"
    "msan=no"
    "asan=no"
    "ubsan=no"
    "valgrind_backtrace=no")
