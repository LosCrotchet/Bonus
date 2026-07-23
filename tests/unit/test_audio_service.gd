extends Node


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	for cue in [
		&"ui_hover",
		&"ui_confirm",
		&"ui_fade_in",
		&"card_deal",
		&"card_draw",
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
	assert(not AudioService.has_cue(&"card_select"))
	assert(not AudioService.has_cue(&"card_deselect"))
	assert(not AudioService.has_cue(&"bonus_loop"))
	assert(AudioService.get_bonus_step_count() == 10)

	var catalog := AudioService.get("_cue_streams") as Dictionary
	var hover := catalog[&"ui_hover"] as AudioStreamRandomizer
	var card_deal := catalog[&"card_deal"] as AudioStreamRandomizer
	var card_draw := catalog[&"card_draw"] as AudioStreamRandomizer
	assert(hover.streams_count == 4)
	assert(hover.random_pitch_semitones > 0.0)
	assert(card_deal == card_draw)
	assert(card_deal.streams_count == 3)
	assert(card_deal.random_pitch_semitones > 0.0)
	var dice_land := catalog[&"dice_land"] as AudioStreamRandomizer
	assert(dice_land.streams_count == 4)
	assert(dice_land.get_stream(0).resource_path.ends_with("dice_roll_1.wav"))
	var bonus_steps: Array[AudioStream] = AudioService.get("_bonus_streams")
	assert(
		(bonus_steps[0] as AudioStreamRandomizer)
		.get_stream(0)
		.resource_path
		.ends_with("match_synth_1.wav")
	)
	assert(
		(bonus_steps[9] as AudioStreamRandomizer)
		.get_stream(0)
		.resource_path
		.ends_with("match_synth_10_MAX.wav")
	)

	AudioService.play(&"ui_hover")
	AudioService.play_bonus_step(0)
	AudioService.play_bonus_step(10)
	await AudioService.shutdown()
	print("BONUS_TEST_AUDIO_SERVICE_OK")
	get_tree().quit()
