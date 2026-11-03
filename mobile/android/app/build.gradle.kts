plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "ma.taxi.taxi_maroc"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Requis par flutter_local_notifications (notifications du chauffeur pendant Waze / Google Maps).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "ma.taxi.taxi_maroc"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Clé Google Maps : variable d'environnement MAPS_API_KEY (secret GitHub), vide par défaut.
        manifestPlaceholders["MAPS_API_KEY"] = System.getenv("MAPS_API_KEY") ?: ""
        // Deux applications installables côte à côte : « Bab Taxi » (réelle) et « Bab Taxi Démo » (BAB_DEMO=oui).
        // « Bab Taxi Chauffeur » (BAB_APP=chauffeur) : troisième application, réservée aux chauffeurs.
        if (System.getenv("BAB_DEMO") == "oui") {
            applicationIdSuffix = ".demo"
            manifestPlaceholders["appLabel"] = "Bab Taxi Démo"
        } else if (System.getenv("BAB_APP") == "chauffeur") {
            applicationIdSuffix = ".chauffeur"
            manifestPlaceholders["appLabel"] = "Bab Taxi Chauffeur"
        } else {
            manifestPlaceholders["appLabel"] = "Bab Taxi"
        }
    }

    // Clé de signature stable (secret GitHub BAB_KEYSTORE_B64, décodé par la CI dans BAB_KEYSTORE) : chaque
    // nouvelle version s'installe par-dessus l'ancienne, et le bouton « Suivre mon taxi » de WhatsApp ouvre
    // l'application directement (App Links, /.well-known/assetlinks.json du serveur). Sans le secret : clé de debug.
    val babKeystore = System.getenv("BAB_KEYSTORE")?.let { file(it) }?.takeIf { it.exists() }
    signingConfigs {
        if (babKeystore != null) {
            create("bab") {
                storeFile = babKeystore
                storePassword = System.getenv("BAB_KEYSTORE_PASS")
                keyAlias = System.getenv("BAB_KEY_ALIAS") ?: "babtaxi"
                keyPassword = System.getenv("BAB_KEY_PASS") ?: System.getenv("BAB_KEYSTORE_PASS")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (babKeystore != null) "bab" else "debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
