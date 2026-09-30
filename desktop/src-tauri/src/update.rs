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

pub enum Outcome {
    // the installer was started; the app should close so it can replace the files
    Installing,
    UpToDate,
    // couldn't reach honeybun.me (offline, or the version file isn't published yet)
    Unknown,
}

// total size of the installer, so the splash can show a real percentage
fn installer_size() -> Option<u64> {
    let out = curl().args(["-sIL", "--max-time", "10", INSTALLER_URL]).output().ok()?;
    String::from_utf8_lossy(&out.stdout)
        .lines()
        .filter_map(|l| l.to_ascii_lowercase().strip_prefix("content-length:").and_then(|v| v.trim().parse::<u64>().ok()))
        .last()
}

// Looks for a newer version and, if there is one, downloads and starts the installer.
// `progress` gets a short message and an optional percentage for the opening screen.
// `force` skips the once-an-hour retry guard (someone clicked "Check for updates").
// `quiet_ok` is false when someone is using the window, so a background check never interrupts them.
pub fn run(quiet_ok: bool, force: bool, progress: &dyn Fn(&str, Option<u32>)) -> Outcome {
    let out = match curl().args(["-fsSL", "--max-time", "10", VERSION_URL]).output() {
        Ok(o) if o.status.success() => o,
        _ => return Outcome::Unknown,
    };
    let latest = String::from_utf8_lossy(&out.stdout).trim().to_string();
    if parts(&latest).is_none() {
        return Outcome::Unknown;
    }
    if !is_newer(&latest, THIS_VERSION) || !quiet_ok {
        return Outcome::UpToDate;
    }
    let dir = std::env::temp_dir();
    // never retry the same version within an hour, so a stale cache can't cause an install loop
    let mark = dir.join("honeybun-update-tried.txt");
    if let Some(s) = std::fs::read_to_string(&mark).ok().filter(|_| !force) {
        let mut it = s.trim().split(' ');
        if let (Some(v), Some(t)) = (it.next(), it.next().and_then(|t| t.parse::<u64>().ok())) {
            if v == latest && now().saturating_sub(t) < 3600 {
                return Outcome::UpToDate;
            }
        }
    }
    let _ = std::fs::write(&mark, format!("{} {}", latest, now()));
    let msg = format!("Downloading Honeybun {}…", latest.trim_start_matches('v'));
    progress(&msg, Some(0));
    let total = installer_size();
    let exe = dir.join("Honeybun-Setup-update.exe");
    let _ = std::fs::remove_file(&exe);
    let mut child = match curl().args(["-fsSL", "--max-time", "300", "-o"]).arg(&exe).arg(INSTALLER_URL).spawn() {
        Ok(c) => c,
        Err(_) => return Outcome::Unknown,
    };
    let ok = loop {
        match child.try_wait() {
            Ok(Some(st)) => break st.success(),
            Ok(None) => {
                let have = std::fs::metadata(&exe).map(|m| m.len()).unwrap_or(0);
                progress(&msg, total.filter(|t| *t > 0).map(|t| ((have * 100 / t).min(99)) as u32));
                std::thread::sleep(Duration::from_millis(250));
            }
            Err(_) => break false,
        }
    };
    // a real installer is several MB; anything tiny is an error page
    if !ok || std::fs::metadata(&exe).map(|m| m.len()).unwrap_or(0) < 1_000_000 {
        let _ = std::fs::remove_file(&exe);
        return Outcome::Unknown;
    }
    progress("Installing… Honeybun will reopen by itself", Some(100));
    if Command::new(&exe).args(["/S", "/UPDATE"]).spawn().is_ok() {
        Outcome::Installing
    } else {
        Outcome::Unknown
    }
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
