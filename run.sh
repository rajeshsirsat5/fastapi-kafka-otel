#!/usr/bin/env bash
# run.sh — starts the FastAPI app with zero-code OTel instrumentation
#
# USAGE:
#   chmod +x run.sh
#   ./run.sh
#
# This script:
#   1. Locates the virtual environment (venv/ or .venv/) in the project root
#   2. Resolves the full path to opentelemetry-instrument inside the venv
#      so it works whether or not you have the venv activated in your shell
#   3. Exports OTEL_* vars from .env into the shell
#      (opentelemetry-instrument reads env vars, NOT .env files directly)
#   4. Starts uvicorn wrapped by the OTel agent

set -e

# ── Step 1: locate the virtual environment ────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -d "$SCRIPT_DIR/venv" ]; then
    VENV_DIR="$SCRIPT_DIR/venv"
elif [ -d "$SCRIPT_DIR/.venv" ]; then
    VENV_DIR="$SCRIPT_DIR/.venv"
else
    echo "ERROR: No virtual environment found."
    echo "       Expected 'venv/' or '.venv/' in: $SCRIPT_DIR"
    echo "       Create one with: python -m venv venv"
    echo "       Then install deps: pip install -r requirements.txt"
    exit 1
fi

OTEL_INSTRUMENT="$VENV_DIR/bin/opentelemetry-instrument"
PYTHON="$VENV_DIR/bin/python"
UVICORN="$VENV_DIR/bin/uvicorn"

# ── Step 2: confirm opentelemetry-instrument is installed ─────────────────────
if [ ! -f "$OTEL_INSTRUMENT" ]; then
    echo "ERROR: opentelemetry-instrument not found at: $OTEL_INSTRUMENT"
    echo "       Run: pip install -r requirements.txt"
    exit 1
fi

# ── Step 3: load .env into shell environment ──────────────────────────────────
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo "ERROR: .env file not found at: $SCRIPT_DIR/.env"
    exit 1
fi

set -a   # automatically export every variable that is set
source "$SCRIPT_DIR/.env"
set +a

echo "Starting FastAPI with OTel zero-code instrumentation..."
echo "  Venv    : $VENV_DIR"
echo "  Service : $OTEL_SERVICE_NAME"
echo "  Endpoint: $OTEL_EXPORTER_OTLP_ENDPOINT"
echo "  Protocol: $OTEL_EXPORTER_OTLP_PROTOCOL"
echo ""

# ── Step 4: start the app ─────────────────────────────────────────────────────
"$OTEL_INSTRUMENT" "$UVICORN" app.main:app --host 0.0.0.0 --port 8000 --reload
