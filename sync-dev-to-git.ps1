param(
    [ValidateSet("all", "mobile", "api")]
    [string]$Project = "all",

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Evita caracteres corrompidos no PowerShell/Robocopy.
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[Console]::InputEncoding = $Utf8NoBom
[Console]::OutputEncoding = $Utf8NoBom
$OutputEncoding = $Utf8NoBom

$DevRoot = "C:\DEV\Flutter"
$GitRoot = "C:\GIT\DAM"

# Pastas locais, geradas ou temporarias que nunca devem ser copiadas.
$ExcludeDirs = @(
    ".git",
    ".dart_tool",
    "build",
    "node_modules",
    ".wrangler",
    "coverage",
    ".gradle",
    ".kotlin",
    "cloudflare_dist",
    "dist",
    "ephemeral",
    ".idea",
    ".vscode"
)

# Ficheiros locais, gerados, temporarios ou potencialmente sensiveis.
$ExcludeFiles = @(
    ".dev.vars",
    ".env",
    ".env.*",

    ".flutter-plugins",
    ".flutter-plugins-dependencies",

    "gradlew",
    "gradlew.bat",
    "gradle-wrapper.jar",
    "*.log",
    "*.tmp",
    "*.bak",
    "*.orig",
    "*.rej",
    "*.swp",
    "*.swo",

    "*.zip",
    "*.7z",
    "*.rar",

    "*.db",
    "*.sqlite",
    "*.sqlite3",

    "*.pem",
    "*.key",
    "*.p12",
    "*.pfx",
    "*.jks",
    "*.keystore",
    "key.properties",

    "local.properties",
    "Generated.xcconfig",
    "flutter_export_environment.sh",

    "Thumbs.db",
    ".DS_Store"
)

function Test-ExcludedRelativePath {
    param(
        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    $Normalized = $RelativePath.Replace("/", "\")
    $Parts = $Normalized.Split("\")

    foreach ($Part in $Parts) {
        if ($ExcludeDirs -contains $Part) {
            return $true
        }
    }

    $FileName = [System.IO.Path]::GetFileName($Normalized)

    foreach ($Pattern in $ExcludeFiles) {
        if ($FileName -like $Pattern) {
            return $true
        }
    }

    return $false
}

function Sync-DailyTalkProject {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $Source = Join-Path $DevRoot $Name
    $Destination = Join-Path $GitRoot $Name

    if (-not (Test-Path $Source)) {
        throw "Origem nao encontrada: $Source"
    }

    if (-not (Test-Path $Destination)) {
        throw "Destino nao encontrado: $Destination"
    }

    Write-Host ""
    Write-Host "=================================================="
    Write-Host "Sincronizar: $Name"
    Write-Host "DEV : $Source"
    Write-Host "GIT : $Destination"
    Write-Host "=================================================="

    $Arguments = @(
        $Source,
        $Destination,
        "*.*",
        "/E",
        "/COPY:DAT",
        "/DCOPY:DAT",
        "/R:2",
        "/W:1",
        "/XJ",
        "/NP"
    )

    if ($DryRun) {
        $Arguments += "/L"
        Write-Host "MODO DRY-RUN: nenhum ficheiro sera alterado."
    }

    $Arguments += "/XD"
    $Arguments += $ExcludeDirs

    $Arguments += "/XF"
    $Arguments += $ExcludeFiles

    & robocopy @Arguments

    $RoboCopyExitCode = $LASTEXITCODE

    # Robocopy: 0-7 = resultado normal; 8 ou superior = erro.
    if ($RoboCopyExitCode -ge 8) {
        throw "Robocopy falhou para $Name. Exit code: $RoboCopyExitCode"
    }

    Write-Host ""
    Write-Host "$Name sincronizado com sucesso."
}

function Show-TrackedFilesMissingFromDev {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    Write-Host ""
    Write-Host "Verificar ficheiros rastreados no GIT que ja nao existem no DEV ($Name)..."

    $Tracked = git -C $GitRoot ls-files -- $Name

    $Missing = @()

    foreach ($GitPath in $Tracked) {
        if ([string]::IsNullOrWhiteSpace($GitPath)) {
            continue
        }

        $Prefix = "$Name/"
        if (-not $GitPath.StartsWith($Prefix)) {
            continue
        }

        $Relative = $GitPath.Substring($Prefix.Length)

        # Nao alertar para elementos que sao deliberadamente locais/gerados.
        if (Test-ExcludedRelativePath $Relative) {
            continue
        }

        $DevPath = Join-Path (Join-Path $DevRoot $Name) $Relative.Replace("/", "\")

        if (-not (Test-Path $DevPath)) {
            $Missing += $GitPath
        }
    }

    if ($Missing.Count -eq 0) {
        Write-Host "OK: nenhum ficheiro rastreado ficou apenas no GIT."
        return
    }

    Write-Warning "Existem ficheiros rastreados no GIT que nao existem mais no DEV."
    Write-Warning "O script NAO os apaga automaticamente por seguranca."
    Write-Host ""
    foreach ($Item in $Missing) {
        Write-Host "  $Item"
    }
    Write-Host ""
    Write-Host "Se a remocao foi intencional, use:"
    Write-Host "  git rm <ficheiro>"
}

function Show-ExcludedUntrackedFiles {
    Write-Host ""
    Write-Host "Verificar ficheiros locais/temporarios presentes no workspace do GIT..."

    $StatusLines = git -C $GitRoot status --porcelain

    $Warnings = @()

    foreach ($Line in $StatusLines) {
        if ($Line.Length -lt 4) {
            continue
        }

        if (-not $Line.StartsWith("??")) {
            continue
        }

        $Path = $Line.Substring(3).Trim('"')

        if (
            $Path -like "*.zip" -or
            $Path -like "*.7z" -or
            $Path -like "*.rar" -or
            $Path -like "*.db" -or
            $Path -like "*.sqlite" -or
            $Path -like "*.sqlite3" -or
            $Path -like "*/local.properties" -or
            $Path -like "*/.dev.vars" -or
            $Path -like "*/.env" -or
            $Path -like "*/.env.*"
        ) {
            $Warnings += $Path
        }
    }

    if ($Warnings.Count -eq 0) {
        Write-Host "OK: nenhum artefacto local conhecido aparece como untracked."
        return
    }

    Write-Warning "Foram encontrados artefactos que nao devem entrar no commit:"
    foreach ($Item in $Warnings) {
        Write-Host "  $Item"
    }
}

# Confirmar que o destino e um repositorio Git valido.
$RepoRoot = git -C $GitRoot rev-parse --show-toplevel 2>$null
if (-not $RepoRoot) {
    throw "Caminho GIT nao e um repositorio valido: $GitRoot"
}

Set-Location $GitRoot

switch ($Project) {
    "mobile" {
        Sync-DailyTalkProject "dailytalk_mobile"
        Show-TrackedFilesMissingFromDev "dailytalk_mobile"
    }

    "api" {
        Sync-DailyTalkProject "dailytalk-api"
        Show-TrackedFilesMissingFromDev "dailytalk-api"
    }

    "all" {
        Sync-DailyTalkProject "dailytalk_mobile"
        Sync-DailyTalkProject "dailytalk-api"

        Show-TrackedFilesMissingFromDev "dailytalk_mobile"
        Show-TrackedFilesMissingFromDev "dailytalk-api"
    }
}

Write-Host ""
Write-Host "=================================================="
Write-Host "VERIFICACAO DO GIT"
Write-Host "=================================================="

git status --short

Show-ExcludedUntrackedFiles

Write-Host ""
Write-Host "Verificar ficheiros sensiveis ja rastreados pelo Git..."

$SensitiveTracked = git -C $GitRoot ls-files |
    Select-String -Pattern `
    '(^|/)(\.dev\.vars|\.env($|\.)|key\.properties$)|\.(p12|pfx|jks|keystore|key)$'

if ($SensitiveTracked) {
    Write-Warning "ATENCAO: existem ficheiros potencialmente sensiveis rastreados pelo Git:"
    $SensitiveTracked
}
else {
    Write-Host "OK: nenhum ficheiro sensivel conhecido esta rastreado."
}

Write-Host ""
if ($DryRun) {
    Write-Host "Dry-run concluido. Nenhum ficheiro foi copiado."
}
else {
    Write-Host "Sincronizacao concluida."
}
