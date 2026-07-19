pub mod backend;
pub mod config;
pub mod qt_types;

/// Called from `main()` to force this crate's rlib CGUs into the binary link.
/// Without this reference, lld omits the bridge stub object files and the
/// cxx-qt call-init chain fails with undefined symbol errors at runtime.
pub fn init_qml_module() {}

use cxx_qt::CxxQtType;
use serde::Serialize;
use std::process::{Command, Stdio};
use std::sync::{
    atomic::{AtomicBool, AtomicU64, Ordering},
    Arc, Mutex,
};
use std::time::Instant;

pub enum BackendEvent {
    SearchResults(String),
    InstalledReady(String),
    UpdatesReady(String),
    OperationDone(bool, String),
    PackageDetailsReady(String),
}

#[derive(Serialize, Clone)]
pub struct TaskEntry {
    pub id: u64,
    pub kind: String,       // "install" | "remove" | "update" | "update_all"
    pub pkg_name: String,
    pub pkg_source: String,
    pub status: String,     // "queued" | "running" | "done" | "failed"
    pub progress: u8,       // 0–100
    pub message: String,
}

// ── free functions ────────────────────────────────────────────────────────────

fn enqueue_task(
    tasks: Arc<Mutex<Vec<TaskEntry>>>,
    dirty: Arc<AtomicBool>,
    worker_running: Arc<AtomicBool>,
    event_queue: Arc<Mutex<Vec<BackendEvent>>>,
    entry: TaskEntry,
) {
    tasks.lock().unwrap().push(entry);
    dirty.store(true, Ordering::SeqCst);
    // Start the background worker only if one isn't already running
    if !worker_running.swap(true, Ordering::SeqCst) {
        std::thread::spawn(move || task_worker(tasks, dirty, worker_running, event_queue));
    }
}

fn task_worker(
    tasks: Arc<Mutex<Vec<TaskEntry>>>,
    dirty: Arc<AtomicBool>,
    worker_running: Arc<AtomicBool>,
    event_queue: Arc<Mutex<Vec<BackendEvent>>>,
) {
    loop {
        let task_opt = {
            let guard = tasks.lock().unwrap();
            guard
                .iter()
                .find(|t| t.status == "queued")
                .map(|t| (t.id, t.kind.clone(), t.pkg_name.clone(), t.pkg_source.clone()))
        };

        let Some((id, kind, name, source)) = task_opt else {
            worker_running.store(false, Ordering::SeqCst);
            return;
        };

        // Mark running
        {
            let mut guard = tasks.lock().unwrap();
            if let Some(t) = guard.iter_mut().find(|t| t.id == id) {
                t.status = "running".into();
                t.progress = 5;
                t.message = "Starting...".into();
            }
        }
        dirty.store(true, Ordering::SeqCst);

        let result = execute_task(&kind, &name, &source, &tasks, id, &dirty);

        let (ok, msg) = match result {
            Ok(m) => (true, m),
            Err(e) => (false, e.to_string()),
        };

        {
            let mut guard = tasks.lock().unwrap();
            if let Some(t) = guard.iter_mut().find(|t| t.id == id) {
                t.status = if ok { "done" } else { "failed" }.into();
                t.progress = if ok { 100 } else { 0 };
                t.message = msg.clone();
            }
        }
        dirty.store(true, Ordering::SeqCst);

        // Notify QML side so it can show toast + refresh pages
        if let Ok(mut q) = event_queue.lock() {
            q.push(BackendEvent::OperationDone(ok, msg));
        }
    }
}

fn execute_task(
    kind: &str,
    name: &str,
    source: &str,
    tasks: &Arc<Mutex<Vec<TaskEntry>>>,
    id: u64,
    dirty: &Arc<AtomicBool>,
) -> anyhow::Result<String> {
    let mut cmd = match (kind, source) {
        ("install", "flatpak") | ("install", "flatpak-system") => {
            // app_id is encoded as "remote/app_id" from the search; split to specify remote explicitly
            let (remote, app_id) = name.split_once('/').unwrap_or(("flathub", name));
            let mut c = Command::new("flatpak");
            c.args(["install", "--noninteractive", "-y", "--system", remote, app_id]);
            c
        }
        ("install", "flatpak-user") => {
            let (remote, app_id) = name.split_once('/').unwrap_or(("flathub", name));
            let mut c = Command::new("flatpak");
            c.args(["install", "--noninteractive", "-y", "--user", remote, app_id]);
            c
        }
        ("install", "pacman") => {
            let mut c = Command::new("pkexec");
            c.args(["pacman", "-S", "--noconfirm", name]);
            c
        }
        ("install", "aur") => {
            let mut c = Command::new("vpkg");
            c.args(["aur", "install", name]);
            c
        }
        ("remove", "flatpak") => {
            // strip remote prefix if present; remove only needs the app_id
            let app_id = name.split_once('/').map(|(_, id)| id).unwrap_or(name);
            let mut c = Command::new("flatpak");
            c.args(["remove", "--noninteractive", "-y", app_id]);
            c
        }
        ("remove", "pacman") => {
            let mut c = Command::new("pkexec");
            c.args(["pacman", "-R", "--noconfirm", name]);
            c
        }
        ("update", "flatpak") | ("update", "flatpak-system") | ("update", "flatpak-user") => {
            let app_id = name.split_once('/').map(|(_, id)| id).unwrap_or(name);
            let mut c = Command::new("flatpak");
            c.args(["update", "--noninteractive", "-y", app_id]);
            c
        }
        ("update", "pacman") => {
            let mut c = Command::new("pkexec");
            c.args(["pacman", "-S", "--noconfirm", name]);
            c
        }
        ("update_all", _) => {
            let mut c = Command::new("flatpak");
            c.args(["update", "-y"]);
            c
        }
        _ => anyhow::bail!("Unknown operation: {} / {}", kind, source),
    };

    let mut child = cmd
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| anyhow::anyhow!("Failed to start: {}", e))?;

    let start = Instant::now();

    loop {
        match child.try_wait() {
            Ok(Some(status)) => {
                return if status.success() {
                    Ok(match kind {
                        "install" => format!("Installed {}", name),
                        "remove" => format!("Removed {}", name),
                        "update" => format!("Updated {}", name),
                        _ => "Update complete".into(),
                    })
                } else {
                    use std::io::Read;
                    let mut buf = Vec::new();
                    if let Some(mut err) = child.stderr.take() {
                        let _ = err.read_to_end(&mut buf);
                    }
                    let text = String::from_utf8_lossy(&buf);
                    let last = text
                        .lines()
                        .filter(|l| !l.trim().is_empty())
                        .last()
                        .unwrap_or("Operation failed")
                        .trim()
                        .to_string();
                    Err(anyhow::anyhow!("{}", last))
                };
            }
            Ok(None) => {
                let secs = start.elapsed().as_secs_f32();
                // Smooth progress curve: 5 → 90 over ~60 s
                let progress = (5.0 + 85.0 * (1.0 - (-secs / 30.0f32).exp())) as u8;
                let msg = if secs < 5.0 {
                    "Starting..."
                } else if secs < 15.0 {
                    "Resolving dependencies..."
                } else if secs < 35.0 {
                    "Downloading..."
                } else {
                    "Installing..."
                };
                {
                    let mut guard = tasks.lock().unwrap();
                    if let Some(t) = guard.iter_mut().find(|t| t.id == id) {
                        t.progress = progress.min(90);
                        t.message = msg.into();
                    }
                }
                dirty.store(true, Ordering::SeqCst);
                std::thread::sleep(std::time::Duration::from_millis(500));
            }
            Err(e) => return Err(anyhow::anyhow!("Wait error: {}", e)),
        }
    }
}

// ── cxx-qt bridge ─────────────────────────────────────────────────────────────

#[cxx_qt::bridge]
mod ffi {
    unsafe extern "C++" {
        type QString = cxx_qt_lib::QString;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(QString, theme_name)]
        #[qproperty(bool, is_loading)]
        #[qproperty(QString, status_message)]
        #[qproperty(bool, show_flatpak)]
        #[qproperty(bool, show_pacman)]
        #[qproperty(bool, show_aur)]
        #[qproperty(i32, active_task_count)]
        type StoreBackend = super::StoreBackendRust;
    }

    unsafe extern "RustQt" {
        #[qinvokable]
        fn search(self: Pin<&mut StoreBackend>, query: &QString);
        #[qinvokable]
        fn get_installed(self: Pin<&mut StoreBackend>);
        #[qinvokable]
        fn get_updates(self: Pin<&mut StoreBackend>);
        #[qinvokable]
        fn install_package(self: Pin<&mut StoreBackend>, name: &QString, source: &QString);
        #[qinvokable]
        fn remove_package(self: Pin<&mut StoreBackend>, name: &QString, source: &QString);
        #[qinvokable]
        fn update_package(self: Pin<&mut StoreBackend>, name: &QString, source: &QString);
        #[qinvokable]
        fn update_all(self: Pin<&mut StoreBackend>);
        #[qinvokable]
        fn set_theme(self: Pin<&mut StoreBackend>, theme: &QString);
        #[qinvokable]
        fn toggle_source(self: Pin<&mut StoreBackend>, source: &QString, enabled: bool);
        #[qinvokable]
        fn load_config(self: Pin<&mut StoreBackend>);
        #[qinvokable]
        fn poll_events(self: Pin<&mut StoreBackend>);
        #[qinvokable]
        fn get_package_details(self: Pin<&mut StoreBackend>, name: &QString, source: &QString, app_id: &QString);
        #[qinvokable]
        fn cancel_task(self: Pin<&mut StoreBackend>, task_id: i64);
        #[qinvokable]
        fn clear_done_tasks(self: Pin<&mut StoreBackend>);

        #[qsignal]
        fn search_results_ready(self: Pin<&mut StoreBackend>, results_json: &QString);
        #[qsignal]
        fn installed_ready(self: Pin<&mut StoreBackend>, results_json: &QString);
        #[qsignal]
        fn updates_ready(self: Pin<&mut StoreBackend>, results_json: &QString);
        #[qsignal]
        fn operation_complete(self: Pin<&mut StoreBackend>, success: bool, message: &QString);
        #[qsignal]
        fn tasks_updated(self: Pin<&mut StoreBackend>, tasks_json: &QString);
        #[qsignal]
        fn package_details_ready(self: Pin<&mut StoreBackend>, details_json: &QString);
    }
}

// ── Rust struct ───────────────────────────────────────────────────────────────

pub struct StoreBackendRust {
    theme_name: cxx_qt_lib::QString,
    is_loading: bool,
    status_message: cxx_qt_lib::QString,
    show_flatpak: bool,
    show_pacman: bool,
    show_aur: bool,
    active_task_count: i32,
    event_queue: Arc<Mutex<Vec<BackendEvent>>>,
    tasks: Arc<Mutex<Vec<TaskEntry>>>,
    next_task_id: Arc<AtomicU64>,
    tasks_dirty: Arc<AtomicBool>,
    worker_running: Arc<AtomicBool>,
}

impl Default for StoreBackendRust {
    fn default() -> Self {
        Self {
            theme_name: cxx_qt_lib::QString::from("dark"),
            is_loading: false,
            status_message: cxx_qt_lib::QString::from(""),
            show_flatpak: true,
            show_pacman: true,
            show_aur: true,
            active_task_count: 0,
            event_queue: Arc::new(Mutex::new(Vec::new())),
            tasks: Arc::new(Mutex::new(Vec::new())),
            next_task_id: Arc::new(AtomicU64::new(1)),
            tasks_dirty: Arc::new(AtomicBool::new(false)),
            worker_running: Arc::new(AtomicBool::new(false)),
        }
    }
}

// ── invokable implementations ─────────────────────────────────────────────────

impl ffi::StoreBackend {
    fn load_config(mut self: core::pin::Pin<&mut Self>) {
        let cfg = config::load_config();
        self.as_mut()
            .set_theme_name(cxx_qt_lib::QString::from(cfg.theme.as_str()));
        self.as_mut().set_show_flatpak(cfg.show_flatpak);
        self.as_mut().set_show_pacman(cfg.show_pacman);
        self.as_mut().set_show_aur(cfg.show_aur);
    }

    fn set_theme(mut self: core::pin::Pin<&mut Self>, theme: &cxx_qt_lib::QString) {
        let theme_str = theme.to_string();
        self.as_mut()
            .set_theme_name(cxx_qt_lib::QString::from(theme_str.as_str()));
        let mut cfg = config::load_config();
        cfg.theme = theme_str;
        let _ = config::save_config(&cfg);
    }

    fn toggle_source(
        mut self: core::pin::Pin<&mut Self>,
        source: &cxx_qt_lib::QString,
        enabled: bool,
    ) {
        let src = source.to_string();
        let mut cfg = config::load_config();
        match src.as_str() {
            "flatpak" => {
                self.as_mut().set_show_flatpak(enabled);
                cfg.show_flatpak = enabled;
            }
            "pacman" => {
                self.as_mut().set_show_pacman(enabled);
                cfg.show_pacman = enabled;
            }
            "aur" => {
                self.as_mut().set_show_aur(enabled);
                cfg.show_aur = enabled;
            }
            _ => {}
        }
        let _ = config::save_config(&cfg);
    }

    fn search(mut self: core::pin::Pin<&mut Self>, query: &cxx_qt_lib::QString) {
        let query_str = query.to_string();
        if query_str.trim().is_empty() {
            return;
        }
        self.as_mut().set_is_loading(true);
        self.as_mut()
            .set_status_message(cxx_qt_lib::QString::from("Searching..."));

        let show_flatpak = *self.show_flatpak();
        let show_pacman = *self.show_pacman();
        let show_aur = *self.show_aur();
        let queue = self.rust().event_queue.clone();

        std::thread::spawn(move || {
            let mut results = Vec::new();
            if show_flatpak {
                results.extend(backend::search_flatpak(&query_str));
            }
            if show_pacman {
                results.extend(backend::search_pacman(&query_str));
            }
            if show_aur {
                results.extend(backend::search_aur(&query_str));
            }
            let json = serde_json::to_string(&results).unwrap_or_default();
            if let Ok(mut q) = queue.lock() {
                q.push(BackendEvent::SearchResults(json));
            }
        });
    }

    fn get_installed(mut self: core::pin::Pin<&mut Self>) {
        self.as_mut().set_is_loading(true);
        let show_flatpak = *self.show_flatpak();
        let show_pacman = *self.show_pacman();
        let queue = self.rust().event_queue.clone();

        std::thread::spawn(move || {
            let mut pkgs = Vec::new();
            if show_flatpak {
                pkgs.extend(backend::get_installed_flatpak());
            }
            if show_pacman {
                pkgs.extend(backend::get_installed_pacman());
            }
            let json = serde_json::to_string(&pkgs).unwrap_or_default();
            if let Ok(mut q) = queue.lock() {
                q.push(BackendEvent::InstalledReady(json));
            }
        });
    }

    fn get_updates(mut self: core::pin::Pin<&mut Self>) {
        self.as_mut().set_is_loading(true);
        let queue = self.rust().event_queue.clone();
        std::thread::spawn(move || {
            let pkgs = backend::get_flatpak_updates();
            let json = serde_json::to_string(&pkgs).unwrap_or_default();
            if let Ok(mut q) = queue.lock() {
                q.push(BackendEvent::UpdatesReady(json));
            }
        });
    }

    fn install_package(
        self: core::pin::Pin<&mut Self>,
        name: &cxx_qt_lib::QString,
        source: &cxx_qt_lib::QString,
    ) {
        let name_str = name.to_string();
        let source_str = source.to_string();
        let id = self.rust().next_task_id.fetch_add(1, Ordering::SeqCst);
        let entry = TaskEntry {
            id,
            kind: "install".into(),
            pkg_name: name_str,
            pkg_source: source_str,
            status: "queued".into(),
            progress: 0,
            message: "Queued".into(),
        };
        enqueue_task(
            self.rust().tasks.clone(),
            self.rust().tasks_dirty.clone(),
            self.rust().worker_running.clone(),
            self.rust().event_queue.clone(),
            entry,
        );
    }

    fn remove_package(
        self: core::pin::Pin<&mut Self>,
        name: &cxx_qt_lib::QString,
        source: &cxx_qt_lib::QString,
    ) {
        let name_str = name.to_string();
        let source_str = source.to_string();
        let id = self.rust().next_task_id.fetch_add(1, Ordering::SeqCst);
        let entry = TaskEntry {
            id,
            kind: "remove".into(),
            pkg_name: name_str,
            pkg_source: source_str,
            status: "queued".into(),
            progress: 0,
            message: "Queued".into(),
        };
        enqueue_task(
            self.rust().tasks.clone(),
            self.rust().tasks_dirty.clone(),
            self.rust().worker_running.clone(),
            self.rust().event_queue.clone(),
            entry,
        );
    }

    fn update_package(
        self: core::pin::Pin<&mut Self>,
        name: &cxx_qt_lib::QString,
        source: &cxx_qt_lib::QString,
    ) {
        let name_str = name.to_string();
        let source_str = source.to_string();
        let id = self.rust().next_task_id.fetch_add(1, Ordering::SeqCst);
        let entry = TaskEntry {
            id,
            kind: "update".into(),
            pkg_name: name_str,
            pkg_source: source_str,
            status: "queued".into(),
            progress: 0,
            message: "Queued".into(),
        };
        enqueue_task(
            self.rust().tasks.clone(),
            self.rust().tasks_dirty.clone(),
            self.rust().worker_running.clone(),
            self.rust().event_queue.clone(),
            entry,
        );
    }

    fn update_all(self: core::pin::Pin<&mut Self>) {
        let id = self.rust().next_task_id.fetch_add(1, Ordering::SeqCst);
        let entry = TaskEntry {
            id,
            kind: "update_all".into(),
            pkg_name: "Flatpak Updates".into(),
            pkg_source: "flatpak".into(),
            status: "queued".into(),
            progress: 0,
            message: "Queued".into(),
        };
        enqueue_task(
            self.rust().tasks.clone(),
            self.rust().tasks_dirty.clone(),
            self.rust().worker_running.clone(),
            self.rust().event_queue.clone(),
            entry,
        );
    }

    fn get_package_details(
        self: core::pin::Pin<&mut Self>,
        name: &cxx_qt_lib::QString,
        source: &cxx_qt_lib::QString,
        app_id: &cxx_qt_lib::QString,
    ) {
        let name_str = name.to_string();
        let source_str = source.to_string();
        let app_id_str = app_id.to_string();
        let queue = self.rust().event_queue.clone();
        std::thread::spawn(move || {
            let details = if source_str.starts_with("flatpak") {
                backend::get_flatpak_details(&app_id_str)
            } else {
                match source_str.as_str() {
                    "pacman" => backend::get_pacman_details(&name_str),
                    "aur"    => backend::get_aur_details(&name_str),
                    _        => return,
                }
            };
            let json = serde_json::to_string(&details).unwrap_or_default();
            if let Ok(mut q) = queue.lock() {
                q.push(BackendEvent::PackageDetailsReady(json));
            }
        });
    }

    fn cancel_task(self: core::pin::Pin<&mut Self>, task_id: i64) {
        let tasks = self.rust().tasks.clone();
        let dirty = self.rust().tasks_dirty.clone();
        let uid = task_id as u64;
        {
            let mut guard = tasks.lock().unwrap();
            guard.retain(|t| !(t.id == uid && t.status == "queued"));
        }
        dirty.store(true, Ordering::SeqCst);
    }

    fn clear_done_tasks(self: core::pin::Pin<&mut Self>) {
        let tasks = self.rust().tasks.clone();
        let dirty = self.rust().tasks_dirty.clone();
        {
            let mut guard = tasks.lock().unwrap();
            guard.retain(|t| t.status != "done" && t.status != "failed");
        }
        dirty.store(true, Ordering::SeqCst);
    }

    fn poll_events(mut self: core::pin::Pin<&mut Self>) {
        // ── regular backend events ─────────────────────────────────────────
        let events: Vec<BackendEvent> = {
            let Ok(mut q) = self.rust().event_queue.lock() else {
                return;
            };
            std::mem::take(&mut *q)
        };

        for event in events {
            match event {
                BackendEvent::SearchResults(json) => {
                    self.as_mut().set_is_loading(false);
                    self.as_mut()
                        .set_status_message(cxx_qt_lib::QString::from(""));
                    let qs = cxx_qt_lib::QString::from(json.as_str());
                    self.as_mut().search_results_ready(&qs);
                }
                BackendEvent::InstalledReady(json) => {
                    self.as_mut().set_is_loading(false);
                    let qs = cxx_qt_lib::QString::from(json.as_str());
                    self.as_mut().installed_ready(&qs);
                }
                BackendEvent::UpdatesReady(json) => {
                    self.as_mut().set_is_loading(false);
                    let qs = cxx_qt_lib::QString::from(json.as_str());
                    self.as_mut().updates_ready(&qs);
                }
                BackendEvent::OperationDone(ok, msg) => {
                    self.as_mut().set_is_loading(false);
                    self.as_mut()
                        .set_status_message(cxx_qt_lib::QString::from(""));
                    let qs = cxx_qt_lib::QString::from(msg.as_str());
                    self.as_mut().operation_complete(ok, &qs);
                }
                BackendEvent::PackageDetailsReady(json) => {
                    let qs = cxx_qt_lib::QString::from(json.as_str());
                    self.as_mut().package_details_ready(&qs);
                }
            }
        }

        // ── task queue updates ─────────────────────────────────────────────
        let is_dirty = self.rust().tasks_dirty.swap(false, Ordering::SeqCst);
        if is_dirty {
            let json;
            let count;
            {
                let guard = self.rust().tasks.lock().unwrap();
                json = serde_json::to_string(&*guard).unwrap_or_default();
                count = guard
                    .iter()
                    .filter(|t| t.status == "queued" || t.status == "running")
                    .count() as i32;
            }
            self.as_mut().set_active_task_count(count);
            let qs = cxx_qt_lib::QString::from(json.as_str());
            self.as_mut().tasks_updated(&qs);
        }
    }
}
