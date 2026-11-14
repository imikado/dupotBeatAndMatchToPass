extends TouchScreenButton

const ButtonStyle = preload("res://src/Common/UI/MenuButtonStyle.gd")
const LABEL_COLOR_NORMAL = ButtonStyle.TEXT
const LABEL_COLOR_SELECTED = ButtonStyle.GOLD
const TEXTURE_SELECTED = ButtonStyle.SELECTED

@export var title="text"
@onready var _label=$Label

@onready var _lifeBottle=$lifeBottle
@onready var _texture_normal: Texture2D = texture_normal

func _ready() -> void:
	_lifeBottle.visible = false
	_fit_label()
	_label.add_theme_color_override("font_color", LABEL_COLOR_NORMAL)
	pass

func select()->void:
	_lifeBottle.visible=true
	_lifeBottle.play()
	_label.add_theme_color_override("font_color", LABEL_COLOR_SELECTED)
	texture_normal=TEXTURE_SELECTED
	pass
	
func deselect()->void:
	_lifeBottle.visible=false
	_lifeBottle.stop()
	_label.add_theme_color_override("font_color", LABEL_COLOR_NORMAL)
	texture_normal=_texture_normal
	pass


func _fit_label() -> void:
	ButtonStyle.fit_label(_label, title, texture_normal.get_size())
