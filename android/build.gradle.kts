allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Some plugins (audiotags 1.4.5 as of this writing) bundle their own Android
// module hardcoded to an old compileSdk, which fails AAR metadata checks
// against newer transitive androidx deps other plugins pull in. Force every
// subproject (including plugin modules) to compile against the same SDK the
// app itself uses, rather than patching a third-party plugin's build file.
// Registered first, and via afterEvaluate (a plugin's own build.gradle sets
// its compileSdkVersion as part of normal script evaluation, which runs
// *after* the plugins{} block, so a withId-based override gets clobbered) —
// must come before evaluationDependsOn(":app") below, which forces early
// evaluation of :app and would make a later afterEvaluate registration fail
// with "project already evaluated".
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.compileSdkVersion(37)
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
