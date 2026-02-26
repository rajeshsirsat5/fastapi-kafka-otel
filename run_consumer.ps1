# run_consumer.ps1 — starts the Kafka consumer with zero-code OTel instrumentation
#
# USAGE (from the project root in PowerShell):
#   .\run_consumer.ps1
#
# If you get a script execution policy error, run this once first:
#   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Step 1: locate the virtual environment ────────────────────────────────────
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (Test-Path "$ScriptDir\venv") {
    $VenvDir = "$ScriptDir\venv"
} elseif (Test-Path "$ScriptDir\.venv") {
    $VenvDir = "$ScriptDir\.venv"
} else {
    Write-Error @"
ERROR: No virtual environment found.
       Expected 'venv\' or '.venv\' in: $ScriptDir
       Create one with:  python -m venv venv
       Then install deps: pip install -r requirements.txt
"@
    exit 1
}

$OtelInstrument = "$VenvDir\Scripts\opentelemetry-instrument.exe"
$Python         = "$VenvDir\Scripts\python.exe"

# ── Step 2: confirm opentelemetry-instrument is installed ─────────────────────
if (-not (Test-Path $OtelInstrument)) {
    Write-Error @"
ERROR: opentelemetry-instrument not found at: $OtelInstrument
       Run: pip install -r requirements.txt
       Then: opentelemetry-bootstrap -a install
"@
    exit 1
}

# ── Step 3: load .env into the current PowerShell session ────────────────────
$EnvFile = "$ScriptDir\.env"
if (-not (Test-Path $EnvFile)) {
    Write-Error "ERROR: .env file not found at: $EnvFile"
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

# ── Step 4: print startup summary ─────────────────────────────────────────────
Write-Host ""
Write-Host "Starting Kafka consumer with OTel zero-code instrumentation..." -ForegroundColor Cyan
Write-Host "  Venv    : $VenvDir"
Write-Host "  Service : $env:OTEL_SERVICE_NAME"
Write-Host "  Endpoint: $env:OTEL_EXPORTER_OTLP_ENDPOINT"
Write-Host ""

# ── Step 5: start the consumer ────────────────────────────────────────────────
& $OtelInstrument $Python -m app.kafka_consumer
