class_name CardTextureCatalog
extends RefCounted

const CARD_ROOT := "res://assets/art/cards/"

static var _texture_cache: Dictionary = {}


static func get_texture(card: CardData) -> Texture2D:
	var path := get_texture_path(card)
	if not _texture_cache.has(path):
		_texture_cache[path] = load(path) as Texture2D
	return _texture_cache[path]


static func get_card_back() -> Texture2D:
	var path := CARD_ROOT + "card_back_blue.png"
	if not _texture_cache.has(path):
		_texture_cache[path] = load(path) as Texture2D
	return _texture_cache[path]


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
