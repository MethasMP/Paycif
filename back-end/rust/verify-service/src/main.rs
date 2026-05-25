use axum::{
    extract::Json,
    routing::post,
    Router,
    http::StatusCode,
};
use ed25519_dalek::{VerifyingKey, Signature, Verifier};
use serde::{Deserialize, Serialize};
use base64::{engine::general_purpose, Engine as _};

#[derive(Deserialize)]
struct VerifyRequest {
    public_key_b64: String,
    signature_b64: String,
    message: String,
}

#[derive(Serialize)]
struct VerifyResponse {
    is_valid: bool,
    error: Option<String>,
}

async fn verify_handler(Json(payload): Json<VerifyRequest>) -> (StatusCode, Json<VerifyResponse>) {
    // 1. Decode Public Key
    let public_key_bytes = match general_purpose::STANDARD.decode(&payload.public_key_b64) {
        Ok(bytes) => bytes,
        Err(e) => return (StatusCode::BAD_REQUEST, Json(VerifyResponse {
            is_valid: false,
            error: Some(format!("Invalid public key base64: {}", e)),
        })),
    };

    // 2. Decode Signature
    let signature_bytes = match general_purpose::STANDARD.decode(&payload.signature_b64) {
        Ok(bytes) => bytes,
        Err(e) => return (StatusCode::BAD_REQUEST, Json(VerifyResponse {
            is_valid: false,
            error: Some(format!("Invalid signature base64: {}", e)),
        })),
    };

    // 3. Parse Ed25519 Public Key
    let public_key = match VerifyingKey::try_from(public_key_bytes.as_slice()) {
        Ok(pk) => pk,
        Err(e) => return (StatusCode::BAD_REQUEST, Json(VerifyResponse {
            is_valid: false,
            error: Some(format!("Invalid public key size/format: {}", e)),
        })),
    };

    // 4. Parse Ed25519 Signature
    let signature = match Signature::try_from(signature_bytes.as_slice()) {
        Ok(sig) => sig,
        Err(e) => return (StatusCode::BAD_REQUEST, Json(VerifyResponse {
            is_valid: false,
            error: Some(format!("Invalid signature size/format: {}", e)),
        })),
    };

    // 5. Verify
    let is_valid = public_key.verify(payload.message.as_bytes(), &signature).is_ok();

    (StatusCode::OK, Json(VerifyResponse {
        is_valid,
        error: None,
    }))
}

#[tokio::main]
async fn main() {
    let app = Router::new().route("/verify", post(verify_handler));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3001").await.unwrap();
    println!("🚀 Rust Verify Service running on http://localhost:3001");
    axum::serve(listener, app).await.unwrap();
}
