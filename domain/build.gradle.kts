plugins {
    id("petcam.kotlin.jvm")
}

dependencies {
    implementation(project(":core:model"))

    testImplementation(libs.junit)
}