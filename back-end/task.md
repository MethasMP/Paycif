# Tasks

- [x] Implement UDS HTTP Client in `internal/usecase/signature.go` for `VerifySignature`
- [x] Add caching for device public keys in `internal/usecase/signature.go`
- [x] Tune database connection pool sizes:
  - [x] Set API Gateway max open connections to 30 in `cmd/api/main.go`
  - [x] Set Accounting Core max open connections to 15 in `cmd/accounting-core/main.go`
  - [x] Set repository DB default max open connections to 15 in `internal/adapter/repository/connection.go`
- [x] Run stress load tests and verify 100% success rate
