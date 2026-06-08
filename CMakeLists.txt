cmake_minimum_required(VERSION 3.24)
project(vertex-store LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)
qt_standard_project_setup(REQUIRES 6.4)

include(FetchContent)
FetchContent_Declare(
    Corrosion
    GIT_REPOSITORY https://github.com/corrosion-rs/corrosion.git
    GIT_TAG v0.5
)
FetchContent_MakeAvailable(Corrosion)

corrosion_import_crate(MANIFEST_PATH "${CMAKE_SOURCE_DIR}/Cargo.toml")

# cxx-qt generates a CMake target helper
include("${CMAKE_BINARY_DIR}/corrosion/Cargo.toml-vertex-store-cxx-qt.cmake" OPTIONAL)

target_link_libraries(vertex-store-shared
    INTERFACE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
)
