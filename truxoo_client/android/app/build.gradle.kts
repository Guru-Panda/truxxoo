import java.util.Properties
import java.io.FileInputStream

// 1. MOVED TO TOP: Load the properties file safely before doing anything else
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") 
}

android {
    namespace = "com.unloadweb.unload"
    
    // 🔥 UPGRADE 1: Bumped to 36 to fix those yellow Flutter plugin warnings
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            // Looks for upload-keystore.jks inside the android/app/ folder
            storeFile = keystoreProperties.getProperty("storeFile")?.let { project.file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // 🔥 UPGRADE 2: Strict Kotlin casting for JVM target (matches Captain app)
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.unloadweb.unload"
        minSdk = flutter.minSdkVersion  
        targetSdk = 36 // 🔥 UPGRADE 3: Matched with compileSdk
        
        // Keeping flutter dynamic versions here so you don't have to change them manually!
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            
            isMinifyEnabled = false
            isShrinkResources = false
            
            // 🔥 UPGRADE 4: Added Proguard rules configuration (matches Captain app)
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    // --- YOUR CRITICAL FIX (UNTOUCHED) ---
    // Keeps your AndroidX versions stable
    configurations.all {
        resolutionStrategy {
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
    "coreLibraryDesugaring"("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("androidx.multidex:multidex:2.0.1")
    
    // 🔥 UPGRADE 5: Added Firebase BOM for version stability (matches Captain app)
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    
    implementation("androidx.browser:browser:1.8.0")
    implementation("androidx.activity:activity-ktx:1.9.3")
    implementation("androidx.core:core-ktx:1.15.0")
}