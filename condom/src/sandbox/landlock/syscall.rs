use super::*;

const LANDLOCK_CREATE_RULESET_VERSION: u32 = 1;

const LANDLOCK_RULE_PATH_BENEATH: u32 = 1;

const LANDLOCK_RULE_NET_PORT: u32 = 2;

pub(super) const LANDLOCK_ACCESS_FS_EXECUTE: u64 = 1 << 0;

const LANDLOCK_ACCESS_FS_WRITE_FILE: u64 = 1 << 1;

const LANDLOCK_ACCESS_FS_READ_FILE: u64 = 1 << 2;

const LANDLOCK_ACCESS_FS_READ_DIR: u64 = 1 << 3;

const LANDLOCK_ACCESS_FS_REMOVE_DIR: u64 = 1 << 4;

const LANDLOCK_ACCESS_FS_REMOVE_FILE: u64 = 1 << 5;

const LANDLOCK_ACCESS_FS_MAKE_CHAR: u64 = 1 << 6;

const LANDLOCK_ACCESS_FS_MAKE_DIR: u64 = 1 << 7;

const LANDLOCK_ACCESS_FS_MAKE_REG: u64 = 1 << 8;

const LANDLOCK_ACCESS_FS_MAKE_SOCK: u64 = 1 << 9;

const LANDLOCK_ACCESS_FS_MAKE_FIFO: u64 = 1 << 10;

const LANDLOCK_ACCESS_FS_MAKE_BLOCK: u64 = 1 << 11;

const LANDLOCK_ACCESS_FS_MAKE_SYM: u64 = 1 << 12;

pub(super) const LANDLOCK_ACCESS_FS_REFER: u64 = 1 << 13;

pub(super) const LANDLOCK_ACCESS_FS_TRUNCATE: u64 = 1 << 14;

pub(super) const LANDLOCK_ACCESS_NET_CONNECT_TCP: u64 = 1 << 1;

pub(super) const LANDLOCK_SCOPE_ABSTRACT_UNIX_SOCKET: u64 = 1 << 0;

pub(super) const LANDLOCK_SCOPE_SIGNAL: u64 = 1 << 1;

pub(super) const FILESYSTEM_NOTIFICATION_POLL_MS: i32 = 25;

pub(super) const RUNTIME_PATH_ARG: &str = "--runtime-path";

pub(super) const INTERACTIVE_PTY_ARG: &str = "--interactive-pty";

pub(super) const READ_ACCESS: u64 = LANDLOCK_ACCESS_FS_READ_FILE | LANDLOCK_ACCESS_FS_READ_DIR;

pub(super) const EXECUTE_ACCESS: u64 = LANDLOCK_ACCESS_FS_EXECUTE | READ_ACCESS;

pub(super) const PROC_SUPPORT_ACCESS: u64 = READ_ACCESS;

pub(super) const WRITE_ACCESS_BASE: u64 = READ_ACCESS
    | LANDLOCK_ACCESS_FS_WRITE_FILE
    | LANDLOCK_ACCESS_FS_REMOVE_DIR
    | LANDLOCK_ACCESS_FS_REMOVE_FILE
    | LANDLOCK_ACCESS_FS_MAKE_CHAR
    | LANDLOCK_ACCESS_FS_MAKE_DIR
    | LANDLOCK_ACCESS_FS_MAKE_REG
    | LANDLOCK_ACCESS_FS_MAKE_SOCK
    | LANDLOCK_ACCESS_FS_MAKE_FIFO
    | LANDLOCK_ACCESS_FS_MAKE_BLOCK
    | LANDLOCK_ACCESS_FS_MAKE_SYM;

pub(super) const DIRECTORY_ONLY_ACCESS: u64 = LANDLOCK_ACCESS_FS_READ_DIR
    | LANDLOCK_ACCESS_FS_REMOVE_DIR
    | LANDLOCK_ACCESS_FS_REMOVE_FILE
    | LANDLOCK_ACCESS_FS_MAKE_CHAR
    | LANDLOCK_ACCESS_FS_MAKE_DIR
    | LANDLOCK_ACCESS_FS_MAKE_REG
    | LANDLOCK_ACCESS_FS_MAKE_SOCK
    | LANDLOCK_ACCESS_FS_MAKE_FIFO
    | LANDLOCK_ACCESS_FS_MAKE_BLOCK
    | LANDLOCK_ACCESS_FS_MAKE_SYM
    | LANDLOCK_ACCESS_FS_REFER;

#[repr(C)]
pub(super) struct LandlockRulesetAttr {
    pub(super) handled_access_fs: u64,
    pub(super) handled_access_net: u64,
    pub(super) scoped: u64,
}

#[repr(C)]
struct LandlockPathBeneathAttr {
    pub(super) allowed_access: u64,
    pub(super) parent_fd: i32,
}

#[repr(C)]
struct LandlockNetPortAttr {
    pub(super) allowed_access: u64,
    pub(super) port: u64,
}

pub(super) struct LandlockPlan {
    pub(super) handled_access_fs: u64,
    pub(super) handled_access_net: u64,
    pub(super) scoped: u64,
    pub(super) rules: Vec<LandlockPathRule>,
    pub(super) network_rules: Vec<LandlockNetworkRule>,
}

pub(super) struct LandlockPathRule {
    pub(super) path: PathBuf,
    pub(super) fd: OwnedFd,
    pub(super) allowed_access: u64,
}

pub(super) struct LandlockNetworkRule {
    pub(super) port: u16,
    pub(super) allowed_access: u64,
}

pub(super) fn landlock_abi() -> io::Result<i32> {
    let abi = unsafe {
        libc::syscall(
            libc::SYS_landlock_create_ruleset,
            std::ptr::null::<libc::c_void>(),
            0usize,
            LANDLOCK_CREATE_RULESET_VERSION,
        )
    };
    if abi < 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(abi as i32)
}

pub(super) fn handled_filesystem_access(abi: i32) -> u64 {
    let mut access = EXECUTE_ACCESS | WRITE_ACCESS_BASE;
    if abi >= 2 {
        access |= LANDLOCK_ACCESS_FS_REFER;
    }
    if abi >= 3 {
        access |= LANDLOCK_ACCESS_FS_TRUNCATE;
    }
    access
}

pub(super) fn handled_network_access(
    abi: i32,
    policy_snapshot: &PolicySnapshot,
) -> io::Result<u64> {
    if !policy::network_mediation_required(&policy_snapshot.network) {
        return Ok(0);
    }
    if abi < 4 {
        return Err(io::Error::new(
            io::ErrorKind::Unsupported,
            "Landlock TCP connect restrictions require ABI 4 or newer",
        ));
    }
    Ok(LANDLOCK_ACCESS_NET_CONNECT_TCP)
}

pub(super) fn scoped_restrictions(abi: i32) -> io::Result<u64> {
    if abi < 6 {
        return Err(io::Error::new(
            io::ErrorKind::Unsupported,
            "Landlock scoped IPC restrictions require ABI 6 or newer",
        ));
    }
    Ok(LANDLOCK_SCOPE_ABSTRACT_UNIX_SOCKET | LANDLOCK_SCOPE_SIGNAL)
}

pub(super) fn abi_write_extensions(abi: i32) -> u64 {
    let mut access = 0;
    if abi >= 3 {
        access |= LANDLOCK_ACCESS_FS_TRUNCATE;
    }
    access
}

pub(super) fn landlock_create_ruleset(attr: &LandlockRulesetAttr) -> io::Result<i32> {
    let fd = unsafe {
        libc::syscall(
            libc::SYS_landlock_create_ruleset,
            attr as *const LandlockRulesetAttr,
            std::mem::size_of::<LandlockRulesetAttr>(),
            0u32,
        )
    };
    if fd < 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(fd as i32)
}

pub(super) fn landlock_add_path_rule(ruleset_fd: i32, rule: &LandlockPathRule) -> io::Result<()> {
    let path_rule = LandlockPathBeneathAttr {
        allowed_access: rule.allowed_access,
        parent_fd: rule.fd.as_raw_fd(),
    };
    let result = unsafe {
        libc::syscall(
            libc::SYS_landlock_add_rule,
            ruleset_fd,
            LANDLOCK_RULE_PATH_BENEATH,
            &path_rule as *const LandlockPathBeneathAttr,
            0u32,
        )
    };
    if result < 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}

pub(super) fn landlock_add_network_rule(
    ruleset_fd: i32,
    rule: &LandlockNetworkRule,
) -> io::Result<()> {
    let network_rule = LandlockNetPortAttr {
        allowed_access: rule.allowed_access,
        port: u64::from(rule.port),
    };
    let result = unsafe {
        libc::syscall(
            libc::SYS_landlock_add_rule,
            ruleset_fd,
            LANDLOCK_RULE_NET_PORT,
            &network_rule as *const LandlockNetPortAttr,
            0u32,
        )
    };
    if result < 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}

pub(super) fn landlock_restrict_self(ruleset_fd: i32) -> io::Result<()> {
    let result = unsafe { libc::syscall(libc::SYS_landlock_restrict_self, ruleset_fd, 0u32) };
    if result < 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}

pub(super) fn close_fd(fd: i32) {
    unsafe {
        libc::close(fd);
    }
}
