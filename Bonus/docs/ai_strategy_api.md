# AI 策略接口

Bonus 的 AI 是可替换策略。牌局只规定策略何时决策、能看到哪些信息以及必须返回什么；选牌方式、记牌方式和风险偏好都由策略自行实现。默认实现位于 `res://ai/strategies/default.gd`。

## 安全边界

策略只能依据牌桌上的公开信息和自己的手牌决策。`GameSession.create_strategy_context()` 会创建与真实牌局分离的快照，不提供其他玩家的手牌，也不允许策略直接修改牌局。

策略不得：

- 访问 `GameSession.players`、场景节点或其他玩家的 `HandView`。
- 读取牌堆中尚未公开的牌面或卡牌顺序。
- 直接增删手牌、推进回合或调用 `GameSession` 的操作方法。
- 根据动画、节点位置等表现层信息作出规则决策。

## 必须实现的方法

策略脚本继承 `PlayerStrategy`，至少实现以下方法：

```gdscript
func get_strategy_id() -> StringName
func get_display_name_key() -> StringName
func choose_action(context: StrategyContext) -> PlayerDecision
```

`get_strategy_id()` 返回稳定且唯一的英文标识，用于注册和存档，例如 `&"cautious"`。`get_display_name_key()` 返回翻译键。`choose_action()` 每次必须返回一个 `PlayerDecision`，且不能保留或修改传入的上下文来影响牌局。

基类会在开局时调用：

```gdscript
func setup(player_index: int, player_count: int) -> void
```

重写时应先调用 `super.setup(player_index, player_count)`，或自行正确设置 `controlled_player_index` 与 `player_count`。

## 可选方法

```gdscript
func observe_action(public_action: Dictionary) -> void
func reset() -> void
```

`observe_action()` 在一个已确认的公开动作完成后调用，适合记牌或更新概率模型。`reset()` 用于清空跨回合缓存；策略不得借此保存或恢复真实牌局对象。

公开动作包含公共字段 `type`、`player_index`、`hand_count`。不同动作还可能包含：

| `type` | 附加字段 |
| --- | --- |
| `roll` | `dice_value` |
| `play` | `cards`、`interpretation_key` |
| `pass` | 无 |

`cards` 仅在牌已打出后提供，由 `card_id`、`rank`、`suit`、`joker_kind` 组成。

## StrategyContext

每次决策都会收到新的只读语义快照：

| 字段 | 含义 |
| --- | --- |
| `player_index` | 当前策略控制的玩家索引 |
| `phase` | `PHASE_ROLL` 或 `PHASE_ACTION` |
| `own_hand` | 自己手牌的副本，可读取 `card_id`、点数、花色和万能牌类型 |
| `player_summaries` | 各玩家索引、名称翻译键、手牌数量、是否当前行动者、是否为掷骰者 |
| `draw_pile_count` | 摸牌堆剩余数量 |
| `discard_pile_count` | 弃牌堆数量 |
| `dice_value` | 本轮骰子点数，尚未掷骰时为 `0` |
| `is_bonus` | 当前是否处于 BONUS 环节 |
| `roller_index` | 本轮掷骰玩家 |
| `last_player_index` | 最近成功出牌的玩家；没有时为 `-1` |
| `target_pattern` | 跟牌时需要盖过的牌型副本；自由出牌时为 `null` |
| `visible_table_cards` | 当前桌面明牌的副本 |

花色不参与牌型比较，但可以用于记忆已经公开过的实体牌。策略若需要长期信息，应只通过 `observe_action()` 自行记录公开动作。

## 决策格式

使用 `PlayerDecision` 的构造函数返回动作：

```gdscript
return PlayerDecision.create_roll()
return PlayerDecision.create_pass()
return PlayerDecision.create_play(card_ids, interpretation_key)
```

出牌时 `card_ids` 必须全部来自 `context.own_hand`。若同一组牌有多种合法解读，`interpretation_key` 必须指定其中一种；可用 `HandEvaluator.get_distinct_interpretations()` 取得候选，再以 `HandEvaluator.beats()` 过滤能盖过目标的解读。BONUS 第一次出牌不能返回 `PASS`。

牌局会再次验证所有决策。非法决策不会改变牌局，当前场景会退回到内置合法动作，防止自定义策略卡死流程；策略作者不应依赖这一兜底。

## 最小示例

```gdscript
class_name CautiousStrategy
extends PlayerStrategy


func get_strategy_id() -> StringName:
	return &"cautious"


func get_display_name_key() -> StringName:
	return &"AI_STRATEGY_CAUTIOUS"


func choose_action(context: StrategyContext) -> PlayerDecision:
	if context.phase == StrategyContext.PHASE_ROLL:
		return PlayerDecision.create_roll()

	var ids: Array[int]
	if context.target_pattern != null:
		ids = LegalMoveFinder.find_play(
			context.own_hand,
			context.target_pattern.card_count,
			context.target_pattern,
		)
	elif context.is_bonus:
		ids = LegalMoveFinder.find_bonus_play(context.own_hand)
	else:
		ids = LegalMoveFinder.find_play(context.own_hand, context.dice_value)

	if ids.is_empty():
		return PlayerDecision.create_pass()
	return PlayerDecision.create_play(ids, "")
```

若选牌可能包含万能牌，示例中的空 `interpretation_key` 应替换为经过筛选的具体牌型键，默认策略展示了完整处理方法。

## 注册策略

将脚本放入 `res://ai/strategies/`，添加翻译键后，在加载游戏前注册：

```gdscript
StrategyRegistry.register_strategy(
	&"cautious",
	preload("res://ai/strategies/cautious.gd"),
)
```

注册函数会实例化脚本并检查它是否继承 `PlayerStrategy`。同一标识再次注册会替换旧实现。当前游戏界面固定创建 `default`，后续策略选择界面只需把所选标识传给 `StrategyRegistry.create()`。

## 验证清单

- 掷骰阶段只返回 `ROLL`。
- 普通首出牌数等于骰子点数。
- 跟牌的牌数与目标相同，且牌型和主体点数确实能盖过目标。
- BONUS 第一次至少出一张合法牌，不返回 `PASS`。
- 所有 `card_id` 均属于自己的当前手牌。
- 多解牌明确返回合法的 `interpretation_key`。
- 只使用上下文和 `observe_action()` 提供的公开信息。
