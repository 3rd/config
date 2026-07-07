use std::fmt;
use std::fs::OpenOptions;
use std::io::Write;
use std::path::PathBuf;

pub const FORWARDED_DEBUG_ENV: &str = "CONDOM_DEBUG";
pub const DEBUG_LOG_ENV: &str = "CONDOM_DEBUG_LOG";

pub fn enabled() -> bool {
    std::env::var("DEBUG")
        .ok()
        .or_else(|| std::env::var(FORWARDED_DEBUG_ENV).ok())
        .is_some_and(|value| value_enabled(&value))
        || log_path().is_some()
}

pub fn log_path() -> Option<PathBuf> {
    std::env::var_os(DEBUG_LOG_ENV)
        .filter(|value| !value.is_empty())
        .map(PathBuf::from)
}

pub fn log_startup(binary: &str) {
    log(format_args!(
        "{binary} start args={:?} cwd={} euid={} egid={}",
        std::env::args().collect::<Vec<_>>(),
        std::env::current_dir()
            .map(|path| path.display().to_string())
            .unwrap_or_else(|error| format!("<unavailable: {error}>")),
        unsafe { libc::geteuid() },
        unsafe { libc::getegid() },
    ));
}

pub fn log(args: fmt::Arguments<'_>) {
    if enabled() {
        let line = format!("condom: debug: pid={} {args}", std::process::id());
        eprintln!("{line}");
        append_log_file(&line);
    }
}

#[macro_export]
macro_rules! debug_log {
    ($($arg:tt)*) => {
        $crate::app::debug::log(format_args!($($arg)*))
    };
}

fn value_enabled(value: &str) -> bool {
    matches!(value, "1" | "true" | "TRUE" | "True")
}

fn append_log_file(line: &str) {
    let Some(path) = log_path() else {
        return;
    };
    if let Some(parent) = path.parent() {
        if let Err(error) = std::fs::create_dir_all(parent) {
            eprintln!(
                "condom: debug: failed to create debug log dir {}: {error}",
                parent.display()
            );
            return;
        }
    }
    match OpenOptions::new().create(true).append(true).open(&path) {
        Ok(mut file) => {
            if let Err(error) = writeln!(file, "{line}") {
                eprintln!(
                    "condom: debug: failed to write debug log {}: {error}",
                    path.display()
                );
            }
        }
        Err(error) => eprintln!(
            "condom: debug: failed to open debug log {}: {error}",
            path.display()
        ),
    }
}

#[cfg(test)]
mod tests {
    use std::sync::Mutex;

    static ENV_LOCK: Mutex<()> = Mutex::new(());

    #[test]
    fn debug_env_accepts_true_and_one_only() {
        let _guard = ENV_LOCK.lock().unwrap();
        let previous = std::env::var_os("DEBUG");
        let previous_forwarded = std::env::var_os(super::FORWARDED_DEBUG_ENV);
        std::env::remove_var(super::FORWARDED_DEBUG_ENV);

        std::env::set_var("DEBUG", "1");
        assert!(super::enabled());
        std::env::set_var("DEBUG", "true");
        assert!(super::enabled());
        std::env::set_var("DEBUG", "0");
        assert!(!super::enabled());
        std::env::set_var("DEBUG", "false");
        assert!(!super::enabled());
        std::env::remove_var("DEBUG");
        std::env::set_var(super::FORWARDED_DEBUG_ENV, "1");
        assert!(super::enabled());

        if let Some(previous) = previous {
            std::env::set_var("DEBUG", previous);
        } else {
            std::env::remove_var("DEBUG");
        }
        if let Some(previous_forwarded) = previous_forwarded {
            std::env::set_var(super::FORWARDED_DEBUG_ENV, previous_forwarded);
        } else {
            std::env::remove_var(super::FORWARDED_DEBUG_ENV);
        }
    }

    #[test]
    fn debug_log_path_enables_file_logging() {
        let _guard = ENV_LOCK.lock().unwrap();
        let previous_debug = std::env::var_os("DEBUG");
        let previous_forwarded = std::env::var_os(super::FORWARDED_DEBUG_ENV);
        let previous_log = std::env::var_os(super::DEBUG_LOG_ENV);
        let temp = tempfile::tempdir().unwrap();
        let log_path = temp.path().join("condom-debug.log");

        std::env::remove_var("DEBUG");
        std::env::remove_var(super::FORWARDED_DEBUG_ENV);
        std::env::set_var(super::DEBUG_LOG_ENV, &log_path);
        super::log(format_args!("file logging test"));

        let content = std::fs::read_to_string(&log_path).unwrap();
        assert!(content.contains("file logging test"));

        restore_env("DEBUG", previous_debug);
        restore_env(super::FORWARDED_DEBUG_ENV, previous_forwarded);
        restore_env(super::DEBUG_LOG_ENV, previous_log);
    }

    fn restore_env(key: &str, value: Option<std::ffi::OsString>) {
        if let Some(value) = value {
            std::env::set_var(key, value);
        } else {
            std::env::remove_var(key);
        }
    }
}
