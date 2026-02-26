#!/usr/bin/env bash
# run_consumer.sh — starts the Kafka consumer with zero-code OTel instrumentation

set -e

export $(grep -v '^\s*#' .env | grep -v '^\s*$' | xargs)

echo "Starting Kafka consumer with OTel zero-code instrumentation..."
echo "  Service : $OTEL_SERVICE_NAME"
echo "  Endpoint: $OTEL_EXPORTER_OTLP_ENDPOINT"
echo ""

opentelemetry-instrument python -m app.kafka_consumer
