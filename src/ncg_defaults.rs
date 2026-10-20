use base::config::keys;
use hbb_common::config;

const SERVER_HOST: &str = "rust.northwoodscomputerguy.com";
const RELAY_SERVER: &str = "rust.northwoodscomputerguy.com:21117";
const PUBLIC_KEY: &str = "sjVK2P8Cik7MW4v6sn1FhCN5RdRAK1BpqXlSDraF0qY=";

#[cfg(windows)]
pub fn trace(msg: &str) {
    use std::io::Write;
    let dir = "C:\\ProgramData\\NCG";
    let _ = std::fs::create_dir_all(dir);
    if let Ok(mut f) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(format!("{dir}\\ncg_trace.log"))
    {
        let _ = writeln!(
            f,
            "{} pid={} {}",
            chrono::Local::now().format("%H:%M:%S%.3f"),
            std::process::id(),
            msg
        );
    }
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
    let res = std::process::Command::new("cmd")
        .raw_arg(format!(
            "/c for /l %i in (1,1,150) do (sc query \"{app}\" | find \"RUNNING\" >nul && \
             (ping -n 7 127.0.0.1 >nul & start \"\" \"{exe}\" & exit) || ping -n 2 127.0.0.1 >nul)"
        ))
        .creation_flags(0x0800_0000)
        .spawn();
    trace(&format!(
        "relaunch helper ok={:?}",
        res.map(|c| c.id()).map_err(|e| e.to_string())
    ));
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
