use base::config::keys;
use hbb_common::config;

const SERVER_HOST: &str = "rust.northwoodscomputerguy.com";
const RELAY_SERVER: &str = "rust.northwoodscomputerguy.com:21117";
const PUBLIC_KEY: &str = "sjVK2P8Cik7MW4v6sn1FhCN5RdRAK1BpqXlSDraF0qY=";
const APP_NAME: &str = "NCG_Remote_Assistance";

// Public-facing name (shortcuts, Programs list, service, tray). APP_NAME itself must stay
// space-free: it is the service, exe and config folder name used in unquoted commands.
pub fn display_name() -> String {
    config::APP_NAME
        .read()
        .map(|n| n.replace('_', " "))
        .unwrap_or_default()
}

#[cfg(windows)]
pub fn spawn_relaunch_helper() {
    use std::os::windows::process::CommandExt;
    let app = config::APP_NAME
        .read()
        .map(|n| n.clone())
        .unwrap_or_default();
    let (_, _, _, exe) = crate::platform::windows::get_install_info();
    if app.is_empty() || exe.is_empty() || exe.contains(['%', '^', '&', '!', '"']) {
        return;
    }
    if let Err(e) = std::process::Command::new("cmd")
        .raw_arg(format!(
            "/c for /l %i in (1,1,150) do (sc query \"{app}\" | find \"RUNNING\" >nul && \
             (ping -n 7 127.0.0.1 >nul & start \"\" \"{exe}\" & exit) || ping -n 2 127.0.0.1 >nul)"
        ))
        .creation_flags(0x0800_0000)
        .spawn()
    {
        hbb_common::log::warn!("relaunch helper failed: {e}");
    }
}

// A second copy (e.g. the unpacked Setup EXE) cannot start its own server while the
// installed service owns it. Same-size check: only hand off to an identical build,
// so a newer Setup never silently opens an older install.
#[cfg(windows)]
pub fn hand_off_to_installed() -> bool {
    if crate::platform::is_cur_exe_the_installed() || !crate::platform::is_self_service_running()
    {
        return false;
    }
    let (_, _, _, exe) = crate::platform::windows::get_install_info();
    let same_build = match (std::env::current_exe().and_then(std::fs::metadata), std::fs::metadata(&exe)) {
        (Ok(a), Ok(b)) => a.len() == b.len(),
        _ => false,
    };
    if !same_build {
        return false;
    }
    match std::process::Command::new(&exe).spawn() {
        Ok(_) => true,
        Err(e) => {
            hbb_common::log::warn!("hand off to installed copy failed: {e}");
            false
        }
    }
}

#[cfg(windows)]
pub fn uninstall_cleanup_cmds() -> String {
    let app = config::APP_NAME
        .read()
        .map(|n| n.clone())
        .unwrap_or_default();
    let user_logs = config::Config::log_path().to_string_lossy().into_owned();
    let dirs = [
        format!("C:\\Windows\\ServiceProfiles\\LocalService\\AppData\\Roaming\\{app}"),
        user_logs,
    ];
    let mut cmds = String::new();
    for dir in dirs {
        let safe = !app.is_empty()
            && (dir.ends_with(&format!("\\{app}")) || dir.ends_with(&format!("\\{app}\\log")))
            && !dir.contains(['%', '^', '&', '!', '"']);
        if safe {
            cmds.push_str(&format!("\nif exist \"{dir}\" rd /s /q \"{dir}\"\n"));
        }
    }
    cmds
}

pub fn apply() {
    if let Ok(mut app) = config::APP_NAME.write() {
        *app = APP_NAME.to_owned();
    }
    let Ok(mut overwrite) = config::OVERWRITE_SETTINGS.write() else {
        hbb_common::log::error!("NCG defaults: settings lock poisoned");
        return;
    };
    for (k, v) in [
        (keys::OPTION_CUSTOM_RENDEZVOUS_SERVER, SERVER_HOST),
        (keys::OPTION_RELAY_SERVER, RELAY_SERVER),
        (keys::OPTION_KEY, PUBLIC_KEY),
        (keys::OPTION_ENABLE_CHECK_UPDATE, "N"),
        (keys::OPTION_ALLOW_AUTO_UPDATE, "N"),
    ] {
        overwrite.insert(k.to_owned(), v.to_owned());
    }
}
