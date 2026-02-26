#!/usr/bin/env bash
# run_consumer.sh — starts the Kafka consumer with zero-code OTel instrumentation
#
# USAGE:
#   chmod +x run_consumer.sh
#   ./run_consumer.sh

set -e

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

if [ ! -f "$OTEL_INSTRUMENT" ]; then
    echo "ERROR: opentelemetry-instrument not found at: $OTEL_INSTRUMENT"
    echo "       Run: pip install -r requirements.txt"
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo "ERROR: .env file not found at: $SCRIPT_DIR/.env"
    exit 1
fi

set -a
source "$SCRIPT_DIR/.env"
set +a

echo "Starting Kafka consumer with OTel zero-code instrumentation..."
echo "  Venv    : $VENV_DIR"
echo "  Service : $OTEL_SERVICE_NAME"
echo "  Endpoint: $OTEL_EXPORTER_OTLP_ENDPOINT"
echo ""

"$OTEL_INSTRUMENT" "$PYTHON" -m app.kafka_consumer
