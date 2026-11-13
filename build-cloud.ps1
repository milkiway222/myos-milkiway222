# =============================================================================
#  build-cloud.ps1 — собирает ISO MyOS в GitHub Actions и скачивает его.
#
#  Запуск (из PowerShell):
#      powershell -ExecutionPolicy Bypass -File .\build-cloud.ps1
#  или двойным щелчком по build-cloud.cmd.
#
#  Что нужно:
#    - аккаунт GitHub (бесплатный), интернет;
#    - ~4 ГБ свободного места на диске для готового ISO.
#
#  Скрипт сам скачает портативные git и gh в D:\myos-tools (или в
#  %LOCALAPPDATA%\myos-tools), создаст публичный репозиторий, запустит
#  сборку и положит ISO в D:\myos-out.
# =============================================================================
[CmdletBinding()]
param(
    [string]$OutDir = ''
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

if (-not $OutDir) {
    if (Test-Path 'D:\') { $OutDir = 'D:\myos-out' }
    else { $OutDir = Join-Path $env:USERPROFILE 'myos-out' }
}
$OutDir = [IO.Path]::GetFullPath($OutDir)

function Write-Step([string]$Text) {
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Write-Ok([string]$Text) {
    Write-Host "    $Text" -ForegroundColor Green
}

function Get-ToolFile([string]$Url, [string]$Dest) {
    if (Test-Path -LiteralPath $Dest) { return }
    Write-Host "    скачиваю $(Split-Path -Leaf $Dest) ..."
    & curl.exe -L --retry 3 --silent --show-error -o $Dest $Url
    if ($LASTEXITCODE -ne 0) { throw "не удалось скачать $Url" }
}

try {
    Write-Host "MyOS: сборка ISO в GitHub Actions"
    Write-Host "Проект: $root"

    # ------------------------------------------------------------ инструменты
    $tools = if (Test-Path 'D:\') { 'D:\myos-tools' } else { Join-Path $env:LOCALAPPDATA 'myos-tools' }
    New-Item -ItemType Directory -Path $tools -Force | Out-Null

    $ghZip = Join-Path $tools 'gh.zip'
    $gitSetup = Join-Path $tools 'PortableGit.exe'
    Get-ToolFile 'https://github.com/cli/cli/releases/download/v2.104.0/gh_2.104.0_windows_amd64.zip' $ghZip
    Get-ToolFile 'https://github.com/git-for-windows/git/releases/download/v2.56.1.windows.1/PortableGit-2.56.1-64-bit.7z.exe' $gitSetup

    $ghDir = Join-Path $tools 'gh'
    $ghExe = Get-ChildItem -LiteralPath $ghDir -Recurse -Filter 'gh.exe' -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $ghExe) {
        Expand-Archive -Path $ghZip -DestinationPath $ghDir -Force
        $ghExe = Get-ChildItem -LiteralPath $ghDir -Recurse -Filter 'gh.exe' |
            Select-Object -First 1
    }
    if (-not $ghExe) { throw 'gh.exe не найден после распаковки.' }
    $Gh = $ghExe.FullName

    $gitDir = Join-Path $tools 'PortableGit'
    $Git = Join-Path $gitDir 'cmd\git.exe'
    if (-not (Test-Path -LiteralPath $Git)) {
        & $gitSetup -o"$gitDir" -y | Out-Null
    }
    if (-not (Test-Path -LiteralPath $Git)) { throw 'git.exe не найден после распаковки.' }

    $env:PATH = "$gitDir\cmd;$ghDir;$env:PATH"
    Write-Ok (& $Git --version)
    Write-Ok ((& $Gh --version | Select-Object -First 1))

    # ------------------------------------------------------------ авторизация
    function Test-GhAuth {
        & $Gh auth status *> $null
        return ($LASTEXITCODE -eq 0)
    }

    if (-not (Test-GhAuth)) {
        Write-Step 'Авторизация в GitHub'
        Write-Host '    Откроется отдельное окно. Выбери:'
        Write-Host '      GitHub.com  ->  HTTPS  ->  Login with a web browser'
        Write-Host ''
        Write-Host '    Нет аккаунта? Создай бесплатно: https://github.com/signup'
        Write-Host '    (это займёт пару минут, карта не нужна)'
        Write-Host ''
        Write-Host '    Жду завершения авторизации (до 8 минут)...'
        $cmd = "& '$($Gh.Replace("'", "''"))' auth login --hostname github.com --git-protocol https --web"
        Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoExit', '-Command', $cmd | Out-Null
        $deadline = (Get-Date).AddMinutes(8)
        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Seconds 3
            if (Test-GhAuth) { break }
        }
        if (-not (Test-GhAuth)) {
            throw 'авторизация не завершена. Запусти скрипт ещё раз, когда войдёшь в GitHub.'
        }
    }

    $Login = (& $Gh api user --jq .login).Trim()
    if (-not $Login) { throw 'не удалось получить имя пользователя GitHub.' }
    $RepoName = "myos-$($Login.ToLower())"
    $Repo = "$Login/$RepoName"
    Write-Ok "аккаунт: $Login"
    Write-Ok "репозиторий: $Repo"

    # ------------------------------------------------------------ репозиторий
    Write-Step "Репозиторий $Repo"
    & $Gh repo view $Repo *> $null
    if ($LASTEXITCODE -ne 0) {
        & $Gh repo create $RepoName --public --add-readme `
            --description 'MyOS - Arch Linux + KDE Plasma' | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "не удалось создать репозиторий $Repo." }
        Write-Ok 'создан публичный репозиторий'
    } else {
        Write-Ok 'уже существует, обновляю'
    }

    # ------------------------------------------------------------ загрузка
    Write-Step 'Загружаю проект на GitHub'
    Push-Location $root
    try {
        if (-not (Test-Path -LiteralPath (Join-Path $root '.git'))) {
            & $Git init -b main | Out-Host
        }
        & $Git config user.name $Login
        & $Git config user.email "$Login@users.noreply.github.com"
        & $Git config core.autocrlf false
        & $Git add -A
        & $Git commit -m "MyOS build $(Get-Date -Format 'yyyy-MM-dd HH:mm')" 2>&1 | Out-Host
        & $Git branch -M main
        & $Gh auth setup-git | Out-Host
        & $Git remote remove origin 2>$null | Out-Null
        & $Git remote add origin "https://github.com/$Repo.git"
        & $Git push -u origin main --force 2>&1 | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'git push завершился с ошибкой.' }
    }
    finally {
        Pop-Location
    }
    & $Gh repo edit $Repo --default-branch main *> $null
    Write-Ok 'проект загружен'

    # ------------------------------------------------------------ сборка
    Write-Step 'Запускаю сборку в GitHub Actions'
    $start = (Get-Date).ToUniversalTime()
    $triggered = $false
    for ($i = 0; $i -lt 20; $i++) {
        & $Gh workflow run build-iso.yml --repo $Repo --ref main 2>&1 | Out-Host
        if ($LASTEXITCODE -eq 0) { $triggered = $true; break }
        Start-Sleep -Seconds 3
    }
    if (-not $triggered) {
        throw 'не удалось запустить workflow. Проверь, что .github/workflows/build-iso.yml загружен.'
    }

    $run = $null
    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep -Seconds 3
        $json = & $Gh run list --repo $Repo --workflow build-iso.yml --limit 1 `
            --json databaseId,status,conclusion,url,createdAt 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $json) { continue }
        $candidate = $json | ConvertFrom-Json
        if (-not $candidate) { continue }
        $created = [datetime]::Parse($candidate.createdAt).ToUniversalTime()
        if ($created -ge $start.AddMinutes(-2)) {
            $run = $candidate
            break
        }
    }
    if (-not $run) { throw 'не удалось найти запуск workflow в списке.' }
    Write-Ok "запуск: $($run.url)"
    Write-Host ''
    Write-Host '    Сборка занимает 20-60 минут. Не закрывай это окно.' -ForegroundColor Yellow

    & $Gh run watch $run.databaseId --repo $Repo --exit-status
    if ($LASTEXITCODE -ne 0) {
        Write-Host ''
        Write-Host 'Сборка не удалась. Последние строки лога:' -ForegroundColor Red
        & $Gh run view $run.databaseId --repo $Repo --log-failed 2>&1 |
            Select-Object -Last 200 | Out-Host
        throw 'сборка завершилась с ошибкой.'
    }

    # ------------------------------------------------------------ скачивание
    Write-Step 'Скачиваю готовый ISO (это может занять несколько минут)'
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    & $Gh run download $run.databaseId --repo $Repo --name myos-iso --dir $OutDir
    if ($LASTEXITCODE -ne 0) { throw 'не удалось скачать артефакт myos-iso.' }

    $iso = Get-ChildItem -LiteralPath $OutDir -Recurse -Filter '*.iso' |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $iso) { throw "ISO не найден в $OutDir." }

    $sizeGb = [math]::Round($iso.Length / 1GB, 2)
    Write-Host ''
    Write-Host "ГОТОВО: $($iso.FullName) ($sizeGb ГБ)" -ForegroundColor Green
    Write-Host ''
    Write-Host 'Записать на флешку:'
    Write-Host '  1. Rufus: https://rufus.ie'
    Write-Host '  2. Устройство: твоя флешка (все данные на ней сотрутся)'
    Write-Host "  3. Выбрать ISO: $($iso.FullName)"
    Write-Host '  4. Схема раздела: GPT, целевая система: UEFI'
    Write-Host '  5. Secure Boot в BIOS выключить'
    Write-Host '  6. Начать и дождаться записи'
    Write-Host ''
    Write-Host 'Или Ventoy: поставь Ventoy на флешку и просто скопируй ISO в её корень.'
}
catch {
    Write-Host ''
    Write-Host "ОШИБКА: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ''
    Write-Host 'Если ошибка непонятная — скопируй весь текст из этого окна и пришли мне.'
    exit 1
}
