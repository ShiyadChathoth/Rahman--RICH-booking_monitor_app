// Import necessary classes at the top
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // Apply the Google Services plugin
    id("com.google.gms.google-services")
}

// Read local properties for Flutter SDK path
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { stream ->
        localProperties.load(stream)
    }
}

val flutterRoot: String = localProperties.getProperty("flutter.sdk") ?: throw RuntimeException("Flutter SDK not found. Define location in local.properties")
val flutterVersionCode: String = localProperties.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName: String = localProperties.getProperty("flutter.versionName") ?: "1.0"


android {
    namespace = "com.example.booking_monitor_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        // Set Java 11 compatibility
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        // Set JVM target for Kotlin
        jvmTarget = "11"
    }

    signingConfigs {
         getByName("debug") {
            keyAlias = "androiddebugkey"
            keyPassword = "android"
            storeFile = file("${System.getProperty("user.home")}/.android/debug.keystore")
            storePassword = "android"
        }
    }

    defaultConfig {
        applicationId = "com.example.booking_monitor_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
         debug {
             signingConfig = signingConfigs.getByName("debug")
         }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // --- Firebase BoM and Dependencies ---
    implementation(platform("com.google.firebase:firebase-bom:33.1.1")) // Check for latest BoM version
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-messaging")
    // --- End Firebase ---

    // Core library desugaring dependency
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}