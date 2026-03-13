import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
 namespace = "com.example.givelocally_app"
 compileSdk = flutter.compileSdkVersion
 ndkVersion = flutter.ndkVersion

 compileOptions {
 sourceCompatibility = JavaVersion.VERSION_17
 targetCompatibility = JavaVersion.VERSION_17
 isCoreLibraryDesugaringEnabled = true
 }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.givelocally.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
 source = "../.."
}

dependencies {
 implementation(platform("com.google.firebase:firebase-bom:33.10.0"))
 implementation("com.google.firebase:firebase-appcheck")
 implementation("com.google.firebase:firebase-appcheck-playintegrity")
 implementation("com.google.firebase:firebase-appcheck-debug")
 implementation("com.google.firebase:firebase-auth")
 implementation("com.google.android.gms:play-services-auth:20.7.0")
 implementation("com.google.android.gms:play-services-base:18.3.0")
 
 // Required for flutter_local_notifications
 coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
