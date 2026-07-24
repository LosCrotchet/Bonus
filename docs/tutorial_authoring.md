# BONUS 教程制作指南

教程系统把对局、演出和内容分开。普通牌局仍由 `GameSession` 执行规则；教程资源描述何时说什么、指向哪里以及 AI 下一步做什么；`TutorialDirector` 只负责节奏和展示，不改牌型判定。

## 文件职责

| 文件 | 用途 |
| --- | --- |
| `features/tutorial/content/default_tutorial.tres` | 教程入口实际加载的场景配置、固定种子和步骤列表 |
| `features/tutorial/tutorial_step.gd` | 单个教程步骤的数据格式 |
| `features/tutorial/tutorial_director.gd` | 对话、emoji、遮罩、高亮、暂停和继续 |
| `ai/strategies/tutorial.gd` | 执行教程指定的 AI 动作；没有指令时使用默认 AI |
| `assets/tutorial/emoji/` | 已选入项目的教程角色素材 |

## 编写步骤

1. 在 Godot 检视器中打开 `default_tutorial.tres`，确定 `player_count`、8 位种子和规则。
2. 为每段内容新建一个 `TutorialStep` 资源，建议保存到 `features/tutorial/content/steps/`，再按顺序加入 `steps`。
3. 正式台词写入 `localization/strings.csv`，步骤使用 `message_key`。`fallback_message` 只用于草稿。
4. 运行同一种子，记录需要高亮的节点路径、期望玩家操作和 AI 动作；逐步补齐触发事件和指令。

步骤严格按数组顺序执行。当前步骤未结束时，后续事件不会跳过它，因而不会因动画快慢造成时序漂移。

## 步骤字段

| 字段 | 含义 |
| --- | --- |
| `trigger` | 显示该步骤的事件，例如 `tutorial_started`、`initial_deal_finished`、`awaiting_roll`、`awaiting_action`、`bonus_started`、`action_play`、`action_pass`、`game_finished` |
| `message_key` | `strings.csv` 中的多语言键 |
| `emoji` | 对话角色或手势图片；留空时文本自动占用该空间 |
| `placement` | 对话框位于上、下、左或右；优先避开当前要观察的区域 |
| `dialog_width` | 对话框目标宽度，默认 760；运行时会按当前分辨率限制在安全范围内 |
| `dialog_height` | 对话框目标高度，默认 210；长文本步骤可以单独调高 |
| `pointer_emoji` | 独立于对话角色的手势图片，用于指向牌桌控件 |
| `pointer_target_path` | 手势指向的 `GameScene` 节点；导演会随目标移动，并把手势放在目标右侧 |
| `pointer_size` | 手势显示尺寸，默认 72 像素 |
| `blocks_gameplay` | 是否冻结玩家操作与 AI 调度；对话解释规则时通常启用 |
| `continue_mode` | `BUTTON` 表示点击屏幕继续（名称为兼容旧资源而保留），`EVENT` 表示等待指定操作完成 |
| `continue_event` | `EVENT` 模式所等待的事件 |
| `minimum_display_time` | 允许点击继续前的最短时间；时间到后右下角的三角提示才会渐显 |
| `highlight_path` | 相对于 `GameScene` 的节点路径，导演会持续跟随该控件的位置和尺寸 |
| `ai_commands` | 进入该步骤时注入教程 AI 的指令 |

## 台词与 emoji

- 每个对话框只讲一个操作或一个规则，正文以 1 至 3 行为宜。
- 先说明玩家现在要做什么，再解释原因；技巧和例外放到动作完成之后。
- 表情 emoji 放在角色发言中，手势 emoji 用于短暂指向骰子、手牌或按钮。不要同时显示多个手势。
- 当前导演提供淡入和轻微弹性缩放。需要挥手、点按或抖动时，在导演中按步骤增加独立动画，避免让素材自身位置参与牌桌布局。

## 节奏控制

- 需要阅读时设置 `blocks_gameplay = true`。此时牌局输入、发牌跳过、手牌、自动操作和 AI 调度全部锁定，仅保留右上角的牌型与设置；音乐和对话动画仍正常运行。
- 要求玩家完成动作时，先点击屏幕关闭讲解，再用一个 `blocks_gameplay = false` 的 `EVENT` 步骤等待 `action_play`、`action_pass` 等事件；等待玩家操作的步骤不能同时锁住牌局。
- AI 行动前先注入命令，再解除锁定。不要使用固定 `Timer` 猜测牌局是否已经完成。
- 教程种子由 `default_tutorial.tres` 固定配置；更换种子后必须重新核对所有按点数选牌的 AI 指令。

## `continue_event` 的用法

通常不需要自己定义事件。`continue_event` 只是填写一个已有事件的名称，只有 `continue_mode = EVENT` 时才会读取。导演显示该步骤后会一直等待；当 `GameScene` 报告同名事件时，步骤自动结束。

目前可以直接使用的事件包括：

- 阶段事件：`initial_deal_finished`、`awaiting_roll`、`awaiting_action`、`bonus_started`、`game_finished`。
- 玩家动作：`action_roll`、`action_play`、`action_pass`。
- 通用动作：`action_resolved`，任何掷骰、出牌或过牌都会触发。

例如，要求玩家亲自掷骰：

```gdscript
trigger = &"awaiting_roll"
continue_mode = TutorialStep.ContinueMode.EVENT
continue_event = &"action_roll"
blocks_gameplay = false
highlight_path = NodePath("SafeArea/MainLayout/MainArea/TableRow/RollPanel/RollLayout/DiceGroup/DiceArea/DiceButton")
```

这里不能启用 `blocks_gameplay`，否则玩家无法掷骰，`action_roll` 也就永远不会发生。只有现有事件无法表达新的教程检查点时，才需要在 `GameScene` 的状态提交位置调用 `_notify_tutorial_event(&"你的事件名")` 增加事件；不要在 `_process()` 中轮询。

## 开场示例

`welcome.tres` 和 `initial_hand.tres` 展示了两个独立步骤的基础配置：

1. `steps/welcome.tres`：收到 `tutorial_started` 后锁定牌局，在屏幕下方显示欢迎语和 `emoji_u1f970`。
2. `steps/initial_hand.tres`：玩家点击继续后仍保持牌局锁定，在屏幕右侧说明初始手牌；`emoji_u1f600` 作为说话角色，`emoji_u1f448` 独立指向并高亮 `HandPanel`。

同一事件下连续讲解时，让这些步骤使用相同的 `trigger` 并相邻排列。玩家关闭最后一个点击步骤后，导演解除锁定，牌局流程才会继续。当前 `default_tutorial.tres` 中的 `welcome_1` 至 `welcome_6` 就采用这种方式串联。

## AI 指令

每条命令必须带 `player_index`，可选 `phase` 用于防止在错误阶段消费：

```gdscript
{
    "player_index": 1,
    "phase": "awaiting_roll",
    "action": "roll",
}
```

```gdscript
{
    "player_index": 1,
    "phase": "awaiting_action",
    "action": "play",
    "ranks": [3, 3],
    "interpretation_key": "",
}
```

支持 `roll`、`pass` 和 `play`。`play` 可用稳定的 `ranks`，也可用具体 `card_ids`；存在多种牌型解释时应填写 `interpretation_key`。指令无法在当前手牌中解析时，教程 AI 会回退到默认策略，避免对局卡死。

## 扩展边界

教程需要新的触发点时，在 `GameScene` 的关键状态提交处调用 `_notify_tutorial_event()`，不要在 `_process()` 中轮询规则状态。需要新的演出形式时扩展 `TutorialDirector`；需要新的 AI 表达方式时扩展 `TutorialStrategy` 的命令解析，不要把教程分支写进 `GameSession`。
