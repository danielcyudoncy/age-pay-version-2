group = "net.nfet.flutter.printing"
version = "1.0"

plugins {
    id("com.android.library")
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
        disable("InvalidPackage")
    }
}

repositories {
    google()
    mavenCentral()
}