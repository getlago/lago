$ErrorActionPreference = "Stop"

$root = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")
$dataDir = Join-Path $root ".local\postgres"

if (-not (Test-Path -LiteralPath $dataDir)) {
  Write-Host "Local Postgres cluster does not exist: $dataDir"
  exit 0
}

pg_ctl -D $dataDir stop
