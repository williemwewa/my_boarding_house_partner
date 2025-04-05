plugins {
    id("com.android.application")
    id("kotlin-android") 
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Apply the Google services plugin (this avoids potential Kotlin compilation issues)
apply(plugin = "com.google.gms.google-services")

android {
    namespace = "com.example.my_boarding_house_partner"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
    
    defaultConfig {
        applicationId = "com.example.my_boarding_house_partner"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }
    
    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Force compatible versions
configurations.all {
    resolutionStrategy.force("com.google.firebase:firebase-auth:22.1.2")
    
    // Exclude any transitive dependencies that might bring in the problematic version
    exclude(group = "com.google.firebase", module = "firebase-auth-api")
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.multidex:multidex:2.0.1")
    
    // Firebase dependencies without using BOM
    implementation("com.google.firebase:firebase-auth:22.1.2")  // Explicitly downgraded
    implementation("com.google.firebase:firebase-firestore:24.7.0")  // Specify compatible version
    implementation("com.google.android.gms:play-services-safetynet:18.0.1")
    
    // Google Maps dependencies
    implementation("com.google.android.gms:play-services-maps:18.2.0")
    implementation("com.google.android.gms:play-services-location:21.0.1")
}