#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "SPA UNAS - Frontend QA"
echo "=========================================="

case "${SUITE:-}" in
  unitarias|todo)
    ;;
  *)
    echo "ERROR: Unsupported frontend test suite"
    exit 1
    ;;
esac

if [[ ! -f package.json || ! -f package-lock.json ]]; then
  echo "ERROR: Frontend package files not found"
  exit 1
fi

echo "Checking runtime versions"
node --version
npm --version

if [[ "$(node -p 'process.versions.node.split(".")[0]')" != "22" ]]; then
  echo "ERROR: Node.js 22 is required"
  exit 1
fi

export CI=true

echo "STEP 1: Installing dependencies"
npm ci

echo "STEP 2: Running ESLint"
npm run lint

echo "STEP 3: Running tests and coverage"
npm run test:ci

echo "STEP 4: Building frontend"
npm run build

echo "STEP 5: Auditing dependencies"
npm audit --omit=dev --audit-level=high

echo "=========================================="
echo "FRONTEND QA: PASSED"
echo "=========================================="
