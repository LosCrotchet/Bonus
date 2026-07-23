class_name CardTextureCatalog
extends RefCounted

const CARD_ROOT := "res://assets/art/cards/"
const SUIT_FILE_NAMES := ["clubs", "diamond", "heart", "spade"]

static var _texture_cache: Dictionary = {}
static var _warmup_requested := false
static var _pending_warmup_paths := PackedStringArray()


static func warm_up() -> void:
	if _warmup_requested:
		return
	_warmup_requested = true
	_request_texture(CARD_ROOT + "card_back_blue.png")
	_request_texture(CARD_ROOT + "card_joker_black.png")
	_request_texture(CARD_ROOT + "card_joker_red.png")
	for suit_name in SUIT_FILE_NAMES:
		for rank in range(1, 14):
			_request_texture("%scard_%s_%d.png" % [CARD_ROOT, suit_name, rank])


static func get_texture(card: CardData) -> Texture2D:
	var path := get_texture_path(card)
	if not _texture_cache.has(path):
		_texture_cache[path] = _load_texture(path)
	return _texture_cache[path]


static func get_card_back() -> Texture2D:
	var path := CARD_ROOT + "card_back_blue.png"
	if not _texture_cache.has(path):
		_texture_cache[path] = _load_texture(path)
	return _texture_cache[path]


static func finish_warm_up() -> void:
	# Initial dealing gives the background requests time to finish. Collect them
	# once so no loader work remains when the scene is later released.
	for path in _pending_warmup_paths:
		var status := ResourceLoader.load_threaded_get_status(path)
		var texture: Texture2D
		if status in [
			ResourceLoader.THREAD_LOAD_IN_PROGRESS,
			ResourceLoader.THREAD_LOAD_LOADED,
		]:
			texture = ResourceLoader.load_threaded_get(path) as Texture2D
		if texture == null:
			texture = load(path) as Texture2D
		if texture != null:
			_texture_cache[path] = texture
	_pending_warmup_paths.clear()


static func _request_texture(path: String) -> void:
	if ResourceLoader.has_cached(path):
		return
	if ResourceLoader.load_threaded_request(path, "Texture2D") == OK:
		_pending_warmup_paths.append(path)


static func _load_texture(path: String) -> Texture2D:
	var status := ResourceLoader.load_threaded_get_status(path)
	if status in [
		ResourceLoader.THREAD_LOAD_IN_PROGRESS,
		ResourceLoader.THREAD_LOAD_LOADED,
	]:
		var texture := ResourceLoader.load_threaded_get(path) as Texture2D
		_pending_warmup_paths.erase(path)
		if texture != null:
			return texture
	return load(path) as Texture2D


static func get_texture_path(card: CardData) -> String:
	if card.joker_kind == CardData.JokerKind.SMALL:
		return CARD_ROOT + "card_joker_black.png"
	if card.joker_kind == CardData.JokerKind.BIG:
		return CARD_ROOT + "card_joker_red.png"

	var suit_names := {
		CardData.Suit.CLUBS: "clubs",
		CardData.Suit.DIAMONDS: "diamond",
		CardData.Suit.HEARTS: "heart",
		CardData.Suit.SPADES: "spade",
	}
	var asset_rank := card.rank
	if card.rank == CardData.Rank.ACE:
		asset_rank = 1
	elif card.rank == CardData.Rank.TWO:
		asset_rank = 2
	return "%scard_%s_%d.png" % [CARD_ROOT, suit_names[card.suit], asset_rank]
