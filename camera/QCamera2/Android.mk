ifneq (,$(filter $(TARGET_ARCH), arm arm64))

LOCAL_PATH:= $(call my-dir)

include $(CLEAR_VARS)

LOCAL_SRC_FILES := \
        util/QCameraCmdThread.cpp \
        util/QCameraFlash.cpp \
        util/QCameraQueue.cpp \
        QCamera2Hal.cpp \
        QCamera2Factory.cpp

#HAL 3.0 source
LOCAL_SRC_FILES += \
        HAL3/QCamera3HWI.cpp \
        HAL3/QCamera3Mem.cpp \
        HAL3/QCamera3Stream.cpp \
        HAL3/QCamera3Channel.cpp \
        HAL3/QCamera3VendorTags.cpp \
        HAL3/QCamera3PostProc.cpp \
        HAL3/QCamera3CropRegionMapper.cpp

#HAL 1.0 source
LOCAL_SRC_FILES += \
        HAL/QCamera2HWI.cpp \
        HAL/QCameraMem.cpp \
        HAL/QCameraStateMachine.cpp \
        HAL/QCameraChannel.cpp \
        HAL/QCameraStream.cpp \
        HAL/QCameraPostProc.cpp \
        HAL/QCamera2HWICallbacks.cpp \
        HAL/QCameraParameters.cpp \
        HAL/QCameraThermalAdapter.cpp

LOCAL_CFLAGS := -Wall -Wextra -Werror
# Newer Clang diagnoses legacy QCamera2 bookkeeping assignments as unused.
LOCAL_CFLAGS += -Wno-error=unused-but-set-variable
LOCAL_CFLAGS += -DHAS_MULTIMEDIA_HINTS
# Legacy QCamera2 uses String8::string() and String8::isEmpty().
LOCAL_CFLAGS += -DENABLE_STRING8_OBSOLETE_METHODS

# Android 12 removed the Qualcomm-only camera1 command and face-metadata ABI
# from system/camera.h.  Use the HAL's standard camera1 path instead of writing
# the removed extended camera_face_t fields past the framework structure.
LOCAL_CFLAGS += -DVANILLA_HAL

#use media extension
ifeq ($(TARGET_USES_MEDIA_EXTENSIONS), true)
LOCAL_CFLAGS += -DUSE_MEDIA_EXTENSIONS
endif

#HAL 1.0 Flags
LOCAL_CFLAGS += -DDEFAULT_DENOISE_MODE_ON -DHAL3

LOCAL_C_INCLUDES := \
        $(LOCAL_PATH)/stack/common \
        frameworks/native/include/media/hardware \
        frameworks/native/include/media/openmax \
        hardware/qcom-caf/msm8994/media/libstagefrighthw \
        system/media/camera/include \
        $(LOCAL_PATH)/../mm-image-codec/qexif \
        $(LOCAL_PATH)/../mm-image-codec/qomx_core \
        $(LOCAL_PATH)/util \
        frameworks/native/libs/nativewindow/include \

#HAL 1.0 Include paths
LOCAL_C_INCLUDES += \
        frameworks/native/include/media/hardware \
        $(LOCAL_PATH)/HAL

LOCAL_HEADER_LIBRARIES := display_headers generated_kernel_headers media_plugin_headers

#LOCAL_STATIC_LIBRARIES := libqcamera2_util
LOCAL_C_INCLUDES += \
        $(TARGET_OUT_HEADERS)/qcom/display

# Only the metadata and camera1 parameter classes are needed from the framework.
# Compile them into the vendor HAL to avoid a dependency on libcamera_client.
LOCAL_SRC_FILES += \
        ../../../../../frameworks/av/camera/CameraMetadata.cpp \
        ../../../../../frameworks/av/camera/CameraParameters.cpp \
        ../../../../../frameworks/av/camera/VendorTagDescriptor.cpp
LOCAL_C_INCLUDES += frameworks/av/camera/include system/media/private/camera/include

LOCAL_SHARED_LIBRARIES := libbinder liblog libhardware libutils libcutils libdl
LOCAL_SHARED_LIBRARIES += libmmcamera_interface libmmjpeg_interface libui libcamera_metadata
LOCAL_SHARED_LIBRARIES += libqdMetaData libnativewindow

LOCAL_MODULE_RELATIVE_PATH := hw
LOCAL_MODULE := camera.$(TARGET_BOARD_PLATFORM)
LOCAL_MODULE_TAGS := optional
LOCAL_VENDOR_MODULE := true

LOCAL_32_BIT_ONLY := $(BOARD_QTI_CAMERA_32BIT_ONLY)
include $(BUILD_SHARED_LIBRARY)

endif
