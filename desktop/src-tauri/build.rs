fn main() {
    // The website may only call these two: the taskbar badge and the seasonal window icon.
    tauri_build::try_build(
        tauri_build::Attributes::new()
            .app_manifest(tauri_build::AppManifest::new().commands(&["set_unread", "set_season_icon"])),
    )
    .expect("failed to run tauri build script");
}
