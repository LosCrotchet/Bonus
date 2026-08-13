# BONUS 分发与持久化约定

## 用户数据

运行时可变数据统一写入 Godot 的 `user://`，不得写入安装目录。Windows 默认位置为：

`%APPDATA%\Godot\app_userdata\Bonus\`

当前文件如下：

| 文件 | 内容 |
| --- | --- |
| `bonus_settings.cfg` | 分辨率、语言、音量和游戏设置 |
| `bonus_progress.cfg` | 教程是否已经打开等解锁进度 |
| `bonus_statistics.cfg` | 生涯对局、连胜和操作统计 |
| `bonus_save.json` | 未完成的单人牌局与本局统计 |
| `bonus_save.tmp` / `bonus_save.backup`、`bonus_statistics.tmp` / `bonus_statistics.backup` | 原子替换所用的临时文件 |

安装目录在 `Program Files` 等位置可能不可写，也会被平台更新覆盖。以上文件后续均可作为 Steam Cloud 的同步候选；临时文件和 backup 不必同步。

## SteamPipe 基线

Windows 发行版保持 `bonus.exe + bonus.pck` 分离，不将 PCK 嵌入 EXE。EXE 是 Godot 运行时，PCK 是项目脚本和资源。这允许资源更新不必改变入口文件，也便于诊断和版本管理。

SteamPipe 会将文件拆分为约 1 MB 的块并生成二进制增量，因此 EXE 或 PCK 发生变化并不等价于重新下载整个文件。Steam 官方仍建议控制大型包文件、保持包内资产顺序稳定，并避免一个小改动重写整个包。参考：[SteamPipe 上传文档](https://partner.steamgames.com/doc/sdk/uploading)。

当前项目体量不需要立即拆分多个 PCK。过早拆包会增加加载、版本匹配和测试复杂度。达到以下条件之一时再按稳定功能边界拆分资源包：

- 单个 PCK 明显增大，常规更新的 Steam Preview 补丁体积异常；
- 新增大型、低频变化的音乐、语音或可选高清素材；
- 需要可选 DLC 或按平台提供不同资产。

不要按零散文件类型盲目拆包。新大型内容优先进入新包，避免重排已有包。Steam 已负责传输压缩，不应为了上传再把整个发行目录套一层会频繁整体变化的压缩包。

## 发布检查

每次平台发布应完成：

1. 生成干净的 release 导出，并确认 PCK 未嵌入 EXE。
2. 比较上一版本与当前版本的 EXE、PCK 大小和哈希。
3. 使用 SteamPipe Preview 检查实际变更块和预计下载量。
4. 验证升级安装不会修改或删除 `user://` 中的设置、统计和未完成牌局。
5. Windows、Linux/SteamOS、macOS 采用独立 depot；同平台内先保持一个基础 depot，等资产规模证明有必要后再拆。
