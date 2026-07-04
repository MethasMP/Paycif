.PHONY: build run stop clean redis-up redis-down

build:
	@echo "🐹 Building Go Microservices..."
	@mkdir -p bin
	go build -o bin/verify-service ./cmd/verify-service
	go build -o bin/accounting-core ./cmd/accounting-core
	go build -o bin/fx-engine ./cmd/fx-engine
	go build -o bin/payload-worker ./cmd/payload-worker
	go build -o bin/worker ./cmd/worker
	go build -o bin/api ./cmd/api
	@echo "✅ All Services Built"

run: stop build
	@echo "🚀 Starting all services..."
	@mkdir -p logs
	@if [ -f .env ]; then set -a; source .env; set +a; fi; \
	./bin/verify-service > logs/verify-service.log 2>&1 & echo $$! > bin/verify-service.pid; \
	./bin/accounting-core > logs/accounting-core.log 2>&1 & echo $$! > bin/accounting-core.pid; \
	./bin/fx-engine > logs/fx-engine.log 2>&1 & echo $$! > bin/fx-engine.pid; \
	./bin/payload-worker > logs/payload-worker.log 2>&1 & echo $$! > bin/payload-worker.pid; \
	./bin/worker > logs/worker.log 2>&1 & echo $$! > bin/worker.pid; \
	echo "⏳ Waiting for services to stabilize..."; \
	sleep 2; \
	echo "🚀 Starting Go API (Press Ctrl+C to stop)..."; \
	GIN_MODE=debug ./bin/api

stop:
	@echo "🛑 Stopping all services..."
	@kill `cat bin/verify-service.pid 2>/dev/null` 2>/dev/null || true
	@kill `cat bin/accounting-core.pid 2>/dev/null` 2>/dev/null || true
	@kill `cat bin/fx-engine.pid 2>/dev/null` 2>/dev/null || true
	@kill `cat bin/payload-worker.pid 2>/dev/null` 2>/dev/null || true
	@kill `cat bin/worker.pid 2>/dev/null` 2>/dev/null || true
	@rm -f bin/*.pid
	@pkill -f bin/api || true
	@lsof -ti:8080 | xargs kill -9 2>/dev/null || true
	@echo "✨ All services stopped."

clean: stop
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf bin tmp_go_build logs *.log
	@echo "✅ Cleaned"

redis-up:
	@echo "🚀 Starting Redis..."
	docker-compose -f docker-compose.redis.yml up -d
	@echo "✅ Redis started on port 6379"

redis-down:
	@echo "🛑 Stopping Redis..."
	docker-compose -f docker-compose.redis.yml down
	@echo "✅ Redis stopped"
