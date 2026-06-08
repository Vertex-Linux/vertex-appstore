#[cxx::bridge]
pub mod ffi_qt {
    #[namespace = ""]
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;

        include!("app_icon.h");
        fn set_application_icon(path: &str);
    }
}
