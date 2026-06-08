use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::path::Path;
use std::process::Command;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Package {
    pub name: String,
    pub description: String,
    pub version: String,
    pub source: String,
    pub installed: bool,
    pub size: String,
    pub icon: String,
    /// For flatpak: the application ID (e.g. org.mozilla.firefox).
    /// For pacman/aur: same as name. Always use this for install/remove commands.
    pub app_id: String,
}

impl Package {
    fn new(name: &str, desc: &str, version: &str, source: &str) -> Self {
        Self {
            name: name.to_string(),
            description: desc.to_string(),
            version: version.to_string(),
            source: source.to_string(),
            installed: false,
            size: String::new(),
            icon: String::new(),
            app_id: name.to_string(),
        }
    }
}

fn flatpak_icon(app_id: &str) -> String {
    let home = std::env::var("HOME").unwrap_or_default();
    let sizes = ["128x128", "64x64"];
    let bases = [
        "/var/lib/flatpak/appstream".to_string(),
        format!("{}/.local/share/flatpak/appstream", home),
    ];
    for base in &bases {
        for size in &sizes {
            // glob over remotes and arches by scanning the base dir
            if let Ok(remotes) = std::fs::read_dir(base) {
                for remote in remotes.flatten() {
                    let icon = remote
                        .path()
                        .join("x86_64/active/icons")
                        .join(size)
                        .join(format!("{}.png", app_id));
                    if icon.exists() {
                        return format!("file://{}", icon.display());
                    }
                }
            }
        }
    }
    String::new()
}

fn system_icon(name: &str) -> String {
    let candidates = [
        format!("/usr/share/icons/hicolor/48x48/apps/{}.png", name),
        format!("/usr/share/icons/hicolor/32x32/apps/{}.png", name),
        format!("/usr/share/icons/hicolor/scalable/apps/{}.svg", name),
        format!("/usr/share/pixmaps/{}.png", name),
        format!("/usr/share/pixmaps/{}.svg", name),
        format!("/usr/share/pixmaps/{}.xpm", name),
    ];
    for c in &candidates {
        if Path::new(c).exists() {
            return format!("file://{}", c);
        }
    }
    String::new()
}

pub fn search_flatpak(query: &str) -> Vec<Package> {
    let output = Command::new("flatpak")
        .args(["search", "--columns=name,description,version,application,remotes", query])
        .output();

    let Ok(out) = output else { return vec![] };
    let text = String::from_utf8_lossy(&out.stdout);

    text.lines()
        .filter_map(|line| {
            let parts: Vec<&str> = line.split('\t').collect();
            if parts.len() >= 3 {
                let mut p = Package::new(
                    parts[0].trim(),
                    parts[1].trim(),
                    parts[2].trim(),
                    "flatpak",
                );
                let raw_id = parts.get(3).map(|s| s.trim()).unwrap_or(parts[0].trim());
                // remotes field may be comma-separated (e.g. "flathub,flathub-beta"); take first
                let remotes_field = parts.get(4).map(|s| s.trim()).unwrap_or("flathub");
                let origin = remotes_field.split(',').next().unwrap_or("flathub").trim();
                p.icon = flatpak_icon(raw_id);
                // Encode remote into app_id as "remote/app_id" so install knows which remote to use
                p.app_id = if origin.is_empty() {
                    raw_id.to_string()
                } else {
                    format!("{}/{}", origin, raw_id)
                };
                Some(p)
            } else {
                None
            }
        })
        .filter(|p| !p.name.is_empty())
        .take(30)
        .collect()
}

pub fn search_pacman(query: &str) -> Vec<Package> {
    let output = Command::new("pacman").args(["-Ss", query]).output();

    let Ok(out) = output else { return vec![] };
    let text = String::from_utf8_lossy(&out.stdout);
    let lines: Vec<&str> = text.lines().collect();

    let mut packages = vec![];
    let mut i = 0;
    while i + 1 < lines.len() {
        let header = lines[i];
        let desc = lines[i + 1].trim();

        if let Some(slash_pos) = header.find('/') {
            let rest = &header[slash_pos + 1..];
            let mut parts = rest.splitn(2, ' ');
            let name = parts.next().unwrap_or("").trim();
            let version = parts
                .next()
                .unwrap_or("")
                .split_whitespace()
                .next()
                .unwrap_or("")
                .trim();
            let installed = header.contains("[installed]");

            let mut p = Package::new(name, desc, version, "pacman");
            p.installed = installed;
            p.icon = system_icon(name);
            if !p.name.is_empty() {
                packages.push(p);
            }
        }
        i += 2;
    }
    packages.into_iter().take(30).collect()
}

pub fn search_aur(query: &str) -> Vec<Package> {
    #[derive(Deserialize)]
    struct AurResult {
        #[serde(rename = "Name")]
        name: String,
        #[serde(rename = "Description")]
        description: Option<String>,
        #[serde(rename = "Version")]
        version: String,
    }
    #[derive(Deserialize)]
    struct AurResponse {
        results: Vec<AurResult>,
    }

    let encoded: String = query
        .chars()
        .map(|c| match c {
            'A'..='Z' | 'a'..='z' | '0'..='9' | '-' | '_' | '.' => c.to_string(),
            ' ' => "+".to_string(),
            other => format!("%{:02X}", other as u32),
        })
        .collect();
    let url = format!("https://aur.archlinux.org/rpc/v5/search/{}?by=name-desc", encoded);

    let output = Command::new("curl")
        .args(["-s", "--max-time", "15", &url])
        .output();

    let Ok(out) = output else { return vec![] };
    let text = String::from_utf8_lossy(&out.stdout);
    let Ok(resp) = serde_json::from_str::<AurResponse>(&text) else { return vec![] };

    resp.results
        .into_iter()
        .take(30)
        .map(|r| {
            let mut p = Package::new(
                &r.name,
                r.description.as_deref().unwrap_or(""),
                &r.version,
                "aur",
            );
            p.icon = system_icon(&r.name);
            p
        })
        .collect()
}

pub fn get_installed_flatpak() -> Vec<Package> {
    let output = Command::new("flatpak")
        .args(["list", "--columns=name,description,version,application,origin"])
        .output();

    let Ok(out) = output else { return vec![] };
    let text = String::from_utf8_lossy(&out.stdout);

    text.lines()
        .filter_map(|line| {
            let parts: Vec<&str> = line.split('\t').collect();
            if parts.len() >= 1 && !parts[0].trim().is_empty() {
                let mut p = Package::new(
                    parts[0].trim(),
                    parts.get(1).copied().unwrap_or("").trim(),
                    parts.get(2).copied().unwrap_or("").trim(),
                    "flatpak",
                );
                p.installed = true;
                let raw_id = parts.get(3).map(|s| s.trim()).unwrap_or(parts[0].trim());
                let origin = parts.get(4).map(|s| s.trim()).unwrap_or("flathub");
                p.icon = flatpak_icon(raw_id);
                p.app_id = if origin.is_empty() {
                    raw_id.to_string()
                } else {
                    format!("{}/{}", origin, raw_id)
                };
                Some(p)
            } else {
                None
            }
        })
        .collect()
}

pub fn get_installed_pacman() -> Vec<Package> {
    let output = Command::new("pacman").args(["-Q"]).output();

    let Ok(out) = output else { return vec![] };
    let text = String::from_utf8_lossy(&out.stdout);

    text.lines()
        .filter_map(|line| {
            let mut parts = line.splitn(2, ' ');
            let name = parts.next().unwrap_or("").trim();
            let version = parts.next().unwrap_or("").trim();
            if !name.is_empty() {
                let mut p = Package::new(name, "", version, "pacman");
                p.installed = true;
                p.icon = system_icon(name);
                Some(p)
            } else {
                None
            }
        })
        .collect()
}

pub fn get_flatpak_updates() -> Vec<Package> {
    let output = Command::new("flatpak")
        .args(["remote-ls", "--updates", "--columns=name,description,version,application,origin"])
        .output();

    let Ok(out) = output else { return vec![] };
    let text = String::from_utf8_lossy(&out.stdout);

    text.lines()
        .filter_map(|line| {
            let parts: Vec<&str> = line.split('\t').collect();
            if parts.len() >= 1 && !parts[0].trim().is_empty() {
                let mut p = Package::new(
                    parts[0].trim(),
                    parts.get(1).copied().unwrap_or("").trim(),
                    parts.get(2).copied().unwrap_or("").trim(),
                    "flatpak",
                );
                let raw_id = parts.get(3).map(|s| s.trim()).unwrap_or(parts[0].trim());
                let origin = parts.get(4).map(|s| s.trim()).unwrap_or("flathub");
                p.icon = flatpak_icon(raw_id);
                p.app_id = if origin.is_empty() {
                    raw_id.to_string()
                } else {
                    format!("{}/{}", origin, raw_id)
                };
                Some(p)
            } else {
                None
            }
        })
        .collect()
}

pub fn install_flatpak(name: &str) -> Result<String> {
    let out = Command::new("flatpak")
        .args(["install", "-y", name])
        .output()?;
    if out.status.success() {
        Ok(format!("Installed {} via Flatpak", name))
    } else {
        let err = String::from_utf8_lossy(&out.stderr);
        anyhow::bail!("{}", err.trim())
    }
}

pub fn install_pacman(name: &str) -> Result<String> {
    let out = Command::new("pkexec")
        .args(["pacman", "-S", "--noconfirm", name])
        .output()?;
    if out.status.success() {
        Ok(format!("Installed {} via pacman", name))
    } else {
        let err = String::from_utf8_lossy(&out.stderr);
        anyhow::bail!("{}", err.trim())
    }
}

pub fn install_aur(name: &str) -> Result<String> {
    let out = Command::new("vpkg")
        .args(["aur", "install", name])
        .output()?;
    if out.status.success() {
        Ok(format!("Installed {} from AUR via vpkg", name))
    } else {
        let err = String::from_utf8_lossy(&out.stderr);
        anyhow::bail!("{}", err.trim())
    }
}

pub fn remove_flatpak(name: &str) -> Result<String> {
    let out = Command::new("flatpak")
        .args(["remove", "-y", name])
        .output()?;
    if out.status.success() {
        Ok(format!("Removed {} (Flatpak)", name))
    } else {
        let err = String::from_utf8_lossy(&out.stderr);
        anyhow::bail!("{}", err.trim())
    }
}

pub fn remove_pacman(name: &str) -> Result<String> {
    let out = Command::new("pkexec")
        .args(["pacman", "-R", "--noconfirm", name])
        .output()?;
    if out.status.success() {
        Ok(format!("Removed {} (pacman)", name))
    } else {
        let err = String::from_utf8_lossy(&out.stderr);
        anyhow::bail!("{}", err.trim())
    }
}

pub fn update_all_flatpak() -> Result<String> {
    let out = Command::new("flatpak").args(["update", "-y"]).output()?;
    if out.status.success() {
        Ok("All Flatpak apps updated".to_string())
    } else {
        let err = String::from_utf8_lossy(&out.stderr);
        anyhow::bail!("{}", err.trim())
    }
}

// ── Package detail types ──────────────────────────────────────────────────────

#[derive(Debug, Serialize, Clone, Default)]
pub struct ChangelogEntry {
    pub version: String,
    pub date: String,
    pub description: String,
}

#[derive(Debug, Serialize, Clone, Default)]
pub struct PackageDetails {
    pub name: String,
    pub summary: String,
    pub description: String,
    pub version: String,
    pub source: String,
    pub app_id: String,
    pub icon: String,
    pub screenshots: Vec<String>,
    pub homepage: String,
    pub developer: String,
    pub license: String,
    pub size: String,
    pub last_updated: String,
    pub changelog: Vec<ChangelogEntry>,
}

fn strip_html(s: &str) -> String {
    let s = s
        .replace("</p>", "\n\n")
        .replace("<br>", "\n").replace("<br/>", "\n").replace("<br />", "\n")
        .replace("</li>", "\n").replace("<li>", "• ")
        .replace("</ul>", "\n").replace("<ul>", "").replace("</ol>", "\n").replace("<ol>", "");
    let mut out = String::new();
    let mut in_tag = false;
    for c in s.chars() {
        match c {
            '<' => in_tag = true,
            '>' => in_tag = false,
            _ if !in_tag => out.push(c),
            _ => {}
        }
    }
    let out = out
        .replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
        .replace("&quot;", "\"").replace("&#39;", "'").replace("&apos;", "'")
        .replace("&nbsp;", " ");
    let mut result = String::new();
    let mut blanks = 0usize;
    for line in out.lines() {
        let t = line.trim();
        if t.is_empty() {
            blanks += 1;
            if blanks <= 1 { result.push('\n'); }
        } else {
            blanks = 0;
            result.push_str(t);
            result.push('\n');
        }
    }
    result.trim().to_string()
}

fn format_unix_ts(ts: i64) -> String {
    Command::new("date")
        .args(["-d", &format!("@{}", ts), "+%B %d, %Y"])
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.trim().to_string())
        .unwrap_or_default()
}

// ── Detail fetchers ───────────────────────────────────────────────────────────

pub fn get_flatpak_details(raw_app_id: &str) -> PackageDetails {
    let actual_id = raw_app_id.split_once('/').map(|(_, id)| id).unwrap_or(raw_app_id);

    let mut d = PackageDetails {
        source: "flatpak".to_string(),
        app_id: raw_app_id.to_string(),
        icon: flatpak_icon(actual_id),
        name: actual_id.to_string(),
        ..Default::default()
    };

    // Basic info from flatpak info (size, version)
    if let Ok(out) = Command::new("flatpak").args(["info", actual_id]).output() {
        let text = String::from_utf8_lossy(&out.stdout);
        for line in text.lines() {
            let line = line.trim();
            if let Some(v) = line.strip_prefix("Version:") { d.version = v.trim().to_string(); }
            if let Some(v) = line.strip_prefix("Installed size:") { d.size = v.trim().to_string(); }
        }
    }

    // Rich metadata from Flathub API
    let url = format!("https://flathub.org/api/v2/appstream/{}", actual_id);
    let curl_out = Command::new("curl").args(["-s", "--max-time", "10", &url]).output();
    if let Ok(out) = curl_out {
        if let Ok(text) = String::from_utf8(out.stdout) {
            if let Ok(json) = serde_json::from_str::<serde_json::Value>(&text) {
                if let Some(v) = json["name"].as_str()          { d.name = v.to_string(); }
                if let Some(v) = json["summary"].as_str()       { d.summary = v.to_string(); }
                if let Some(v) = json["description"].as_str()   { d.description = strip_html(v); }
                if let Some(v) = json["developer_name"].as_str(){ d.developer = v.to_string(); }
                if let Some(v) = json["project_license"].as_str(){ d.license = v.to_string(); }
                if let Some(v) = json["urls"]["homepage"].as_str(){ d.homepage = v.to_string(); }

                // Screenshots — each entry has a "sizes" array; pick the first URL
                if let Some(shots) = json["screenshots"].as_array() {
                    for s in shots.iter().take(6) {
                        let url = s["sizes"].as_array()
                            .and_then(|a| a.first())
                            .and_then(|sz| sz["src"].as_str())
                            .or_else(|| s["src"].as_str());
                        if let Some(u) = url { d.screenshots.push(u.to_string()); }
                    }
                }

                // Releases / changelog
                if let Some(releases) = json["releases"].as_array() {
                    for r in releases.iter().take(6) {
                        let version = r["version"].as_str().unwrap_or("").to_string();
                        if version.is_empty() { continue; }
                        let date = r["date"].as_str().map(|s| s.to_string())
                            .or_else(|| r["timestamp"].as_i64().map(format_unix_ts))
                            .unwrap_or_default();
                        let desc = r["description"].as_str()
                            .map(|s| strip_html(s)).unwrap_or_default();
                        if d.last_updated.is_empty() && !date.is_empty() {
                            d.last_updated = date.clone();
                        }
                        d.changelog.push(ChangelogEntry { version, date, description: desc });
                    }
                }
            }
        }
    }
    d
}

pub fn get_pacman_details(name: &str) -> PackageDetails {
    let mut d = PackageDetails {
        source: "pacman".to_string(),
        name: name.to_string(),
        app_id: name.to_string(),
        icon: system_icon(name),
        ..Default::default()
    };

    // Try installed first, fall back to sync database
    let out = Command::new("pacman").args(["-Qi", name]).output()
        .or_else(|_| Command::new("pacman").args(["-Si", name]).output());

    if let Ok(o) = out {
        let text = String::from_utf8_lossy(&o.stdout);
        for line in text.lines() {
            if let Some(colon) = line.find(" : ") {
                let key = line[..colon].trim();
                let val = line[colon + 3..].trim().to_string();
                match key {
                    "Version"                      => d.version = val,
                    "Description"                  => { d.summary = val.clone(); d.description = val; }
                    "URL"                          => d.homepage = val,
                    "Licenses"                     => d.license = val,
                    "Installed Size" | "Download Size" => if d.size.is_empty() { d.size = val; }
                    "Build Date" | "Install Date"  => if d.last_updated.is_empty() { d.last_updated = val; }
                    "Packager"                     => d.developer = val,
                    _ => {}
                }
            }
        }
    }
    d
}

pub fn get_aur_details(name: &str) -> PackageDetails {
    #[derive(Deserialize)]
    #[allow(dead_code)]
    struct AurInfo {
        #[serde(rename = "Name")]       name: String,
        #[serde(rename = "Description")]description: Option<String>,
        #[serde(rename = "Version")]    version: String,
        #[serde(rename = "URL")]        url: Option<String>,
        #[serde(rename = "Maintainer")] maintainer: Option<String>,
        #[serde(rename = "LastModified")]last_modified: Option<i64>,
        #[serde(rename = "License")]    license: Option<Vec<String>>,
    }
    #[derive(Deserialize)]
    struct AurResp { results: Vec<AurInfo> }

    let mut d = PackageDetails {
        source: "aur".to_string(),
        name: name.to_string(),
        app_id: name.to_string(),
        icon: system_icon(name),
        ..Default::default()
    };

    let url = format!("https://aur.archlinux.org/rpc/v5/info?arg[]={}", name);
    if let Ok(out) = Command::new("curl").args(["-s", "--max-time", "10", &url]).output() {
        if let Ok(text) = String::from_utf8(out.stdout) {
            if let Ok(resp) = serde_json::from_str::<AurResp>(&text) {
                if let Some(info) = resp.results.into_iter().next() {
                    d.name    = info.name;
                    d.version = info.version;
                    if let Some(desc) = info.description { d.summary = desc.clone(); d.description = desc; }
                    if let Some(u)    = info.url         { d.homepage = u; }
                    if let Some(m)    = info.maintainer  { d.developer = m; }
                    if let Some(ts)   = info.last_modified { d.last_updated = format_unix_ts(ts); }
                    if let Some(lic)  = info.license     { d.license = lic.join(", "); }
                }
            }
        }
    }
    d
}
