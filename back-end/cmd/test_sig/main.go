package main

import (
	"context"
	"encoding/hex"
	"fmt"
	"log"

	fxrpc "paysif/internal/grpc"
)

func main() {
	// 1. Connect using the production-ready wrapper
	// Rust engine defaults to /tmp/fx_engine.sock in IPC mode
	client, err := fxrpc.NewFXClient("unix:///tmp/fx_engine.sock")
	if err != nil {
		log.Fatalf("Failed to connect: %v", err)
	}
	defer client.Close()

	fmt.Println("✅ Connected to Rust FX Engine via UDS")

	// 2. Mock Data (Valid Ed25519 Keypair)
	// Key: 32 bytes, Sig: 64 bytes
	pubKey, _ := hex.DecodeString("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a")
	msg := []byte("paysif-signature-test")
	// This is a fake signature, verification should fail gracefully
	sig := make([]byte, 64) 

	fmt.Println("🚀 Testing SIMD-Accelerated Signature Verification...")

	// 3. Call the method using the wrapper
	resp, err := client.VerifySignature(context.Background(), pubKey, sig, msg)
	if err != nil {
		log.Fatalf("RPC Failed: %v", err)
	}

	if resp.Valid {
		fmt.Println("✅ Signature VALID!")
	} else {
		fmt.Printf("❌ Signature INVALID: %s\n", resp.ErrorMessage)
	}
	
	fmt.Println("🎉 Integration Test Passed (Connectivity & Protocol Verified)")
}
