#!/usr/bin/env bash
# run.sh — starts the app with zero-code OTel instrumentation
#
# WHY THIS FILE EXISTS:
#   opentelemetry-instrument reads OTEL_* config from environment variables.
#   It does NOT automatically read a .env file.
#   This script uses `export $(cat .env)` to load .env into the shell first,
#   then hands off to opentelemetry-instrument.
#
# USAGE:
#   chmod +x run.sh
#   ./run.sh

set -e

# Load .env into the current shell environment
# The grep strips blank lines and comment lines (lines starting with #)
export $(grep -v '^\s*#' .env | grep -v '^\s*$' | xargs)

echo "Starting FastAPI with OTel zero-code instrumentation..."
echo "  Service : $OTEL_SERVICE_NAME"
echo "  Endpoint: $OTEL_EXPORTER_OTLP_ENDPOINT"
echo "  Protocol: $OTEL_EXPORTER_OTLP_PROTOCOL"
echo ""

opentelemetry-instrument uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
