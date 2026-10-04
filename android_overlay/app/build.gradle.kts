plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.drangelzuniga.angel_medical_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    packaging {
        // JVM OSGi metadata is duplicated across BC jars and is unused by Android.
        resources.excludes.add("META-INF/versions/**/OSGI-INF/MANIFEST.MF")
        // Preserve library licenses/notices while combining duplicate paths.
        resources.merges.add("META-INF/LICENSE*")
        resources.merges.add("META-INF/NOTICE*")
    }

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
            proguardFiles("proguard-rules.pro")
            signingConfig = if (System.getenv("ANGEL_KEYSTORE_PATH") != null)
                signingConfigs.getByName("angelRelease") else signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation("org.bouncycastle:bcprov-jdk18on:1.86")
    implementation("org.bouncycastle:bcpkix-jdk18on:1.86")
    testImplementation("junit:junit:4.13.2")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
