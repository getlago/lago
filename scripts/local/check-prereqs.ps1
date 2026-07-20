$ErrorActionPreference = "Continue"

function Test-Command {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [string]$Expected
  )

  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $cmd) {
    Write-Host "[missing] $Name"
    return
  }

  $version = ""
  try {
    if ($Name -eq "psql") {
      $version = (& $Name --version) -join " "
    } elseif ($Name -eq "ruby" -or $Name -eq "node" -or $Name -eq "pnpm" -or $Name -eq "redis-server") {
      $version = (& $Name -v) -join " "
    } elseif ($Name -eq "bundle") {
      $version = (& $Name -v) -join " "
    }
  } catch {
    $version = "found at $($cmd.Source), but version check failed"
  }

  if ($Expected) {
    Write-Host "[found]   $Name => $version (expected $Expected)"
  } else {
    Write-Host "[found]   $Name => $version"
  }
}

Write-Host "BFP Lago local prerequisites"
Write-Host ""

Test-Command ruby "4.0.2"
Test-Command bundle "4.0.4"
Test-Command node "24.18.0"
Test-Command pnpm "10.34.4"
Test-Command psql "PostgreSQL 16+"
Test-Command redis-server "Redis-compatible server"

Write-Host ""
if (Test-Path -LiteralPath "api/.env") {
  Write-Host "[found]   api/.env"
} else {
  Write-Host "[missing] api/.env"
}

if (Test-Path -LiteralPath "front/.env") {
  Write-Host "[found]   front/.env"
} else {
  Write-Host "[missing] front/.env"
}

if (Test-Path -LiteralPath "api/config/keys/private.pem") {
  Write-Host "[found]   api/config/keys/private.pem"
} else {
  Write-Host "[missing] api/config/keys/private.pem"
}

Write-Host ""
pg_isready -h localhost -p 55432 -U lago 2>$null
if ($LASTEXITCODE -eq 0) {
  Write-Host "[found]   local project Postgres on localhost:55432"
} else {
  Write-Host "[missing] local project Postgres on localhost:55432"
}
