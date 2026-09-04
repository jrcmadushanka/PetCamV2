package com.civdevops.petcam.core.model.camera

enum class RecordingFailure {
    CAMERA_UNAVAILABLE,
    START_FAILED,
    FINALIZATION_FAILED,
    STORAGE_UNAVAILABLE,
    UNKNOWN,
}