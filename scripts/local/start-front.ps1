$ErrorActionPreference = "Stop"

$root = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")
$portableNode = Join-Path $root ".local\node-v24.18.0-win-x64"

if (Test-Path -LiteralPath $portableNode) {
  $env:Path = "$portableNode;$env:Path"
}

Set-Location -LiteralPath (Join-Path $root "front")
pnpm dev --host 127.0.0.1 --port 5173
