# Stray — FSR 4.1 Lite upscaling (OptiScaler + ReShade + StrayDLSS)

Upscaling and frame-generation setup for **Stray** (Unreal Engine 4.27, DirectX 12) using the
ReShade add-on **StrayDLSS** as the DLSS/FSR input provider and **OptiScaler** to force
**FSR 4.1 Lite** (INT8, the model aimed at APUs) in place of the game's TAA.

Tuned for the **ASUS ROG Ally Z1 Extreme** (Radeon 780M iGPU, RDNA3), 1920×1080.

> **This repository contains no binaries.** It ships an installer (`install.ps1`) that downloads
> every component from its official source and lays out the user configuration. See
> [Licensing](#licensing) for why.

---

## Result

| Before | After |
|---|---|
| 1600×900, TAA, ray tracing on by default in DX12, ~17–20 FPS | 1920×1080 output, **FSR 4.1 Lite**, RT off, **60 FPS locked** |

Verified in `OptiScaler.log` and `StrayDLSS.log`:

```
FSR runtime loaded, upscalers offered: 4.1.2, 3.1.6, 2.3.4
FSR context created: up to 1920x1080 -> 1920x1080, upscaler FSR 4.1.2
Upscaler support - fsr4: int8 lite (forced), driver model: INT8Lite
Framerate.FramerateLimit: 60.000000
```

---

## Requirements

- **Stray**, DirectX 12 mode (Steam launch option `-dx12`).
- Windows 10/11 x64 with **PowerShell 5.1+** and **`tar.exe`** (built into Windows 10 1803+).
- **7-Zip** installed (`C:\Program Files\7-Zip\7z.exe`) — used to unpack the OptiScaler `.7z`
  and to pull `ReShade64.dll` out of the ReShade setup executable.
- A GPU that supports FSR 4 (RDNA3/RDNA4 recommended for INT8 Lite). Tuned and tested on
  **Radeon 780M (RDNA3)**; other GPUs need `Fsr4GpuSupport`/`Fsr4Model` adjusted (see below).
- Admin rights (the game folder lives under `Program Files (x86)`).

## Install

1. Open **PowerShell as Administrator**.
2. Run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\install.ps1
```

3. Add `-dx12` to Stray's launch options in Steam.
4. Start the game and **load into gameplay** (the upscaler engages in-game, not in menus).

The installer also writes the tuned `Engine.ini` and `GameUserSettings.ini` (with
`ScreenPercentage=100`, which the donor requires at startup) to
`%LOCALAPPDATA%\Hk_project\Saved\Config\WindowsNoEditor\`.

### Options

| Parameter | Meaning |
|---|---|
| `-GameDir "<path>"` | Game `Win64` folder. Default: `C:\Program Files (x86)\Stray\Hk_project\Binaries\Win64`. |
| `-NoConfig` | Skip copying the tuned `.ini` files (keep your own). |
| `-SkipDownload` | Use files already present in `.\downloads` instead of downloading. |

## What gets installed

| File / folder | Source |
|---|---|
| `dxgi.dll` (= OptiScaler) | OptiScaler nightly release |
| `OptiScaler.ini`, `OptiScaler\` (incl. FSR4 runtimes) | OptiScaler nightly release |
| `ReShade64.dll` | ReShade 6.8 Add-on setup (official) |
| `StrayDLSS.addon64`, `nvngx_dlss.dll`, `nvngx_dlssd.dll`, `amd_fidelityfx_*_dx12.dll`, `streamline\` | StrayDLSS v1.1.0 release |
| `OptiScaler\amdxcffx64.dll` | Copied from the installed **AMD driver** (DriverStore); not redistributed here |
| `OptiScaler.ini`, `ReShade.ini`, `Engine.ini`, `GameUserSettings.ini` | This repository (`configs\`) |

## Configuration notes

The shipped `configs\OptiScaler.ini` differs from the OptiScaler default in these keys (all
tuned for Stray on a 780M):

```ini
[Upscalers]   Dx12Upscaler = ffx          ; use AMD FSR via FidelityFX
[FSR]         Fsr4GpuSupport = 4          ; force INT8 Lite (the APU model)
              Fsr4Model = 3               ; INT8 Lite
              FsrNonLinearColorSpace = true
[Framerate]   FramerateLimit = 60.000000  ; final FPS cap (works without game Reflex)
[Plugins]     LoadReshade = true          ; pull in ReShade64.dll (StrayDLSS)
              LoadAsiPlugins = true
[OptiFG]      HUDFix = true
[Hooks]       ColorResourceBarrier = 4    ; required for UE on AMD (no rainbow colours)
[InitFlags]   AutoExposure = true
```

`Sharpness = 0.801`, `CAS = true` and `Contrast` come from the Elden Ring tuning; if the image
looks oversharp in Stray, set `Sharpness/OverrideSharpness = false` (sharpening then comes only
from FSR inside StrayDLSS).

### StrayDLSS settings (`ReShade.ini → [StrayDLSS]`)

```ini
Enabled = 1        ; upscaler on
Upscaler = 2       ; FSR branch (the DLSS branch needs an NVIDIA RTX card)
DlssMode = 4       ; Performance  = 50% render  (2 = Quality 66.7%, 3 = Balanced 58%)
FsrSharpness = 0.1 ; low, to avoid shimmer on fur
```

`DlssMode` scale: `0`=Game 100%, `1`=DLAA, `2`=Quality 66.7%, `3`=Balanced 58%,
`4`=Performance 50%, `5`=Ultra Performance 33.3%.

### Frame generation

This build runs **without** frame generation: the 780M produces 60 real FPS, and XeFG only
added latency. To try 2X anyway, set `FGInput = upscaler`, `FGOutput = XeFG`,
`[XeFG] InterpolationCount = 1`, `ForceBorderless = true` in `OptiScaler.ini`.

### Other GPUs

- **RDNA4 / other Radeon:** `Fsr4GpuSupport = auto`, `Fsr4Model = auto`.
- **RDNA2:** `Fsr4GpuSupport = 4` + `Fsr4Model = 0` (quality) or `3` (perf).
- **No FSR 4 support:** StrayDLSS alone still gives FSR 3.1 via the add-on.

## Uninstall

Delete these from the game's `Win64` folder: `dxgi.dll`, `ReShade64.dll`, `ReShade.ini`,
`OptiScaler.ini`, `OptiScaler.log`, `StrayDLSS.addon64`, `StrayDLSS.log`, `nvngx_dlss.dll`,
`nvngx_dlssd.dll`, the `amd_fidelityfx_*_dx12.dll` files, and the `OptiScaler\` and
`streamline\` folders. Then delete the `[SystemSettings]` block from `Engine.ini` (or restore
your backup) if you want the original effects back.

## Licensing

The binaries this installer downloads are **not** redistributed here, because their licences do
not allow it:

- **NVIDIA DLSS** (`nvngx_dlss.dll`, `nvngx_dlssd.dll`, Streamline) — NVIDIA proprietary, no
  standalone redistribution. Fetched from the StrayDLSS release.
- **AMD FidelityFX / FSR 4** runtimes — pulled from the OptiScaler nightly and the StrayDLSS
  release; the `amdxcffx64.dll` runtime is copied from **your** installed AMD driver.
- **Intel XeSS / XeLL** (`libxess*.dll`, `libxell.dll`) — Intel licence, part of the OptiScaler
  archive.
- **ReShade** — BSD-3-Clause (redistributable, but downloaded from the official setup anyway).
- **OptiScaler** — see its repository for the licence.

Only the configuration files and the installer script in this repository are the author's work.

## Credits

- [OptiScaler](https://github.com/optiscaler/OptiScaler) — upscaler/frame-gen injector.
- [StrayDLSS](https://github.com/GreatDanish1026/StrayDLSS) — ReShade add-on that supplies
  DLSS/FSR inputs on UE4.27.
- [ReShade](https://reshade.me) — add-on framework.

Not affiliated with the authors of Stray, AMD, NVIDIA or Intel.
