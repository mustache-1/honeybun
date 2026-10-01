// Honeybun for Windows: one window showing https://honeybun.me.
// Everything lives on the server, so the desktop app, phones and the website always show the same data,
// and every website deploy shows up here without reinstalling.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod update;

use std::sync::atomic::{AtomicU32, Ordering};
use std::time::Duration;
use tauri::menu::{Menu, MenuItem};
use tauri::tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent};
use tauri::{image::Image, AppHandle, Manager, WindowEvent, Url, UserAttentionType, WebviewUrl, WebviewWindow, WebviewWindowBuilder};

const HOME: &str = "https://honeybun.me/?app=desktop";

// Pages that stay inside the window. Anything else (mail links, Buy me a coffee, help articles)
// opens in the person's normal browser instead.
fn stays_inside(url: &Url) -> bool {
    match url.scheme() {
        "about" | "data" | "blob" | "tauri" => true,
        "http" => matches!(url.host_str(), Some("tauri.localhost")),
        "https" => matches!(url.host_str(), Some(h) if h == "honeybun.me" || h.ends_with(".honeybun.me")),
        _ => false,
    }
}

// A small red dot with a white ring, shown over the taskbar icon while something is unread (like Discord).
fn badge_dot() -> Image<'static> {
    const S: u32 = 32;
    let mut px = vec![0u8; (S * S * 4) as usize];
    let c = (S as f32 - 1.0) / 2.0;
    for y in 0..S {
        for x in 0..S {
            let d = ((x as f32 - c).powi(2) + (y as f32 - c).powi(2)).sqrt();
            let i = ((y * S + x) * 4) as usize;
            let (rgb, a) = if d <= 12.5 { ([229u8, 72, 77], 1.0) } else if d <= 15.5 { ([255u8, 255, 255], 1.0) } else if d <= 16.2 { ([255u8, 255, 255], 16.2 - d) } else { ([0u8, 0, 0], 0.0) };
            px[i..i + 3].copy_from_slice(&rgb);
            px[i + 3] = (a * 255.0) as u8;
        }
    }
    Image::new_owned(px, S, S)
}

static UNREAD: AtomicU32 = AtomicU32::new(0);

// Called by honeybun.me with the number of unread things (Bun's inbox + new updates).
// Shows or clears the red dot, and flashes the taskbar button when the count goes up while
// the window isn't in front. It never takes focus, so it won't pull you out of a game.
#[tauri::command]
fn set_unread(window: WebviewWindow, count: u32) {
    let before = UNREAD.swap(count, Ordering::Relaxed);
    if count == before {
        return;
    }
    let _ = window.set_overlay_icon(if count > 0 { Some(badge_dot()) } else { None });
    if count > before && !window.is_focused().unwrap_or(true) {
        let _ = window.request_user_attention(Some(UserAttentionType::Informational));
    }
}

// Halloween: honeybun.me tells the app whether to show the witch-hat Bun in the window and taskbar.
// (The .exe file and its Start menu shortcut keep the normal icon; those are fixed when installed.)
#[tauri::command]
fn set_season_icon(window: WebviewWindow, on: bool) {
    let bytes: &[u8] = if on { include_bytes!("../assets/halloween.png") } else { include_bytes!("../icons/icon.png") };
    if let Ok(img) = Image::from_bytes(bytes) {
        let _ = window.set_icon(img);
    }
}

// a JavaScript string literal for the opening screen's status text
fn serde_json_str(s: &str) -> String {
    let mut o = String::from("\"");
    for c in s.chars() {
        match c {
            '"' => o.push_str("\\\""),
            '\\' => o.push_str("\\\\"),
            '\n' => o.push_str("\\n"),
            c => o.push(c),
        }
    }
    o.push('"');
    o
}

// "Check for updates" in the side menu. Returns right away; progress and the result come back to the page
// through window.hbUpdateStatus(state, text, percent) so the button can show them.
#[tauri::command]
fn check_for_update(window: WebviewWindow) {
    std::thread::spawn(move || {
        let send = |state: &str, text: &str, pct: Option<u32>| {
            let js = format!(
                "window.hbUpdateStatus&&window.hbUpdateStatus({},{},{})",
                serde_json_str(state),
                serde_json_str(text),
                pct.map(|p| p.to_string()).unwrap_or("null".into())
            );
            let _ = window.eval(&js);
        };
        send("checking", "Checking for updates…", None);
        let out = update::run(true, true, &|msg, pct| send("downloading", msg, pct));
        match out {
            update::Outcome::Installing => {
                send("installing", "Installing… Honeybun will reopen", Some(100));
                std::thread::sleep(Duration::from_secs(3));
                window.app_handle().exit(0);
            }
            update::Outcome::UpToDate => send("current", "Up to date", None),
            update::Outcome::Unknown => send("error", "Couldn't check right now", None),
        }
    });
}

fn show_main(app: &AppHandle) {
    if let Some(w) = app.get_webview_window("main") {
        let _ = w.eval("window.hbNativeHidden=false;window.dispatchEvent(new Event('hb-native-visibility'))");
        let _ = w.show();
        let _ = w.unminimize();
        let _ = w.set_focus();
    }
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        // opening Honeybun again while Bun waits in the tray just brings the window back
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| show_main(app)))
        // the X button tucks Honeybun into the tray instead of quitting; "Quit Honeybun" in the tray menu really closes it
        .on_window_event(|window, event| {
            if let WindowEvent::CloseRequested { api, .. } = event {
                api.prevent_close();
                // tell the page it is hidden so it stops animating and refreshing while Bun waits in the tray
                if let Some(w) = window.app_handle().get_webview_window("main") {
                    let _ = w.eval("window.hbNativeHidden=true;window.dispatchEvent(new Event('hb-native-visibility'))");
                }
                let _ = window.hide();
            }
        })
        .invoke_handler(tauri::generate_handler![set_unread, set_season_icon, check_for_update])
        .setup(|app| {
            let win = WebviewWindowBuilder::new(app, "main", WebviewUrl::App("index.html".into()))
                .title("Honeybun")
                .inner_size(1280.0, 820.0)
                .min_inner_size(900.0, 600.0)
                .center()
                .on_navigation(|url| {
                    if stays_inside(url) {
                        return true;
                    }
                    let _ = tauri_plugin_opener::open_url(url.as_str(), None::<&str>);
                    false
                })
                .build()?;
            let open = MenuItem::with_id(app, "open", "Open Honeybun", true, None::<&str>)?;
            let quit = MenuItem::with_id(app, "quit", "Quit Honeybun", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&open, &quit])?;
            TrayIconBuilder::new()
                .icon(Image::from_bytes(include_bytes!("../icons/64x64.png"))?)
                .tooltip("Honeybun")
                .menu(&menu)
                .show_menu_on_left_click(false)
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "open" => show_main(app),
                    "quit" => app.exit(0),
                    _ => {}
                })
                .on_tray_icon_event(|tray, event| {
                    if let TrayIconEvent::Click { button: MouseButton::Left, button_state: MouseButtonState::Up, .. } = event {
                        show_main(tray.app_handle());
                    }
                })
                .build(app)?;
            // The opening screen (dist/index.html) shows "checking for updates" under Bun, installs a newer
            // version if there is one, and then goes on to honeybun.me. After that it re-checks every 6 hours,
            // only while the window isn't in use.
            let handle = app.handle().clone();
            std::thread::spawn(move || {
                let say = |msg: &str, pct: Option<u32>| {
                    let js = format!("window.hbStatus&&window.hbStatus({},{})", serde_json_str(msg), pct.map(|p| p.to_string()).unwrap_or("null".into()));
                    let _ = win.eval(&js);
                };
                std::thread::sleep(Duration::from_millis(500)); // let the opening screen load first
                say("Checking for updates…", None);
                let started = std::time::Instant::now();
                let out = update::run(true, false, &say);
                if let update::Outcome::Installing = out {
                    std::thread::sleep(Duration::from_secs(3));
                    handle.exit(0);
                    return;
                }
                say(if let update::Outcome::UpToDate = out { "Honeybun is up to date" } else { "Opening Honeybun…" }, Some(100));
                // keep the opening screen up long enough to read
                if let Some(rest) = Duration::from_millis(1400).checked_sub(started.elapsed()) {
                    std::thread::sleep(rest);
                }
                let _ = win.navigate(HOME.parse().expect("valid url"));
                loop {
                    std::thread::sleep(update::every(6));
                    let idle = handle.get_webview_window("main").map(|w| !w.is_focused().unwrap_or(false)).unwrap_or(true);
                    if let update::Outcome::Installing = update::run(idle, false, &|_, _| {}) {
                        std::thread::sleep(Duration::from_secs(3));
                        handle.exit(0);
                        return;
                    }
                }
            });
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running Honeybun");
}
