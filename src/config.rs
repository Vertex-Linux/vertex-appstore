use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Config {
    pub theme: String,
    pub show_flatpak: bool,
    pub show_pacman: bool,
    pub show_aur: bool,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            theme: "dark".to_string(),
            show_flatpak: true,
            show_pacman: true,
            show_aur: true,
        }
    }
}

fn config_path() -> PathBuf {
    let mut p = dirs::config_dir().unwrap_or_else(|| PathBuf::from("~/.config"));
    p.push("vertex-store");
    p.push("config.toml");
    p
}

pub fn load_config() -> Config {
    let path = config_path();
    if let Ok(data) = std::fs::read_to_string(&path) {
        toml::from_str(&data).unwrap_or_default()
    } else {
        Config::default()
    }
}

pub fn save_config(cfg: &Config) -> Result<()> {
    let path = config_path();
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let data = toml::to_string_pretty(cfg)?;
    std::fs::write(&path, data)?;
    Ok(())
}
