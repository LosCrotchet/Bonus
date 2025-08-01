extends AudioStreamPlayer2D

@onready var button_sound = preload("res://assets/sound/button.ogg")
@onready var cancel_sound = preload("res://assets/sound/cancel.ogg")
@onready var card_1 = preload("res://assets/sound/card1.ogg")
@onready var card_fan_2 = preload("res://assets/sound/cardFan2.ogg")
@onready var card_3 = preload("res://assets/sound/card3.ogg")
@onready var card_slide_1 = preload("res://assets/sound/cardSlide1.ogg")
@onready var card_slide_2 = preload("res://assets/sound/cardSlide2.ogg")
@onready var generic_1 = preload("res://assets/sound/generic1.ogg")
@onready var other_1 = preload("res://assets/sound/other1.ogg")
@onready var win_sound = preload("res://assets/sound/win.ogg")

func _on_button_pressed():
	stream = button_sound
	stream.loop = false
	play()

func _on_player_manager_player_dice_roll():
	stream = other_1
	stream.loop = false
	play()

func _on_dice_dice_timeout(result):
	stream = other_1
	stream.loop = false
	play()
