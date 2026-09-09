$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$apiDir = Join-Path $repoRoot "dailytalk-api"
$mobileDir = Join-Path $repoRoot "dailytalk_mobile"
$logDir = Join-Path $env:TEMP "dailytalk-phase2-gate"
$stdout = Join-Path $logDir "wrangler.out.log"
$stderr = Join-Path $logDir "wrangler.err.log"

New-Item $logDir -ItemType Directory -Force | Out-Null
Remove-Item $stdout, $stderr -Force -ErrorAction SilentlyContinue

Write-Host "[1/4] A iniciar Worker DEV em 127.0.0.1:8787..."
$worker = Start-Process -FilePath "npx.cmd" `
  -ArgumentList @("wrangler", "dev", "--config", "wrangler.test.jsonc", "--port", "8787") `
  -WorkingDirectory $apiDir `
  -PassThru `
  -RedirectStandardOutput $stdout `
  -RedirectStandardError $stderr

try {
  $ready = $false
  for ($attempt = 1; $attempt -le 30; $attempt++) {
    Start-Sleep -Seconds 1
    try {
      $health = Invoke-WebRequest `
        -Uri "http://127.0.0.1:8787/api/health" `
        -Headers @{ "X-DailyTalk-Environment" = "DEV" } `
        -UseBasicParsing `
        -TimeoutSec 2
      if ($health.StatusCode -eq 200) {
        $ready = $true
        break
      }
    } catch {
      if ($worker.HasExited) { break }
    }
  }

  if (-not $ready) {
    Write-Host "Worker não ficou pronto. STDOUT:"
    if (Test-Path $stdout) { Get-Content $stdout }
    Write-Host "STDERR:"
    if (Test-Path $stderr) { Get-Content $stderr }
    throw "Falha ao iniciar o Worker DEV para o gate da Fase 2.2."
  }

  Write-Host "[2/4] Catálogo remoto disponível."
  $catalog = Invoke-RestMethod `
    -Uri "http://127.0.0.1:8787/api/content/catalog" `
    -Headers @{ "X-DailyTalk-Environment" = "DEV" }
  $metadata = $catalog.packages | Where-Object { $_.pathId -eq "student.fr-fr.phase1" } | Select-Object -First 1
  if (-not $metadata -or $metadata.packageVersion -ne 2) {
    throw "O catálogo não publicou student.fr-fr.phase1 packageVersion=2."
  }
  Write-Host "[3/4] API anuncia packageVersion=$($metadata.packageVersion), SHA-256=$($metadata.sha256)"

  Push-Location $mobileDir
  try {
    flutter test tool\phase2\learning_content_live_api_test.dart --concurrency=1
    if ($LASTEXITCODE -ne 0) {
      throw "Gate Flutter/API falhou com exit code $LASTEXITCODE."
    }
  } finally {
    Pop-Location
  }

  Write-Host "[4/4] Gate Fase 2.2 aprovado: v1 -> API v2 -> SQLite -> leitura local."
} finally {
  if ($worker -and -not $worker.HasExited) {
    Stop-Process -Id $worker.Id -Force -ErrorAction SilentlyContinue
    Wait-Process -Id $worker.Id -ErrorAction SilentlyContinue
  }
}
