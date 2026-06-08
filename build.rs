use cxx_qt_build::{CxxQtBuilder, QmlFile, QmlModule};

fn main() {
    // SAFETY: We only add a force-include flag so the generated C++ for our cxx-qt
    // bridge can resolve the `IsRelocatable<QString>` specialization that lives in
    // cxx-qt-lib's qstring.h.  cxx-qt-build adds that header's directory to the
    // include search path automatically via the cxx-qt-lib manifest, so the -include
    // path is always resolvable.
    unsafe {
        CxxQtBuilder::new_qml_module(
            QmlModule::new("VertexStore")
                .version(1, 0)
                .qml_files(vec![
                    QmlFile::from("qml/main.qml"),
                    QmlFile::from("qml/Theme.qml").singleton(true),
                    QmlFile::from("qml/TaskQueueOverlay.qml"),
                    QmlFile::from("qml/pages/HomePage.qml"),
                    QmlFile::from("qml/pages/InstalledPage.qml"),
                    QmlFile::from("qml/pages/UpdatesPage.qml"),
                    QmlFile::from("qml/pages/SearchPage.qml"),
                    QmlFile::from("qml/pages/SettingsPage.qml"),
                    QmlFile::from("qml/components/PackageCard.qml"),
                    QmlFile::from("qml/components/SideBar.qml"),
                    QmlFile::from("qml/components/LoadingSpinner.qml"),
                    QmlFile::from("qml/components/EmptyState.qml"),
                    QmlFile::from("qml/components/ActionButton.qml"),
                    QmlFile::from("qml/components/ConfirmDialog.qml"),
                    QmlFile::from("qml/pages/PackageDetailPage.qml"),
                ]),
        )
        .qrc_resources(["assets/icon.svg"])
        .cc_builder(|cc| {
            // Force-include the cxx-qt-lib QString header into every generated C++
            // translation unit so the rust::IsRelocatable<QString> specialisation is
            // visible even though we cannot use include!() inside #[cxx_qt::bridge]
            // on Rust >= 1.85 (non-foreign-item macro validation).
            cc.flag("-include");
            cc.flag("cxx-qt-lib/qstring.h");
            // Allow bridge files to include project-local headers (e.g. app_icon.h)
            cc.include("src");
        })
        .file("src/lib.rs")
        .file("src/qt_types.rs")
        .build();
    }

    // Cargo propagates cargo:rustc-link-lib from *dependency* build scripts to
    // dependents, but NOT from a package's own build script to its own binaries.
    // The cxx-qt-call-init-* archives must be linked with --whole-archive so their
    // C++ static initializers actually run at startup (registering the QML plugin
    // and resources).
    //
    // The call-init archives are appended to the end of the linker command via
    // rustc-link-arg-bin, which means they come AFTER the first scan of
    // libvertex-store-cxxqt-generated.a (emitted by CxxQtBuilder).  The call-init
    // objects then leave cxx_qt_init_* symbols undefined.  We fix this by adding a
    // SECOND -l reference to the generated lib after the call-init libs so lld
    // rescans it and picks up the initialiser archive members.
    let out_dir = std::env::var("OUT_DIR").unwrap();
    for flag in [
        // Disable --gc-sections so the Rust cxxbridge stubs (property getters/
        // setters and invokables) are not eliminated.  They are only reachable at
        // runtime via Qt's property/invokable dispatch and the linker cannot trace
        // that path statically.
        "-Wl,--no-gc-sections".to_string(),
        // 1. Link the call-init archives with --whole-archive so their file-scope
        //    static variables are included and run before main().
        "-Wl,--whole-archive".to_string(),
        format!("-Wl,{out_dir}/libcxx-qt-call-init-crate_vertex_store.a"),
        format!("-Wl,{out_dir}/libcxx-qt-call-init-qml_module_VertexStore.a"),
        "-Wl,--no-whole-archive".to_string(),
        // 2. Rescan the generated libs so that the cxx_qt_init_* symbols now
        //    referenced by the call-init objects are resolved.  Both lld and gold
        //    rescan an archive each time it appears in the command line.
        //    We must rescan our own archive AND the dependency crates' archives:
        //    cxx-qt and cxx-qt-lib each have their own call-init archives
        //    (propagated via rustc-link-arg since Rust 1.72) and their own
        //    generated archives that define cxx_qt_init_crate_cxx_qt{,_lib}.
        format!("-Wl,-lvertex-store-cxxqt-generated"),
        format!("-Wl,-lcxx-qt-cxxqt-generated"),
        format!("-Wl,-lcxx-qt-lib-cxxqt-generated"),
    ] {
        println!("cargo:rustc-link-arg-bin=vertex-store={flag}");
    }
}
