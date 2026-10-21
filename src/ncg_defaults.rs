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
            // g is set once the old service has stopped (upgrade) or at once (first install);
            // only then wait for the new service to run, so the relaunched window is not
            // killed by the install script that is still replacing files.
            "/c {start}for /l %i in (1,1,150) do (if not defined g (sc query \"{app}\" | find \"RUNNING\" >nul \
             && ping -n 2 127.0.0.1 >nul || set g=1)) & \
             for /l %i in (1,1,150) do (if defined g (sc query \"{app}\" | find \"RUNNING\" >nul && \
             (ping -n 7 127.0.0.1 >nul & start \"\" \"{exe}\" & exit) || ping -n 2 127.0.0.1 >nul) \
             else ping -n 2 127.0.0.1 >nul)",
            start = if crate::platform::is_self_service_running() { "" } else { "set g=1 & " },
        ))
        .creation_flags(0x0800_0000)
        .spawn()
    {
        hbb_common::log::warn!("relaunch helper failed: {e}");
    }
}

// A second copy (e.g. the unpacked Setup EXE) cannot start its own server while the
// installed service owns it. Same-build check: only hand off to an identical build,
// so a newer Setup never silently opens an older install.
// Our own version, bumped with kNcgVersion and libs/portable. Stored as the installed
// program's DisplayVersion so a newer Setup can tell it is an upgrade.
pub const NCG_VERSION: &str = "1.5.0.9";

#[cfg(windows)]
fn installed_version() -> String {
    use winreg::{enums::*, RegKey};
    let app = config::APP_NAME.read().map(|n| n.clone()).unwrap_or_default();
    RegKey::predef(HKEY_LOCAL_MACHINE)
        .open_subkey(format!(
            "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{app}"
        ))
        .and_then(|k| k.get_value::<String, _>("DisplayVersion"))
        .unwrap_or_default()
}

// A different build is installed: ask before showing the normal screen.
// Returns true when this process should exit (handled or cancelled).
#[cfg(windows)]
fn offer_upgrade(installed_exe: &str) -> bool {
    use winapi::um::winuser::{
        MessageBoxW, IDNO, IDYES, MB_ICONQUESTION, MB_SETFOREGROUND, MB_TOPMOST, MB_YESNOCANCEL,
    };
    let wide = |s: &str| s.encode_utf16().chain(std::iter::once(0)).collect::<Vec<u16>>();
    let old = installed_version();
    let old = if old.is_empty() || old == "1.5.0" { "an older version".to_owned() } else { format!("version {old}") };
    let name = display_name();
    let text = wide(&format!(
        "{name} is already installed ({old}). This is version {NCG_VERSION}.\n\n\
         Yes: upgrade now (keeps your ID, peers and settings)\n\
         No: open the installed version instead\n\
         Cancel: do nothing"
    ));
    let caption = wide(&format!("{name} {NCG_VERSION}"));
    let answer = unsafe {
        MessageBoxW(
            std::ptr::null_mut(),
            text.as_ptr(),
            caption.as_ptr(),
            MB_YESNOCANCEL | MB_ICONQUESTION | MB_SETFOREGROUND | MB_TOPMOST,
        )
    };
    match answer {
        IDYES => {
            spawn_relaunch_helper();
            match crate::platform::windows::install_me("startmenu desktopicon", "".to_owned(), false, false) {
                Ok(_) => true,
                Err(e) => {
                    hbb_common::log::warn!("upgrade failed: {e}");
                    let msg = wide(&format!("The upgrade did not finish. Nothing was changed.\n\n{e}"));
                    unsafe { MessageBoxW(std::ptr::null_mut(), msg.as_ptr(), caption.as_ptr(), MB_SETFOREGROUND | MB_TOPMOST) };
                    false
                }
            }
        }
        IDNO => {
            if let Err(e) = std::process::Command::new(installed_exe).spawn() {
                hbb_common::log::warn!("open installed copy failed: {e}");
                return false;
            }
            true
        }
        _ => true,
    }
}

#[cfg(windows)]
pub fn hand_off_to_installed() -> bool {
    if crate::platform::is_cur_exe_the_installed() || !crate::platform::is_self_service_running()
    {
        return false;
    }
    let (_, _, _, exe) = crate::platform::windows::get_install_info();
    // The launcher exe is identical in every build; the code is in librustdesk.dll,
    // so compare the recorded version and the dll size.
    let dll_len = |exe: &std::path::Path| {
        exe.parent()
            .and_then(|d| std::fs::metadata(d.join("librustdesk.dll")).ok())
            .map(|m| m.len())
    };
    let same_build = installed_version() == NCG_VERSION
        && match std::env::current_exe() {
            Ok(cur) => {
                let (a, b) = (dll_len(&cur), dll_len(std::path::Path::new(&exe)));
                a.is_some() && a == b
            }
            Err(_) => false,
        };
    if !same_build {
        return offer_upgrade(&exe);
    }
    match std::process::Command::new(&exe).spawn() {
        Ok(_) => true,
        Err(e) => {
            hbb_common::log::warn!("hand off to installed copy failed: {e}");
            false
        }
    }
}

fn bad_cmd_chars(s: &str) -> bool {
    s.contains(['%', '^', '&', '!', '"', '\r', '\n', '|', '<', '>'])
}

// Old NCG wrapper installs (stock RustDesk MSI configured for our server) and
// older builds of this app (underscore shortcut names). Cleans only what is
// ours; a RustDesk the customer set up for themselves is left alone.
#[cfg(windows)]
fn legacy_wrapper_install() -> bool {
    let appdata = std::env::var("APPDATA").unwrap_or_default();
    let toml = std::fs::read_to_string(format!("{appdata}\\RustDesk\\config\\RustDesk2.toml"))
        .unwrap_or_default();
    toml.contains("northwoodscomputerguy")
        || std::path::Path::new(r"C:\ProgramData\NCG\NCG_RustDesk_Setup").is_dir()
}

// Copies saved peers of the old RustDesk into this app (never overwrites).
// Returns false if anything failed, so the old data is then kept.
#[cfg(windows)]
fn migrate_legacy_peers(appdata: &str) -> bool {
    let src = std::path::PathBuf::from(format!("{appdata}\\RustDesk\\config\\peers"));
    let Ok(entries) = std::fs::read_dir(&src) else {
        return true;
    };
    let dst = config::Config::path("peers");
    if std::fs::create_dir_all(&dst).is_err() {
        return false;
    }
    let mut ok = true;
    for e in entries.flatten() {
        let from = e.path();
        let Some(name) = from.file_name() else { continue };
        let to = dst.join(name);
        if to.exists() {
            continue;
        }
        let mtime = e.metadata().and_then(|m| m.modified()).ok();
        match std::fs::copy(&from, &to) {
            Ok(_) => {
                if let (Some(t), Ok(f)) = (mtime, std::fs::OpenOptions::new().write(true).open(&to)) {
                    let _ = f.set_modified(t);
                }
            }
            Err(e) => {
                hbb_common::log::warn!("legacy peer copy failed: {e}");
                ok = false;
            }
        }
    }
    ok
}

#[cfg(windows)]
fn legacy_msi_cmds() -> String {
    use winreg::{enums::*, RegKey};
    let mut cmds = String::new();
    for sub in [
        r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    ] {
        let Ok(root) = RegKey::predef(HKEY_LOCAL_MACHINE).open_subkey(sub) else {
            continue;
        };
        for name in root.enum_keys().flatten() {
            let Ok(k) = root.open_subkey(&name) else { continue };
            let dn: String = k.get_value("DisplayName").unwrap_or_default();
            if dn != "RustDesk" || bad_cmd_chars(&name) {
                continue;
            }
            let is_guid = name.starts_with('{')
                && name.ends_with('}')
                && name.chars().all(|c| c.is_ascii_hexdigit() || "{}-".contains(c));
            if is_guid {
                cmds.push_str(&format!("start /wait \"\" msiexec /x {name} /qn /norestart\n"));
            }
            cmds.push_str(&format!("reg delete \"HKLM\\{sub}\\{name}\" /f\n"));
        }
    }
    cmds
}

// Commands added to the elevated install script.
#[cfg(windows)]
pub fn install_cleanup_cmds(start_menu: &str) -> String {
    let app = config::APP_NAME.read().map(|n| n.clone()).unwrap_or_default();
    if app.is_empty() || bad_cmd_chars(&app) || bad_cmd_chars(start_menu) {
        return String::new();
    }
    let sm = "%PROGRAMDATA%\\Microsoft\\Windows\\Start Menu\\Programs";
    // shortcuts named with underscores by v1.5.0.2 and earlier
    let mut cmds = format!(
        "
if exist \"%PUBLIC%\\Desktop\\{app}.lnk\" del /f /q \"%PUBLIC%\\Desktop\\{app}.lnk\"
if exist \"{start_menu}\\{app}.lnk\" del /f /q \"{start_menu}\\{app}.lnk\"
if exist \"{start_menu}\\Uninstall {app}.lnk\" del /f /q \"{start_menu}\\Uninstall {app}.lnk\"
if exist \"{sm}\\Startup\\{app} Tray.lnk\" del /f /q \"{sm}\\Startup\\{app} Tray.lnk\"
"
    );
    let appdata = std::env::var("APPDATA").unwrap_or_default();
    if !legacy_wrapper_install() || appdata.is_empty() || bad_cmd_chars(&appdata) {
        return cmds;
    }
    let peers_ok = migrate_legacy_peers(&appdata);
    cmds.push_str(
        "
sc stop RustDesk
sc delete RustDesk
taskkill /F /IM rustdesk.exe
",
    );
    cmds.push_str(&legacy_msi_cmds());
    cmds.push_str(&format!(
        "
netsh advfirewall firewall delete rule name=\"RustDesk Service\"
if exist \"C:\\Program Files\\RustDesk\" rd /s /q \"C:\\Program Files\\RustDesk\"
if exist \"C:\\Program Files (x86)\\RustDesk\" rd /s /q \"C:\\Program Files (x86)\\RustDesk\"
if exist \"%PUBLIC%\\Desktop\\RustDesk.lnk\" del /f /q \"%PUBLIC%\\Desktop\\RustDesk.lnk\"
if exist \"{sm}\\RustDesk\" rd /s /q \"{sm}\\RustDesk\"
if exist \"{sm}\\Startup\\RustDesk Tray.lnk\" del /f /q \"{sm}\\Startup\\RustDesk Tray.lnk\"
if exist \"{sm}\\Startup\\RustDesk.lnk\" del /f /q \"{sm}\\Startup\\RustDesk.lnk\"
if exist \"C:\\ProgramData\\NCG\\ncg_remote.ico\" del /f /q \"C:\\ProgramData\\NCG\\ncg_remote.ico\"
if exist \"C:\\ProgramData\\NCG\\NCG_RustDesk_Setup\" rd /s /q \"C:\\ProgramData\\NCG\\NCG_RustDesk_Setup\"
if exist \"C:\\Windows\\ServiceProfiles\\LocalService\\AppData\\Roaming\\RustDesk\" rd /s /q \"C:\\Windows\\ServiceProfiles\\LocalService\\AppData\\Roaming\\RustDesk\"
"
    ));
    if peers_ok {
        cmds.push_str(&format!(
            "if exist \"{appdata}\\RustDesk\" rd /s /q \"{appdata}\\RustDesk\"\n"
        ));
    }
    cmds
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
    // set only by the developer-mode erase button, for that one run
    if std::env::var("NCG_ERASE_SETTINGS").as_deref() == Ok("1") {
        if let Some(root) = config::Config::path("").parent() {
            let root = root.to_string_lossy().into_owned();
            if !app.is_empty() && root.ends_with(&format!("\\{app}")) && !bad_cmd_chars(&root) {
                cmds.push_str(&format!("\nif exist \"{root}\" rd /s /q \"{root}\"\n"));
            }
        }
    }
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
