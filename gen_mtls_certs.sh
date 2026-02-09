#!/bin/bash
set -e

# Directory for certs
CERT_DIR="back-end/certs"
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

echo "🔐 Generating mTLS Certificates..."

# 1. Generate CA's private key and self-signed certificate
openssl req -x509 -newkey rsa:4096 -days 365 -nodes -keyout ca-key.pem -out ca-cert.pem -subj "/C=TH/ST=Bangkok/L=Bangkok/O=Paycif/OU=Security/CN=Paycif Root CA"

echo "✅ CA Certificate generated"

# 2. Generate Web Server's private key and certificate signing request (CSR)
openssl req -newkey rsa:4096 -nodes -keyout server-key.pem -out server-req.pem -subj "/C=TH/ST=Bangkok/L=Bangkok/O=Paycif/OU=Accounting/CN=localhost"

# 3. Use CA's private key to sign web server's CSR and get back the signed certificate
openssl x509 -req -in server-req.pem -days 365 -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem -extfile <(echo "subjectAltName=DNS:localhost,IP:127.0.0.1,IP:0.0.0.0")

echo "✅ Server Certificate generated"

# 4. Generate Client's private key and CSR
openssl req -newkey rsa:4096 -nodes -keyout client-key.pem -out client-req.pem -subj "/C=TH/ST=Bangkok/L=Bangkok/O=Paycif/OU=Backend/CN=go-client"

# 5. Use CA's private key to sign client's CSR
openssl x509 -req -in client-req.pem -days 365 -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial -out client-cert.pem

echo "✅ Client Certificate generated"

# Set permissions
chmod 600 *-key.pem
chmod 644 *-cert.pem

echo "🎉 All certificates generated in $CERT_DIR"
