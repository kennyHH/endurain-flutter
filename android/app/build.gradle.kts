import org.gradle.api.GradleException
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeyPropertiesFile = keystorePropertiesFile.exists()
if (hasKeyPropertiesFile) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

val requiredSigningKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val hasAllSigningKeys = hasKeyPropertiesFile &&
    requiredSigningKeys.all { !keystoreProperties.getProperty(it).isNullOrBlank() }
val releaseStoreFilePath = keystoreProperties.getProperty("storeFile")
val hasReleaseKeystore = hasAllSigningKeys &&
    releaseStoreFilePath != null &&
    rootProject.file(releaseStoreFilePath).exists()

val hasReleaseSigningConfig = hasAllSigningKeys && hasReleaseKeystore
val allowDebugSigningForLocalRelease = providers
    .gradleProperty("allowDebugSigningForLocalRelease")
    .map { it.equals("true", ignoreCase = true) }
    .orElse(false)
    .get()
val isReleaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}

android {
    namespace = "com.dev.endurain"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.dev.endurain"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigningConfig) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(releaseStoreFilePath!!)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            when {
                hasReleaseSigningConfig -> {
                    signingConfig = signingConfigs.getByName("release")
                }
                // Explicit opt-in fallback for local/dev diagnostics only.
                allowDebugSigningForLocalRelease -> {
                    signingConfig = signingConfigs.getByName("debug")
                }
                // Secure default: release task without signing setup should fail fast.
                isReleaseTaskRequested -> {
                    throw GradleException(
                        "Release signing is not configured. Provide android/key.properties " +
                            "and a valid keystore file, or use -PallowDebugSigningForLocalRelease=true " +
                            "for local non-production diagnostics only.",
                    )
                }
            }

            // Reduce release binary size (code + resources) for production builds.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
