<#
    Stray - FSR 4.1 Lite upscaling installer
    OptiScaler (dxgi.dll) + ReShade 6.8 + StrayDLSS add-on

    Downloads every component from its official source and lays out the
    tuned configuration. No proprietary binaries are bundled with this repo.

    Run in PowerShell as Administrator from the folder containing this script:
        Set-ExecutionPolicy -Scope Process Bypass -Force
        .\install.ps1
#>

[CmdletBinding()]
param(
    [string]$GameDir = "C:\Program Files (x86)\Stray\Hk_project\Binaries\Win64",
    [switch]$NoConfig,
    [switch]$SkipDownload
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# ---------------------------------------------------------------- sources
$OptiNightlyApi = 'https://api.github.com/repos/optiscaler/OptiScaler-nightly/releases?per_page=1'
$StrayDlssApi   = 'https://api.github.com/repos/GreatDanish1026/StrayDLSS/releases/latest'
$ReShadeSetup   = 'https://reshade.me/downloads/ReShade_Setup_6.8.0_Addon.exe'

$Root       = Split-Path -Parent $MyInvocation.MyCommand.Path
$Downloads  = Join-Path $Root 'downloads'
$ConfigsSrc = Join-Path $Root 'configs'
$UeConfig   = Join-Path $env:LOCALAPPDATA 'Hk_project\Saved\Config\WindowsNoEditor'

# 7-Zip: needed for the .7z archive and to pull a file out of the ReShade setup.
$SevenZip = @(
    'C:\Program Files\7-Zip\7z.exe',
    'C:\Program Files (x86)\7-Zip\7z.exe'
) | Where-Object { Test-Path $_ } | Select-Object -First 1

function Say  ($m) { Write-Host "  $m" }
function Head ($m) { Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function Die  ($m) { Write-Host "`n[ERROR] $m" -ForegroundColor Red; exit 1 }

function Get-Url ($url, $out) {
    if (Test-Path $out) { Say "уже скачано: $(Split-Path $out -Leaf)"; return }
    Say "качаю $(Split-Path $out -Leaf) ..."
    Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -Headers @{ 'User-Agent' = 'stray-fsr4-installer' }
}

# ---------------------------------------------------------------- checks
Head 'Проверка окружения'

if (-not (Test-Path $GameDir)) {
    Die "Папка игры не найдена: $GameDir`nУкажите её через -GameDir `<путь`>."
}
if (-not (Test-Path (Join-Path $GameDir 'Stray-Win64-Shipping.exe'))) {
    Say "  (предупреждение) Stray-Win64-Shipping.exe не найден в $GameDir — ставлю всё равно."
}
if (-not $SevenZip) {
    Die "Не найден 7-Zip (7z.exe). Установите его с https://www.7-zip.org/ и запустите снова."
}
if (-not (Get-Command tar.exe -ErrorAction SilentlyContinue)) {
    Die "Не найден tar.exe (входит в Windows 10 1803+). Обновите систему."
}
Say "7-Zip : $SevenZip"
Say "Игра  : $GameDir"

# Проверка прав на запись (Program Files требует админа).
try {
    $probe = Join-Path $GameDir '.write-test'
    Set-Content -Path $probe -Value 'x' -ErrorAction Stop
    Remove-Item $probe -Force
} catch {
    Die "Нет прав на запись в папку игры. Запустите PowerShell от имени администратора."
}
Say 'права на запись: ок'

New-Item -ItemType Directory -Force -Path $Downloads | Out-Null

# ---------------------------------------------------------------- download
Head 'Скачивание компонентов'

$optiUrl = $null
$dlssUrl = $null

if (-not $SkipDownload) {
    try {
        $r = Invoke-RestMethod -Uri $OptiNightlyApi -Headers @{ 'User-Agent' = 'stray-fsr4-installer' } -TimeoutSec 60
        $asset = $r[0].assets | Where-Object { $_.name -like '*.7z' } | Select-Object -First 1
        if ($asset) { $optiUrl = $asset.browser_download_url }
    } catch { Say "GitHub API (OptiScaler): $($_.Exception.Message)" }

    try {
        $r = Invoke-RestMethod -Uri $StrayDlssApi -Headers @{ 'User-Agent' = 'stray-fsr4-installer' } -TimeoutSec 60
        $asset = $r.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1
        if ($asset) { $dlssUrl = $asset.browser_download_url }
    } catch { Say "GitHub API (StrayDLSS): $($_.Exception.Message)" }
}

# Fallback: pinned, known-good versions if the API is unavailable.
if (-not $optiUrl) {
    $optiUrl = 'https://github.com/optiscaler/OptiScaler-nightly/releases/download/nightly-20261113/OptiScaler_v10.0.0-pre1_20261113.7z'
    Say 'API недоступен — беру закреплённый nightly OptiScaler.'
}
if (-not $dlssUrl) {
    $dlssUrl = 'https://github.com/GreatDanish1026/StrayDLSS/releases/download/v1.1.0/StrayDLSS-1.1.0.zip'
    Say 'API недоступен — беру закреплённый StrayDLSS v1.1.0.'
}

$optiFile = Join-Path $Downloads (Split-Path $optiUrl -Leaf)
$dlssFile = Join-Path $Downloads (Split-Path $dlssUrl -Leaf)
$rsFile   = Join-Path $Downloads 'ReShade_Setup_6.8.0_Addon.exe'

Get-Url $optiUrl $optiFile
Get-Url $dlssUrl $dlssFile
Get-Url $ReShadeSetup $rsFile

# ---------------------------------------------------------------- extract
Head 'Распаковка'

$tmp = Join-Path $Downloads '_extract'
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path "$tmp\opti", "$tmp\dlss", "$tmp\rs" | Out-Null

# OptiScaler (.7z) — tar.exe умеет 7z начиная с Windows 10 1803,
# но для надёжности используем 7z.exe.
& $SevenZip x $optiFile "-o$tmp\opti" -y | Out-Null
if (-not (Test-Path "$tmp\opti\OptiScaler.dll")) { Die 'Не удалось распаковать OptiScaler (нет OptiScaler.dll).' }
Say 'OptiScaler: ок'

# StrayDLSS (.zip)
& tar.exe -xf $dlssFile -C "$tmp\dlss"
if (-not (Test-Path "$tmp\dlss\StrayDLSS.addon64")) { Die 'Не удалось распаковать StrayDLSS (нет StrayDLSS.addon64).' }
Say 'StrayDLSS: ок'

# ReShade64.dll из официального установщика (это PE с приклеенным zip).
& $SevenZip e $rsFile 'ReShade64.dll' "-o$tmp\rs" -y | Out-Null
if (-not (Test-Path "$tmp\rs\ReShade64.dll")) { Die 'Не удалось извлечь ReShade64.dll из установщика ReShade.' }
Say 'ReShade64.dll: ок'

# ---------------------------------------------------------------- install
Head 'Установка в папку игры'

# OptiScaler: OptiScaler.dll -> dxgi.dll
Copy-Item "$tmp\opti\OptiScaler.dll" (Join-Path $GameDir 'dxgi.dll') -Force
Say 'dxgi.dll (OptiScaler)'

# Папка OptiScaler\ (FSR/XeSS/XeLL рантаймы, лицензии)
Copy-Item "$tmp\opti\OptiScaler" $GameDir -Recurse -Force
Say 'OptiScaler\'

if (Test-Path "$tmp\opti\Licenses") {
    Copy-Item "$tmp\opti\Licenses" $GameDir -Recurse -Force
    Say 'Licenses\'
}

# ReShade
Copy-Item "$tmp\rs\ReShade64.dll" $GameDir -Force
Say 'ReShade64.dll'

# StrayDLSS + его рантаймы (всё в корень Win64)
Get-ChildItem "$tmp\dlss" -Force | Where-Object { $_.Name -ne 'README.md' } | ForEach-Object {
    Copy-Item $_.FullName $GameDir -Recurse -Force
}
Say 'StrayDLSS.addon64, nvngx_dlss*.dll, amd_fidelityfx_*_dx12.dll, streamline\'

# amdxcffx64.dll — рантайм FSR из ДРАЙВЕРА AMD. Не распространяется вместе с
# модом, поэтому копируем из DriverStore этой машины (как делает виджет FSR4Lite).
$dstAmd = Join-Path $GameDir 'OptiScaler\amdxcffx64.dll'
if (-not (Test-Path $dstAmd)) {
    $ds = Get-ChildItem 'C:\Windows\System32\DriverStore\FileRepository' -Recurse -Filter 'amdxcffx64.dll' -ErrorAction SilentlyContinue |
          Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($ds) {
        Copy-Item $ds.FullName $dstAmd -Force
        Say "amdxcffx64.dll (из драйвера AMD: $($ds.VersionInfo.FileVersion))"
    } else {
        Say 'amdxcffx64.dll в драйвере не найден — FSR 4 возьмёт системную копию, если она есть.'
    }
} else {
    Say 'amdxcffx64.dll уже на месте'
}

# ---------------------------------------------------------------- configs
if (-not $NoConfig) {
    Head 'Конфигурация'

    if (Test-Path $ConfigsSrc) {
        Copy-Item "$ConfigsSrc\OptiScaler.ini" $GameDir -Force
        Say 'OptiScaler.ini'
        Copy-Item "$ConfigsSrc\ReShade.ini" $GameDir -Force
        Say 'ReShade.ini'

        New-Item -ItemType Directory -Force -Path $UeConfig | Out-Null
        foreach ($f in 'Engine.ini', 'GameUserSettings.ini') {
            $target = Join-Path $UeConfig $f
            if ((Test-Path $target) -and -not (Test-Path "$target.strayfsr4.bak")) {
                Copy-Item $target "$target.strayfsr4.bak" -Force
            }
            Copy-Item "$ConfigsSrc\$f" $target -Force
            Say "$f -> $UeConfig"
        }
    } else {
        Say "папка configs\ не найдена — пропускаю (конфиги останутся по умолчанию)."
    }
}

# ---------------------------------------------------------------- done
Head 'Готово'
Write-Host @"
Установлено. Дальше:

  1. Steam -> Stray -> Свойства -> Параметры запуска:  добавьте  -dx12
  2. Запустите игру и ЗАГРУЗИТЕ ГЕЙМПЛЕЙ (апскейлер включается в игре, не в меню).
  3. Home — оверлей StrayDLSS (вкл/выкл апскейлер, FSR/DLSS, пресет).
     Insert — оверлей OptiScaler (лимит FPS, шарп, отладка).

Проверить, что FSR 4.1 Lite поднялся, можно по логу:
  $GameDir\OptiScaler.log   ->  "upscaler FSR 4.1.2" и "int8 lite"

Если картинка пересвечена шарпом — в OptiScaler.ini поставьте
  [Sharpness] OverrideSharpness = false

Откат: удалить из папки игры dxgi.dll, ReShade64.dll, ReShade.ini, OptiScaler.ini,
OptiScaler\ , StrayDLSS.addon64, nvngx_dlss*.dll, amd_fidelityfx_*_dx12.dll, streamline\ .
Резервные копии Engine.ini / GameUserSettings.ini лежат рядом как *.strayfsr4.bak
"@ -ForegroundColor Green
