const CAP_NET_ADMIN: u64 = 12;
#[cfg(target_os = "linux")]
const LINUX_CAPABILITY_VERSION_3: u32 = 0x20080522;
#[cfg(target_os = "linux")]
const PR_CAP_AMBIENT: libc::c_int = 47;
#[cfg(target_os = "linux")]
const PR_CAP_AMBIENT_CLEAR_ALL: libc::c_ulong = 4;

#[cfg(target_os = "linux")]
#[repr(C)]
struct CapabilityHeader {
    version: u32,
    pid: i32,
}

#[cfg(target_os = "linux")]
#[repr(C)]
#[derive(Clone, Copy)]
struct CapabilityData {
    effective: u32,
    permitted: u32,
    inheritable: u32,
}

pub fn has_effective_cap_net_admin() -> bool {
    let Ok(status) = std::fs::read_to_string("/proc/self/status") else {
        return false;
    };
    status_has_effective_cap_net_admin(&status)
}

fn status_has_effective_cap_net_admin(status: &str) -> bool {
    status
        .lines()
        .find_map(|line| line.strip_prefix("CapEff:"))
        .and_then(|value| u64::from_str_radix(value.trim(), 16).ok())
        .is_some_and(|capabilities| capabilities & (1 << CAP_NET_ADMIN) != 0)
}

#[cfg(target_os = "linux")]
pub fn drop_process_capabilities() -> std::io::Result<()> {
    unsafe {
        libc::prctl(
            PR_CAP_AMBIENT,
            PR_CAP_AMBIENT_CLEAR_ALL,
            0 as libc::c_ulong,
            0 as libc::c_ulong,
            0 as libc::c_ulong,
        );
    }
    let header = CapabilityHeader {
        version: LINUX_CAPABILITY_VERSION_3,
        pid: 0,
    };
    let data = [CapabilityData {
        effective: 0,
        permitted: 0,
        inheritable: 0,
    }; 2];
    let result = unsafe { libc::syscall(libc::SYS_capset, &header, data.as_ptr()) };
    if result == -1 {
        return Err(std::io::Error::last_os_error());
    }
    restore_dumpable_after_privilege_drop()
}

#[cfg(target_os = "linux")]
pub fn restore_dumpable_after_privilege_drop() -> std::io::Result<()> {
    // bwrap writes /proc/$child/uid_map after forking a user namespace.
    let result = unsafe { libc::prctl(libc::PR_SET_DUMPABLE, 1, 0, 0, 0) };
    if result == -1 {
        Err(std::io::Error::last_os_error())
    } else {
        Ok(())
    }
}

#[cfg(not(target_os = "linux"))]
pub fn drop_process_capabilities() -> std::io::Result<()> {
    Ok(())
}

#[cfg(not(target_os = "linux"))]
pub fn restore_dumpable_after_privilege_drop() -> std::io::Result<()> {
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_effective_net_admin_capability() {
        assert!(status_has_effective_cap_net_admin(
            "Name:\tcondom\nCapEff:\t0000000000001000\n"
        ));
        assert!(!status_has_effective_cap_net_admin(
            "Name:\tcondom\nCapEff:\t0000000000000000\n"
        ));
        assert!(!status_has_effective_cap_net_admin("Name:\tcondom\n"));
    }
}
