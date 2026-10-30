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
subprojects {
    val alignKotlinTarget: Project.() -> Unit = {
        val android = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        if (android != null) {
            val javaTarget = android.compileOptions.targetCompatibility.toString()
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions.jvmTarget.set(
                    org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(javaTarget)
                )
            }
        }
    }
    if (state.executed) alignKotlinTarget() else afterEvaluate { alignKotlinTarget() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}