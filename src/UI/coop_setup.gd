extends Node2D

# Écran des contrôles, avant la partie : coop_setup.tscn (2 joueurs) et
# solo_setup.tscn (1 joueur, two_players = false, configuration PlayerInput.SOLO).
# Chaque joueur choisit clavier ou manette ; au clavier, les touches partent d'un
# préréglage AZERTY / QWERTY et se redéfinissent une par une.
# Haut / bas : ligne, gauche / droite : joueur (ou disposition du clavier),
# Entrée / A : changer, Échap / B : retour au menu.
# En bas, le ou les héros sur un bout de sol : TEST les rend jouables pour essayer
# les touches (Échap / Start : fin de l'essai).

@export var two_players := true

const LEVEL_SCENE := "res://src/Levels/LevelTemplate.tscn"
const MENU_SCENE := "res://src/UI/menu.tscn"

const COLOR_SELECTED := Color("ffd34d")
const COLOR_NORMAL := Color(1, 1, 1, 0.85)
const COLOR_DIM := Color(1, 1, 1, 0.45)
const COLOR_ERROR := Color("ff4d4d")
const COLOR_HIGHLIGHT := Color(1.0, 0.83, 0.3, 0.22)

const ROW_LAYOUT := 0
const ROW_DEVICE := 1
const ROW_FIRST_KEY := 2
const ROW_START := ROW_FIRST_KEY + 7
const ROW_TEST := ROW_START + 1
const ROW_BACK := ROW_TEST + 1

# Écran compact : le bas (ControlsTestArea) est réservé aux héros
const COLUMN_X := [20.0, 166.0]
const COLUMN_X_SOLO := 93.0
const COLUMN_WIDTH := 134.0
const ROW_HEIGHT := 8.0
const HIGHLIGHT_OFFSET_Y := 7.5
const Y_TITLE := -5.0
const Y_LAYOUT := 9.0
const Y_HEADER := 17.0
const Y_DEVICE := 25.0
const Y_FIRST_KEY := 33.0
const Y_PAD_NAME := 89.0
const Y_MESSAGE := 97.0
const Y_BUTTONS := 106.0
const PANEL_RECT := Rect2(10, 2, 300, 124)
# START, TEST, BACK sur la même ligne
const BUTTON_X := {ROW_START: 70.0, ROW_TEST: 135.0, ROW_BACK: 200.0}
const BUTTON_WIDTH := 50.0

var _row := ROW_DEVICE
var _col := 0
var _capturing := false
var _leaving := false

var _root: Control
var _highlight: ColorRect
var _layout_label: Label
# [colonne] -> {row: Label} (libellés de valeur) et noms des actions
var _values := [{}, {}]
var _names := [{}, {}]
var _pad_labels := []
var _message: Label
var _buttons := {}
var _message_tween: Tween
var _test_area: ControlsTestArea
# configurations PlayerInput affichées, une par colonne
var _indices: Array


func _ready() -> void:
	_indices = PlayerInput.indices(two_players)
	# actions des héros de la zone d'essai
	PlayerInput.apply()
	_test_area = ControlsTestArea.new()
	add_child(_test_area)
	_test_area.setup(two_players, get_node("Camera2D"))
	build_ui()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	refresh()


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	refresh()


func build_label(text_: String, font_size: int, position_: Vector2, width: float, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text_
	label.add_theme_font_override("font", Fx.FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", COLOR_NORMAL)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = position_
	label.size = Vector2(width, ROW_HEIGHT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)
	return label


# Clic / toucher : sélectionne la ligne puis la change
func clickable(label: Label, row: int, col: int) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _capturing:
			_row = row
			_col = col
			activate()
	)


func build_ui() -> void:
	# calque à part : l'orage de la zone d'essai n'assombrit pas le texte
	var layer := CanvasLayer.new()
	add_child(layer)
	_root = Control.new()
	_root.size = Vector2(320, 180)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_root)

	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0.05, 0.78)
	panel.position = PANEL_RECT.position
	panel.size = PANEL_RECT.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)

	_highlight = ColorRect.new()
	_highlight.color = COLOR_HIGHLIGHT
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_highlight)

	var title := build_label("2 PLAYERS" if two_players else "1 PLAYER", 10, Vector2(0, Y_TITLE), 320, HORIZONTAL_ALIGNMENT_CENTER)
	title.size.y = 14
	title.add_theme_color_override("font_color", Color("7fdbff"))

	_layout_label = build_label("", 5, Vector2(0, Y_LAYOUT), 320, HORIZONTAL_ALIGNMENT_CENTER)
	clickable(_layout_label, ROW_LAYOUT, 0)

	for col in range(_indices.size()):
		var x := column_x(col)
		# en solo, la colonne n'a pas besoin d'en-tête
		var header := build_label("PLAYER %d" % (col + 1) if two_players else "", 5, Vector2(x, Y_HEADER), COLUMN_WIDTH, HORIZONTAL_ALIGNMENT_CENTER)
		header.add_theme_color_override("font_color", Player.COOP_COLORS[col])

		_names[col][ROW_DEVICE] = build_label("CONTROL", 5, Vector2(x + 4, Y_DEVICE), 60)
		_values[col][ROW_DEVICE] = build_label("", 5, Vector2(x + 50, Y_DEVICE), COLUMN_WIDTH - 54, HORIZONTAL_ALIGNMENT_RIGHT)
		clickable(_values[col][ROW_DEVICE], ROW_DEVICE, col)

		for i in range(PlayerInput.ACTIONS.size()):
			var row := ROW_FIRST_KEY + i
			var y := Y_FIRST_KEY + ROW_HEIGHT * i
			_names[col][row] = build_label(PlayerInput.ACTION_LABELS[PlayerInput.ACTIONS[i]], 5, Vector2(x + 4, y), 60)
			_values[col][row] = build_label("", 5, Vector2(x + 50, y), COLUMN_WIDTH - 54, HORIZONTAL_ALIGNMENT_RIGHT)
			clickable(_values[col][row], row, col)

		var pad := build_label("", 5, Vector2(x, Y_PAD_NAME), COLUMN_WIDTH, HORIZONTAL_ALIGNMENT_CENTER)
		pad.add_theme_color_override("font_color", COLOR_DIM)
		pad.clip_text = true
		_pad_labels.append(pad)

	_message = build_label("", 5, Vector2(0, Y_MESSAGE), 320, HORIZONTAL_ALIGNMENT_CENTER)
	for row in BUTTON_X:
		var text: String = {ROW_START: "START", ROW_TEST: "TEST", ROW_BACK: "BACK"}[row]
		_buttons[row] = build_label(text, 5, Vector2(BUTTON_X[row], Y_BUTTONS), BUTTON_WIDTH, HORIZONTAL_ALIGNMENT_CENTER)
		clickable(_buttons[row], row, 0)


# configuration PlayerInput de la colonne
func idx(col: int) -> int:
	return _indices[col]


func column_x(col: int) -> float:
	return COLUMN_X[col] if two_players else COLUMN_X_SOLO


func is_keyboard(col: int) -> bool:
	return PlayerInput.players[idx(col)]["device"] == PlayerInput.Device.KEYBOARD


func any_keyboard() -> bool:
	for col in range(_indices.size()):
		if is_keyboard(col):
			return true
	return false


func selectable_rows() -> Array:
	var rows := []
	if any_keyboard():
		rows.append(ROW_LAYOUT)
	rows.append(ROW_DEVICE)
	for i in range(PlayerInput.ACTIONS.size()):
		if PlayerInput.is_remappable(idx(_col), PlayerInput.ACTIONS[i]):
			rows.append(ROW_FIRST_KEY + i)
	rows.append(ROW_START)
	rows.append(ROW_TEST)
	rows.append(ROW_BACK)
	return rows


func refresh() -> void:
	if not selectable_rows().has(_row):
		_row = ROW_DEVICE

	_layout_label.visible = any_keyboard()
	_layout_label.text = "KEYBOARD   < " + PlayerInput.layout.to_upper() + " >"
	set_color(_layout_label, _row == ROW_LAYOUT)

	var conflicts := PlayerInput.conflicting_keys(_indices)
	for col in range(_indices.size()):
		var keyboard := is_keyboard(col)
		var button_conflicts := PlayerInput.conflicting_buttons(idx(col))
		var device_text := "< KEYBOARD >" if keyboard else "< GAMEPAD >"
		_values[col][ROW_DEVICE].text = device_text
		set_color(_values[col][ROW_DEVICE], _row == ROW_DEVICE and _col == col)

		for i in range(PlayerInput.ACTIONS.size()):
			var row := ROW_FIRST_KEY + i
			var action: String = PlayerInput.ACTIONS[i]
			var label: Label = _values[col][row]
			var selected := _row == row and _col == col
			if selected and _capturing:
				label.text = "PRESS A KEY" if keyboard else "PRESS A BUTTON"
			else:
				label.text = PlayerInput.action_label(idx(col), action)
			var editable := PlayerInput.is_remappable(idx(col), action)
			var error := conflicts.has(PlayerInput.players[idx(col)]["keys"][action]) if keyboard else button_conflicts.has(action)
			set_color(label, selected, COLOR_ERROR if error else (COLOR_NORMAL if editable else COLOR_DIM))
			_names[col][row].add_theme_color_override("font_color", COLOR_NORMAL if editable else COLOR_DIM)

		if keyboard:
			_pad_labels[col].text = ""
		else:
			var pad_name := PlayerInput.gamepad_name(idx(col))
			_pad_labels[col].text = pad_name if pad_name != "" else "NO GAMEPAD"
			_pad_labels[col].add_theme_color_override("font_color", COLOR_DIM if pad_name != "" else COLOR_ERROR)

	var error_text := PlayerInput.validation_error(_indices)
	if _test_area.is_testing():
		_message.text = "TRY YOUR CONTROLS  -  ESC / START: STOP"
		_message.add_theme_color_override("font_color", COLOR_SELECTED)
	elif _capturing:
		_message.text = "PRESS A KEY  -  ESC: CANCEL" if is_keyboard(_col) else "PRESS A BUTTON  -  START: CANCEL"
		_message.add_theme_color_override("font_color", COLOR_SELECTED)
	elif error_text != "":
		_message.text = error_text
		_message.add_theme_color_override("font_color", COLOR_ERROR)
	else:
		_message.text = "ENTER: CHANGE   ESC: BACK"
		_message.add_theme_color_override("font_color", COLOR_DIM)

	set_color(_buttons[ROW_START], _row == ROW_START, COLOR_NORMAL if error_text == "" else COLOR_DIM)
	set_color(_buttons[ROW_TEST], _row == ROW_TEST)
	set_color(_buttons[ROW_BACK], _row == ROW_BACK)
	place_highlight()


func set_color(label: Label, selected: bool, normal := COLOR_NORMAL) -> void:
	label.add_theme_color_override("font_color", COLOR_SELECTED if selected else normal)


func place_highlight() -> void:
	var rect := Rect2()
	match _row:
		ROW_LAYOUT:
			rect = Rect2(90, Y_LAYOUT, 140, ROW_HEIGHT)
		ROW_START, ROW_TEST, ROW_BACK:
			rect = Rect2(BUTTON_X[_row], Y_BUTTONS, BUTTON_WIDTH, ROW_HEIGHT)
		_:
			var y: float = Y_DEVICE if _row == ROW_DEVICE else Y_FIRST_KEY + ROW_HEIGHT * (_row - ROW_FIRST_KEY)
			rect = Rect2(column_x(_col), y, COLUMN_WIDTH, ROW_HEIGHT)
	# le Label est plus haut que ROW_HEIGHT (ligne de la police Pixeled) : texte plus bas
	rect.position.y += HIGHLIGHT_OFFSET_Y
	_highlight.position = rect.position
	_highlight.size = rect.size


func _input(event: InputEvent) -> void:
	if _leaving:
		return
	# essai : les touches vont aux héros, seuls Échap / Start arrêtent
	if _test_area.is_testing():
		if Game.isInputPauseButton(event):
			stop_test()
			get_viewport().set_input_as_handled()
		return
	if _capturing:
		capture(event)
		return

	if event.is_action_pressed("ui_up"):
		move(-1)
	elif event.is_action_pressed("ui_down"):
		move(1)
	elif event.is_action_pressed("ui_left"):
		horizontal(-1)
	elif event.is_action_pressed("ui_right"):
		horizontal(1)
	elif event.is_action_pressed("ui_cancel"):
		leave(MENU_SCENE)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("attack"):
		activate()
	else:
		return
	get_viewport().set_input_as_handled()


func capture(event: InputEvent) -> void:
	if not is_keyboard(_col):
		capture_button(event)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode != KEY_ESCAPE:
			var keycode: int = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
			PlayerInput.set_key(idx(_col), PlayerInput.ACTIONS[_row - ROW_FIRST_KEY], keycode)
			Sound.play("menu_select", 0.0)
		_capturing = false
		refresh()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		_capturing = false
		refresh()
		get_viewport().set_input_as_handled()


# Manette : seuls les boutons de la manette du joueur comptent ; Start / Select ou Échap annulent
func capture_button(event: InputEvent) -> void:
	var cancel: bool = event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE
	if event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_START, JOY_BUTTON_BACK]:
		cancel = true
	if not cancel:
		if event.device != PlayerInput.gamepad_for(idx(_col)) or not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
			return
		var button := PlayerInput.button_from_event(event)
		if button < 0:
			return
		PlayerInput.set_button(idx(_col), PlayerInput.ACTIONS[_row - ROW_FIRST_KEY], button)
		Sound.play("menu_select", 0.0)
	_capturing = false
	refresh()
	get_viewport().set_input_as_handled()


func move(direction: int) -> void:
	var rows := selectable_rows()
	var index := rows.find(_row)
	_row = rows[wrapi(index + direction, 0, rows.size())]
	Sound.play("menu_move", 0.0)
	refresh()


func horizontal(direction: int) -> void:
	if _row == ROW_LAYOUT:
		cycle_layout(direction)
		return
	if BUTTON_X.has(_row):
		var rows: Array = BUTTON_X.keys()
		_row = rows[wrapi(rows.find(_row) + direction, 0, rows.size())]
		Sound.play("menu_move", 0.0)
		refresh()
		return
	_col = wrapi(_col + direction, 0, _indices.size())
	Sound.play("menu_move", 0.0)
	refresh()


func cycle_layout(direction: int) -> void:
	var index := PlayerInput.LAYOUTS.find(PlayerInput.layout)
	PlayerInput.set_layout(PlayerInput.LAYOUTS[wrapi(index + direction, 0, PlayerInput.LAYOUTS.size())])
	Sound.play("menu_move", 0.0)
	refresh()


func activate() -> void:
	match _row:
		ROW_LAYOUT:
			cycle_layout(1)
		ROW_DEVICE:
			var device: int = PlayerInput.Device.GAMEPAD if is_keyboard(_col) else PlayerInput.Device.KEYBOARD
			PlayerInput.set_device(idx(_col), device)
			Sound.play("menu_move", 0.0)
			refresh()
		ROW_START:
			start_game()
		ROW_TEST:
			if _test_area.is_testing():
				stop_test()
			else:
				start_test()
		ROW_BACK:
			leave(MENU_SCENE)
		_:
			if is_keyboard(_col) or PlayerInput.gamepad_for(idx(_col)) >= 0:
				_capturing = true
				Sound.play("menu_move", 0.0)
				refresh()


func start_test() -> void:
	# touches redéfinies juste avant : appliquées aux héros
	PlayerInput.apply()
	_test_area.set_testing(true)
	Sound.play("menu_select", 0.0)
	refresh()


func stop_test() -> void:
	_test_area.set_testing(false)
	Sound.play("menu_move", 0.0)
	refresh()


func start_game() -> void:
	if PlayerInput.validation_error(_indices) != "":
		Sound.play("menu_move", 0.0, 0.0, 0.6)
		shake_message()
		return
	PlayerInput.save_config()
	PlayerInput.apply()
	GlobalPlayer.reset_game()
	GlobalPlayer.two_players = two_players
	leave(LEVEL_SCENE)


func shake_message() -> void:
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	for offset in [-3, 3, -2, 2, 0]:
		_message_tween.tween_property(_message, "position:x", float(offset), 0.04)


func leave(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	if path == MENU_SCENE:
		PlayerInput.save_config()
	Sound.play("menu_select", 0.0)
	Transition.goto(path)
