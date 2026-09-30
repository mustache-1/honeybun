fn main() {
    // The website may only call these: the taskbar badge, the seasonal window icon and \"Check for updates\".
    tauri_build::try_build(
        tauri_build::Attributes::new()
            .app_manifest(tauri_build::AppManifest::new().commands(&["set_unread", "set_season_icon", "check_for_update"])),
    )
    .expect("failed to run tauri build script");
}
