extends Node

const STATISTICS_PATH := "user://bonus_statistics.cfg"
const TEMP_STATISTICS_PATH := "user://bonus_statistics.tmp"
const BACKUP_STATISTICS_PATH := "user://bonus_statistics.backup"

const DEFAULTS := {
	"games_played": 0,
	"games_won": 0,
	"current_win_streak": 0,
	"best_win_streak": 0,
	"total_play_actions": 0,
	"total_cards_played": 0,
	"total_dice_rolls": 0,
	"total_bonus_triggers": 0,
}

var _values: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	_load_statistics()


func get_snapshot() -> Dictionary:
	return _values.duplicate(true)


func finish_match(match_stats: Dictionary, won: bool) -> Dictionary:
	var previous_best := int(_values["best_win_streak"])
	_values["games_played"] = int(_values["games_played"]) + 1
	_values["games_won"] = int(_values["games_won"]) + (1 if won else 0)
	_values["current_win_streak"] = (
		int(_values["current_win_streak"]) + 1 if won else 0
	)
	_values["best_win_streak"] = maxi(
		previous_best,
		int(_values["current_win_streak"]),
	)
	_values["total_play_actions"] = (
		int(_values["total_play_actions"])
		+ int(match_stats.get("play_actions", 0))
	)
	_values["total_cards_played"] = (
		int(_values["total_cards_played"])
		+ int(match_stats.get("cards_played", 0))
	)
	_values["total_dice_rolls"] = (
		int(_values["total_dice_rolls"])
		+ int(match_stats.get("dice_rolls", 0))
	)
	_values["total_bonus_triggers"] = (
		int(_values["total_bonus_triggers"])
		+ int(match_stats.get("bonus_triggers", 0))
	)
	_save_statistics()
	var result := get_snapshot()
	result["new_streak_record"] = (
		won
		and int(_values["current_win_streak"]) > previous_best
	)
	return result


func _load_statistics() -> void:
	var config := ConfigFile.new()
	if config.load(STATISTICS_PATH) != OK:
		if config.load(BACKUP_STATISTICS_PATH) != OK:
			return
	for key in DEFAULTS:
		_values[key] = maxi(0, int(config.get_value("statistics", key, DEFAULTS[key])))


func _save_statistics() -> void:
	var config := ConfigFile.new()
	for key in DEFAULTS:
		config.set_value("statistics", key, _values[key])
	var error := config.save(TEMP_STATISTICS_PATH)
	if error != OK:
		push_warning("Unable to save Bonus statistics: %s" % error_string(error))
		return
	if FileAccess.file_exists(BACKUP_STATISTICS_PATH):
		DirAccess.remove_absolute(BACKUP_STATISTICS_PATH)
	if FileAccess.file_exists(STATISTICS_PATH):
		var backup_error := DirAccess.rename_absolute(
			STATISTICS_PATH,
			BACKUP_STATISTICS_PATH,
		)
		if backup_error != OK:
			push_warning("Unable to back up Bonus statistics: %s" % error_string(backup_error))
			return
	var rename_error := DirAccess.rename_absolute(TEMP_STATISTICS_PATH, STATISTICS_PATH)
	if rename_error != OK:
		push_warning("Unable to install Bonus statistics: %s" % error_string(rename_error))
		if FileAccess.file_exists(BACKUP_STATISTICS_PATH):
			DirAccess.rename_absolute(BACKUP_STATISTICS_PATH, STATISTICS_PATH)
		return
	if FileAccess.file_exists(BACKUP_STATISTICS_PATH):
		DirAccess.remove_absolute(BACKUP_STATISTICS_PATH)
