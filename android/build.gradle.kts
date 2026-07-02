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
    // Some old plugins (e.g. file_picker 3.x) declare their package only in the
    // legacy AndroidManifest and set no `namespace`, which AGP 8+ rejects.
    // Inject the manifest package as the namespace via reflection so we don't
    // have to pin those plugins to versions that conflict with other deps.
    // Registered before evaluationDependsOn so the project isn't yet evaluated.
    if (!project.state.executed) {
        project.afterEvaluate {
            val androidExt = extensions.findByName("android") ?: return@afterEvaluate
            val getNamespace = androidExt.javaClass.methods.firstOrNull {
                it.name == "getNamespace" && it.parameterCount == 0
            }
            val setNamespace = androidExt.javaClass.methods.firstOrNull {
                it.name == "setNamespace" && it.parameterCount == 1
            }
            val current = getNamespace?.invoke(androidExt) as? String
            if (current == null && setNamespace != null) {
                val manifest = file("src/main/AndroidManifest.xml")
                if (manifest.exists()) {
                    val pkg = Regex("""package\s*=\s*"([^"]+)"""")
                        .find(manifest.readText())
                        ?.groupValues
                        ?.get(1)
                    if (pkg != null) {
                        setNamespace.invoke(androidExt, pkg)
                    }
                }
            }
        }
    }

    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
