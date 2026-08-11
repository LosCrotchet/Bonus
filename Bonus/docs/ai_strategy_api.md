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

## 默认策略的决策模型

默认策略不是“找到第一手合法牌就出”。它会先按点数分组枚举所有不同的合法牌组及其合法解读，再以确定性的评分选择动作；相同牌局状态始终得到相同决策。

评分按以下优先关系综合计算：

1. **立即获胜：**能合法打完手牌且不触发万能牌收尾罚摸时，始终优先出完。
2. **残局紧迫度：**任一对手只剩 1～2 张时，策略更愿意拆组或使用大牌夺回牌权；平时则保守处理这些资源。
3. **剩余手牌牌效：**完整保留对子、三条及相邻牌。尤其避免从三张同点数牌中拆出对子、留下难处理的孤张，也避免轻易拆散二连对或潜在顺子。
4. **万能牌成本：**大小王参与普通组合时被视为高价值修正资源；手牌尚多时不会为了普通跟牌轻易消耗。
5. **牌权与反盖风险：**结合牌型主体点数、其他玩家手牌数、摸牌堆规模和已公开大牌，估算更高同型牌或整组炸牌仍在对手手中的可能性。局面不紧迫时倾向用够用的较小牌，紧迫时才提高压制强度。
6. **骰点归属：**当前没有桌面目标、且骰子并非自己投出时，默认策略通常选择 Pass，因为接过上家放弃的骰点并不会天然改善自己的下一轮位置；能直接获胜或必须阻止濒胜对手时例外。
7. **BONUS 整理：**BONUS 必须出牌。策略先寻找不属于对子、三条或连张的真正孤张；没有孤张时，再选择张数较多、破坏较小且较难被盖过的完整牌型。

默认策略只按点数结构枚举代表牌组，不重复计算花色不同但策略价值相同的组合，因此即使手牌因罚摸变多，也不会按实体牌组合产生无意义的指数重复。万能牌的不同合法解读仍会分别评分。

### 公开牌记忆

`observe_action()` 会按实体 `card_id` 记录已确认打出的牌，普通点数每种按两副牌共 8 张估算，大小王每种按 2 张估算。记忆同时供单机 AI、人类自动托管和联机服务器 AI 使用。

弃牌堆回收进摸牌堆时，已打出的牌重新成为未知可摸牌，默认策略会清空“当前不可用牌”计数，再从桌面明牌开始重新记录。恢复旧存档时不会读取其他玩家手牌，也不会从未保存的历史动作反推隐藏信息。

这套模型是启发式牌效策略，不是搜索完整博弈树。关键阈值位于 `default.gd` 顶部及 `_score_move()`、`_should_play()` 中，调整时应同时运行 `tests/unit/test_ai_strategy.gd` 的场景测试和多种固定种子完整牌局。

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
