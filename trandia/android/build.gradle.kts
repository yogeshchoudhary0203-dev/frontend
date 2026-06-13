buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // Suppress "source/target value 8 is obsolete" and deprecated-API notes
    // from third-party libraries compiled with older Java compatibility settings.
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.addAll(listOf("-Xlint:-options", "-Xlint:-deprecation"))
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        val target = project.extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
            ?.compileOptions?.targetCompatibility
        val jvmTargetEnum = if (target != null) {
            when (target.toString()) {
                "1.8", "8" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
                "11" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
                "17" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
                "21" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21
                else -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
            }
        } else {
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        }
        compilerOptions {
            jvmTarget.set(jvmTargetEnum)
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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
