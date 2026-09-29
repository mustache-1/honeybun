fn main() {
    // `set_unread` is the only command the website may call: it updates the taskbar badge.
    tauri_build::try_build(
        tauri_build::Attributes::new()
            .app_manifest(tauri_build::AppManifest::new().commands(&["set_unread"])),
    )
    .expect("failed to run tauri build script");
}
