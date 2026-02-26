# FastAPI + Kafka + OpenTelemetry (Zero-Code Instrumentation)

## What is Zero-Code Instrumentation?

Zero-code instrumentation means your application code contains **zero OpenTelemetry
imports**. Instead, you prefix your startup command with `opentelemetry-instrument`,
and the OTel agent:

- Monkey-patches FastAPI, `logging`, HTTP clients, and more **at runtime**
- Automatically creates a span for every HTTP request
- Injects `trace_id` and `span_id` into every log record
- Exports traces, metrics, and logs to your OTel Collector

**Your code stays clean. OTel lives entirely outside it.**

---

## Project Structure

```
fastapi-kafka-otel/
├── app/
│   ├── __init__.py
│   ├── main.py              ← pure business logic, zero OTel imports
│   ├── models.py
│   ├── config.py
│   ├── logging_config.py    ← standard logging only, no OTel
│   ├── kafka_producer.py
│   └── kafka_consumer.py
├── otel-collector/
│   ├── otel-collector-config.yaml   ← collector pipeline config
│   ├── prometheus.yaml              ← prometheus scrape config
│   └── grafana-datasources.yaml     ← auto-provisions Grafana data sources
├── .env                     ← all OTel config as environment variables
├── docker-compose.yml       ← Kafka + full observability stack
├── run.sh                   ← start the API with OTel agent (loads .env first)
├── run_consumer.sh          ← start the consumer with OTel agent (loads .env first)
└── requirements.txt
```

---

## How the Signals Flow

```
Your App (FastAPI)
      │
      │  OTLP HTTP/protobuf (port 4318)
      ▼
OTel Collector
      │
      ├──► Jaeger     (traces)  → http://localhost:16686
      ├──► Prometheus (metrics) → http://localhost:9090
      └──► Loki       (logs)   → viewed via Grafana
                                  http://localhost:3000
```

---

## Prerequisites

- Python 3.11.14 with a virtual environment activated
- Docker Desktop running

---

## Step 1 — Install Python Dependencies

```bash
pip install -r requirements.txt
```

After installing, run the OTel bootstrap command. This scans your installed
packages and automatically installs any missing instrumentation libraries:

```bash
opentelemetry-bootstrap -a install
```

> **What does this do?**
> It detects that you have `fastapi` installed and automatically installs
> `opentelemetry-instrumentation-fastapi`, detects `requests` and installs its
> instrumentation, and so on. Run this once, and again after adding new dependencies.

---

## Step 2 — Start the Full Observability Stack

```bash
docker-compose up -d
```

Wait about 20 seconds for all services to be healthy, then verify:

```bash
docker-compose ps
```

| Service | Purpose | URL |
|---|---|---|
| Kafka + Zookeeper | Message broker | `localhost:9092` |
| OTel Collector | Receives signals on HTTP port 4318, fans out to backends | `localhost:4318` |
| Jaeger | Trace visualisation | http://localhost:16686 |
| Prometheus | Metrics storage & query | http://localhost:9090 |
| Loki | Log aggregation | (backend only, no UI) |
| Grafana | Unified dashboard for all signals | http://localhost:3000 |

---

## Step 3 — Run the API with Zero-Code Instrumentation

Use the provided shell script. Do **not** call `opentelemetry-instrument` directly
from your shell — it won't be found unless the venv is active, and even then
the `.env` variables won't be loaded. The script handles both problems for you.

```bash
chmod +x run.sh
./run.sh
```

What this script does internally:
```bash
# 1. Locates your venv/ or .venv/ directory automatically
OTEL_INSTRUMENT="$VENV_DIR/bin/opentelemetry-instrument"

# 2. Sources .env so all OTEL_* vars are in the shell
#    (opentelemetry-instrument reads env vars, NOT .env files directly)
source .env

# 3. Starts the app using the full venv path — works whether venv is active or not
"$OTEL_INSTRUMENT" "$UVICORN" app.main:app --host 0.0.0.0 --port 8000 --reload
```

You will see startup output like:
```
Starting FastAPI with OTel zero-code instrumentation...
  Service : fastapi-kafka-service
  Endpoint: http://localhost:4318
  Protocol: http/protobuf

INFO | app.main:lifespan - Application starting up
```

---

## Step 4 — Run the Kafka Consumer with Zero-Code Instrumentation

Open a **second terminal**, activate the venv, then:

```bash
chmod +x run_consumer.sh
./run_consumer.sh
```

---

## Step 5 — Generate a User and Observe Telemetry

```bash
curl -X POST http://localhost:8000/users/generate
```

Expected response:
```json
{"id": "3f1b2c4d-...", "name": "Alice Johnson"}
```

---

## Step 6 — View Telemetry in the Backends

### Traces → Jaeger

1. Open http://localhost:16686
2. Select `fastapi-kafka-service` from the **Service** dropdown
3. Click **Find Traces**
4. Click any trace to see the full span breakdown: HTTP request + Kafka publish as child span

### Metrics → Prometheus

1. Open http://localhost:9090
2. In the query box enter: `http_server_duration_milliseconds_bucket`
3. Click **Execute** to see request latency histograms

### Logs → Grafana + Loki

1. Open http://localhost:3000 (credentials: `admin` / `admin`)
2. Click **Explore** in the left sidebar
3. Select **Loki** as the data source
4. In the query box enter:
   ```
   {service_name="fastapi-kafka-service"}
   ```
5. Every log line will contain `trace_id` and `span_id` — click them to jump
   directly to the matching trace in Jaeger

---

## The .env File Explained

All OTel behaviour is controlled by these environment variables:

```env
# Identifies your service in every signal sent to the collector
OTEL_SERVICE_NAME=fastapi-kafka-service
OTEL_SERVICE_VERSION=1.0.0
OTEL_DEPLOYMENT_ENVIRONMENT=local

# OTel Collector address — HTTP/protobuf on port 4318
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf

# Enable all three signals
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp

# KEY SETTING FOR LOGS:
# Tells the agent to hook into Python's standard logging module and
# inject trace_id + span_id into every log record automatically
OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED=true

# Metrics push interval (15 seconds)
OTEL_METRIC_EXPORT_INTERVAL=15000

# 100% trace sampling — lower this in production (e.g. 0.1 = 10%)
OTEL_TRACES_SAMPLER=always_on
```

To switch to a different environment (staging, production), only change `.env`. No code changes needed.

---

## What the Agent Instruments Automatically

| Library | What it captures |
|---|---|
| FastAPI / Starlette | Span per HTTP request with route, method, status code |
| Python `logging` | Injects `trace_id`, `span_id`, `service.name` into every log record |
| `requests` / `urllib3` | Span per outbound HTTP call |

---

## Useful Commands

```bash
# Stop the full observability stack
docker-compose down

# Watch OTel Collector logs — useful to confirm signals are arriving
docker-compose logs otel-collector -f

# Re-run bootstrap after adding new pip packages
opentelemetry-bootstrap -a install

# Confirm which OTel instrumentation libraries are installed
pip list | grep opentelemetry
```

---

## Troubleshooting

| Problem | Likely cause | Fix |
|---|---|---|
| No traces in Jaeger | Env vars not loaded into shell | Use `./run.sh` — not `uvicorn` directly |
| Logs missing from Loki | `OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED` not set | Confirm it is `true` in `.env` and `run.sh` is exporting it |
| `opentelemetry-instrument: command not found` | Script using bare command instead of venv path | Always use `./run.sh` — it resolves the full venv binary path automatically |
| `Connection refused` to port 4318 | OTel Collector container not running | `docker-compose ps` — restart with `docker-compose up -d` |
| `NoBrokersAvailable` on Kafka | Kafka not ready yet | Wait 15–20s after `docker-compose up`, then retry |
| Metrics not visible in Prometheus | Prometheus not scraping collector | Check `otel-collector/prometheus.yaml` — target must be `otel-collector:8889` |
