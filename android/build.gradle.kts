group = "com.sparkleo.flutter_blue_background.flutter_blue_background"
version = "1.0-SNAPSHOT"

// NOTE: This plugin intentionally does NOT pin the Android Gradle Plugin or
// Kotlin Gradle Plugin versions via a `buildscript { classpath(...) }` block.
// Instead it applies them through the `plugins {}` block with no version, so
// the *consuming app* supplies the version from its own settings.gradle
// pluginManagement. This lets the same plugin build inside both older Flutter
// apps (AGP 8.x / Gradle 8.x) and the latest (AGP 9.x), instead of forcing a
// single modern toolchain on every consumer.
plugins {
    id("com.android.library")
}

android {
    namespace = "com.sparkleo.flutter_blue_background.flutter_blue_background"

    // Conservative compileSdk: high enough for modern apps, low enough that
    // older apps with older Android SDKs can still build the plugin.
    compileSdk = 34

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            kotlin.directories.add("src/main/kotlin")
        }
        getByName("test") {
            kotlin.directories.add("src/test/kotlin")
        }
    }

    defaultConfig {
        // 21 is the practical floor for BLE on Android and keeps the plugin
        // usable by a wide range of host apps.
        minSdk = 21
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}
