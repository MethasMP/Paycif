use std::io::Result;

fn main() -> Result<()> {
    // Compile .proto file to Rust code
    tonic_build::configure()
        .build_server(true)
        .build_client(true) // Build client for tests
        .compile(&["proto/accounting.proto"], &["proto"])?;
    Ok(())
}
