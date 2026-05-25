# Build Stage
FROM rust:1.76-slim-bookworm as builder

WORKDIR /app
COPY . .

# Install Protocol Buffers compiler (needed for tonic-build)
RUN apt-get update && apt-get install -y protobuf-compiler libprotobuf-dev

# Build (Release mode)
RUN cargo build --release

# Runtime Stage
FROM debian:bookworm-slim

WORKDIR /app
COPY --from=builder /app/target/release/fx_engine .

# Expose gRPC port
EXPOSE 50052

CMD ["./fx_engine"]
