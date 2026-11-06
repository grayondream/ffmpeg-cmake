# =============================================================================
# Android / NDK platform wiring.
#
# The NDK toolchain file already supplies the compiler, sysroot and ABI flags.
# This module only fills in the feature state that FFmpeg's configure script
# normally derives for target_os=android, and probes NDK-only libraries.
# =============================================================================

function(ffmpeg_android_detect)
    if(NOT ANDROID)
        return()
    endif()

    # configure's "android" target_os branch:
    #   disable symver
    #   enable section_data_rel_ro
    #   add -fPIE to CFLAGS and -fPIE -pie to executables
    ffmpeg_set_feature("android" yes)
    ffmpeg_set_feature("section_data_rel_ro" yes)
    ffmpeg_set_feature("symver" no)
    ffmpeg_set_feature("symver_gnu_asm" no)

    # bionic's ioctl() is __overloadable with both int and unsigned long
    # operation arguments, which makes FFmpeg's v4l2 function-pointer
    # wrappers fail to compile.  Android apps use Camera2/MediaCodec instead.
    # An explicit -DFFMPEG_ENABLE_V4L2_INDEV=ON / _OUTDEV=ON re-enables it.
    foreach(_component v4l2_indev v4l2_outdev fbdev_indev fbdev_outdev)
        ffmpeg_option_name("${_component}" _opt)
        if(NOT "${${_opt}}" STREQUAL "ON")
            ffmpeg_state_set("${_component}" no)
        endif()
    endforeach()
    ffmpeg_state_set("v4l2_m2m" no)

    # JNI is required by MediaCodec.  jni.h lives in the NDK sysroot.
    if(FFMPEG_ENABLE_JNI)
        set(CMAKE_REQUIRED_QUIET TRUE)
        check_include_file(jni.h FFMPEG_ANDROID_HAVE_JNI_H)
        if(FFMPEG_ANDROID_HAVE_JNI_H)
            ffmpeg_set_feature("jni" yes)
            ffmpeg_status("android: JNI support enabled")
        else()
            ffmpeg_set_feature("jni" no)
            ffmpeg_warn("android: jni.h not found; disabling JNI and MediaCodec")
            ffmpeg_state_set("mediacodec" no)
        endif()
    else()
        ffmpeg_set_feature("jni" no)
        ffmpeg_state_set("mediacodec" no)
    endif()

    # configure checks these with check_lib():
    #   mediandk   media/NdkMediaFormat.h   AMediaFormat_new   -lmediandk
    #   camera2ndk camera/NdkCameraManager.h ACameraManager_create -lcamera2ndk
    #   android    android/native_window.h  ANativeWindow_acquire -landroid
    check_library_exists(mediandk AMediaFormat_new
        "" FFMPEG_ANDROID_MEDIANDK)
    check_library_exists(camera2ndk ACameraManager_create
        "" FFMPEG_ANDROID_CAMERA2NDK)
    check_library_exists(android ANativeWindow_acquire
        "" FFMPEG_ANDROID_LIBANDROID)

    if(FFMPEG_ANDROID_MEDIANDK)
        ffmpeg_set_feature("mediandk" yes)
    else()
        ffmpeg_set_feature("mediandk" no)
    endif()
    if(FFMPEG_ANDROID_CAMERA2NDK)
        ffmpeg_set_feature("camera2ndk" yes)
    else()
        ffmpeg_set_feature("camera2ndk" no)
    endif()
    if(FFMPEG_ANDROID_LIBANDROID)
        ffmpeg_set_feature("libandroid" yes)
    else()
        ffmpeg_set_feature("libandroid" no)
    endif()

    # mediacodec is a global configure feature, not a component.  Its hwaccel
    # components (h264_mediacodec_decoder, ...) depend on this switch.
    ffmpeg_state_get("jni" _jni_state)
    if(FFMPEG_ENABLE_MEDIACODEC
       AND _jni_state STREQUAL "yes"
       AND FFMPEG_ANDROID_MEDIANDK)
        ffmpeg_set_feature("mediacodec" yes)
        # configure's add_compat android/binder.o; both libavutil/Makefile
        # and fftools/Makefile consume COMPAT_OBJS.
        set_property(GLOBAL PROPERTY FFMPEG_MAKE_COMPAT_OBJS
            "android/binder.o")
    else()
        ffmpeg_set_feature("mediacodec" no)
    endif()

    ffmpeg_status("android: ABI=${ANDROID_ABI}, platform=${ANDROID_PLATFORM}")
    ffmpeg_status("android: MediaCodec=${FFMPEG_ANDROID_MEDIANDK}, camera2ndk=${FFMPEG_ANDROID_CAMERA2NDK}")
endfunction()
