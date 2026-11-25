#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "SPA UNAS - Database QA"
echo "=========================================="

case "${SUITE:-}" in
  integracion|todo)
    ;;
  *)
    echo "ERROR: Unsupported database test suite"
    exit 1
    ;;
esac

export LC_ALL=C

ROOT_DIR="$(pwd -P)"
CONTAINER="spa-qa-database"
IMAGE="postgis/postgis:16-3.4"

SHIM="scripts/ci/supabase_shim.sql"
SEED="supabase/seed.sql"

shopt -s nullglob
MIGRATIONS=(supabase/migrations/*.sql)
SQL_TESTS=(tests/sql/*.sql)

if [[ ! -f "$SHIM" ]]; then
  echo "ERROR: Supabase shim not found"
  exit 1
fi

if (( ${#MIGRATIONS[@]} == 0 )); then
  echo "ERROR: No migrations found"
  exit 1
fi

if (( ${#SQL_TESTS[@]} == 0 )); then
  echo "ERROR: No SQL tests found"
  exit 1
fi

cleanup() {
  echo "Cleaning up temporary database"
  docker rm -f -v "$CONTAINER" >/dev/null 2>&1 || true
}

trap cleanup EXIT

echo "STEP 1: Starting temporary PostgreSQL/PostGIS"

docker run -d \
  --name "$CONTAINER" \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=spa \
  -v "$ROOT_DIR:/workspace:ro" \
  "$IMAGE"

echo "STEP 2: Waiting for database readiness"

READY=false

for attempt in $(seq 1 60); do
  if docker exec "$CONTAINER" \
    pg_isready -h 127.0.0.1 -U postgres -d spa >/dev/null 2>&1; then
    READY=true
    break
  fi

  sleep 2
done

if [[ "$READY" != "true" ]]; then
  echo "ERROR: Database did not become ready"
  docker logs "$CONTAINER"
  exit 1
fi

run_sql() {
  docker exec "$CONTAINER" \
    psql -X -v ON_ERROR_STOP=1 \
    -U postgres -d spa \
    -f "/workspace/$1"
}

echo "STEP 3: Applying Supabase shim"
run_sql "$SHIM"

echo "STEP 4: Applying migrations"

for migration in "${MIGRATIONS[@]}"; do
  echo "Migration: $migration"
  run_sql "$migration"
done

echo "STEP 5: Loading seed"

if [[ -f "$SEED" ]]; then
  run_sql "$SEED"
else
  echo "No seed file found"
fi

echo "STEP 6: Running SQL tests"

for test_file in "${SQL_TESTS[@]}"; do
  echo "SQL test: $test_file"
  run_sql "$test_file"
done

echo "STEP 7: Checking migration idempotency"

for migration in "${MIGRATIONS[@]}"; do
  echo "Reapplying: $migration"
  run_sql "$migration"
done

echo "=========================================="
echo "DATABASE QA: PASSED"
echo "Migrations: ${#MIGRATIONS[@]}"
echo "SQL test files: ${#SQL_TESTS[@]}"
echo "Idempotency: PASSED"
echo "=========================================="
