import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.zameel.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.zameel.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
        if (System.getenv("CI") == "true" && System.getenv("CM_KEYSTORE_PATH") != null) {
            create("codemagicRelease") {
                storeFile = file(System.getenv("CM_KEYSTORE_PATH"))
                storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("CM_KEY_ALIAS")
                keyPassword = System.getenv("CM_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        getByName("release") {
            when {
                System.getenv("CI") == "true" && System.getenv("CM_KEYSTORE_PATH") != null -> {
                    signingConfig = signingConfigs.getByName("codemagicRelease")
                }
                keystorePropertiesFile.exists() -> {
                    signingConfig = signingConfigs.getByName("release")
                }
                else -> {
                    // Local release builds fall back to the debug certificate so
                    // development remains possible; Codemagic uses a real upload key.
                    signingConfig = signingConfigs.getByName("debug")
                }
            }
            // Keep release builds compatible with the current AGP/R8 toolchain.
            // R8/ProGuard can be re-enabled after a dedicated rules audit.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
