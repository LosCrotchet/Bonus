extends Node

const SAVE_VERSION := 1
const SAVE_PATH := "user://bonus_save.json"
const TEMP_SAVE_PATH := "user://bonus_save.tmp"
const BACKUP_SAVE_PATH := "user://bonus_save.backup"


func has_unfinished_game() -> bool:
	var payload := load_game()
	if payload.is_empty():
		return false
	var session_snapshot := payload.get("session", {}) as Dictionary
	return int(session_snapshot.get("phase", GameSession.Phase.FINISHED)) != GameSession.Phase.FINISHED


func save_session(session: GameSession, custom_seed: bool = false) -> bool:
	if session == null or session.phase == GameSession.Phase.FINISHED:
		clear_save()
		return false
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"custom_seed": custom_seed,
		"session": session.to_snapshot(),
	}
	var file := FileAccess.open(TEMP_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Unable to open Bonus save file: %s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(payload))
	file.flush()
	file = null
	return _replace_save_file()


func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or json.data is not Dictionary:
		return {}
	var payload := json.data as Dictionary
	if int(payload.get("version", -1)) != SAVE_VERSION:
		return {}
	if payload.get("session", null) is not Dictionary:
		return {}
	return payload


func clear_save() -> void:
	for path in [SAVE_PATH, TEMP_SAVE_PATH, BACKUP_SAVE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _replace_save_file() -> bool:
	if FileAccess.file_exists(BACKUP_SAVE_PATH):
		DirAccess.remove_absolute(BACKUP_SAVE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		var backup_error := DirAccess.rename_absolute(SAVE_PATH, BACKUP_SAVE_PATH)
		if backup_error != OK:
			push_warning("Unable to back up Bonus save file: %s" % error_string(backup_error))
			return false

	var replace_error := DirAccess.rename_absolute(TEMP_SAVE_PATH, SAVE_PATH)
	if replace_error != OK:
		push_warning("Unable to replace Bonus save file: %s" % error_string(replace_error))
		if FileAccess.file_exists(BACKUP_SAVE_PATH):
			DirAccess.rename_absolute(BACKUP_SAVE_PATH, SAVE_PATH)
		return false
	if FileAccess.file_exists(BACKUP_SAVE_PATH):
		DirAccess.remove_absolute(BACKUP_SAVE_PATH)
	return true
