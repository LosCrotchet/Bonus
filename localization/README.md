# 本地化资源

`strings.csv` 是游戏界面与规则提示的翻译源文件，采用 Godot 4.7 支持的 UTF-8 CSV 格式。

- 第一列是稳定且唯一的翻译键，代码与场景只引用该键。
- 其余列使用 Godot locale 名称，例如 `zh_CN`、`en`。
- 新增语言时增加一列，并在 Godot 导入完成后把生成的 `.translation` 资源加入 `project.godot` 的 `internationalization/locale/translations`。
- 动态文本使用 `{name}` 形式的命名占位符，便于不同语言调整语序。

不要在核心规则或 AI 策略中直接拼接面向玩家的文本；这些模块应返回翻译键和占位参数，由表现层调用 `tr()`。
