extends Node2D

const BACKGROUND_TINT := Color(0.55, 0.55, 0.6)
const COLOR_MUTED := Color("c9ccff")
const COLOR_OUTLINE := Color("140c1c")

var _selected := 0
var _leaving := false
var _buttons := []


func _ready() -> void:
	# même fond d'herbe assombri que le menu principal
	var background := TextureRect.new()
	background.texture = load("res://src/Levels/LevelTemplate/background.png")
	background.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	background.stretch_mode = TextureRect.STRETCH_TILE
	background.size = Vector2(320, 180)
	background.modulate = BACKGROUND_TINT
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	add_child(build_label("TRAINING", 10, 20, Color.WHITE))
	add_child(build_label("PRACTICE YOUR COMBOS ON A TARGET", 5, 44, COLOR_MUTED))
	for i in range(3):
		var item = load("res://src/UI/menu/menuButton.tscn").instantiate()
		item.title = ["1 PLAYER", "2 PLAYERS", "BACK"][i]
		item.position = Vector2(128, 66 + 27 * i)
		add_child(item)
		item.released.connect(choose.bind(i))
		_buttons.append(item)
	refresh()


func build_label(text_: String, font_size: int, y: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text_
	label.position = Vector2(0, y)
	label.size = Vector2(320, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", Fx.FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	label.add_theme_constant_override("outline_size", 3 if font_size > 5 else 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func refresh() -> void:
	for i in range(_buttons.size()):
		if i == _selected:
			_buttons[i].select()
		else:
			_buttons[i].deselect()


func choose(index: int) -> void:
	if _leaving:
		return
	_leaving = true
	Sound.play("menu_select", 0.0)
	if index == 0 and Game.is_mobile() and Game.isControlsEnabled():
		GlobalPlayer.two_players = false
		PlayerInput.apply()
		Transition.goto("res://src/Levels/Training.tscn")
		return
	Transition.goto(["res://src/UI/training_solo_setup.tscn", "res://src/UI/training_coop_setup.tscn", "res://src/UI/menu.tscn"][index])


func _input(event: InputEvent) -> void:
	if _leaving or event.is_echo():
		return
	if event.is_action_pressed("ui_up"):
		_selected = wrapi(_selected - 1, 0, 3)
	elif Game.isInputNextButton(event):
		_selected = wrapi(_selected + 1, 0, 3)
	elif Game.isInputValidateButton(event):
		choose(_selected)
	elif Game.isInputPauseButton(event):
		choose(2)
	else:
		return
	refresh()
	get_viewport().set_input_as_handled()
