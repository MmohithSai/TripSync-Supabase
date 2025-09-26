plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services") // <-- Google Services plugin for Firebase
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.innovision.tripsync"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Set your unique Application ID to match Firebase
        applicationId = "com.innovision.tripsync"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signing with debug keys for now
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Firebase BoM ensures all Firebase libraries are compatible
    implementation(platform("com.google.firebase:firebase-bom:34.3.0"))

    // Firebase SDKs you want
    implementation("com.google.firebase:firebase-auth")       // Authentication
    implementation("com.google.firebase:firebase-firestore")  // Cloud Firestore
    implementation("com.google.firebase:firebase-analytics")  // Optional analytics
}
