plugins {
    id("com.android.application") apply false
    id("com.android.library") apply false
    id("org.jetbrains.kotlin.android") apply false
    id("com.google.gms.google-services") apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// Make every plugin's Kotlin target match its own Java target.
// Fixes: "Inconsistent JVM-target compatibility detected for tasks
// 'compileReleaseJavaWithJavac' (1.8) and 'compileReleaseKotlin' (23)"
// (seen in flutter_facebook_auth and other older plugins).
//
// The Java target is read lazily from the matching Java compile task
// (e.g. compileReleaseKotlin -> compileReleaseJavaWithJavac) only when the
// Kotlin task runs, so it never touches compileOptions before the Android
// Gradle Plugin has finalized them ("targetCompatibility is not yet finalized").
subprojects {
    val projectTasks = tasks
    projectTasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        val javaTaskName = name.replace("Kotlin", "JavaWithJavac")
        compilerOptions.jvmTarget.set(
            project.provider {
                val javaTask = projectTasks.findByName(javaTaskName) as? JavaCompile
                val javaTarget = javaTask?.targetCompatibility ?: "17"
                org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(javaTarget)
            }
        )
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}