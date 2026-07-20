$ErrorActionPreference = "Stop"

Set-Location -LiteralPath (Join-Path $PSScriptRoot "..\..\api")
bundle exec rails server -p 3000
