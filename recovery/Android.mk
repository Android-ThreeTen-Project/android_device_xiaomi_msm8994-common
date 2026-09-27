LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_C_INCLUDES := \
    bootable/deprecated-ota/edify/include \
    bootable/recovery/otautil/include \
    bootable/deprecated-ota/updater/include
LOCAL_SRC_FILES := recovery_updater.cpp
LOCAL_MODULE := librecovery_updater_msm8994
include $(BUILD_STATIC_LIBRARY)
