extends Node

const PROGRESS_SCRIPT := preload("res://autoload/player_progress_service.gd")


func _ready() -> void:
	var service := PROGRESS_SCRIPT.new()
	add_child(service)
	var original_opened := service.tutorial_opened
	service.tutorial_opened = false
	service.mark_tutorial_opened()
	assert(service.tutorial_opened)
	var config := ConfigFile.new()
	assert(config.load(service.PROGRESS_PATH) == OK)
	assert(bool(config.get_value("progress", "tutorial_opened", false)))
	service.tutorial_opened = original_opened
	if original_opened:
		service.call("_save_progress")
	else:
		DirAccess.remove_absolute(service.PROGRESS_PATH)
	print("BONUS_TEST_PLAYER_PROGRESS_OK")
	get_tree().quit()
