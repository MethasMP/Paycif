use std::fs;

use tonic::transport::{Certificate, Identity, ServerTlsConfig};

pub fn load_tls_config(
    enable_tls: bool,
    ca_path: &str,
    cert_path: &str,
    key_path: &str,
) -> Option<ServerTlsConfig> {
    if !enable_tls {
        return None;
    }

    // Load Web Server Cert/Key (Identity)
    let cert = fs::read_to_string(cert_path).expect("Failed to read server cert");
    let key = fs::read_to_string(key_path).expect("Failed to read server key");
    let identity = Identity::from_pem(cert, key);

    // Load CA (Client Validation)
    let ca_pem = fs::read_to_string(ca_path).expect("Failed to read CA cert");
    let client_ca_cert = Certificate::from_pem(ca_pem);

    Some(
        ServerTlsConfig::new()
            .identity(identity)
            .client_ca_root(client_ca_cert), // Enable mTLS
    )
}
