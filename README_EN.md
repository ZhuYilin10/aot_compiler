# AOT Compiler

**One-tap dex2oat AOT compilation for Android apps — a KernelSU / Magisk module with a built-in WebUI.**

After flashing a ROM, doing a factory reset, or migrating to a new device, your apps are effectively *uncompiled*, which is why everything feels sluggish. This module turns the system's own dex2oat capability into a single button: tap once and your apps are precompiled to native code.

No PC, no terminal. The compile job runs detached from the UI, so closing the page or unplugging USB won't interrupt it.

[![License](https://img.shields.io/github/license/ZhuYilin10/aot_compiler)](LICENSE)
[![Release](https://img.shields.io/github/v/release/ZhuYilin10/aot_compiler)](https://github.com/ZhuYilin10/aot_compiler/releases)
[![Android](https://img.shields.io/badge/Android-7.0%2B-3ddc84?logo=android&logoColor=white)](#requirements)
[![KernelSU](https://img.shields.io/badge/KernelSU-WebUI-4c8dff)](https://kernelsu.org)
[![Downloads](https://img.shields.io/github/downloads/ZhuYilin10/aot_compiler/total)](https://github.com/ZhuYilin10/aot_compiler/releases)

[中文](README.md)

---

## Download

| Method | Link |
|---|---|
| **Latest (recommended)** | [Releases · latest](https://github.com/ZhuYilin10/aot_compiler/releases/latest) |
| Direct zip | [`aot_compiler-v1.2.0.zip`](https://github.com/ZhuYilin10/aot_compiler/releases/download/v1.2.0/aot_compiler-v1.2.0.zip) |
| In-repo copy | [`download/aot_compiler-v1.2.0.zip`](download/aot_compiler-v1.2.0.zip) |

`updateJson` is configured, so your manager can check for updates.

## Screenshots

| Main screen | Compiling | Per-app query |
|---|---|---|
| ![Main](screenshots/01-overview.png) | ![Running](screenshots/02-running.png) | ![Query](screenshots/03-query.png) |

---

## Why this exists

**1. After a flash, your apps aren't actually compiled.**
Since Android 9, apps are installed with `speed-profile` (hot methods only) and the rest is left to JIT. Worse, after a flash or factory reset many ROMs set `pm.dexopt.first-boot` to `verify` — meaning **no native code is generated at all**. Every cold start then pays for interpretation and JIT warm-up.

**2. Android's own optimizer is extremely patient.**
The background `bg-dexopt` job only runs when the device is **idle and charging**, and it uses `speed-profile`. Waiting for it to optimize hundreds of apps is a matter of luck.

**3. There is no UI for it.**
Full compilation is only reachable through adb:

```sh
adb shell cmd package compile -m everything -f --full -a
```

And the parameters differ before/after Android 14.

**4. Existing tools have aged badly.**
Scene is the best-known one. Its dex2oat feature does support `everything`, but:

- compilation is **per-app only**, there is no true one-tap full run
- its command is **missing `--full`**, so on Android 14+ only the primary dex is compiled and secondary dexes are skipped entirely
- it targets SDK 30 and is limited by modern background restrictions
- it has a "not supported on your device" version gate

**So this module packages the official commands into a one-tap tool** with progress, ETA, logs, cancellation and cleanup — and keeps the job running independently of the UI.

---

## How it works

### How app code executes

Android app code lives in APKs as **DEX bytecode**, executed by **ART**. ART has three modes:

| Mode | Description | Speed |
|---|---|---|
| Interpreter | Translates bytecode instruction by instruction | Slowest |
| **JIT** | Compiles hot methods to native code at runtime | Medium, costs runtime CPU |
| **AOT** | Compiles bytecode to native code ahead of time | Fastest |

More AOT coverage is better — but it costs time and storage, so Android constantly trades off how much to compile.

### dex2oat and compiler filters

`dex2oat` performs the DEX → native translation. How much it compiles is decided by the **compiler filter**:

| Filter | Meaning |
|---|---|
| `verify` | Verification only, no native code |
| `speed-profile` | Only hot methods recorded in profiles |
| `speed` | All methods |
| `everything` | Compiles even methods that are normally skipped |

Artifacts are written to `/data/dalvik-cache/<abi>/`, for example:

```
/data/dalvik-cache/arm64/system_ext@priv-app@MiuiSystemUI@MiuiSystemUI.apk@classes.dex
/data/dalvik-cache/arm64/system_ext@priv-app@MiuiSystemUI@MiuiSystemUI.apk@classes.vdex
```

They **persist across reboots**, but an OTA update or manually clearing dalvik-cache wipes them.

### Command chain

The module never implements compilation itself — it calls the official interfaces:

```
cmd package compile -m <filter> -f --full -a
        │
        ▼
PackageManagerShellCommand  ──►  ArtManagerLocal  ──►  ArtService  ──►  dex2oat
```

Android 14 additionally exposes `pm art` (the shell entry point of ArtManagerLocal). The module uses three of its subcommands:

| Command | Purpose |
|---|---|
| `pm art dump` | Show each app's current compilation state (per-app query) |
| `pm art cancel` | Cancel queued dexopt jobs (Stop button) |
| `pm art cleanup` | Drop stale odex/vdex (Free space button) |

### Why `--full` matters

- **Android 14 (SDK 34) and newer**: has scope flags; `--full` means primary dex + secondary dex + dependencies
- **Android 13 and older**: no `--full`; the module runs the default scope first, then a separate `--secondary-dex` pass

The module picks the right form based on SDK.

### Why the job survives

The backend is launched with `setsid` (falling back to `nohup`), detached from the caller's session, with stdout/stderr redirected to a log file. So closing the WebUI, unplugging USB, or reopening the page later all work fine.

---

## Features

- **Four compiler filters**: `everything` / `speed` / `speed-profile` / `verify`
- **Three scopes**: all apps / third-party only / a single package
- **One-tap controls**: start, stop (also cancels system-side jobs), reset all, free space
- **Live feedback**: progress bar, done/total, elapsed time, **ETA**, live log
- **Per-app query**: inspect the actual compiler filter in use
- **Automatic adaptation** — see below

### Automatic adaptation

| Item | Handling |
|---|---|
| Android version | SDK ≥ 34 uses `--full`; SDK < 34 uses default scope + `--secondary-dex` |
| CPU arch | Detects the dalvik path for `arm64 / arm / x86_64 / x86 / riscv64`, with a fallback scan |
| `pm art` commands | Gated by SDK; skipped cleanly on older versions |
| `everything` rejected | Probed with a small package first; **auto-downgrades to `speed`** and says so in the UI |
| Module id changes | The WebUI resolves the script path from module info, so renaming won't break it |
| Process survival | `setsid` → `nohup` fallback chain |

> Whether `everything` is permitted depends on the ROM. HyperOS allows it; strict user builds may not, in which case it downgrades automatically.

## Requirements

- **Root**: KernelSU / KernelSU-Next / ReSukiSU / APatch, etc.
- **WebUI**: requires a manager that supports module WebUI (the KernelSU family).
  ⚠️ **Magisk has no module WebUI** — use the CLI instead.
- Android 7.0 (API 24) or newer

### Verified

| Device | System | Root | Result |
|---|---|---|---|
| Redmi K40 (`alioth`) | OS4.0.0.30.XPCCNXM / Android 17 (SDK 37) | ReSukiSU 4.2.0 | All features pass |

---

## Installation

### KernelSU family (recommended, WebUI available)

1. Download `aot_compiler-vX.Y.Z.zip`
2. Manager → **Modules** → **Install from storage** → pick the zip
3. **Reboot** (required to activate a newly installed module)
4. Manager → Modules → **AOT 编译器** → tap the **WebUI** icon

### CLI install (universal)

```sh
adb push aot_compiler-v1.2.0.zip /data/local/tmp/
adb shell su -c 'ksud module install /data/local/tmp/aot_compiler-v1.2.0.zip'
adb reboot
```

Verify:

```sh
adb shell su -c 'ksud module list'
# look for "id": "aot_compiler" with "web": "true"
```

### Magisk (CLI only)

Install the zip in Magisk → Modules, reboot, then use the CLI (see below). There is no WebUI on Magisk.

### Upgrade / uninstall

Install the newer zip and reboot to upgrade. To remove, delete the module in the manager (or `ksud module uninstall aot_compiler`) and reboot. Compilation artifacts are not removed — use **Reset all** first if you want them gone.

---

## Usage

**1. Pick a filter** (default `everything`)

| Filter | Meaning | Time | Storage |
|---|---|---|---|
| `everything` | Compile everything that can be compiled | Longest | Largest (may be several GB) |
| `speed` | AOT compile all methods | Long | Large |
| `speed-profile` | Only hot methods from profiles | Short | Small |
| `verify` | Verify only, no native code | Shortest | Smallest |

**2. Pick a scope** — all apps / third-party only / a package name.

**3. Tap Start.** Full `everything` runs ask for confirmation. You get a progress bar, done/total, elapsed time, ETA and a live log.

> First run: try **third-party + verify**. It takes seconds and confirms everything works before a full run.

**4. Other buttons**

- **Stop**: ends the task and cancels queued system-side dexopt jobs
- **Reset all**: wipes dexopt artifacts (back to a freshly installed state)
- **Free space**: runs `pm art cleanup`

### CLI usage

```sh
su -c 'sh /data/adb/modules/aot_compiler/bin/aot.sh status'
su -c 'sh /data/adb/modules/aot_compiler/bin/aot.sh start everything third'
su -c 'sh /data/adb/modules/aot_compiler/bin/aot.sh stop'
```

| Subcommand | Description |
|---|---|
| `start <filter> <scope>` | `filter`: everything/speed/speed-profile/verify; `scope`: `all`/`third`/package |
| `stop` | Stop the task and cancel jobs |
| `status` | Key=value status (`state/filter/scope/total/done/eta/note`) |
| `log [n]` | Last n log lines (default 300) |
| `reset` | Reset dexopt state for all apps |
| `cleanup` | Free stale odex/vdex |
| `query <package>` | Query one app's compilation status |
| `info` | Device and environment info |

Runtime files live in `/data/local/tmp/aot_compiler/`.

---

## FAQ

**How long does it take?**
K40 measurements: 387 apps with `everything` ≈ 10 minutes; 30 third-party apps ≈ 2 minutes. The UI shows an ETA.

**Does it wipe data?**
No. Only dalvik-cache artifacts are touched.

**How much space does it use?**
A full `everything` run typically adds several GB. Watch the "Dalvik" figure in the UI.

**Does it survive a reboot?**
Yes. But an OTA update or clearing dalvik-cache wipes it — just run it again.

**Why did `everything` become `speed`?**
Your ROM disallows the `everything` filter. It downgrades automatically and shows a notice.

**The phone gets hot / laggy during compilation — is that normal?**
Yes. dex2oat saturates the CPU. Keep it charging; it recovers once done.

**Can I close the UI?**
Yes, the job runs detached. Reopen the page to see progress. Don't reboot mid-run.

## Project layout

```
.
├── module.prop              # module metadata (incl. updateJson)
├── customize.sh             # install script, prints device + scope
├── bin/aot.sh               # core dex2oat backend
├── webroot/index.html       # WebUI
├── build.sh                 # local packaging
├── update.json              # update check
├── screenshots/             # README images
├── download/                # prebuilt zip
└── .github/workflows/release.yml
```

## Development

```sh
./build.sh              # build to dist/ and sync to download/
./build.sh --dist-only  # build to dist/ only
```

Release checklist: bump `module.prop` → update `CHANGELOG.md` → update `update.json` → `git tag vX.Y.Z && git push origin vX.Y.Z` (Actions builds and publishes the Release).

## Contributing

Issues and PRs welcome. For compatibility reports include: device, ROM + version, Android version/SDK, root solution + version, and any error output or screenshot.

## Disclaimer

This module only calls the system's own dex2oat interfaces. It does not modify system partitions or wipe data. Any low-level operation carries risk — use at your own discretion.

## License

[MIT](LICENSE)
