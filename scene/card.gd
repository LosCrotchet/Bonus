extends Node2D

@export var face_position:Vector2i
@export var background_position:Vector2i = Vector2i(1, 0)
@export var is_selected:bool = false
@export var face_enable:bool = true
@export var flip:bool = false

@onready var Face = $Face
@onready var Background = $Background

func _ready():
	Face.region_rect = Rect2(142*face_position.x, 190*face_position.y, 142, 190)
	Background.region_rect = Rect2(142*background_position.x, 190*background_position.y, 142, 190)

func _process(delta):
	Face.flip_h = flip
	Face.visible = face_enable
	Face.region_rect = Rect2(142*face_position.x, 190*face_position.y, 142, 190)
	Background.region_rect = Rect2(142*background_position.x, 190*background_position.y, 142, 190)
