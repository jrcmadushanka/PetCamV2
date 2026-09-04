package com.civdevops.petcam.core.model.media

@JvmInline
value class MediaId(
    val rawValue: String,
) {
    init {
        require(rawValue.isNotBlank()) {
            "MediaId must not be blank."
        }
    }
}