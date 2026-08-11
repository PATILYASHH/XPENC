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

// Some plugins pin their own compileOptions/kotlinOptions to an old JVM
// target (e.g. home_widget sets Java+Kotlin to 1.8) while others set none
// at all and inherit a much newer Kotlin default — either way AGP refuses
// to build once Java and Kotlin disagree ("Inconsistent JVM Target
// Compatibility"). Re-applied here, after each subproject's own script has
// already run, so this wins over whatever a plugin set for itself — a
// plugin's own build.gradle doesn't need to be current for this to build.
// :app already sets its own (correct, Java 17) compileOptions — re-touching
// an already-finalized property on an already-evaluated project throws, and
// there is nothing to fix there anyway.
subprojects {
    if (project.path == ":app") return@subprojects
    fun pinJvmTarget() {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
            ?.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(
                org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17,
            )
        }
    }
    if (state.executed) pinJvmTarget() else afterEvaluate { pinJvmTarget() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
