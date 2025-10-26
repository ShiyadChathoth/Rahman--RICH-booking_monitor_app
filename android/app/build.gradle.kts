// Import necessary classes at the top
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // Apply the Google Services plugin (ensure version is defined in project-level build.gradle.kts)
    id("com.google.gms.google-services")
}

// Read local properties for Flutter SDK path
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    // Correct way to read the properties file
    localPropertiesFile.inputStream().use { stream ->
        localProperties.load(stream)
    }
}

val flutterRoot: String = localProperties.getProperty("flutter.sdk") ?: throw RuntimeException("Flutter SDK not found. Define location in local.properties")
val flutterVersionCode: String = localProperties.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName: String = localProperties.getProperty("flutter.versionName") ?: "1.0"


android {
    namespace = "com.example.booking_monitor_app" // Matches manifest
    // Ensure compileSdk matches Flutter's requirements (often fetched via flutter object)
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

    // Signing Configurations block should be directly inside 'android'
    signingConfigs {
        // Define debug signing config
         getByName("debug") { // Use getByName("debug") for the default one
            keyAlias = "androiddebugkey"
            keyPassword = "android"
            storeFile = file("${System.getProperty("user.home")}/.android/debug.keystore")
            storePassword = "android"
        }
        // You would add release signing configs here for production builds
        // create("release") { ... }
    }

    defaultConfig {
        applicationId = "com.example.booking_monitor_app"
        // Use minSdk from Flutter config or set explicitly (e.g., 21)
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
        multiDexEnabled = true // Keep multidex enabled
    }

    buildTypes {
        release {
            // Point release builds to use the debug signing config unless you create a specific 'release' config above
            signingConfig = signingConfigs.getByName("debug")
            // Add other release settings like ProGuard/R8 if needed
            // isMinifyEnabled = true
            // proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
         debug {
             // Debug builds usually use the default debug signing config automatically
             signingConfig = signingConfigs.getByName("debug")
         }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Import the Firebase BoM (Bill of Materials) - Use the latest compatible version
    implementation(platform("com.google.firebase:firebase-bom:33.1.1")) // Check for latest

    // Add dependencies for Firebase products you want to use
    // Analytics is often recommended
    implementation("com.google.firebase:firebase-analytics")
    // Cloud Messaging dependency
    implementation("com.google.firebase:firebase-messaging")
    // Add other Firebase dependencies here WITHOUT version numbers (BoM manages them)

    // Core library desugaring dependency
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4") // Keep this version or check for updates if needed

}