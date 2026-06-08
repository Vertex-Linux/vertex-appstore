use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QUrl};

fn main() {
    // Force the vertex_store lib's Rust object code into the binary's link.
    // See the doc comment on init_qml_module() for why this is required.
    vertex_store::init_qml_module();
    let mut app = QGuiApplication::new();
    app.pin_mut()
        .set_application_name(&cxx_qt_lib::QString::from("Vertex Store"));
    app.pin_mut()
        .set_organization_name(&cxx_qt_lib::QString::from("Vertex Linux"));
    vertex_store::qt_types::ffi_qt::set_application_icon(
        "qrc:/qt/qml/VertexStore/assets/icon.svg",
    );

    let mut engine = QQmlApplicationEngine::new();
    engine
        .pin_mut()
        .load(&QUrl::from("qrc:/qt/qml/VertexStore/qml/main.qml"));

    app.pin_mut().exec();
}
