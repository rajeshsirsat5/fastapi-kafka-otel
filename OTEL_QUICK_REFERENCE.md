# OpenTelemetry Zero-Code Instrumentation — Quick Reference

This document captures exactly what was needed to get **traces, metrics, and logs**
flowing from a FastAPI + Kafka Python app into an OTel Collector (and onwards to
Grafana/Jaeger/Loki).

---

## 1. Dependencies

Add these two packages to your `requirements.txt` (or install them directly):

```
opentelemetry-distro
opentelemetry-exporter-otlp
```

**Why these two?**

- `opentelemetry-distro` — installs the OTel SDK and the `opentelemetry-instrument` CLI tool
- `opentelemetry-exporter-otlp` — a meta-package that pulls in both the HTTP and gRPC OTLP exporters at automatically matching versions. Do **not** pin the sub-packages (`proto-grpc`, `proto-http`) separately — this causes version conflict errors.

After installing, run the bootstrap command once. It scans your installed packages
and auto-installs any matching instrumentation libraries (e.g. for FastAPI, requests, logging):

```bash
pip install opentelemetry-distro opentelemetry-exporter-otlp
opentelemetry-bootstrap -a install
```

---

## 2. Environment Variables

Set these in PowerShell before running the instrument command:

```powershell
# Your service name — appears in every trace, metric, and log in Grafana
$env:OTEL_SERVICE_NAME                            = "fastapi-kafka-service"
$env:OTEL_SERVICE_VERSION                         = "1.0.0"
$env:OTEL_DEPLOYMENT_ENVIRONMENT                  = "local"

# OTel Collector address — HTTP on port 4318
$env:OTEL_EXPORTER_OTLP_ENDPOINT                  = "http://localhost:4318"
$env:OTEL_EXPORTER_OTLP_PROTOCOL                  = "http/protobuf"

# Which signals to export (traces and metrics work from env vars)
$env:OTEL_TRACES_EXPORTER                         = "otlp"
$env:OTEL_METRICS_EXPORTER                        = "otlp"
$env:OTEL_LOGS_EXPORTER                           = "otlp"

# CRITICAL for logs — tells the agent to hook into Python's standard
# logging module and inject trace_id + span_id into every log record.
# Without this, logs are NOT exported even if OTEL_LOGS_EXPORTER is set.
$env:OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED = "true"

# How often metrics are pushed to the collector (milliseconds)
$env:OTEL_METRIC_EXPORT_INTERVAL                  = "15000"

# Sample 100% of traces. Lower this in production (e.g. 0.1 = 10%)
$env:OTEL_TRACES_SAMPLER                          = "always_on"
```

> **Note:** `OTEL_LOGS_EXPORTER=otlp` in the env vars alone is NOT enough
> to export logs. You must also pass `--logs_exporter otlp` explicitly on the
> command line (see Section 3). This is different from traces and metrics.

---

## 3. The Instrument Command

Run your app wrapped by the OTel agent. The `--logs_exporter` flag is **required
on the command line** — it cannot be set via environment variable alone.

**To run the FastAPI app:**

```powershell
opentelemetry-instrument `
    --traces_exporter otlp `
    --metrics_exporter otlp `
    --logs_exporter otlp `
    uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

**To run the Kafka consumer:**

```powershell
opentelemetry-instrument `
    --traces_exporter otlp `
    --metrics_exporter otlp `
    --logs_exporter otlp `
    python -m app.kafka_consumer
```

> **Backtick (`` ` ``) is the PowerShell line continuation character.**
> On Linux/macOS bash, use `\` instead.

---

## 4. Things to Watch Out For

**Use standard `logging`, not Loguru**
The OTel agent hooks into Python's built-in `logging` module. Loguru has its
own separate pipeline and is invisible to OTel — logs will never reach the
collector. Always use `logging.getLogger(__name__)`.

**`opentelemetry-instrument` must be on your PATH**
The binary lives inside your environment's `Scripts\` folder (Conda or venv).
If you get *"command not found"*, either activate your environment first or
use the full path:
```powershell
& "$env:CONDA_PREFIX\Scripts\opentelemetry-instrument.exe" ...
```

**All OTel packages must be on the same release train**
If you pin versions manually, the SDK core (`opentelemetry-sdk==X.Y`) and
contrib packages (`opentelemetry-instrumentation-*`) must match. The safest
approach is to let `opentelemetry-exporter-otlp` (the meta-package) resolve
versions automatically — avoid pinning sub-packages individually.

**The OTel Collector must be reachable before starting the app**
If the collector is not running on `localhost:4318`, the app will start but
silently drop all telemetry. Check with:
```powershell
Invoke-WebRequest -Uri http://localhost:4318 -Method GET
```
A connection refused error means the collector is down.

**Run `opentelemetry-bootstrap` after adding new dependencies**
Every time you `pip install` a new library (e.g. `requests`, `sqlalchemy`),
re-run:
```bash
opentelemetry-bootstrap -a install
```
This ensures the matching instrumentation library is installed for the new package.
