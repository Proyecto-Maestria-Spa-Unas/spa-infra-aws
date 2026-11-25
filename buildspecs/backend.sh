#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "SPA UNAS - Backend QA"
echo "=========================================="

case "${SUITE:-}" in
  unitarias|integracion|todo)
    ;;
  *)
    echo "ERROR: Unsupported backend test suite"
    exit 1
    ;;
esac

export LC_ALL=C
export APP_ENV=test
export JWT_SECRET=ci-only-not-a-real-secret-0123456789
export DB_URL=postgresql+psycopg://postgres:postgres@127.0.0.1:1/inexistente

CONTAINER="spa-qa-backend-postgis"
IMAGE="postgis/postgis:16-3.4"
DB_REPO="https://github.com/Proyecto-Maestria-Spa-Unas/spa-database.git"

WORK_DIR="$(mktemp -d)"
DB_DIR="$WORK_DIR/spa-database"
CONTAINER_STARTED=false

cleanup() {
  echo "Cleaning up temporary resources"

  if [[ "$CONTAINER_STARTED" == "true" ]]; then
    docker rm -f -v "$CONTAINER" >/dev/null 2>&1 || true
  fi

  rm -rf -- "$WORK_DIR"
}

trap cleanup EXIT

echo "Checking Python runtime"
python --version

if ! python -c 'import sys; sys.exit(sys.version_info[:2] != (3, 12))'; then
  echo "ERROR: Python 3.12 is required"
  exit 1
fi

if [[ ! -f requirements-dev.txt || ! -f requirements.txt ]]; then
  echo "ERROR: Backend requirements not found"
  exit 1
fi

echo "Installing backend dependencies"
python -m pip install --upgrade pip
python -m pip install -r requirements-dev.txt

run_unitarias() {
  echo "=========================================="
  echo "UNIT TESTS AND CODE QUALITY"
  echo "=========================================="

  echo "STEP 1: Ruff lint"
  ruff check .

  echo "STEP 2: Ruff format"
  ruff format --check .

  echo "STEP 3: Mypy"
  mypy app

  echo "STEP 4: Architecture contracts"
  lint-imports

  echo "STEP 5: Unit tests and coverage"
  pytest -m "not integracion" \
    --cov=app \
    --cov-report=term-missing \
    --cov-report=xml \
    --cov-fail-under=80

  echo "STEP 6: Dependency audit"
  pip-audit --skip-editable

  echo "UNIT TESTS: PASSED"
}

run_sql() {
  docker exec "$CONTAINER" \
    psql -X -v ON_ERROR_STOP=1 \
    -U postgres -d app_test \
    -f "/workspace/$1"
}

run_integracion() {
  echo "=========================================="
  echo "INTEGRATION TESTS"
  echo "=========================================="

  echo "STEP 1: Cloning database repository"

  git clone --depth 1 --branch develop \
    "$DB_REPO" "$DB_DIR"

  echo "Database commit:"
  git -C "$DB_DIR" rev-parse HEAD

  if [[ ! -f "$DB_DIR/scripts/ci/supabase_shim.sql" ]]; then
    echo "ERROR: Supabase shim not found"
    exit 1
  fi

  shopt -s nullglob
  MIGRATIONS=("$DB_DIR"/supabase/migrations/*.sql)

  if (( ${#MIGRATIONS[@]} == 0 )); then
    echo "ERROR: No database migrations found"
    exit 1
  fi

  echo "STEP 2: Starting temporary PostGIS"

  docker run -d \
    --name "$CONTAINER" \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD=postgres \
    -e POSTGRES_DB=app_test \
    -p 127.0.0.1:54322:5432 \
    -v "$DB_DIR:/workspace:ro" \
    "$IMAGE"

  CONTAINER_STARTED=true

  echo "STEP 3: Waiting for database readiness"

  READY=false

  for attempt in $(seq 1 60); do
    if docker exec "$CONTAINER" \
      pg_isready -h 127.0.0.1 \
      -U postgres -d app_test >/dev/null 2>&1; then
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

  echo "STEP 4: Applying Supabase shim"
  run_sql "scripts/ci/supabase_shim.sql"

  echo "STEP 5: Applying database migrations"

  for migration in "${MIGRATIONS[@]}"; do
    relative_path="${migration#"$DB_DIR"/}"
    echo "Migration: $relative_path"
    run_sql "$relative_path"
  done

  echo "STEP 6: Loading seed"

  if [[ -f "$DB_DIR/supabase/seed.sql" ]]; then
    run_sql "supabase/seed.sql"
  else
    echo "No seed file found"
  fi

  export DB_URL_INTEGRACION=postgresql+psycopg://postgres:postgres@127.0.0.1:54322/app_test
  export DB_URL="$DB_URL_INTEGRACION"

  echo "STEP 7: Verifying SQLAlchemy connection"

  python - <<'PYTHON'
import os
from sqlalchemy import create_engine, text

engine = create_engine(
    os.environ["DB_URL_INTEGRACION"],
    connect_args={
        "prepare_threshold": None,
        "connect_timeout": 3,
    },
)

try:
    with engine.connect() as connection:
        result = connection.execute(text("SELECT 1")).scalar()
        if result != 1:
            raise RuntimeError("Database connection check failed")
        print("Database connection: OK")
finally:
    engine.dispose()
PYTHON

  echo "STEP 8: Running integration tests"

  pytest -m "integracion" \
    -rs \
    --junitxml="$WORK_DIR/integration-results.xml"

  echo "STEP 9: Verifying integration test execution"

  python - "$WORK_DIR/integration-results.xml" <<'PYTHON'
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
cases = list(root.iter("testcase"))

total = len(cases)
skipped = sum(case.find("skipped") is not None for case in cases)
executed = total - skipped

print(f"Collected tests: {total}")
print(f"Skipped tests: {skipped}")
print(f"Executed tests: {executed}")

if executed == 0:
    raise SystemExit("ERROR: No integration tests were executed")
PYTHON

  echo "INTEGRATION TESTS: PASSED"
}

case "$SUITE" in
  unitarias)
    run_unitarias
    ;;
  integracion)
    run_integracion
    ;;
  todo)
    run_unitarias
    run_integracion
    ;;
esac

echo "=========================================="
echo "BACKEND QA: PASSED"
echo "=========================================="
