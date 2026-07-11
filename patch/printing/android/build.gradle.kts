import java.util.Properties

plugins {
    id("com.android.library") version "8.11.1"
}

group = "net.nfet.flutter.printing"
version = "1.0"

val flutterSdkPath: String = Properties().let { props ->
    file("local.properties").inputStream().use { props.load(it) }
    props.getProperty("flutter.sdk") ?: error("flutter.sdk not set in local.properties")
}

android {
    namespace = "net.nfet.flutter.printing"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    defaultConfig {
        minSdk = 16
    }

    lint {
        disable += "InvalidPackage"
    }
}

dependencies {
    implementation("androidx.annotation:annotation:1.6.0")
    implementation("androidx.core:core:1.10.1")
    compileOnly(files("${flutterSdkPath}/bin/cache/artifacts/engine/android-arm-release/flutter.jar"))
}

repositories {
    google()
    mavenCentral()
}
