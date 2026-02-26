# run_consumer.ps1 — starts the Kafka consumer with zero-code OTel instrumentation
#
# USAGE (from the project root in PowerShell):
#   .\run_consumer.ps1
#
# Works with Conda environments and standard venv.
# If using Conda, run `conda activate <env-name>` before this script.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ── Step 1: locate opentelemetry-instrument ───────────────────────────────────
$OtelInstrument = $null
$Python         = $null
$EnvLabel       = $null

if ($env:CONDA_PREFIX) {
    $candidate = "$env:CONDA_PREFIX\Scripts\opentelemetry-instrument.exe"
    if (Test-Path $candidate) {
        $OtelInstrument = $candidate
        $Python         = "$env:CONDA_PREFIX\python.exe"
        $EnvLabel       = "Conda: $env:CONDA_PREFIX"
    } else {
        Write-Host "WARNING: Conda env active ($env:CONDA_PREFIX) but opentelemetry-instrument not found." -ForegroundColor Yellow
        Write-Host "         Run: pip install -r requirements.txt && opentelemetry-bootstrap -a install" -ForegroundColor Yellow
        Write-Host ""
    }
}

if (-not $OtelInstrument -and $env:VIRTUAL_ENV) {
    $candidate = "$env:VIRTUAL_ENV\Scripts\opentelemetry-instrument.exe"
    if (Test-Path $candidate) {
        $OtelInstrument = $candidate
        $Python         = "$env:VIRTUAL_ENV\Scripts\python.exe"
        $EnvLabel       = "venv (active): $env:VIRTUAL_ENV"
    }
}

if (-not $OtelInstrument -and (Test-Path "$ScriptDir\venv")) {
    $candidate = "$ScriptDir\venv\Scripts\opentelemetry-instrument.exe"
    if (Test-Path $candidate) {
        $OtelInstrument = $candidate
        $Python         = "$ScriptDir\venv\Scripts\python.exe"
        $EnvLabel       = "venv: $ScriptDir\venv"
    }
}

if (-not $OtelInstrument -and (Test-Path "$ScriptDir\.venv")) {
    $candidate = "$ScriptDir\.venv\Scripts\opentelemetry-instrument.exe"
    if (Test-Path $candidate) {
        $OtelInstrument = $candidate
        $Python         = "$ScriptDir\.venv\Scripts\python.exe"
        $EnvLabel       = "venv: $ScriptDir\.venv"
    }
}

if (-not $OtelInstrument) {
    Write-Host "ERROR: Could not find opentelemetry-instrument in any environment." -ForegroundColor Red
    Write-Host ""
    Write-Host "  If you are using Conda:"
    Write-Host "    conda activate <your-env-name>"
    Write-Host "    pip install -r requirements.txt"
    Write-Host "    opentelemetry-bootstrap -a install"
    Write-Host "    .\run_consumer.ps1"
    Write-Host ""
    Write-Host "  If you are using a standard venv:"
    Write-Host "    .\venv\Scripts\Activate.ps1"
    Write-Host "    pip install -r requirements.txt"
    Write-Host "    opentelemetry-bootstrap -a install"
    Write-Host "    .\run_consumer.ps1"
    exit 1
}

# ── Step 2: load .env ─────────────────────────────────────────────────────────
$EnvFile = "$ScriptDir\.env"
if (-not (Test-Path $EnvFile)) {
    Write-Host "ERROR: .env file not found at: $EnvFile" -ForegroundColor Red
    exit 1
}

Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and $line -notmatch '^\s*#') {
        $parts = $line -split '=', 2
        $key   = $parts[0].Trim()
        $value = $parts[1].Trim()
        [System.Environment]::SetEnvironmentVariable($key, $value, "Process")
    }
}

# ── Step 3: print startup summary ─────────────────────────────────────────────
Write-Host ""
Write-Host "Starting Kafka consumer with OTel zero-code instrumentation..." -ForegroundColor Cyan
Write-Host "  Environment : $EnvLabel"
Write-Host "  Service     : $env:OTEL_SERVICE_NAME"
Write-Host "  Endpoint    : $env:OTEL_EXPORTER_OTLP_ENDPOINT"
Write-Host ""

# ── Step 4: start the consumer ────────────────────────────────────────────────
& $OtelInstrument $Python -m app.kafka_consumer
