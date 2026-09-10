$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$apiDir = Join-Path $repoRoot "dailytalk-api"
$mobileDir = Join-Path $repoRoot "dailytalk_mobile"
$logDir = Join-Path $env:TEMP "dailytalk-phase2-assets-gate"
$stdout = Join-Path $logDir "wrangler.out.log"
$stderr = Join-Path $logDir "wrangler.err.log"

New-Item $logDir -ItemType Directory -Force | Out-Null
Remove-Item $stdout, $stderr -Force -ErrorAction SilentlyContinue

Write-Host "[1/5] A iniciar Worker DEV em 127.0.0.1:8787..."
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
    throw "Falha ao iniciar o Worker DEV para o gate da Fase 2.3."
  }

  Write-Host "[2/5] Catálogo de assets remoto disponível."
  $catalog = Invoke-RestMethod `
    -Uri "http://127.0.0.1:8787/api/content/assets/catalog" `
    -Headers @{ "X-DailyTalk-Environment" = "DEV" }

  $metadata = $catalog.manifests |
    Where-Object { $_.pathId -eq "student.fr-fr.phase1" } |
    Select-Object -First 1

  if (-not $metadata -or $metadata.packageVersion -ne 2 -or $metadata.manifestVersion -ne 1) {
    throw "A API não publicou o manifesto esperado para student.fr-fr.phase1 v2."
  }

  Write-Host "[3/5] Manifesto v$($metadata.manifestVersion), SHA-256=$($metadata.sha256)"

  $manifest = Invoke-RestMethod `
    -Uri "http://127.0.0.1:8787$($metadata.downloadPath)" `
    -Headers @{ "X-DailyTalk-Environment" = "DEV" }

  if ($manifest.assets.Count -lt 2) {
    throw "O manifesto deveria publicar pelo menos imagem e áudio de referência."
  }

  Write-Host "[4/5] A executar gate Flutter/API/SQLite..."
  Push-Location $mobileDir
  try {
    flutter test tool\phase2\learning_content_asset_live_api_test.dart --concurrency=1
    if ($LASTEXITCODE -ne 0) {
      throw "Gate Flutter/API de assets falhou com exit code $LASTEXITCODE."
    }
  } finally {
    Pop-Location
  }

  Write-Host "[5/5] Gate Fase 2.3 aprovado: manifest -> assets -> cache incremental -> leitura offline."
} finally {
  if ($worker -and -not $worker.HasExited) {
    Stop-Process -Id $worker.Id -Force -ErrorAction SilentlyContinue
    Wait-Process -Id $worker.Id -ErrorAction SilentlyContinue
  }
}
