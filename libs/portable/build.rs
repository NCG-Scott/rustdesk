fn main() {
    #[cfg(windows)]
    {
        use std::io::Write;
        let mut res = winres::WindowsResource::new();
        res.set_version_info(winres::VersionInfo::FILEVERSION, 0x0001_0005_0000_0005)
            .set_version_info(winres::VersionInfo::PRODUCTVERSION, 0x0001_0005_0000_0005)
            .set_icon("../../res/icon.ico")
            .set_language(winapi::um::winnt::MAKELANGID(
                winapi::um::winnt::LANG_ENGLISH,
                winapi::um::winnt::SUBLANG_ENGLISH_US,
            ))
            .set_manifest_file("../../res/manifest.xml");
        match res.compile() {
            Err(e) => {
                write!(std::io::stderr(), "{}", e).unwrap();
                std::process::exit(1);
            }
            Ok(_) => {}
        }
    }
}
