plugins {
    `kotlin-dsl`
}

group = "com.civdevops.petcam.buildlogic"

dependencies {
    implementation(libs.android.gradlePlugin)
    implementation(libs.kotlin.gradlePlugin)
}
