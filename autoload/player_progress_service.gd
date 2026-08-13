extends Node

const PROGRESS_PATH := "user://bonus_progress.cfg"

var tutorial_opened := false


func _ready() -> void:
	_load_progress()


func mark_tutorial_opened() -> void:
	if tutorial_opened:
		return
	tutorial_opened = true
	_save_progress()


func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(PROGRESS_PATH) != OK:
		return
	tutorial_opened = bool(config.get_value("progress", "tutorial_opened", false))


func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "tutorial_opened", tutorial_opened)
	var error := config.save(PROGRESS_PATH)
	if error != OK:
		push_warning("Unable to save Bonus player progress: %s" % error_string(error))
