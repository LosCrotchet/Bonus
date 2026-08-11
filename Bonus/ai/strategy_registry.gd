class_name StrategyRegistry
extends RefCounted

static var _strategy_scripts: Dictionary = {
	&"default": preload("res://ai/strategies/default.gd"),
	&"tutorial": preload("res://ai/strategies/tutorial.gd"),
}


static func register_strategy(strategy_id: StringName, strategy_script: Script) -> bool:
	if strategy_id.is_empty() or strategy_script == null:
		return false
	var instance: Object = strategy_script.new()
	if instance is not PlayerStrategy:
		return false
	_strategy_scripts[strategy_id] = strategy_script
	return true


static func create(strategy_id: StringName = &"default") -> PlayerStrategy:
	var strategy_script := _strategy_scripts.get(strategy_id) as Script
	if strategy_script == null:
		strategy_script = _strategy_scripts[&"default"] as Script
	return strategy_script.new() as PlayerStrategy


static func get_registered_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for strategy_id in _strategy_scripts:
		ids.append(strategy_id)
	ids.sort()
	return ids
