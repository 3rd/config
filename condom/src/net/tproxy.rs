pub const ROUTING_ENV: &str = "CONDOM_TPROXY_ROUTING";
pub const PORT_ENV: &str = "CONDOM_TPROXY_PORT";
pub const TCP_PORTS_ENV: &str = "CONDOM_TPROXY_TCP_PORTS";
pub const MARK_ENV: &str = "CONDOM_TPROXY_MARK";
pub const TABLE_ENV: &str = "CONDOM_TPROXY_TABLE";
pub const TABLE_NAME_ENV: &str = "CONDOM_TPROXY_TABLE_NAME";
pub const INTERFACE_ENV: &str = "CONDOM_TPROXY_INTERFACE";

pub const DEFAULT_PORT: u16 = 15080;
pub const DEFAULT_MARK: u32 = 49374;
pub const DEFAULT_TABLE: u32 = 15080;
pub const DEFAULT_TABLE_NAME: &str = "condom-tproxy";
pub const DEFAULT_INTERFACE: &str = "lo";
pub const DEFAULT_TCP_PORTS: &[u16] = &[80, 443];

pub fn routing_configured(value: Option<&std::ffi::OsStr>) -> bool {
    value
        .and_then(|value| value.to_str())
        .map(|value| matches!(value, "1" | "true" | "yes"))
        .unwrap_or(false)
}
