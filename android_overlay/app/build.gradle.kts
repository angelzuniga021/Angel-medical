plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.drangelzuniga.angel_medical_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = System.getenv("ANGEL_APPLICATION_ID") ?: "com.drangelzuniga.angel_medical_mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (System.getenv("ANGEL_KEYSTORE_PATH") != null) {
            create("angelRelease") {
                storeFile = file(System.getenv("ANGEL_KEYSTORE_PATH"))
                storePassword = System.getenv("ANGEL_STORE_PASSWORD")
                keyAlias = System.getenv("ANGEL_KEY_ALIAS")
                keyPassword = System.getenv("ANGEL_KEY_PASSWORD")
            }
        }
    }
    buildTypes {
        release {
            signingConfig = if (System.getenv("ANGEL_KEYSTORE_PATH") != null)
                signingConfigs.getByName("angelRelease") else signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
