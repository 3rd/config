pub mod app;
pub mod auth;
pub mod kernel;
pub mod model;
pub mod net;
pub mod sandbox;

pub const VERSION: &str = env!("CARGO_PKG_VERSION");
