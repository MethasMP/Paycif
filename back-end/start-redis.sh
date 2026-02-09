#!/bin/bash

# Start Redis for Paycif Backend
# Usage: ./start-redis.sh [up|down|logs]

set -e

COMPOSE_FILE="docker-compose.redis.yml"
ACTION=${1:-up}

case "$ACTION" in
  up)
    echo "🚀 Starting Redis..."
    docker-compose -f "$COMPOSE_FILE" up -d
    echo "✅ Redis started on port 6379"
    echo "📊 Redis Commander (GUI) available at http://localhost:8081"
    echo ""
    echo "Add to your .env file:"
    echo "REDIS_URL=redis://localhost:6379/0"
    ;;
  down)
    echo "🛑 Stopping Redis..."
    docker-compose -f "$COMPOSE_FILE" down
    echo "✅ Redis stopped"
    ;;
  logs)
    docker-compose -f "$COMPOSE_FILE" logs -f
    ;;
  status)
    docker-compose -f "$COMPOSE_FILE" ps
    ;;
  *)
    echo "Usage: $0 [up|down|logs|status]"
    exit 1
    ;;
esac
