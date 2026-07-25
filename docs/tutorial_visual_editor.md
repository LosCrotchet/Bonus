# BONUS 可视化教程编辑器

项目已启用 `BONUS Tutorial Editor` 插件。打开 Godot 后，点击顶部工作区的 **Tutorial** 即可进入。工具直接编辑 `TutorialScenario` 和 `TutorialStep` 资源；点击 **Save All** 后，场景和每个步骤都会保存为 `.tres`，运行时不依赖编辑器插件。

## 工作区

| 区域 | 用途 |
| --- | --- |
| 顶部工具栏 | 打开、重载、校验、保存教程；运行项目检查完整演出 |
| 左侧 | 编辑玩家数和固定种子；增删、复制、排序步骤；查看确定种子下所有玩家的初始手牌 |
| WYSIWYG Preview | 以 1280×720 基准嵌入真实 `game_scene.tscn`；拖动或拉伸对话框；取样 pointer、高亮和控件目标 |
| Flow Graph | 拖线创建步骤关系；拖动节点保存排版；断开连线删除 Transition |
| 右侧 | 编辑台词、布局、时序、输入锁、控件指令、AI 指令和分支属性 |

## 创建与保存

1. 打开 `features/tutorial/content/default_tutorial.tres`，或打开 `features/tutorial/examples/branching_example.tres` 查看完整分支示例。
2. 点击 `+` 新建步骤。每个 `step_id` 必须唯一；工具会用它作为流程图节点名和运行时跳转目标。
3. 对正式内容使用 `message_key`，台词写进 `localization/strings.csv`。`fallback_message` 适合快速预览和草稿。
4. 点击 **Save All**。未单独保存过的新步骤会写入 `features/tutorial/content/steps/<step_id>.tres`。
5. 点击 **Validate** 检查空 ID、重复 ID、无效入口和悬空跳转。

不要在文件管理器里直接复制一个步骤后只改文件名；资源内部的 `step_id` 也必须修改。改名时工具会同步所有指向该 ID 的 Transition。

## 所见即所得布局

对话框支持两种布局：

- **Preset**：上、下、左、右四个响应式预设，兼容已有教程。
- **Custom rect**：在预览中拖动对话框，拖右边、下边或右下角可改变尺寸。

自定义布局保存为 `normalized_dialog_rect`，其中位置与尺寸都是相对于视口的 0–1 比例，而不是固定像素。因此 720p、1080p 和 4K 会保持相同构图。运行时仍会限制在安全区域内，避免小分辨率溢出。

Pointer 与 Highlight 右侧的 **Sample** 会进入取样模式。此时点击预览中的目标控件，工具会写入相对于 `GameScene` 的真实 `NodePath`。不要手工猜路径；场景结构调整后应重新取样并运行校验。

## 线性步骤与流程图

`entry_step_id` 为空时，导演使用旧的线性模式：按 `steps` 数组顺序执行，`trigger` 决定步骤何时出现，`continue_mode` 与 `continue_event` 决定何时结束。左侧 **Up/Down** 调整线性顺序。

点击 **Selected = Start** 后，场景进入流程图模式：

- 入口节点在教程开始时立即显示。
- 从节点右侧端口拖到另一个节点，创建一个默认的 Click Transition。
- 选中步骤后，在右侧 **Outgoing Transitions** 选择连线，把 Trigger 改成 Click 或 Event。
- Event Transition 填写 `event_key`，例如 `action_roll`、`action_play`、`initial_deal_finished`。
- 点击 **Edit conditions**，在 Godot Inspector 的 `conditions` 数组中添加 `TutorialCondition`。
- 目标 ID 留空表示结束教程。

同一个事件可以有多条条件分支。运行时按数组顺序检查，第一条满足条件的 Transition 生效，因此应把具体条件放在前面，把没有条件的兜底分支放在最后。

### 条件

条件可以读取两类数据：

- `EVENT_PAYLOAD`：当前事件携带的数据，例如 `action_roll` 的 `dice_value`、动作的 `player_index`。
- `GAME_PROPERTY`：从 `GameScene` 开始读取属性链，例如 `_session.dice_value`。这类条件应谨慎使用，优先使用事件 payload，使步骤依赖明确的状态提交点。

支持等于、不等于、大小比较和真假判断。`property_path` 使用点号访问嵌套值。多个条件是 AND 关系。

## 输入与控件控制

`blocks_gameplay` 是总开关：暂停发牌、玩家操作、自动操作和 AI，但仍允许打开右上角设置与牌型界面。

Input Locks 用于更细的控制，不需要冻结整个对局：

| 锁 | 效果 |
| --- | --- |
| Deal skip | 禁止双击跳过初始发牌 |
| Double click | 禁止双击出牌或过牌 |
| Roll | 禁止玩家掷骰子 |
| Hand | 手牌仍显示，但无法选择 |
| Play / Pass / Hint | 分别禁用对应操作 |
| Automation | 禁用自动掷骰、自动跳过和 AI 托管图标 |
| AI | 暂停非玩家角色调度 |

Control Directives 可对任意实际控件执行 Disable、Hide、Enable 或 Show。选择模式后点击 **Sample & add**，再在预览中点目标。指令只在当前步骤有效，离开步骤时会恢复进入前的状态；导演会持续维护指令，避免游戏界面的刷新函数把按钮重新启用或显示。

隐藏和禁用用途不同：不希望玩家看到未来功能时使用 Hide；需要保留布局、同时明确展示当前不可用状态时使用 Disable。

## AI 编排与手牌

左下角 **Deterministic Hands** 使用教程的固定种子和规则生成真实初始手牌。牌显示为 `点数#card_id`，例如 `3#17`。`card_id` 是两副牌中唯一且稳定的标识，适合精确控制；只关心点数时也可使用 ranks。

每条 Scripted AI 指令包含：

- `player_index`：要控制的 AI 座位索引。
- `phase`：可限制为 `awaiting_roll` 或 `awaiting_action`，防止指令在错误时机被消费。
- `action`：Roll、Play 或 Pass。
- `forced_dice_value`：Roll 时填 1–6 会固定骰子结果；0 使用该种子的正常随机结果。
- `card_ids`：精确指定要出的牌；优先于 ranks。
- `ranks`：按点数从当前 AI 手牌中解析牌。
- `interpretation_key`：万能牌存在多种合法解释时指定牌型。

指令在进入步骤时加入对应 AI 的队列。每一次 AI 行动都应有独立指令，并把 `phase` 填准确。若牌 ID 已不在当前手牌中，教程策略会回退默认策略并产生可诊断的行为，而不会让牌局永久卡死。

初始手牌可以静态确定；中途摸牌后的手牌取决于此前所有玩家动作。制作此类步骤时，应从编辑器运行同一种子，在状态提交点核对实际牌局，再把后续 AI 指令放到对应步骤。不要根据动画计时推测 AI 何时行动。

## 推荐制作流程

1. 先只写节点、台词和 Click 连线，完成教程叙事骨架。
2. 设置固定种子，核对初始手牌，确定每次掷骰和出牌。
3. 把玩家必须完成的动作改成 Event Transition，并关闭会阻止该动作的锁。
4. 给解释步骤设置 Block/Dim；给操作步骤只设置必要的 Input Locks。
5. 用 Sample 绑定 pointer、highlight 和操作按钮，不手填路径。
6. 为每次 AI 行动添加命令，优先使用 card ID；摸牌后的步骤以实际运行结果为准。
7. Validate、Save All，再用 Run Tutorial 完整播放。测试 1280×720、1920×1080 和窗口拉伸后的对话框边界。

## 扩展事件

现有事件不足时，在 `GameScene` 的状态真正提交后调用 `_notify_tutorial_event(&"event_name", payload)`。不要在 `_process()` 中轮询，也不要用固定 Timer 猜测动画是否结束。新事件应把分支需要的数据放进 payload，这样可视化编辑器中的条件可以直接读取。
