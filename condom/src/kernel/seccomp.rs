use std::io;
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd};
use std::os::unix::process::CommandExt;
use std::process::Command;

#[cfg(target_arch = "x86_64")]
const AUDIT_ARCH_X86_64: u32 = 0xc000_003e;
#[cfg(target_arch = "x86_64")]
const SECCOMP_DATA_NR_OFFSET: u32 = 0;
#[cfg(target_arch = "x86_64")]
const SECCOMP_DATA_ARCH_OFFSET: u32 = 4;
#[cfg(target_arch = "x86_64")]
const SECCOMP_DATA_ARG0_OFFSET: u32 = 16;
#[cfg(target_arch = "x86_64")]
const SECCOMP_DATA_ARG1_OFFSET: u32 = 24;

#[cfg(target_arch = "x86_64")]
const BPF_LD_W_ABS: u16 = 0x20;
#[cfg(target_arch = "x86_64")]
const BPF_JMP_JEQ_K: u16 = 0x15;
#[cfg(target_arch = "x86_64")]
const BPF_ALU_AND_K: u16 = 0x54;
#[cfg(target_arch = "x86_64")]
const BPF_RET_K: u16 = 0x06;

#[cfg(target_arch = "x86_64")]
const SECCOMP_RET_KILL_PROCESS: u32 = 0x8000_0000;
#[cfg(target_arch = "x86_64")]
const SECCOMP_RET_ERRNO: u32 = 0x0005_0000;
#[cfg(target_arch = "x86_64")]
const SECCOMP_RET_ALLOW: u32 = 0x7fff_0000;

#[cfg(target_arch = "x86_64")]
const SECCOMP_IOCTL_NOTIF_RECV: libc::c_ulong =
    ioctl_iowr(0, std::mem::size_of::<libc::seccomp_notif>());
#[cfg(target_arch = "x86_64")]
const SECCOMP_IOCTL_NOTIF_SEND: libc::c_ulong =
    ioctl_iowr(1, std::mem::size_of::<libc::seccomp_notif_resp>());
#[cfg(target_arch = "x86_64")]
const SECCOMP_IOCTL_NOTIF_ADDFD: libc::c_ulong =
    ioctl_iow(3, std::mem::size_of::<libc::seccomp_notif_addfd>());

#[cfg(target_arch = "x86_64")]
const SYS_SOCKET: u32 = libc::SYS_socket as u32;
#[cfg(target_arch = "x86_64")]
const FILESYSTEM_NOTIFICATION_SYSCALLS: &[u32] = &[
    libc::SYS_open as u32,
    libc::SYS_openat as u32,
    libc::SYS_openat2 as u32,
    libc::SYS_creat as u32,
    libc::SYS_mknod as u32,
    libc::SYS_mknodat as u32,
    libc::SYS_unlink as u32,
    libc::SYS_unlinkat as u32,
    libc::SYS_rmdir as u32,
    libc::SYS_mkdir as u32,
    libc::SYS_mkdirat as u32,
    libc::SYS_link as u32,
    libc::SYS_linkat as u32,
    libc::SYS_symlink as u32,
    libc::SYS_symlinkat as u32,
    libc::SYS_rename as u32,
    libc::SYS_renameat as u32,
    libc::SYS_renameat2 as u32,
    libc::SYS_chmod as u32,
    libc::SYS_fchmodat as u32,
    libc::SYS_chown as u32,
    libc::SYS_lchown as u32,
    libc::SYS_fchownat as u32,
    libc::SYS_truncate as u32,
    libc::SYS_utimensat as u32,
    libc::SYS_execve as u32,
    libc::SYS_execveat as u32,
];
#[cfg(target_arch = "x86_64")]
const AF_INET: u32 = libc::AF_INET as u32;
#[cfg(target_arch = "x86_64")]
const AF_INET6: u32 = libc::AF_INET6 as u32;
#[cfg(target_arch = "x86_64")]
const AF_PACKET: u32 = libc::AF_PACKET as u32;
#[cfg(target_arch = "x86_64")]
const SOCK_DGRAM: u32 = libc::SOCK_DGRAM as u32;
#[cfg(target_arch = "x86_64")]
const SOCK_RAW: u32 = libc::SOCK_RAW as u32;
#[cfg(target_arch = "x86_64")]
const SOCK_TYPE_MASK: u32 = 0x0f;

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct SocketFilterPolicy {
    pub deny_internet_udp: bool,
}

#[cfg(target_arch = "x86_64")]
#[repr(C)]
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
struct SockFilter {
    code: u16,
    jt: u8,
    jf: u8,
    k: u32,
}

#[cfg(target_arch = "x86_64")]
#[repr(C)]
struct SockFprog {
    len: u16,
    filter: *const SockFilter,
}

pub fn install_socket_filter(command: &mut Command, policy: SocketFilterPolicy) {
    install_socket_filter_for_arch(command, policy);
}

pub fn socket_filter_supported() -> bool {
    socket_filter_supported_for_arch()
}

pub fn filesystem_notification_supported() -> bool {
    filesystem_notification_supported_for_arch()
}

pub fn install_filesystem_notification_filter() -> io::Result<OwnedFd> {
    install_filesystem_notification_filter_for_arch()
}

pub fn receive_filesystem_notification(listener: &OwnedFd) -> io::Result<libc::seccomp_notif> {
    receive_filesystem_notification_for_arch(listener)
}

pub enum FilesystemNotificationResponse {
    Continue,
    Deny(libc::c_int),
    AddFd { fd: OwnedFd, close_on_exec: bool },
}

pub fn respond_filesystem_notification(
    listener: &OwnedFd,
    notification: &libc::seccomp_notif,
    response: FilesystemNotificationResponse,
) -> io::Result<()> {
    respond_filesystem_notification_for_arch(listener, notification, response)
}

#[cfg(target_arch = "x86_64")]
fn socket_filter_supported_for_arch() -> bool {
    unsafe {
        let pid = libc::fork();
        if pid < 0 {
            return false;
        }
        if pid == 0 {
            let code = if apply_socket_filter(SocketFilterPolicy::default()).is_ok() {
                0
            } else {
                1
            };
            libc::_exit(code);
        }
        let mut status = 0;
        loop {
            let waited = libc::waitpid(pid, &mut status, 0);
            if waited == pid {
                break;
            }
            if waited < 0 && io::Error::last_os_error().kind() != io::ErrorKind::Interrupted {
                return false;
            }
        }
        libc::WIFEXITED(status) && libc::WEXITSTATUS(status) == 0
    }
}

#[cfg(target_arch = "x86_64")]
fn filesystem_notification_supported_for_arch() -> bool {
    unsafe {
        let pid = libc::fork();
        if pid < 0 {
            return false;
        }
        if pid == 0 {
            let code = match install_filesystem_notification_filter_for_arch() {
                Ok(listener) => {
                    drop(listener);
                    0
                }
                Err(_) => 1,
            };
            libc::_exit(code);
        }
        let mut status = 0;
        loop {
            let waited = libc::waitpid(pid, &mut status, 0);
            if waited == pid {
                break;
            }
            if waited < 0 && io::Error::last_os_error().kind() != io::ErrorKind::Interrupted {
                return false;
            }
        }
        libc::WIFEXITED(status) && libc::WEXITSTATUS(status) == 0
    }
}

#[cfg(not(target_arch = "x86_64"))]
fn socket_filter_supported_for_arch() -> bool {
    false
}

#[cfg(not(target_arch = "x86_64"))]
fn filesystem_notification_supported_for_arch() -> bool {
    false
}

#[cfg(target_arch = "x86_64")]
fn install_socket_filter_for_arch(command: &mut Command, policy: SocketFilterPolicy) {
    unsafe {
        command.pre_exec(move || apply_socket_filter(policy));
    }
}

#[cfg(not(target_arch = "x86_64"))]
fn install_socket_filter_for_arch(command: &mut Command, _policy: SocketFilterPolicy) {
    unsafe {
        command.pre_exec(|| {
            Err(io::Error::new(
                io::ErrorKind::Unsupported,
                "socket seccomp filter is only implemented on x86_64",
            ))
        });
    }
}

#[cfg(target_arch = "x86_64")]
fn apply_socket_filter(policy: SocketFilterPolicy) -> io::Result<()> {
    let filter = socket_filter(policy);
    let program = SockFprog {
        len: u16::try_from(filter.len()).expect("seccomp filter length fits in u16"),
        filter: filter.as_ptr(),
    };
    unsafe {
        if libc::prctl(libc::PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) != 0 {
            return Err(io::Error::last_os_error());
        }
        if libc::prctl(
            libc::PR_SET_SECCOMP,
            libc::SECCOMP_MODE_FILTER,
            &program as *const SockFprog,
            0,
            0,
        ) != 0
        {
            return Err(io::Error::last_os_error());
        }
    }
    Ok(())
}

#[cfg(target_arch = "x86_64")]
fn install_filesystem_notification_filter_for_arch() -> io::Result<OwnedFd> {
    let filter = filesystem_notification_filter();
    let program = SockFprog {
        len: u16::try_from(filter.len()).expect("seccomp filter length fits in u16"),
        filter: filter.as_ptr(),
    };
    unsafe {
        if libc::prctl(libc::PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) != 0 {
            return Err(io::Error::last_os_error());
        }
        let fd = libc::syscall(
            libc::SYS_seccomp,
            libc::SECCOMP_SET_MODE_FILTER,
            libc::SECCOMP_FILTER_FLAG_NEW_LISTENER,
            &program as *const SockFprog,
        );
        if fd < 0 {
            return Err(io::Error::last_os_error());
        }
        Ok(OwnedFd::from_raw_fd(fd as i32))
    }
}

#[cfg(not(target_arch = "x86_64"))]
fn install_filesystem_notification_filter_for_arch() -> io::Result<OwnedFd> {
    Err(io::Error::new(
        io::ErrorKind::Unsupported,
        "filesystem seccomp notification is only implemented on x86_64",
    ))
}

#[cfg(target_arch = "x86_64")]
fn receive_filesystem_notification_for_arch(listener: &OwnedFd) -> io::Result<libc::seccomp_notif> {
    let mut notification = unsafe { std::mem::zeroed::<libc::seccomp_notif>() };
    let result = unsafe {
        libc::ioctl(
            listener.as_raw_fd(),
            SECCOMP_IOCTL_NOTIF_RECV,
            &mut notification,
        )
    };
    if result < 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(notification)
}

#[cfg(not(target_arch = "x86_64"))]
fn receive_filesystem_notification_for_arch(
    _listener: &OwnedFd,
) -> io::Result<libc::seccomp_notif> {
    Err(io::Error::new(
        io::ErrorKind::Unsupported,
        "filesystem seccomp notification is only implemented on x86_64",
    ))
}

#[cfg(target_arch = "x86_64")]
fn respond_filesystem_notification_for_arch(
    listener: &OwnedFd,
    notification: &libc::seccomp_notif,
    response: FilesystemNotificationResponse,
) -> io::Result<()> {
    let (error, flags) = match response {
        FilesystemNotificationResponse::Continue => {
            (0, libc::SECCOMP_USER_NOTIF_FLAG_CONTINUE as u32)
        }
        FilesystemNotificationResponse::Deny(error) => (-error, 0),
        FilesystemNotificationResponse::AddFd { fd, close_on_exec } => {
            return add_filesystem_notification_fd(listener, notification, &fd, close_on_exec);
        }
    };
    let mut response = libc::seccomp_notif_resp {
        id: notification.id,
        val: 0,
        error,
        flags,
    };
    let result = unsafe {
        libc::ioctl(
            listener.as_raw_fd(),
            SECCOMP_IOCTL_NOTIF_SEND,
            &mut response,
        )
    };
    if result < 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}

#[cfg(target_arch = "x86_64")]
fn add_filesystem_notification_fd(
    listener: &OwnedFd,
    notification: &libc::seccomp_notif,
    fd: &OwnedFd,
    close_on_exec: bool,
) -> io::Result<()> {
    let mut addfd = libc::seccomp_notif_addfd {
        id: notification.id,
        flags: libc::SECCOMP_ADDFD_FLAG_SEND as u32,
        srcfd: fd.as_raw_fd() as u32,
        newfd: 0,
        newfd_flags: if close_on_exec {
            libc::O_CLOEXEC as u32
        } else {
            0
        },
    };
    let result =
        unsafe { libc::ioctl(listener.as_raw_fd(), SECCOMP_IOCTL_NOTIF_ADDFD, &mut addfd) };
    if result < 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}

#[cfg(not(target_arch = "x86_64"))]
fn respond_filesystem_notification_for_arch(
    _listener: &OwnedFd,
    _notification: &libc::seccomp_notif,
    _response: FilesystemNotificationResponse,
) -> io::Result<()> {
    Err(io::Error::new(
        io::ErrorKind::Unsupported,
        "filesystem seccomp notification is only implemented on x86_64",
    ))
}

#[cfg(target_arch = "x86_64")]
fn socket_filter(policy: SocketFilterPolicy) -> Vec<SockFilter> {
    let mut filter = vec![
        stmt(BPF_LD_W_ABS, SECCOMP_DATA_ARCH_OFFSET),
        jump(BPF_JMP_JEQ_K, AUDIT_ARCH_X86_64, 1, 0),
        stmt(BPF_RET_K, SECCOMP_RET_KILL_PROCESS),
        stmt(BPF_LD_W_ABS, SECCOMP_DATA_NR_OFFSET),
        jump(
            BPF_JMP_JEQ_K,
            SYS_SOCKET,
            0,
            if policy.deny_internet_udp { 9 } else { 8 },
        ),
        stmt(BPF_LD_W_ABS, SECCOMP_DATA_ARG0_OFFSET),
        jump(
            BPF_JMP_JEQ_K,
            AF_PACKET,
            if policy.deny_internet_udp { 6 } else { 5 },
            0,
        ),
        jump(BPF_JMP_JEQ_K, AF_INET, 1, 0),
        jump(
            BPF_JMP_JEQ_K,
            AF_INET6,
            0,
            if policy.deny_internet_udp { 5 } else { 4 },
        ),
        stmt(BPF_LD_W_ABS, SECCOMP_DATA_ARG1_OFFSET),
        stmt(BPF_ALU_AND_K, SOCK_TYPE_MASK),
    ];
    if policy.deny_internet_udp {
        filter.extend([
            jump(BPF_JMP_JEQ_K, SOCK_RAW, 1, 0),
            jump(BPF_JMP_JEQ_K, SOCK_DGRAM, 0, 1),
        ]);
    } else {
        filter.push(jump(BPF_JMP_JEQ_K, SOCK_RAW, 0, 1));
    }
    filter.extend([
        stmt(BPF_RET_K, SECCOMP_RET_ERRNO | libc::EPERM as u32),
        stmt(BPF_RET_K, SECCOMP_RET_ALLOW),
    ]);
    filter
}

#[cfg(target_arch = "x86_64")]
fn filesystem_notification_filter() -> Vec<SockFilter> {
    let mut filter = vec![
        stmt(BPF_LD_W_ABS, SECCOMP_DATA_ARCH_OFFSET),
        jump(BPF_JMP_JEQ_K, AUDIT_ARCH_X86_64, 1, 0),
        stmt(BPF_RET_K, SECCOMP_RET_KILL_PROCESS),
        stmt(BPF_LD_W_ABS, SECCOMP_DATA_NR_OFFSET),
    ];
    for syscall in FILESYSTEM_NOTIFICATION_SYSCALLS {
        filter.extend([
            jump(BPF_JMP_JEQ_K, *syscall, 0, 1),
            stmt(BPF_RET_K, libc::SECCOMP_RET_USER_NOTIF),
        ]);
    }
    filter.push(stmt(BPF_RET_K, SECCOMP_RET_ALLOW));
    filter
}

#[cfg(target_arch = "x86_64")]
const fn ioctl_iowr(nr: u32, size: usize) -> libc::c_ulong {
    const IOC_NRBITS: u32 = 8;
    const IOC_TYPEBITS: u32 = 8;
    const IOC_SIZEBITS: u32 = 14;
    const IOC_NRSHIFT: u32 = 0;
    const IOC_TYPESHIFT: u32 = IOC_NRSHIFT + IOC_NRBITS;
    const IOC_SIZESHIFT: u32 = IOC_TYPESHIFT + IOC_TYPEBITS;
    const IOC_DIRSHIFT: u32 = IOC_SIZESHIFT + IOC_SIZEBITS;
    const IOC_WRITE: u32 = 1;
    const IOC_READ: u32 = 2;
    const SECCOMP_IOC_MAGIC: u32 = b'!' as u32;

    (((IOC_READ | IOC_WRITE) as libc::c_ulong) << IOC_DIRSHIFT)
        | ((SECCOMP_IOC_MAGIC as libc::c_ulong) << IOC_TYPESHIFT)
        | ((nr as libc::c_ulong) << IOC_NRSHIFT)
        | ((size as libc::c_ulong) << IOC_SIZESHIFT)
}

#[cfg(target_arch = "x86_64")]
const fn ioctl_iow(nr: u32, size: usize) -> libc::c_ulong {
    const IOC_NRBITS: u32 = 8;
    const IOC_TYPEBITS: u32 = 8;
    const IOC_SIZEBITS: u32 = 14;
    const IOC_NRSHIFT: u32 = 0;
    const IOC_TYPESHIFT: u32 = IOC_NRSHIFT + IOC_NRBITS;
    const IOC_SIZESHIFT: u32 = IOC_TYPESHIFT + IOC_TYPEBITS;
    const IOC_DIRSHIFT: u32 = IOC_SIZESHIFT + IOC_SIZEBITS;
    const IOC_WRITE: u32 = 1;
    const SECCOMP_IOC_MAGIC: u32 = b'!' as u32;

    ((IOC_WRITE as libc::c_ulong) << IOC_DIRSHIFT)
        | ((SECCOMP_IOC_MAGIC as libc::c_ulong) << IOC_TYPESHIFT)
        | ((nr as libc::c_ulong) << IOC_NRSHIFT)
        | ((size as libc::c_ulong) << IOC_SIZESHIFT)
}

#[cfg(target_arch = "x86_64")]
fn stmt(code: u16, k: u32) -> SockFilter {
    SockFilter {
        code,
        jt: 0,
        jf: 0,
        k,
    }
}

#[cfg(target_arch = "x86_64")]
fn jump(code: u16, k: u32, jt: u8, jf: u8) -> SockFilter {
    SockFilter { code, jt, jf, k }
}

#[cfg(all(test, target_arch = "x86_64"))]
mod tests {
    use super::*;

    #[test]
    fn raw_socket_filter_checks_arch_before_syscall() {
        let filter = socket_filter(SocketFilterPolicy::default());

        assert_eq!(filter[0], stmt(BPF_LD_W_ABS, SECCOMP_DATA_ARCH_OFFSET));
        assert_eq!(filter[1], jump(BPF_JMP_JEQ_K, AUDIT_ARCH_X86_64, 1, 0));
        assert_eq!(filter[2], stmt(BPF_RET_K, SECCOMP_RET_KILL_PROCESS));
    }

    #[test]
    fn raw_socket_filter_denies_packet_and_inet_raw_sockets() {
        let filter = socket_filter(SocketFilterPolicy::default());

        assert_eq!(filter[4], jump(BPF_JMP_JEQ_K, SYS_SOCKET, 0, 8));
        assert_eq!(filter[6], jump(BPF_JMP_JEQ_K, AF_PACKET, 5, 0));
        assert_eq!(filter[7], jump(BPF_JMP_JEQ_K, AF_INET, 1, 0));
        assert_eq!(filter[8], jump(BPF_JMP_JEQ_K, AF_INET6, 0, 4));
        assert_eq!(filter[10], stmt(BPF_ALU_AND_K, SOCK_TYPE_MASK));
        assert_eq!(filter[11], jump(BPF_JMP_JEQ_K, SOCK_RAW, 0, 1));
        assert_eq!(
            filter[12],
            stmt(BPF_RET_K, SECCOMP_RET_ERRNO | libc::EPERM as u32)
        );
    }

    #[test]
    fn proxy_socket_filter_denies_internet_udp_sockets() {
        assert_eq!(
            simulate_socket_filter(
                SocketFilterPolicy {
                    deny_internet_udp: true
                },
                SYS_SOCKET,
                AF_INET,
                SOCK_DGRAM
            ),
            SECCOMP_RET_ERRNO | libc::EPERM as u32
        );
        assert_eq!(
            simulate_socket_filter(
                SocketFilterPolicy {
                    deny_internet_udp: true
                },
                SYS_SOCKET,
                AF_INET6,
                SOCK_DGRAM
            ),
            SECCOMP_RET_ERRNO | libc::EPERM as u32
        );
    }

    #[test]
    fn default_socket_filter_allows_internet_udp_sockets() {
        assert_eq!(
            simulate_socket_filter(
                SocketFilterPolicy::default(),
                SYS_SOCKET,
                AF_INET,
                SOCK_DGRAM
            ),
            SECCOMP_RET_ALLOW
        );
    }

    #[test]
    fn raw_socket_filter_allows_non_matching_syscalls() {
        let filter = socket_filter(SocketFilterPolicy::default());

        assert_eq!(filter.last(), Some(&stmt(BPF_RET_K, SECCOMP_RET_ALLOW)));
    }

    #[test]
    fn filesystem_notification_filter_notifies_path_syscalls() {
        assert_eq!(
            simulate_filesystem_filter(libc::SYS_openat as u32, AUDIT_ARCH_X86_64),
            libc::SECCOMP_RET_USER_NOTIF
        );
        assert_eq!(
            simulate_filesystem_filter(libc::SYS_chmod as u32, AUDIT_ARCH_X86_64),
            libc::SECCOMP_RET_USER_NOTIF
        );
        assert_eq!(
            simulate_filesystem_filter(libc::SYS_execve as u32, AUDIT_ARCH_X86_64),
            libc::SECCOMP_RET_USER_NOTIF
        );
        assert_eq!(
            simulate_filesystem_filter(libc::SYS_execveat as u32, AUDIT_ARCH_X86_64),
            libc::SECCOMP_RET_USER_NOTIF
        );
    }

    #[test]
    fn filesystem_notification_filter_allows_metadata_probes() {
        assert_eq!(
            simulate_filesystem_filter(libc::SYS_newfstatat as u32, AUDIT_ARCH_X86_64),
            SECCOMP_RET_ALLOW
        );
        assert_eq!(
            simulate_filesystem_filter(libc::SYS_access as u32, AUDIT_ARCH_X86_64),
            SECCOMP_RET_ALLOW
        );
        assert_eq!(
            simulate_filesystem_filter(libc::SYS_readlinkat as u32, AUDIT_ARCH_X86_64),
            SECCOMP_RET_ALLOW
        );
    }

    #[test]
    fn filesystem_notification_filter_allows_unmatched_syscalls() {
        assert_eq!(
            simulate_filesystem_filter(SYS_SOCKET, AUDIT_ARCH_X86_64),
            SECCOMP_RET_ALLOW
        );
    }

    #[test]
    fn filesystem_notification_filter_checks_arch_first() {
        assert_eq!(
            simulate_filesystem_filter(libc::SYS_openat as u32, 0),
            SECCOMP_RET_KILL_PROCESS
        );
    }

    fn simulate_socket_filter(
        policy: SocketFilterPolicy,
        syscall: u32,
        family: u32,
        socket_type: u32,
    ) -> u32 {
        let filter = socket_filter(policy);
        let mut accumulator = 0;
        let mut index = 0;
        loop {
            let instruction = filter[index];
            match instruction.code {
                BPF_LD_W_ABS => {
                    accumulator = match instruction.k {
                        SECCOMP_DATA_ARCH_OFFSET => AUDIT_ARCH_X86_64,
                        SECCOMP_DATA_NR_OFFSET => syscall,
                        SECCOMP_DATA_ARG0_OFFSET => family,
                        SECCOMP_DATA_ARG1_OFFSET => socket_type,
                        offset => panic!("unexpected load offset {offset}"),
                    };
                    index += 1;
                }
                BPF_ALU_AND_K => {
                    accumulator &= instruction.k;
                    index += 1;
                }
                BPF_JMP_JEQ_K => {
                    let offset = if accumulator == instruction.k {
                        instruction.jt
                    } else {
                        instruction.jf
                    };
                    index += usize::from(offset) + 1;
                }
                BPF_RET_K => return instruction.k,
                code => panic!("unexpected BPF code {code:#x}"),
            }
        }
    }

    fn simulate_filesystem_filter(syscall: u32, arch: u32) -> u32 {
        let filter = filesystem_notification_filter();
        let mut accumulator = 0;
        let mut index = 0;
        loop {
            let instruction = filter[index];
            match instruction.code {
                BPF_LD_W_ABS => {
                    accumulator = match instruction.k {
                        SECCOMP_DATA_ARCH_OFFSET => arch,
                        SECCOMP_DATA_NR_OFFSET => syscall,
                        offset => panic!("unexpected load offset {offset}"),
                    };
                    index += 1;
                }
                BPF_JMP_JEQ_K => {
                    let offset = if accumulator == instruction.k {
                        instruction.jt
                    } else {
                        instruction.jf
                    };
                    index += usize::from(offset) + 1;
                }
                BPF_RET_K => return instruction.k,
                code => panic!("unexpected BPF code {code:#x}"),
            }
        }
    }
}
