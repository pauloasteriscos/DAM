$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$apiDir = Join-Path $repoRoot "dailytalk-api"
$mobileDir = Join-Path $repoRoot "dailytalk_mobile"
$logDir = Join-Path $env:TEMP "dailytalk-phase2-reference-journey-gate"
$stdout = Join-Path $logDir "wrangler.out.log"
$stderr = Join-Path $logDir "wrangler.err.log"

New-Item $logDir -ItemType Directory -Force | Out-Null
Remove-Item $stdout, $stderr -Force -ErrorAction SilentlyContinue

Write-Host "[1/6] A iniciar Worker DEV em 127.0.0.1:8787..."
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
    throw "Falha ao iniciar o Worker DEV para o gate da Fase 2.4."
  }

  Write-Host "[2/6] A validar catálogo oficial v3..."
  $catalog = Invoke-RestMethod `
    -Uri "http://127.0.0.1:8787/api/content/catalog" `
    -Headers @{ "X-DailyTalk-Environment" = "DEV" }

  $metadata = $catalog.packages |
    Where-Object { $_.pathId -eq "student.fr-fr.phase1" } |
    Select-Object -First 1

  if (-not $metadata -or $metadata.packageVersion -ne 3) {
    throw "A API não publicou student.fr-fr.phase1 packageVersion=3."
  }

  if ($metadata.sha256 -ne "9fc5142ad80c8e66979c8f3f5f547bb8071c4be09160b03a38cf2374eebb070b") {
    throw "SHA-256 do pacote v3 não corresponde ao artefacto aprovado."
  }

  Write-Host "[3/6] A validar percurso oficial de referência..."
  $path = Invoke-RestMethod `
    -Uri "http://127.0.0.1:8787$($metadata.downloadPath)" `
    -Headers @{ "X-DailyTalk-Environment" = "DEV" }

  if ($path.activities.Count -ne 16) {
    throw "O percurso v3 deveria conter exatamente 16 atividades."
  }
  if ($path.journeys.Count -ne 1 -or $path.journeys[0].stages.Count -ne 4) {
    throw "O percurso v3 deveria conter uma jornada com quatro etapas."
  }

  $types = @($path.activities | ForEach-Object { $_.type } | Sort-Object -Unique)
  $requiredTypes = @("vocabulary", "dialogue", "speech", "quiz", "review", "integratedChallenge")
  foreach ($type in $requiredTypes) {
    if ($types -notcontains $type) {
      throw "O percurso oficial não contém o tipo obrigatório '$type'."
    }
  }

  $vocabulary = $path.activities |
    Where-Object { $_.id -eq "arrival.vocabulary-01" } |
    Select-Object -First 1
  if (-not $vocabulary -or
      $vocabulary.currentRevisionId -ne "arrival.vocabulary-01.revision-03" -or
      $vocabulary.revisions.Count -ne 3) {
    throw "A evolução imutável de arrival.vocabulary-01 para revision-03 não foi publicada."
  }

  Write-Host "[4/6] A validar manifesto de assets v3..."
  $assetCatalog = Invoke-RestMethod `
    -Uri "http://127.0.0.1:8787/api/content/assets/catalog" `
    -Headers @{ "X-DailyTalk-Environment" = "DEV" }

  $assetMetadata = $assetCatalog.manifests |
    Where-Object {
      $_.pathId -eq "student.fr-fr.phase1" -and $_.packageVersion -eq 3
    } |
    Select-Object -First 1

  if (-not $assetMetadata -or
      $assetMetadata.packageVersion -ne 3 -or
      $assetMetadata.manifestVersion -ne 1 -or
      $assetMetadata.sha256 -ne "bccf2da598c07ec04ddebf66ea0dc665bc7237b5928cefa0082c888a231a7e80") {
    throw "O manifesto de assets v3 não corresponde ao esperado."
  }

  $manifest = Invoke-RestMethod `
    -Uri "http://127.0.0.1:8787$($assetMetadata.downloadPath)" `
    -Headers @{ "X-DailyTalk-Environment" = "DEV" }
  if ($manifest.assets.Count -ne 8) {
    throw "O manifesto v3 deveria publicar exatamente 8 referências de assets."
  }

  Write-Host "[5/6] A executar gate Flutter/API/SQLite/progressão..."
  Push-Location $mobileDir
  try {
    flutter test tool\phase2\learning_content_reference_journey_live_api_test.dart --concurrency=1
    if ($LASTEXITCODE -ne 0) {
      throw "Gate Flutter/API da Fase 2.4 falhou com exit code $LASTEXITCODE."
    }
  } finally {
    Pop-Location
  }

  Write-Host "[6/6] Gate Fase 2.4 aprovado: v2 -> v3 -> 16 atividades -> progressão -> assets incrementais -> offline."
} finally {
  if ($worker -and -not $worker.HasExited) {
    Stop-Process -Id $worker.Id -Force -ErrorAction SilentlyContinue
    Wait-Process -Id $worker.Id -ErrorAction SilentlyContinue
  }
}
