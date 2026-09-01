param(
  [string]$DevRoot,
  [string]$GitRoot = "C:\GIT\DAM"
)

$ErrorActionPreference = "Stop"

if (-not $DevRoot) {
  $DevRoot = Split-Path -Parent $PSScriptRoot
}

$DevRoot = (Resolve-Path $DevRoot).Path

if (-not (Test-Path $GitRoot)) {
  throw "Repositório GIT não encontrado: $GitRoot"
}
$GitRoot = (Resolve-Path $GitRoot).Path

$ApiRoot = Join-Path $DevRoot "dailytalk-api"
$MobileRoot = Join-Path $DevRoot "dailytalk_mobile"

$DevBaseline = Join-Path $ApiRoot "migrations\0001_baseline.sql"
$GitBaseline = Join-Path $GitRoot "dailytalk-api\migrations\0001_baseline.sql"

function Run-External {
  param(
    [Parameter(Mandatory = $true)][string]$Title,
    [Parameter(Mandatory = $true)][string]$Command,
    [string[]]$Arguments = @()
  )

  Write-Host ""
  Write-Host "=== $Title ===" -ForegroundColor Cyan
  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$Title falhou com exit code $LASTEXITCODE."
  }
}

if (-not (Test-Path $ApiRoot)) {
  throw "API DEV não encontrada: $ApiRoot"
}

if (-not (Test-Path $MobileRoot)) {
  throw "Flutter DEV não encontrado: $MobileRoot"
}

Write-Host "DailyTalk — Fase 0 — Quality Gate" -ForegroundColor Green
Write-Host "DEV : $DevRoot"
Write-Host "GIT : $GitRoot"

# Confirma que GitRoot é realmente um repositório.
Run-External "Git repository check" "git" @(
  "-C", $GitRoot,
  "rev-parse", "--is-inside-work-tree"
)

# Verificações Git são sempre feitas no repositório real.
Run-External "Git diff check" "git" @(
  "-C", $GitRoot,
  "diff", "--check"
)

Run-External "Git cached diff check" "git" @(
  "-C", $GitRoot,
  "diff", "--cached", "--check"
)

# 0001 publicada: DEV e GIT devem continuar byte-a-byte equivalentes.
if ((Test-Path $DevBaseline) -and (Test-Path $GitBaseline)) {
  $devHash = (Get-FileHash $DevBaseline -Algorithm SHA256).Hash
  $gitHash = (Get-FileHash $GitBaseline -Algorithm SHA256).Hash

  if ($devHash -ne $gitHash) {
    throw "BLOQUEADO: 0001_baseline.sql difere entre DEV e GIT. Migration publicada é imutável."
  }

  Write-Host ""
  Write-Host "0001_baseline.sql: DEV = GIT, imutável." -ForegroundColor Green
}

# Também bloqueia alteração da 0001 dentro do working tree GIT.
& git -C $GitRoot diff --quiet HEAD -- "dailytalk-api/migrations/0001_baseline.sql"
$baselineExit = $LASTEXITCODE
if ($baselineExit -eq 1) {
  throw "BLOQUEADO: 0001_baseline.sql foi modificada no GIT."
}
if ($baselineExit -gt 1) {
  throw "Não foi possível verificar a imutabilidade da 0001_baseline.sql no GIT."
}

Write-Host ""
Write-Host "=== Git status ===" -ForegroundColor Cyan
& git -C $GitRoot status --short
if ($LASTEXITCODE -ne 0) {
  throw "git status falhou com exit code $LASTEXITCODE."
}

Push-Location $ApiRoot
try {
  Run-External "npm audit" "npm" @("audit")
  Run-External "API Phase 0" "npm" @("run", "test:phase0")
}
finally {
  Pop-Location
}

Push-Location $MobileRoot
try {
  Run-External "Flutter analyze" "flutter" @("analyze")
  Run-External "Flutter tests" "flutter" @(
    "test",
    "-r", "expanded",
    "--concurrency=1"
  )
}
finally {
  Pop-Location
}

Write-Host ""
Write-Host "QUALITY GATE APROVADO." -ForegroundColor Green
Write-Host "Nenhum deploy, migration remota ou rollback foi executado."
