// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import groovy.json.JsonSlurper

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val config = JsonSlurper().parseText(rootProject.projectDir.parentFile.resolve("config.json").readText()) as Map<*, *>

android {
    namespace = "xyz.journai.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    signingConfigs {
        val keystorePath = config["KEYSTORE_PATH"] as String

        if (keystorePath.isNotEmpty()) {
            create("release") {
                storeFile = file(keystorePath)
                storePassword = config["KEYSTORE_PASSWORD"] as String
                keyAlias = config["KEY_ALIAS"] as String
                keyPassword = config["KEY_PASSWORD"] as String
            }
        }
    }

    defaultConfig {
        applicationId = "xyz.journai.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

flutter {
    source = "../.."
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
