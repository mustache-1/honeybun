// Keeps Honeybun for Windows up to date without asking anyone to reinstall.
// It asks honeybun.me which version is newest; if that's newer than this app, it downloads the installer
// from honeybun.me and runs it silently. The installer closes this window, installs over the old copy
// and opens Honeybun again. It uses curl.exe, which ships with Windows 10/11, so it adds nothing to the app.
use std::process::Command;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

const VERSION_URL: &str = "https://honeybun.me/download/windows/version";
const INSTALLER_URL: &str = "https://honeybun.me/download/windows";

pub const THIS_VERSION: &str = env!("CARGO_PKG_VERSION");

fn parts(v: &str) -> Option<Vec<u32>> {
    let p: Option<Vec<u32>> = v.trim().trim_start_matches('v').split('.').map(|n| n.parse().ok()).collect();
    p.filter(|p| !p.is_empty())
}

// true when `latest` is a higher version than `current`
pub fn is_newer(latest: &str, current: &str) -> bool {
    match (parts(latest), parts(current)) {
        (Some(mut a), Some(mut b)) => {
            let n = a.len().max(b.len());
            a.resize(n, 0);
            b.resize(n, 0);
            a > b
        }
        _ => false,
    }
}

fn curl() -> Command {
    let mut c = Command::new("curl.exe");
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        c.creation_flags(0x0800_0000); // no console window
    }
    c
}

fn now() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0)
}

// Downloads and starts the installer. Returns true when the installer was started (the app should then exit).
// `quiet_ok` is false when someone is using the window, so a background check never interrupts them.
pub fn check_and_install(quiet_ok: bool) -> bool {
    let out = match curl().args(["-fsSL", "--max-time", "20", VERSION_URL]).output() {
        Ok(o) if o.status.success() => o,
        _ => return false,
    };
    let latest = String::from_utf8_lossy(&out.stdout).trim().to_string();
    if !is_newer(&latest, THIS_VERSION) || !quiet_ok {
        return false;
    }
    let dir = std::env::temp_dir();
    // never retry the same version within an hour, so a stale cache can't cause an install loop
    let mark = dir.join("honeybun-update-tried.txt");
    if let Ok(s) = std::fs::read_to_string(&mark) {
        let mut it = s.trim().split(' ');
        if let (Some(v), Some(t)) = (it.next(), it.next().and_then(|t| t.parse::<u64>().ok())) {
            if v == latest && now().saturating_sub(t) < 3600 {
                return false;
            }
        }
    }
    let _ = std::fs::write(&mark, format!("{} {}", latest, now()));
    let exe = dir.join("Honeybun-Setup-update.exe");
    let ok = curl()
        .args(["-fsSL", "--max-time", "300", "-o"])
        .arg(&exe)
        .arg(INSTALLER_URL)
        .status()
        .map(|s| s.success())
        .unwrap_or(false);
    // a real installer is several MB; anything tiny is an error page
    if !ok || std::fs::metadata(&exe).map(|m| m.len()).unwrap_or(0) < 1_000_000 {
        let _ = std::fs::remove_file(&exe);
        return false;
    }
    Command::new(&exe).args(["/S", "/UPDATE"]).spawn().is_ok()
}

pub fn every(hours: u64) -> Duration {
    Duration::from_secs(hours * 3600)
}

#[cfg(test)]
mod tests {
    use super::is_newer;
    #[test]
    fn compares() {
        assert!(is_newer("1.0.4", "1.0.3"));
        assert!(is_newer("1.1", "1.0.9"));
        assert!(is_newer("v2.0.0", "1.9.9"));
        assert!(!is_newer("1.0.3", "1.0.3"));
        assert!(!is_newer("1.0.2", "1.0.3"));
        assert!(!is_newer("<html>", "1.0.3"));
    }
}
