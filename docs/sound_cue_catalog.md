# Bonus 音效需求清单

版本 `0.5.11` 已接入选定音效与场景 BGM。BGM 进入 `Music` 总线并循环播放，主菜单与游戏界面切换时交叉淡入淡出；所有音效进入 `SFX` 总线；同类多素材使用 Godot `AudioStreamRandomizer` 避免连续重复，并按事件加入小范围随机音调和音量变化。高频事件由统一播放器池并发播放并限频。

## 当前 BGM

| 场景 | 文件 | 总线 | 播放方式 |
| --- | --- | --- | --- |
| 主菜单 | `assets/audio/music/menu_music.mp3` | `Music` | 循环播放；进入游戏时淡出 |
| 游戏界面 | `assets/audio/music/game_music.mp3` | `Music` | 循环播放；返回主菜单时淡出 |

## 当前素材映射

| 事件 | 素材与播放规则 |
| --- | --- |
| `ui_hover` | `pop_1`～`pop_4` 随机不连续重复，轻微变调 |
| `ui_confirm` / `ui_cancel` / `ui_invalid` | 对应同名素材；弹出式界面不叠加 confirm |
| `tutorial_confirm` | 教程对话确认；复用 `pop_1`～`pop_4` 随机池并轻微变调 |
| `tutorial_type` | 教程逐字显示；`dot.wav`，每个步骤可设置每 N 个字符播放一次，不设全局冷却并轻微变调 |
| `ui_fade_in` / `ui_fade_out` | 主菜单二级菜单、游戏设置、牌型窗口、万能牌选择窗口及场景转场 |
| `card_deal` / `card_draw` | 共用 `card_draw_1`～`card_draw_3`，按用途调整音量并轻微变调 |
| `card_select` / `card_deselect` | 共用 `card_select`，使用不同音量并随机变调 |
| `card_hover` | 使用 `card_hover`，限频并随机变调 |
| `card_play` | 使用 `card_play`，在牌抵达出牌区时播放并随机变调 |
| `card_reveal` | `card_fan`、`card_fan_2` 随机播放并轻微变调 |
| `dice_shake` | `dice_shake_1`～`dice_shake_3` |
| `dice_land` | `dice_roll_1`～`dice_roll_4` |
| `bonus_trigger` | 使用 `trumpet_cheerful.wav`，每次触发 BONUS 时播放 |
| `pass` / `turn_change` / `round_start` | 对应同名素材 |
| `settings_applied` / `game_win` / `game_lose` | 对应同名素材 |
| `bonus_loop` | 暂不播放，等待后续素材 |

| 编号 | 触发时机 | 建议听感 | 建议时长 | 播放方式与备注 |
| --- | --- | --- | --- | --- |
| `ui_hover` | 鼠标移入可操作按钮 | 很轻、清晰、无明显音高尾巴 | 40～100 ms | 高频触发，音量应低；同一按钮连续移入需限频 |
| `ui_confirm` | 确认、应用、开始游戏 | 短促、肯定、略有明亮上扬 | 100～250 ms | 通用确认音 |
| `ui_cancel` | 取消、返回、关闭窗口 | 柔和下沉，不应带失败感 | 100～250 ms | 通用返回音 |
| `ui_invalid` | 无效出牌、不能过牌等操作 | 克制的阻止提示，不刺耳 | 120～300 ms | 连续误操作需限频 |
| `card_select` | 选中一张手牌 | 轻微纸牌点触声 | 40～120 ms | 建议多变体随机播放 |
| `card_deselect` | 取消选中手牌 | 比选中更轻、更低 | 40～120 ms | 可与选中共用素材并降低音高 |
| `card_deal` | 开局逐张发牌 | 纸牌快速划过桌面的声音 | 60～160 ms | 发牌频率高，必须短且有多个变体；允许按速度轻微变调 |
| `card_draw` | 游戏中摸入一张牌 | 柔和的抽牌、入手声 | 100～220 ms | 多张摸牌可逐张播放或使用专门组合音 |
| `card_play` | 玩家将牌打向出牌区 | 明确的甩牌、落桌声 | 120～300 ms | 手牌飞抵中央时播放 |
| `card_reveal` | 中央牌组从左向右展开 | 连续纸牌展开或扇开声 | 180～450 ms | 根据牌数调整长度，不与 `card_play` 重叠过重 |
| `dice_shake` | 骰子滚动动画期间 | 颗粒清楚的骰子碰撞声 | 300～700 ms | 可循环或使用完整滚动素材 |
| `dice_land` | 骰子点数确定 | 单次清晰落桌声 | 80～220 ms | 与结果出现同步 |
| `turn_change` | 三角锥移动到下一名玩家 | 轻微方向提示或空间移动声 | 80～180 ms | 不应盖过出牌声 |
| `pass` | 玩家选择不出 | 简短、偏中性的提示音 | 100～250 ms | 不使用失败类音效 |
| `bonus_trigger` | BONUS 正式触发 | 鲜明、上扬、有奖励感 | 500～1200 ms | 重要提示音，优先级高 |
| `bonus_loop` | BONUS 环境效果持续期间 | 很轻的流动或闪烁氛围 | 可无缝循环 | 可选；进入和退出需淡入淡出 |
| `wildcard_choice` | 弹出万能牌多解窗口 | 轻微神秘或展开提示 | 150～350 ms | 只在窗口首次出现时播放 |
| `settings_applied` | 设置应用成功 | 轻巧、干净的成功提示 | 120～300 ms | 与绿色反馈文字同步 |
| `round_start` | 新的掷骰回合开始 | 简短的节奏提示 | 150～350 ms | 可选，避免牌局过于嘈杂 |
| `game_win` | 用户获胜 | 完整但不过长的胜利提示 | 1～3 s | 后续可与胜利 BGM 衔接 |
| `game_lose` | AI 玩家率先出完牌 | 平静收束，不使用强烈惩罚感 | 1～2 s | 避免给新手过强负反馈 |

选材时优先保证 `card_deal`、`card_play`、`dice_shake`、`dice_land`、`ui_hover`、`ui_confirm` 和 `bonus_trigger`，这些声音覆盖当前最主要的交互反馈。
