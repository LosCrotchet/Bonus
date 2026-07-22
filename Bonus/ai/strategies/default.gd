class_name DefaultStrategy
extends PlayerStrategy


func get_strategy_id() -> StringName:
	return &"default"


func get_display_name_key() -> StringName:
	return &"AI_STRATEGY_DEFAULT"


func choose_action(context: StrategyContext) -> PlayerDecision:
	if context.phase == StrategyContext.PHASE_ROLL:
		return PlayerDecision.create_roll()

	var card_ids: Array[int]
	if context.target_pattern != null:
		card_ids = LegalMoveFinder.find_play(
			context.own_hand,
			context.target_pattern.card_count,
			context.target_pattern,
			context.rules,
		)
	elif context.is_bonus:
		card_ids = LegalMoveFinder.find_bonus_play(context.own_hand, context.rules)
	else:
		card_ids = LegalMoveFinder.find_play(
			context.own_hand,
			context.dice_value,
			null,
			context.rules,
		)

	if card_ids.is_empty():
		return PlayerDecision.create_pass()

	var selected_cards := _find_cards(context.own_hand, card_ids)
	var interpretations := HandEvaluator.get_distinct_interpretations(
		selected_cards,
		context.rules,
	)
	if context.target_pattern != null:
		interpretations = interpretations.filter(
			func(pattern: HandPattern) -> bool:
				return HandEvaluator.beats(pattern, context.target_pattern)
		)
	var interpretation_key := interpretations[0].get_key() if not interpretations.is_empty() else ""
	return PlayerDecision.create_play(card_ids, interpretation_key)


func _find_cards(hand: Array[CardData], card_ids: Array[int]) -> Array[CardData]:
	var cards: Array[CardData] = []
	for card in hand:
		if card_ids.has(card.card_id):
			cards.append(card)
	return cards
