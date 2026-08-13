extends Node

const STATISTICS_SCRIPT := preload("res://autoload/statistics_service.gd")


func _ready() -> void:
	var service := STATISTICS_SCRIPT.new()
	add_child(service)
	var original := service.get_snapshot()
	service._values = service.DEFAULTS.duplicate()
	var first := service.finish_match({
		"play_actions": 4,
		"cards_played": 10,
		"dice_rolls": 3,
		"bonus_triggers": 1,
	}, true)
	assert(first["games_played"] == 1)
	assert(first["games_won"] == 1)
	assert(first["current_win_streak"] == 1)
	assert(first["best_win_streak"] == 1)
	assert(first["new_streak_record"])
	assert(first["total_cards_played"] == 10)
	var loss := service.finish_match({
		"play_actions": 2,
		"cards_played": 3,
		"dice_rolls": 2,
		"bonus_triggers": 0,
	}, false)
	assert(loss["games_played"] == 2)
	assert(loss["current_win_streak"] == 0)
	assert(loss["best_win_streak"] == 1)
	assert(not loss["new_streak_record"])
	service._values = original
	service._save_statistics()
	assert(not FileAccess.file_exists(service.TEMP_STATISTICS_PATH))
	assert(not FileAccess.file_exists(service.BACKUP_STATISTICS_PATH))
	print("BONUS_TEST_STATISTICS_SERVICE_OK")
	get_tree().quit()
