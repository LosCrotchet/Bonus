class_name StatisticsPanel
extends PanelContainer

signal close_requested

@onready var games_value: Label = %GamesValue
@onready var wins_value: Label = %WinsValue
@onready var win_rate_value: Label = %WinRateValue
@onready var streak_value: Label = %StreakValue
@onready var best_streak_value: Label = %BestStreakValue
@onready var plays_value: Label = %PlaysValue
@onready var dice_value: Label = %DiceValue
@onready var bonus_value: Label = %BonusValue
@onready var average_value: Label = %AverageValue


func _ready() -> void:
	%BackButton.pressed.connect(func() -> void: close_requested.emit())


func refresh() -> void:
	var stats := StatisticsService.get_snapshot()
	var games := int(stats.get("games_played", 0))
	var wins := int(stats.get("games_won", 0))
	var play_actions := int(stats.get("total_play_actions", 0))
	var cards_played := int(stats.get("total_cards_played", 0))
	games_value.text = str(games)
	wins_value.text = str(wins)
	win_rate_value.text = "%.1f%%" % (float(wins) / float(games) * 100.0 if games > 0 else 0.0)
	streak_value.text = str(stats.get("current_win_streak", 0))
	best_streak_value.text = str(stats.get("best_win_streak", 0))
	plays_value.text = str(play_actions)
	dice_value.text = str(stats.get("total_dice_rolls", 0))
	bonus_value.text = str(stats.get("total_bonus_triggers", 0))
	average_value.text = "%.2f" % (
		float(cards_played) / float(play_actions) if play_actions > 0 else 0.0
	)
