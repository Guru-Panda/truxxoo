plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // ADD THIS LINE: This is required for your Firebase integration to work
    id("com.google.gms.google-services") 
}

android {
    namespace = "com.example.truxoo_client_new"
    
    // 1. KEEP THIS AT 35. Do not go to 36 (it is unstable).
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

       defaultConfig {
        applicationId = "com.example.truxoo_client_new"
        minSdk = 23  
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // -----------------------------------------------------------------------
    // THE CRITICAL FIX
    // This block tells Gradle: "I don't care what version the plugins want.
    // Use THESE specific stable versions that work with my Android Studio."
    // -----------------------------------------------------------------------
    configurations.all {
        resolutionStrategy {
            // Fixes the "Requires Android Gradle plugin 8.9.1" errors
            force("androidx.core:core:1.15.0")
            force("androidx.core:core-ktx:1.15.0")
            force("androidx.activity:activity:1.9.3")
            force("androidx.activity:activity-ktx:1.9.3")
            force("androidx.browser:browser:1.8.0")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("androidx.multidex:multidex:2.0.1")
    
    // We also add them here explicitly to be double sure
    implementation("androidx.browser:browser:1.8.0")
    implementation("androidx.activity:activity-ktx:1.9.3")
    implementation("androidx.core:core-ktx:1.15.0")
}