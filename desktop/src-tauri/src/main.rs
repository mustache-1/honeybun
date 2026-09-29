// Honeybun for Windows: one window showing https://honeybun.me.
// Everything lives on the server, so the desktop app, phones and the website always show the same data,
// and every website deploy shows up here without reinstalling.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use tauri::{Url, WebviewUrl, WebviewWindowBuilder};

const HOME: &str = "https://honeybun.me/?app=desktop";

// Pages that stay inside the window. Anything else (mail links, Buy me a coffee, help articles)
// opens in the person's normal browser instead.
fn stays_inside(url: &Url) -> bool {
    match url.scheme() {
        "about" | "data" | "blob" => true,
        "https" => matches!(url.host_str(), Some(h) if h == "honeybun.me" || h.ends_with(".honeybun.me")),
        _ => false,
    }
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .setup(|app| {
            WebviewWindowBuilder::new(app, "main", WebviewUrl::External(HOME.parse().expect("valid url")))
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
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running Honeybun");
}
