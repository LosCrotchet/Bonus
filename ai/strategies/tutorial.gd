class_name TutorialStrategy
extends DefaultStrategy

var _commands: Array[Dictionary] = []


func get_strategy_id() -> StringName:
	return &"tutorial"


func get_display_name_key() -> StringName:
	return &"AI_STRATEGY_TUTORIAL"


func queue_command(command: Dictionary) -> void:
	_commands.append(command.duplicate(true))


func choose_action(context: StrategyContext) -> PlayerDecision:
	if _commands.is_empty():
		return super.choose_action(context)
	var command := _commands[0]
	var required_phase := StringName(str(command.get("phase", "")))
	if not required_phase.is_empty() and required_phase != context.phase:
		return super.choose_action(context)
	_commands.pop_front()
	match StringName(str(command.get("action", ""))):
		&"roll":
			return PlayerDecision.create_roll()
		&"pass":
			return PlayerDecision.create_pass()
		&"play":
			var card_ids := _resolve_card_ids(command, context.own_hand)
			if not card_ids.is_empty():
				return PlayerDecision.create_play(
					card_ids,
					str(command.get("interpretation_key", "")),
				)
	return super.choose_action(context)


func reset() -> void:
	_commands.clear()


func _resolve_card_ids(command: Dictionary, hand: Array[CardData]) -> Array[int]:
	var requested_ids: Array[int] = []
	for value in command.get("card_ids", []) as Array:
		requested_ids.append(int(value))
	if not requested_ids.is_empty():
		for card_id in requested_ids:
			if not hand.any(func(card: CardData) -> bool: return card.card_id == card_id):
				return []
		return requested_ids

	var available := hand.duplicate()
	for value in command.get("ranks", []) as Array:
		var requested_rank := int(value)
		var match_index := available.find_custom(
			func(card: CardData) -> bool: return card.rank == requested_rank,
		)
		if match_index == -1:
			return []
		requested_ids.append(available[match_index].card_id)
		available.remove_at(match_index)
	return requested_ids
