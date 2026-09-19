# AOT Compiler

One-tap **dex2oat AOT compilation** for Android apps, shipped as a KernelSU / Magisk module with a built-in **WebUI**. No PC, no terminal needed.

> This is the "precompile all apps to native code" step. Run it after a fresh flash, a factory reset, or installing a batch of apps — app launches and general responsiveness usually feel noticeably snappier.

[中文](README.md) · [Changelog](CHANGELOG.md) · [Issues](https://github.com/ZhuYilin10/aot_compiler/issues)

---

## Features

- **Four compiler filters**: `everything` / `speed` / `speed-profile` / `verify`
- **Three scopes**: all apps / third-party only / a single package
- **One-tap controls**: start, stop (also cancels system-side dexopt jobs), reset all, free space
- **Live feedback**: progress bar, done/total, elapsed time, **ETA**, live log
- **Per-app query**: inspect the actual compiler filter a package is using
- **Automatic adaptation** — see below

## Automatic adaptation

| Item | Handling |
|---|---|
| Android version | SDK ≥ 34 uses the `--full` scope; SDK < 34 uses the default scope plus a `--secondary-dex` pass |
| CPU arch | Detects the dalvik path for `arm64 / arm / x86_64 / x86 / riscv64`, with a fallback scan |
| `pm art` commands | Gated by SDK; skipped cleanly on older versions |
| `everything` rejected | Probed first with `com.android.shell`; falls back to `speed` automatically and tells you in the UI |
| Module id changes | The WebUI resolves the script path from the manager's module info, so renaming won't break it |
| Process survival | The job is detached with `setsid` / `nohup`, so **closing the WebUI or unplugging USB won't interrupt it**; reopen the page to keep watching |

> Whether `everything` is permitted depends on the ROM. HyperOS allows it; strict user builds may reject it, in which case the module downgrades automatically.

## Requirements

- **Root**: KernelSU / KernelSU-Next / ReSukiSU / APatch, etc. (must grant this module root)
- **WebUI**: requires a manager that supports module WebUI (the KernelSU family).
  **Magisk has no module WebUI** — use the CLI instead (see "CLI usage")
- Android 7.0 (API 24) or newer

### Verified

| Device | System | Root | Result |
|---|---|---|---|
| Redmi K40 (`alioth`) | OS4.0.0.30.XPCCNXM / Android 17 (SDK 37) | ReSukiSU 4.2.0 | All features pass |

Compatibility reports for other devices are welcome.

## Install

1. Download `aot_compiler-vX.Y.Z.zip` from [Releases](https://github.com/ZhuYilin10/aot_compiler/releases)
2. Install it in your manager (KernelSU: Modules → Install from storage)
3. **Reboot** (required to activate a newly installed module)
4. KernelSU → Modules → **AOT 编译器** → open the **WebUI**

`updateJson` is configured, so in-app update checks work.

## Usage

1. Pick a **compiler filter** — `everything` for the best result, `speed-profile` for a quick win
2. Pick a **scope** — all apps / third-party / a package name
3. Tap **Start**, keep the device charging, and wait

**Recommended first run**: choose `third-party + verify`. It finishes in seconds and confirms everything works before you commit to a full `everything` run.

### Filters

| Filter | Meaning | Time | Storage |
|---|---|---|---|
| `everything` | Compile everything that can be compiled | Longest | Largest (may be several GB) |
| `speed` | AOT compile all methods | Long | Large |
| `speed-profile` | Only hot methods from profiles | Short | Small |
| `verify` | Verify only, no native code | Shortest | Smallest |

### Other buttons

- **Stop**: ends the task and cancels queued system-side dexopt jobs (an in-flight single compile may still finish)
- **Reset all**: wipes dexopt artifacts, equivalent to a freshly installed state
- **Free space**: runs `pm art cleanup` to drop stale odex/vdex

## CLI usage

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
| `version` | Version string |

Runtime files live in `/data/local/tmp/aot_compiler/`.

## FAQ

**How long does it take?**
Depends on app count and filter. Roughly 380 apps with `everything` took about 10 minutes on a K40. The UI shows an ETA.

**Does it wipe data?**
No. It only generates/replaces compilation artifacts in dalvik-cache.

**How much space does it use?**
A full `everything` run typically adds several GB. The "Dalvik" figure in the UI reflects it. Use "Free space" or `speed-profile` if you're tight.

**Does it survive a reboot?**
Yes, artifacts persist. But **an OTA update or manually clearing dalvik-cache wipes them** — just run it again.

**Why did `everything` turn into `speed`?**
Your ROM disallows the `everything` filter. The script downgrades automatically and says so in the UI. This is expected.

**How do I uninstall?**
Remove the module. Compilation artifacts remain; use "Reset all" first if you want them gone.

## Project layout

```
.
├── module.prop            # module metadata
├── customize.sh           # install script (prints environment and scope)
├── bin/aot.sh             # core dex2oat backend
├── webroot/index.html     # WebUI
├── build.sh               # local packaging
├── update.json            # update check
└── .github/workflows/     # build & release on tag
```

## Development

```sh
./build.sh          # produces dist/aot_compiler-vX.Y.Z.zip
```

Release checklist:

1. Bump `version` / `versionCode` in `module.prop`
2. Update `CHANGELOG.md`
3. Update `version` / `versionCode` / `zipUrl` in `update.json`
4. `git tag vX.Y.Z && git push origin vX.Y.Z` → GitHub Actions builds and publishes the Release

## Contributing

Issues and PRs are welcome. For compatibility reports, please include:

- Device, ROM name/version, Android version / SDK
- Root solution and version (KernelSU / APatch / Magisk …)
- Error output or a WebUI screenshot

## License

[MIT](LICENSE)
