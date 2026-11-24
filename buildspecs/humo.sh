#!/usr/bin/env bash

set -euo pipefail

echo "========================================"
echo "SPA UNAS - Infrastructure smoke test"
echo "========================================"

echo "[1/5] Checking Python 3.12"

python --version

python -c '
import sys

if sys.version_info[:2] != (3, 12):
    raise SystemExit("ERROR: Python 3.12 is required")

print("PASS: Python 3.12")
'

echo "[2/5] Checking Node.js 22 and npm"

node --version
npm --version

if [[ "$(node -p 'process.versions.node.split(".")[0]')" != "22" ]]; then
    echo "ERROR: Node.js 22 is required"
    exit 1
fi

echo "PASS: Node.js 22"

echo "[3/5] Checking Git and Docker"

git --version
docker --version
docker info >/dev/null

echo "PASS: Docker engine available"

echo "[4/5] Starting temporary PostGIS container"

CONTAINER="spa-qa-smoke-postgis"
IMAGE="postgis/postgis:16-3.4"
CONTAINER_STARTED=false

cleanup() {
    local result=$?

    trap - EXIT

    if [[ "$CONTAINER_STARTED" == "true" ]]; then

        if [[ "$result" -ne 0 ]]; then
            echo "PostGIS diagnostic logs:"
            docker logs --tail 100 "$CONTAINER" 2>&1 || true
        fi

        echo "Removing temporary container and volumes"

        if docker rm -f -v "$CONTAINER" >/dev/null 2>&1; then
            echo "PASS: Temporary resources removed"
        else
            echo "ERROR: Temporary resource cleanup failed"
            result=1
        fi

    fi

    if [[ "$result" -eq 0 ]]; then
        echo "========================================"
        echo "INFRASTRUCTURE SMOKE TEST: PASSED"
        echo "========================================"
    else
        echo "========================================"
        echo "INFRASTRUCTURE SMOKE TEST: FAILED"
        echo "========================================"
    fi

    exit "$result"
}

trap cleanup EXIT

docker run -d \
    --name "$CONTAINER" \
    -e POSTGRES_USER=qa_user \
    -e POSTGRES_PASSWORD=qa_smoke_local \
    -e POSTGRES_DB=qa_smoke \
    "$IMAGE"

CONTAINER_STARTED=true

READY=0

for attempt in $(seq 1 60); do

    if docker exec "$CONTAINER" \
        pg_isready \
        -h 127.0.0.1 \
        -U qa_user \
        -d qa_smoke >/dev/null 2>&1; then

        READY=1
        break
    fi

    echo "Waiting for PostgreSQL: attempt $attempt/60"
    sleep 2

done

if [[ "$READY" -ne 1 ]]; then
    echo "ERROR: PostGIS container is not ready"
    exit 1
fi

echo "PASS: PostgreSQL accepting TCP connections"

echo "[5/5] Checking PostgreSQL and PostGIS"

docker exec \
    -e PGPASSWORD=qa_smoke_local \
    "$CONTAINER" \
    psql \
    -X \
    -v ON_ERROR_STOP=1 \
    -h 127.0.0.1 \
    -U qa_user \
    -d qa_smoke \
    -c "SELECT version();" \
    -c "CREATE EXTENSION IF NOT EXISTS postgis;" \
    -c "SELECT PostGIS_Full_Version();" \
    -c "SELECT ST_AsText(ST_MakePoint(1, 2)) AS spatial_test;"

echo "PASS: PostgreSQL and PostGIS operational"
