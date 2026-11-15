extends "res://src/UI/TrainingSelect.gd"

var _level := 1


func _ready() -> void:
	if OS.get_environment("DEBUG") != "1":
		_leaving = true
		Transition.goto.call_deferred("res://src/UI/menu.tscn")
		return
	var background := TextureRect.new()
	background.texture = load("res://src/Levels/LevelTemplate/background.png")
	background.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	background.stretch_mode = TextureRect.STRETCH_TILE
	background.size = Vector2(320, 180)
	background.modulate = BACKGROUND_TINT
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	add_child(build_label("DEBUG", 10, 12, Color.WHITE))
	for i in range(4):
		var item = preload("res://src/UI/menu/menuButton.tscn").instantiate()
		item.title = ["LEVEL 01", "PLAY LEVEL", "PLAY BONUS", "BACK"][i]
		item.position = [Vector2(84, 55), Vector2(172, 55), Vector2(128, 85), Vector2(128, 115)][i]
		add_child(item)
		item.released.connect(choose.bind(i))
		_buttons.append(item)
	add_child(build_label("LEFT / RIGHT: LEVEL   |   CLICK LEVEL: +1", 5, 150, COLOR_MUTED))
	refresh()


func change_level(delta: int) -> void:
	_level = maxi(1, _level + delta)
	_buttons[0].title = "LEVEL %02d" % _level
	_buttons[0]._fit_label()
	Sound.play("menu_move", 0.0)


func choose(index: int) -> void:
	if _leaving or OS.get_environment("DEBUG") != "1":
		return
	if index == 0:
		change_level(1)
		return
	_leaving = true
	Sound.play("menu_select", 0.0)
	if index == 3:
		Transition.goto("res://src/UI/menu.tscn")
		return
	GlobalPlayer.reset_game()
	# Mode debug : toutes les armes disponibles dès le départ
	GlobalPlayer.owned_weapons = [GlobalPlayer.WEAPONS.duplicate(), GlobalPlayer.WEAPONS.duplicate()]
	GlobalPlayer.two_players = false
	GlobalPlayer.set_level(_level)
	PlayerInput.apply()
	Transition.goto("res://src/Levels/LevelBonus.tscn" if index == 2 else "res://src/Levels/LevelTemplate.tscn")


func _input(event: InputEvent) -> void:
	if _leaving or event.is_echo():
		return
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		change_level(-1)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		change_level(1)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		_selected = wrapi(_selected - 1, 0, _buttons.size())
	elif Game.isInputNextButton(event):
		_selected = wrapi(_selected + 1, 0, _buttons.size())
	elif Game.isInputValidateButton(event):
		choose(_selected)
	elif Game.isInputPauseButton(event):
		choose(3)
	else:
		return
	refresh()
	get_viewport().set_input_as_handled()
