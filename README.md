# AOT 编译器

给安卓应用做 **dex2oat AOT 编译**的一键工具。挂载为 KernelSU / Magisk 模块，通过管理器自带的 **WebUI** 操作，无需电脑、无需命令行。

> 就是那个「把应用全部预先编译成机器码」的功能。新刷机、恢复出厂、刚装完一堆应用之后跑一次，应用启动和响应会明显更跟手。

[English](README_EN.md) · [更新日志](CHANGELOG.md) · [问题反馈](https://github.com/ZhuYilin10/aot_compiler/issues)

---

## 特性

- **四种编译模式**：`everything` 全量 / `speed` / `speed-profile` / `verify`
- **三种编译范围**：全部应用 / 仅第三方应用 / 指定包名
- **一键操作**：开始、停止（含取消系统侧 dexopt 作业）、重置全部、清理空间
- **实时反馈**：进度条、完成数、已用时、**预计剩余时间**、实时日志
- **单应用查询**：查看某个应用当前实际的编译过滤器
- **自动适配**，见下节

## 自动适配

| 项目 | 处理方式 |
|---|---|
| Android 版本 | SDK ≥ 34 用 `--full` 作用域；SDK < 34 用默认作用域 + `--secondary-dex` 二次编译 |
| CPU 架构 | 自动探测 `arm64 / arm / x86_64 / x86 / riscv64` 的 dalvik 路径，带兜底遍历 |
| `pm art` 子命令 | 按 SDK 判断，低版本自动跳过，不报错 |
| `everything` 被拒 | 先用 `com.android.shell` 探测；不支持则自动降级为 `speed` 并在界面提示 |
| 模块 id 变更 | WebUI 通过管理器返回的模块信息动态定位脚本，改名不会失效 |
| 进程存活 | 用 `setsid` / `nohup` 让编译脱离界面，**关掉 WebUI 或拔线都不会中断**，重开页面继续看进度 |

> `everything` 是否可用由各 ROM 决定。例如小米 HyperOS 允许，部分严格 user 构建会拒绝，此时会自动降级。

## 环境要求

- **Root**：KernelSU / KernelSU-Next / ReSukiSU / APatch 等（需要授予本模块 root）
- **WebUI**：需要支持模块 WebUI 的管理器（KernelSU 系）。
  **Magisk 没有模块 WebUI**，只能通过终端执行脚本，用法见下方「命令行用法」
- Android 7.0 (API 24) 及以上

### 已验证

| 设备 | 系统 | Root | 结果 |
|---|---|---|---|
| Redmi K40 (`alioth`) | OS4.0.0.30.XPCCNXM / Android 17 (SDK 37) | ReSukiSU 4.2.0 | 全部功能通过 |

其他机型欢迎按下方模板提交反馈。

## 安装

1. 从 [Releases](https://github.com/ZhuYilin10/aot_compiler/releases) 下载 `aot_compiler-vX.Y.Z.zip`
2. 在管理器中安装该 zip（KernelSU：模块 → 从本地安装）
3. **重启手机**（模块首次安装需要重启激活）
4. KernelSU → 模块 → **AOT 编译器** → 打开 **WebUI**

模块已配置 `updateJson`，管理器内可直接检测更新。

## 使用

1. 选**编译模式**：一般用 `everything 全量`；只想快速见效可用 `speed-profile`
2. 选**编译范围**：全部应用 / 仅第三方 / 填包名
3. 点 **开始编译**，保持充电，等待完成

**建议首次这样验证**：先选 `仅第三方 + verify`，几十秒就能跑完。确认没问题后再跑 `everything + 全部应用`。

### 模式说明

| 模式 | 含义 | 耗时 | 存储占用 |
|---|---|---|---|
| `everything` | 编译所有可编译内容，效果最好 | 最长 | 最大（可能数 GB） |
| `speed` | AOT 编译所有方法 | 较长 | 较大 |
| `speed-profile` | 只编译配置文件中的热点方法 | 短 | 小 |
| `verify` | 仅校验，不生成机器码 | 最短 | 最小 |

### 其他按钮

- **停止**：终止任务，并请求取消系统侧仍在排队的 dexopt 作业（进行中的单个编译可能还会跑完）
- **重置全部**：清除全部 dexopt 产物，等于回到「刚安装」状态
- **清理空间**：`pm art cleanup`，释放无用的 odex/vdex

## 命令行用法

不需要 WebUI 时可直接调用：

```sh
su -c 'sh /data/adb/modules/aot_compiler/bin/aot.sh status'
su -c 'sh /data/adb/modules/aot_compiler/bin/aot.sh start everything third'
su -c 'sh /data/adb/modules/aot_compiler/bin/aot.sh stop'
```

| 子命令 | 说明 |
|---|---|
| `start <filter> <scope>` | `filter`: everything/speed/speed-profile/verify；`scope`: `all`/`third`/包名 |
| `stop` | 停止任务并取消作业 |
| `status` | 状态键值对（含 `state/filter/scope/total/done/eta/note`） |
| `log [n]` | 日志尾部 n 行（默认 300） |
| `reset` | 重置全部应用 dexopt 状态 |
| `cleanup` | 清理无用 odex/vdex |
| `query <包名>` | 查询单个应用编译状态 |
| `info` | 设备与环境信息 |
| `version` | 版本号 |

运行时文件位于 `/data/local/tmp/aot_compiler/`。

## 常见问题

**Q：编译要多久？**
取决于应用数量和模式。约 380 个应用跑 `everything` 约 10 分钟（K40 实测），界面会给出预计剩余时间。

**Q：会清数据吗？**
不会。只生成/替换 dalvik-cache 里的编译产物。

**Q：跑完占了多少空间？**
`everything` 全量通常增加数 GB，界面「Dalvik 占用」可看到变化。空间紧张就用「清理空间」或改用 `speed-profile`。

**Q：重启后还有效吗？**
有效，编译产物持久保存。但**系统 OTA 更新或手动清 dalvik-cache 会失效**，需要重跑。

**Q：为什么 `everything` 自动变成 `speed` 了？**
你的 ROM 不允许 `everything` 过滤器，脚本自动降级并在界面提示，属正常行为。

**Q：能卸载吗？**
可以，直接删模块。编译产物仍保留，需要的话先点「重置全部」。

## 项目结构

```
.
├── module.prop            # 模块信息
├── customize.sh           # 安装脚本（打印环境与作用域）
├── bin/aot.sh             # 核心：dex2oat 编译后端
├── webroot/index.html     # WebUI 界面
├── build.sh               # 本地打包
├── update.json            # 模块更新检查
└── .github/workflows/     # 打 tag 自动构建 Release
```

## 开发与构建

```sh
./build.sh          # 生成 dist/aot_compiler-vX.Y.Z.zip
```

发布流程：

1. 改 `module.prop` 的 `version` / `versionCode`
2. 更新 `CHANGELOG.md`
3. 更新 `update.json` 的 `version` / `versionCode` / `zipUrl`
4. `git tag vX.Y.Z && git push origin vX.Y.Z` → GitHub Actions 自动构建并发布 Release

## 贡献

欢迎提交 Issue / PR。反馈机型兼容性时请附上：

- 机型、ROM 名称与版本、Android 版本 / SDK
- Root 方案与版本（KernelSU / APatch / Magisk …）
- 报错内容或 WebUI 截图

## 许可证

[MIT](LICENSE)
