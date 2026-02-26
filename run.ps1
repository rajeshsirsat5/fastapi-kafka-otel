# run.ps1 — starts the FastAPI app with zero-code OTel instrumentation
#
# USAGE (from the project root in PowerShell):
#   .\run.ps1
#
# Works with:
#   - Conda environments  (conda activate <env-name>  then  .\run.ps1)
#   - Standard venv       (venv\ or .venv\ in the project folder)
#
# If you get a script execution policy error, run this once first:
#   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ── Step 1: locate opentelemetry-instrument ───────────────────────────────────
# Priority order:
#   1. Active Conda environment  (CONDA_PREFIX is set by `conda activate`)
#   2. Active venv               (VIRTUAL_ENV is set by `venv\Scripts\Activate.ps1`)
#   3. venv\ folder in project   (user never activated, but folder exists)
#   4. .venv\ folder in project

$OtelInstrument = $null
$EnvLabel       = $null

if ($env:CONDA_PREFIX) {
    # ── Conda path ────────────────────────────────────────────────────────────
    $candidate = "$env:CONDA_PREFIX\Scripts\opentelemetry-instrument.exe"
    if (Test-Path $candidate) {
        $OtelInstrument = $candidate
        $Uvicorn        = "$env:CONDA_PREFIX\Scripts\uvicorn.exe"
        $EnvLabel       = "Conda: $env:CONDA_PREFIX"
    } else {
        Write-Host "WARNING: Conda env active ($env:CONDA_PREFIX) but opentelemetry-instrument not found." -ForegroundColor Yellow
        Write-Host "         Run: pip install -r requirements.txt && opentelemetry-bootstrap -a install" -ForegroundColor Yellow
        Write-Host ""
    }
}

if (-not $OtelInstrument -and $env:VIRTUAL_ENV) {
    # ── Activated venv ────────────────────────────────────────────────────────
    $candidate = "$env:VIRTUAL_ENV\Scripts\opentelemetry-instrument.exe"
    if (Test-Path $candidate) {
        $OtelInstrument = $candidate
        $Uvicorn        = "$env:VIRTUAL_ENV\Scripts\uvicorn.exe"
        $EnvLabel       = "venv (active): $env:VIRTUAL_ENV"
    }
}

if (-not $OtelInstrument -and (Test-Path "$ScriptDir\venv")) {
    # ── Project-local venv\ ───────────────────────────────────────────────────
    $candidate = "$ScriptDir\venv\Scripts\opentelemetry-instrument.exe"
    if (Test-Path $candidate) {
        $OtelInstrument = $candidate
        $Uvicorn        = "$ScriptDir\venv\Scripts\uvicorn.exe"
        $EnvLabel       = "venv: $ScriptDir\venv"
    }
}

if (-not $OtelInstrument -and (Test-Path "$ScriptDir\.venv")) {
    # ── Project-local .venv\ ──────────────────────────────────────────────────
    $candidate = "$ScriptDir\.venv\Scripts\opentelemetry-instrument.exe"
    if (Test-Path $candidate) {
        $OtelInstrument = $candidate
        $Uvicorn        = "$ScriptDir\.venv\Scripts\uvicorn.exe"
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
    Write-Host "    .\run.ps1"
    Write-Host ""
    Write-Host "  If you are using a standard venv:"
    Write-Host "    python -m venv venv"
    Write-Host "    .\venv\Scripts\Activate.ps1"
    Write-Host "    pip install -r requirements.txt"
    Write-Host "    opentelemetry-bootstrap -a install"
    Write-Host "    .\run.ps1"
    exit 1
}

# ── Step 2: load .env into the current PowerShell session ────────────────────
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
Write-Host "Starting FastAPI with OTel zero-code instrumentation..." -ForegroundColor Cyan
Write-Host "  Environment : $EnvLabel"
Write-Host "  Service     : $env:OTEL_SERVICE_NAME"
Write-Host "  Endpoint    : $env:OTEL_EXPORTER_OTLP_ENDPOINT"
Write-Host "  Protocol    : $env:OTEL_EXPORTER_OTLP_PROTOCOL"
Write-Host ""

# ── Step 4: start the app ─────────────────────────────────────────────────────
& $OtelInstrument $Uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
