allprojects {
    repositories {
        google()
        mavenCentral()
        // Map & GPS module: the Mapbox Maps SDK is not on Maven Central — it
        // is served from Mapbox's own authenticated repo. MAPBOX_DOWNLOADS_TOKEN
        // is a *secret* token (sk.*, scope DOWNLOADS:READ), separate from the
        // public pk.* token the app uses at runtime. It belongs in
        // ~/.gradle/gradle.properties, never in this repo.
        //
        // If the build fails with a 401 on a com.mapbox.* artifact, that token
        // is missing or wrong — the error names the artifact, not the token,
        // so it reads like a dependency problem rather than an auth one.
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
            authentication { create<BasicAuthentication>("basic") }
            credentials {
                username = "mapbox"
                password = providers.gradleProperty("MAPBOX_DOWNLOADS_TOKEN").orNull ?: ""
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// mapbox_maps_flutter 2.28.2 skips applying `kotlin-android` when AGP major
// is >= 9, on the assumption that AGP 9 always brings built-in Kotlin. That
// assumption breaks in a Flutter project: android/gradle.properties sets
// `android.builtInKotlin=false` (the Flutter template does this), and Flutter
// only applies the Kotlin plugin to :app. The plugin's own module therefore
// reaches its top-level `kotlin { compilerOptions { ... } }` block with no
// `kotlin` extension registered and the build fails evaluating it.
//
// Applying the plugin ourselves closes the gap. The `plugins.withId` hook
// fires the moment `com.android.library` is applied — partway through the
// package's own build.gradle, and crucially before the `kotlin { }` block
// further down it is evaluated. Scoped by project name so no other Flutter
// plugin module pays for this.
//
// Remove once mapbox_maps_flutter gates that block on the extension actually
// being present rather than on the AGP version.
subprojects {
    if (name == "mapbox_maps_flutter") {
        plugins.withId("com.android.library") {
            if (!plugins.hasPlugin("org.jetbrains.kotlin.android")) {
                apply(plugin = "org.jetbrains.kotlin.android")
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
