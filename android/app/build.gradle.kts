plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "dev.rustdemo.gamedemo"
    compileSdk = 36

    defaultConfig {
        applicationId = "dev.rustdemo.gamedemo"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        ndk { abiFilters += listOf("arm64-v8a") }
    }
    buildFeatures { compose = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }
}

// Cargo is incremental, so this is cheap when the Rust code did not change.
val buildRust by tasks.registering(Exec::class) {
    val release = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
    workingDir(rootDir.parentFile)
    commandLine("./build-android.sh", if (release) "release" else "dev")
}
tasks.matching { it.name == "preBuild" }.configureEach { dependsOn(buildRust) }

dependencies {
    implementation(platform("androidx.compose:compose-bom:2026.02.01"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.activity:activity-compose:1.12.4")
    // UniFFI-generated Kotlin talks to the Rust .so through JNA.
    implementation("net.java.dev.jna:jna:5.14.0@aar")
}
