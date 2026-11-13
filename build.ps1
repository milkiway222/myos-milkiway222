[CmdletBinding()]
param(
    [string]$Image = 'archlinux:latest',
    [string]$OutDir = '',
    [int]$MinFreeGB = 12,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

if (-not $OutDir) { $OutDir = Join-Path $root 'out' }
$OutDir = [IO.Path]::GetFullPath($OutDir)

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    @'
Docker не найден.

Вариант 1 (проще): установи Docker Desktop и повтори:
    .\build.ps1

Вариант 2: собери на настоящем Arch Linux:
    sudo pacman -S --needed archiso
    sudo ./build.sh

Учти: сборке нужно ~12 ГБ свободного места (готовый ISO — около 3 ГБ).
Если места мало, укажи внешний диск в build.sh через WORK_DIR и OUT_DIR.
'@
    exit 1
}

# Проверка свободного места на диске результата.
$driveLetter = (Split-Path -Qualifier $OutDir).TrimEnd(':')
$freeGb = [math]::Round((Get-PSDrive $driveLetter).Free / 1GB, 1)
Write-Host ("Свободно на {0}: {1} ГБ" -f $driveLetter, $freeGb)

if ($freeGb -lt $MinFreeGB -and -not $Force) {
    Write-Warning ("Для сборки нужно ~{0} ГБ, а свободно {1} ГБ. ISO ~3 ГБ, но промежуточные файлы больше." -f $MinFreeGB, $freeGb)
    Write-Warning "Освободи место, укажи другой диск через -OutDir или запусти с -Force (на свой риск)."
    exit 1
}

docker --version
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$name = "myos-build-" + (Get-Random -Maximum 999999)
Write-Host "Контейнер: $name"

try {
    # Проект копируется внутрь контейнера: сборка идёт на настоящей Linux-ФС,
    # без проблем с правами и симлинками на Windows-разделе.
    docker create --name $name --privileged $Image `
        bash -lc "mkdir -p /build && pacman -Sy --noconfirm archiso >/dev/null && cd /build && bash ./build.sh" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Не удалось создать контейнер." }

    foreach ($item in @('iso', 'packages', 'build.sh')) {
        $src = Join-Path $root $item
        if (-not (Test-Path -LiteralPath $src)) { throw "Не найден $src" }
        docker cp $src "${name}:/build/$item"
        if ($LASTEXITCODE -ne 0) { throw "docker cp $item завершился с ошибкой." }
    }

    docker start -a $name
    $code = docker inspect -f '{{.State.ExitCode}}' $name
    if ($code -ne '0') { throw "Сборка завершилась с кодом $code." }

    docker cp "${name}:/build/out/." $OutDir
    if ($LASTEXITCODE -ne 0) { throw "Не удалось скопировать ISO из контейнера." }
}
finally {
    docker rm -f $name 2>$null | Out-Null
}

$iso = Get-ChildItem -Path $OutDir -Filter '*.iso' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if ($iso) {
    Write-Host ""
    Write-Host ("Готово: {0} ({1} МБ)" -f $iso.FullName, [math]::Round($iso.Length / 1MB))
} else {
    Write-Warning "ISO не найден в $OutDir"
}
