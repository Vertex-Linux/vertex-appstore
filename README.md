# Vertex Store
A gui baised flatpak, aur, and pacman store for Vertex Linux.

# Building stuff

### Rust toolchain

- Rust 1.85+ (stable)
- cargo (comes with Rust)
### System — Qt

- Qt 6.11 (specifically Qt6Core, Qt6Gui, Qt6Qml)
- On Arch: qt6-base qt6-declarative
### System — build tools

- cmake (used internally by cxx-qt-build)
- clang / libclang (required by cxx-qt's bindgen step)
- On Arch: cmake clang
### Runtime — package managers (what the app actually calls)

- flatpak
- pacman (already on Arch)
- pkexec (from polkit, for pacman install/remove with elevated - privileges)
- curl (for AUR search)
- vpkg (Vertex Linux's AUR helper, for AUR installs)
### Cargo dependencies (fetched automatically by cargo):

- cxx-qt 0.8, cxx-qt-lib 0.8, cxx-qt-build 0.8
- serde, serde_json, toml, anyhow, dirs


# Install system deps (Arch)
sudo pacman -S qt6-base qt6-declarative cmake clang flatpak curl

# Build
cargo build --release

# Run
./target/release/vertex-store