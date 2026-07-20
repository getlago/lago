$ErrorActionPreference = "Stop"

$root = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")
$dataDir = Join-Path $root ".local\postgres"
$logFile = Join-Path $root ".local\postgres.log"
$port = "55432"

New-Item -ItemType Directory -Force -Path (Join-Path $root ".local") | Out-Null

if (-not (Test-Path -LiteralPath $dataDir)) {
  Write-Host "Initializing local Postgres cluster at $dataDir"
  initdb -D $dataDir -U lago --auth=trust --encoding=UTF8 --locale=C
}

Write-Host "Starting local Postgres on localhost:$port"
pg_ctl -D $dataDir -o "-p $port" -l $logFile start

Write-Host "Ensuring database 'lago' exists"
$dbExists = & psql -h localhost -p $port -U lago -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = 'lago';"
if ($dbExists.Trim() -ne "1") {
  createdb -h localhost -p $port -U lago lago
}

pg_isready -h localhost -p $port -U lago
