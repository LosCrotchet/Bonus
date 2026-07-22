extends Node


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var original := SettingsService.get_snapshot()
	await _wait_frames(3)

	var windowed := original.duplicate(true)
	windowed["window_mode"] = SettingsService.WindowMode.WINDOWED
	windowed["resolution"] = Vector2i(1280, 720)
	assert(SettingsService.apply_settings(windowed))
	await _wait_frames(4)
	var windowed_ok := get_window().mode == Window.MODE_WINDOWED
	var first_size_ok := get_window().size == Vector2i(1280, 720)

	windowed["resolution"] = Vector2i(1440, 1080)
	assert(SettingsService.apply_settings(windowed))
	await _wait_frames(4)
	var resized_ok := get_window().size == Vector2i(1440, 1080)

	var fullscreen := windowed.duplicate(true)
	fullscreen["window_mode"] = SettingsService.WindowMode.FULLSCREEN
	assert(SettingsService.apply_settings(fullscreen))
	await _wait_frames(4)
	var fullscreen_ok := get_window().mode in [
		Window.MODE_FULLSCREEN,
		Window.MODE_EXCLUSIVE_FULLSCREEN,
	]

	SettingsService.apply_settings(original)
	await _wait_frames(4)
	assert(windowed_ok)
	assert(first_size_ok)
	assert(resized_ok)
	assert(fullscreen_ok)
	print("BONUS_TEST_DISPLAY_SETTINGS_OK")
	get_tree().quit()


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame
