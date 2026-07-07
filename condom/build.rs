use std::collections::BTreeSet;
use std::env;
use std::path::PathBuf;

const APPROVAL_GUI_LINK_LIBRARIES: &[&str] = &[
    "cairo",
    "pangocairo-1.0",
    "pango-1.0",
    "pangoxft-1.0",
    "pangoft2-1.0",
    "gobject-2.0",
    "glib-2.0",
];

fn main() {
    if env::var("CARGO_CFG_TARGET_OS").as_deref() != Ok("linux") {
        return;
    }

    println!("cargo:rerun-if-env-changed=CONDOM_APPROVAL_NATIVE_LIB_DIRS");
    println!("cargo:rerun-if-changed=build.rs");

    let library_dirs = approval_gui_library_dirs();
    for library_dir in library_dirs {
        let library_dir = library_dir.display();
        println!("cargo:rustc-link-search=native={library_dir}");
        println!("cargo:rustc-link-arg-bin=condom-approval=-Wl,-rpath,{library_dir}");
    }
    for link_name in APPROVAL_GUI_LINK_LIBRARIES {
        println!("cargo:rustc-link-arg-bin=condom-approval=-l{link_name}");
    }
}

fn approval_gui_library_dirs() -> BTreeSet<PathBuf> {
    let mut library_dirs = BTreeSet::new();
    add_override_library_dirs(&mut library_dirs);
    add_standard_library_dirs(&mut library_dirs);
    library_dirs
}

fn add_override_library_dirs(library_dirs: &mut BTreeSet<PathBuf>) {
    if let Some(value) = env::var_os("CONDOM_APPROVAL_NATIVE_LIB_DIRS") {
        library_dirs.extend(env::split_paths(&value).filter(|path| path.is_dir()));
    }
}

fn add_standard_library_dirs(library_dirs: &mut BTreeSet<PathBuf>) {
    for path in [
        "/usr/lib",
        "/usr/lib64",
        "/usr/lib/x86_64-linux-gnu",
        "/usr/local/lib",
        "/usr/local/lib64",
    ] {
        let path = PathBuf::from(path);
        if path.is_dir() {
            library_dirs.insert(path);
        }
    }
}
