#!/bin/bash
# Setup dependencies in a virtual environment.
set -e
uv sync
source .venv/bin/activate

# Start RabbitMQ and Redis services using Docker. Prefer stable image tags and
# tolerate an already-occupied local Redis port.
docker start op-rabbitmq 2>/dev/null || docker run -d --name op-rabbitmq -p 5672:5672 rabbitmq:3.13

if ! docker start op-redis 2>/dev/null; then
  if docker run -d --name op-redis -p 6379:6379 redis:7; then
    :
  else
    echo "Redis port 6379 already in use; reusing existing local Redis service."
  fi
fi

# Start Celery worker
./scripts/start_worker.sh &

# Start worker API
./scripts/start_api.sh
