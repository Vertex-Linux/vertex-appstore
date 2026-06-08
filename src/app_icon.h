#pragma once
#include "rust/cxx.h"
#include <QGuiApplication>
#include <QIcon>

inline void set_application_icon(rust::Str path) {
    auto icon = QIcon(QString::fromUtf8(path.data(), static_cast<qsizetype>(path.size())));
    QGuiApplication::setWindowIcon(icon);
}
