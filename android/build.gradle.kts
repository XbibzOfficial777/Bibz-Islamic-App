allprojects {
    repositories {
        google()
        mavenCentral()
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
subprojects {
    project.evaluationDependsOn(":app")
}

// url_launcher_android 6.3.x can crash AGP 9.3's release lint parser on the
// hosted JDK 17 image. This narrowly disables only that dependency's broken
// lint task; the QuranX application lint task remains enabled.
subprojects {
    afterEvaluate {
        if (name == "url_launcher_android") {
            tasks.matching {
                it.name == "lintVitalAnalyzeRelease" || it.name == "lintAnalyzeRelease"
            }.configureEach {
                enabled = false
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
