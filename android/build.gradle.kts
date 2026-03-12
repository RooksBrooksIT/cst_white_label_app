allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Move the root Android project's build/ to the repo root build/ (../../build)
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

// Only relocate buildDir for subprojects that are physically inside this android/ directory.
// This avoids Windows cross-drive issues for Flutter plugin subprojects living under C:\Users\...\ .pub-cache.
subprojects {
    val rootPath = rootProject.projectDir.absoluteFile.toPath().normalize()
    val projPath = project.projectDir.absoluteFile.toPath().normalize()

    if (projPath.startsWith(rootPath)) {
        val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    }
}

// Keep evaluation order for the app module
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}