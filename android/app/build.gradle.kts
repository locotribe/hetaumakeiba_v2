plugins {
    id("com.android.application")
    // START: FlutterFire Configuration

    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.hetaumakeiba_v2"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"  // 明示的に設定

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID
        applicationId = "com.example.hetaumakeiba_v2"
        // You can update the following values to match your application needs.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // --- APKファイル名の自動設定 ---
    applicationVariants.all {
        val variant = this
        variant.outputs.all {
            val output = this as com.android.build.gradle.internal.api.ApkVariantOutputImpl
            val projectName = "hetaumakeiba_v2" // プロジェクト名
            val version = variant.versionName    // pubspec.yamlのバージョン名

            output.outputFileName = "${projectName}-v${version}.apk"
        }
    }
}

flutter {
    source = "../.."
}