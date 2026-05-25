fn main() -> Result<(), Box<dyn std::error::Error>> {
    let proto_file = "../../proto/fx.proto";
    
    tonic_build::configure()
        .build_server(true)
        .build_client(false)
        .compile(&[proto_file], &["../../proto"])?;
        
    println!("cargo:rerun-if-changed={}", proto_file);
    Ok(())
}
