fn main() {
    condom::app::debug::log_startup("condom");
    match condom::app::cli::run() {
        Ok(code) => std::process::exit(code),
        Err(error) => {
            condom::debug_log!("condom error={error:#}");
            eprintln!("condom: {error:#}");
            std::process::exit(1);
        }
    }
}
