use anyhow::Result;
use clap::{Parser, Subcommand};
use std::path::PathBuf;

#[derive(Debug, Parser)]
#[command(
    name = "condom-helper",
    version,
    about = "Privileged setup helper protocol endpoint"
)]
struct HelperCli {
    #[command(subcommand)]
    command: Option<HelperCommand>,
}

#[derive(Debug, Subcommand)]
enum HelperCommand {
    #[command(about = "Print helper protocol information")]
    Probe,
    #[command(about = "Read one JSON helper request from stdin and print the response")]
    Request,
    #[command(about = "Read one socket helper request, including passed stdio fds")]
    SocketRequest,
    #[command(about = "Run a sandbox request from a JSON request file")]
    RunSandbox {
        #[arg(long)]
        request: PathBuf,
    },
}

fn main() {
    condom::app::debug::log_startup("condom-helper");
    if let Err(error) = run() {
        condom::debug_log!("condom-helper error={error:#}");
        eprintln!("condom-helper: {error:#}");
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let cli = HelperCli::parse();
    match cli.command.unwrap_or(HelperCommand::Probe) {
        HelperCommand::Probe => {
            let response = condom::app::helper::validate_protocol(
                condom::app::helper::HELPER_PROTOCOL_VERSION,
            );
            condom::app::helper::write_response(std::io::stdout(), &response)?;
        }
        HelperCommand::Request => {
            let request = condom::app::helper::read_request(std::io::stdin())?;
            let response = condom::app::helper::handle_request(request);
            condom::app::helper::write_response(std::io::stdout(), &response)?;
        }
        HelperCommand::SocketRequest => {
            let response_writer = condom::app::helper::duplicate_stdout()?;
            let request = condom::app::helper::read_socket_request_from_stdio()?;
            let response = condom::app::helper::handle_socket_request(request);
            if let Err(error) = condom::app::helper::write_response(response_writer, &response) {
                if !condom::app::helper::is_broken_pipe_error(&error) {
                    return Err(error);
                }
            }
        }
        HelperCommand::RunSandbox { request } => {
            condom::app::helper::run_sandbox_request_file(&request)?;
        }
    }
    Ok(())
}
