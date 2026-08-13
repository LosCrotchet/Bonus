extends Node


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	for cue in [
		&"ui_hover",
		&"ui_confirm",
		&"tutorial_confirm",
		&"tutorial_type",
		&"ui_fade_in",
		&"card_deal",
		&"card_draw",
		&"card_select",
		&"card_deselect",
		&"card_hover",
		&"card_play",
		&"card_reveal",
		&"dice_shake",
		&"dice_land",
		&"turn_change",
		&"pass",
		&"round_start",
		&"game_win",
		&"game_lose",
	]:
		assert(AudioService.has_cue(cue), "Missing audio cue: %s" % cue)
	assert(not AudioService.has_cue(&"bonus_loop"))
	assert(AudioService.get_bonus_step_count() == 1)
	assert(AudioService.has_music(&"menu"))
	assert(AudioService.has_music(&"game"))
	var music_catalog := AudioService.get("_music_streams") as Dictionary
	assert((music_catalog[&"menu"] as AudioStream).resource_path.ends_with("menu_music.mp3"))
	assert((music_catalog[&"game"] as AudioStream).resource_path.ends_with("game_music.mp3"))
	assert((music_catalog[&"menu"] as AudioStreamMP3).loop)
	assert((music_catalog[&"game"] as AudioStreamMP3).loop)

	var catalog := AudioService.get("_cue_streams") as Dictionary
	var hover := catalog[&"ui_hover"] as AudioStreamRandomizer
	var tutorial_confirm := catalog[&"tutorial_confirm"] as AudioStreamRandomizer
	var tutorial_type := catalog[&"tutorial_type"] as AudioStreamRandomizer
	var card_deal := catalog[&"card_deal"] as AudioStreamRandomizer
	var card_draw := catalog[&"card_draw"] as AudioStreamRandomizer
	assert(hover.streams_count == 1)
	assert(hover.random_pitch_semitones > 0.0)
	assert(hover.get_stream(0).resource_path.ends_with("new_hover.ogg"))
	assert(tutorial_confirm != hover)
	assert(tutorial_confirm.streams_count == 4)
	assert(tutorial_type.streams_count == 1)
	assert(tutorial_type.random_pitch_semitones > 0.0)
	assert(tutorial_type.get_stream(0).resource_path.ends_with("dot.ogg"))
	var cooldowns := AudioService.get("_cue_cooldowns_ms") as Dictionary
	assert(not cooldowns.has(&"tutorial_type"))
	var cue_volumes := AudioService.get("_cue_volume_db") as Dictionary
	for cue in catalog:
		var expected_volume := 0.6 if cue == &"ui_hover" else 0.75
		assert(
			is_equal_approx(db_to_linear(float(cue_volumes[cue])), expected_volume),
			"Unexpected volume for audio cue: %s" % cue,
		)
	var settings_constants := (SettingsService.get_script() as Script).get_script_constant_map()
	assert(is_equal_approx(float(settings_constants["DEFAULT_SFX_VOLUME"]), 0.7))
	assert(card_deal == card_draw)
	assert(card_deal.streams_count == 3)
	assert(card_deal.random_pitch_semitones > 0.0)
	var card_select := catalog[&"card_select"] as AudioStreamRandomizer
	var card_deselect := catalog[&"card_deselect"] as AudioStreamRandomizer
	assert(card_select == card_deselect)
	assert(card_select.random_pitch_semitones > 0.0)
	var card_hover := catalog[&"card_hover"] as AudioStreamRandomizer
	assert(card_hover.get_stream(0).resource_path.ends_with("card_hover.ogg"))
	assert(card_hover.random_pitch_semitones > 0.0)
	var card_play := catalog[&"card_play"] as AudioStreamRandomizer
	assert(card_play.get_stream(0).resource_path.ends_with("card_play.ogg"))
	assert(card_play.random_pitch_semitones > 0.0)
	var dice_land := catalog[&"dice_land"] as AudioStreamRandomizer
	assert(dice_land.streams_count == 4)
	assert(dice_land.get_stream(0).resource_path.ends_with("dice_roll_1.ogg"))
	var bonus_steps: Array[AudioStream] = AudioService.get("_bonus_streams")
	assert(
		(bonus_steps[0] as AudioStreamRandomizer)
		.get_stream(0)
		.resource_path
		.ends_with("trumpet_cheerful.ogg")
	)

	AudioService.play(&"ui_hover")
	AudioService.play_bonus_step(0)
	AudioService.play_bonus_step(10)
	AudioService.stop_music()
	AudioService.play_music(&"menu", 0.05)
	await get_tree().create_timer(0.12).timeout
	var music_players: Array[AudioStreamPlayer] = AudioService.get("_music_players")
	var active_index := int(AudioService.get("_music_active_index"))
	assert(music_players[active_index].playing)
	assert(is_zero_approx(music_players[active_index].volume_db))
	AudioService.play_music(&"game", 0.05)
	await get_tree().create_timer(0.12).timeout
	active_index = int(AudioService.get("_music_active_index"))
	assert(music_players[active_index].playing)
	assert(is_zero_approx(music_players[active_index].volume_db))
	assert(not music_players[1 - active_index].playing)
	await AudioService.shutdown()
	print("BONUS_TEST_AUDIO_SERVICE_OK")
	get_tree().quit()
