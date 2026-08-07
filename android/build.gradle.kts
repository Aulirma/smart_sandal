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

    afterEvaluate {
        if (project.name == "reactive_ble_mobile") {
            extensions.findByName("android")?.let { androidExt ->
                val android = androidExt as com.android.build.gradle.LibraryExtension
                android.compileSdk = 36
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