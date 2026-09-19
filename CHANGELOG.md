# 更新日志

## v1.2.0

开源首发版本，通用化改造。

**新增**

- 界面显示**预计剩余时间（ETA）**
- 界面显示模块版本号，并链接到 GitHub 仓库
- 模块配置 `updateJson`，支持管理器内检查更新
- `version` 子命令
- 日志开头写入本次任务的时间、模式、范围与作用域

**通用化**

- 模块 id 改为 `aot_compiler`，不再绑定机型
- WebUI 通过管理器模块信息动态定位脚本路径，改名不再失效
- dalvik 路径自动探测 `arm64 / arm / x86_64 / x86 / riscv64`，并带兜底遍历
- 按 Android SDK 自动选择作用域：≥ 34 用 `--full`，< 34 用默认作用域 + `--secondary-dex`
- `pm art` 相关命令按 SDK 判断，低版本优雅跳过
- `everything` 过滤器先探测再使用，不支持时自动降级为 `speed` 并在界面提示
- 应用列表优先使用 `cmd package list packages`，回退到 `pm list packages`
- 进程脱离优先 `setsid`，回退 `nohup`

**修复**

- 第三方 / 单包范围的进度计数改用独立计数器，避免低版本二次编译导致计数翻倍
- 完善 pid 失效检测，异常退出后状态能正确落到 `done`

## v1.1.0

- 首个通用化版本（当时 id 仍为 `aot_compiler`，本地验证）
- 增加按 SDK 适配、dalvik 路径探测、`everything` 降级

## v1.0.0

- 初版，仅针对 Redmi K40 验证
- 支持 everything / speed / speed-profile / verify 四种模式
- 支持全部应用 / 仅第三方 / 指定包名
- WebUI：进度条、实时日志、停止、重置、清理空间
