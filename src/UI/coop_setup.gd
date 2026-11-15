extends Node2D

# Choix des commandes, éditeur et essai partagés par les modes solo, coop et entraînement.
@export var two_players := true
@export var training_mode := false
@export var settings_only := false

const SETTINGS_SCENE := "res://src/UI/settings.tscn"
var _original_players := []
var _original_layout := ""

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
const ROW_START := ROW_FIRST_KEY + 9
const ROW_TEST := ROW_START + 1
const ROW_BACK := ROW_TEST + 1
const ROW_EDIT := ROW_BACK + 1
const ACTION_ROWS := [ROW_START, ROW_TEST, ROW_EDIT, ROW_BACK]

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
const Y_MESSAGE := 104.0
const PANEL_RECT := Rect2(10, 2, 300, 130)

const ButtonStyle = preload("res://src/Common/UI/MenuButtonStyle.gd")
const BUTTON_LABEL_NORMAL = ButtonStyle.TEXT
const BUTTON_LABEL_SELECTED = ButtonStyle.GOLD

var _row := ROW_START
var _editing := false
var _editor: Control
var _overview: Control
var _content: Control
var _title: Label
var _subtitle: Label
var _summaries: Array[Label] = []
var _col := 0
var _capturing := false
var _leaving := false

var _root: Control
var _highlight: ColorRect
var _layout_label: Label
# [colonne] -> {row: Label} (libellés de valeur) et noms des actions
var _values := [{}, {}]
var _names := [{}, {}]
var _message: Label
var _buttons := {}
var _message_tween: Tween
var _test_area: ControlsTestArea
# configurations PlayerInput affichées, une par colonne
var _indices: Array


func _ready() -> void:
	_original_players = PlayerInput.players.duplicate(true)
	_original_layout = PlayerInput.layout
	_indices = PlayerInput.indices(two_players)
	# smartphone / tablette : pas de clavier, manettes uniquement
	if Game.is_mobile():
		for i in _indices:
			PlayerInput.set_device(i, PlayerInput.Device.GAMEPAD)
	# actions des héros de la zone d'essai
	PlayerInput.apply()
	_test_area = ControlsTestArea.new()
	add_child(_test_area)
	_test_area.setup(two_players, get_node("Camera2D"))
	build_ui()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	if settings_only:
		_editing = true
		_row = ROW_DEVICE
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
	_content.add_child(label)
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

	_content = _root
	_title = build_label("", 10, Vector2(0, Y_TITLE), 320, HORIZONTAL_ALIGNMENT_CENTER)
	_title.size.y = 14
	_title.add_theme_color_override("font_color", Color("7fdbff"))

	_subtitle = build_label("", 5, Vector2(0, 10), 320, HORIZONTAL_ALIGNMENT_CENTER)
	_overview = Control.new()
	_overview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_overview)
	_content = _overview
	for col in range(_indices.size()):
		var x := column_x(col)
		var card := Panel.new()
		card.position = Vector2(x, 26)
		card.size = Vector2(COLUMN_WIDTH, 44)
		card.add_theme_stylebox_override("panel", button_style(Color("152639"), Player.COOP_COLORS[col]))
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overview.add_child(card)
		var heading := build_label("JOUEUR %d" % (col + 1), 5, Vector2(x, 21), COLUMN_WIDTH, HORIZONTAL_ALIGNMENT_CENTER)
		heading.add_theme_color_override("font_color", Player.COOP_COLORS[col])
		var summary := build_label("", 4, Vector2(x + 5, 34), COLUMN_WIDTH - 10)
		summary.size.y = 36
		summary.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		summary.add_theme_constant_override("line_spacing", 1)
		_summaries.append(summary)
	_editor = Control.new()
	_editor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_editor)
	_content = _editor
	_layout_label = build_label("", 5, Vector2(0, Y_LAYOUT), 320, HORIZONTAL_ALIGNMENT_CENTER)
	clickable(_layout_label, ROW_LAYOUT, 0)

	for col in range(_indices.size()):
		var x := column_x(col)
		# en solo, la colonne n'a pas besoin d'en-tête
		var header := build_label("JOUEUR %d" % (col + 1) if two_players else "", 5, Vector2(x, Y_HEADER), COLUMN_WIDTH, HORIZONTAL_ALIGNMENT_CENTER)
		header.add_theme_color_override("font_color", Player.COOP_COLORS[col])

		_names[col][ROW_DEVICE] = build_label("ENTREE", 5, Vector2(x + 4, Y_DEVICE), 60)
		_values[col][ROW_DEVICE] = build_label("", 5, Vector2(x + 50, Y_DEVICE), COLUMN_WIDTH - 54, HORIZONTAL_ALIGNMENT_RIGHT)
		clickable(_values[col][ROW_DEVICE], ROW_DEVICE, col)

		for i in range(PlayerInput.ACTIONS.size()):
			var row := ROW_FIRST_KEY + i
			var y := Y_FIRST_KEY + ROW_HEIGHT * i
			_names[col][row] = build_label({"ui_left": "GAUCHE", "ui_right": "DROITE", "ui_up": "HAUT", "ui_down": "BAS", "attack": "RAPIDE", "attack_heavy": "LOURDE", "attack_mana": "ORAGE", "dash": "DASH", "weapon": "ARME"}[PlayerInput.ACTIONS[i]], 5, Vector2(x + 4, y), 60)
			_values[col][row] = build_label("", 5, Vector2(x + 50, y), COLUMN_WIDTH - 54, HORIZONTAL_ALIGNMENT_RIGHT)
			clickable(_values[col][row], row, col)
			clickable(_names[col][row], row, col)


	_content = _root
	_message = build_label("", 4, Vector2(0, Y_MESSAGE), 320, HORIZONTAL_ALIGNMENT_CENTER)
	_message.add_theme_constant_override("outline_size", 1)
	for row in ACTION_ROWS:
		var button := Button.new()
		button.name = {ROW_START: "Play", ROW_TEST: "Test", ROW_EDIT: "Edit", ROW_BACK: "Menu"}[row]
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(func():
			if _capturing or _leaving:
				return
			_row = row
			activate()
		)
		button.mouse_entered.connect(func():
			if not _capturing and not _test_area.is_testing():
				_row = row
				refresh()
		)
		_root.add_child(button)
		_buttons[row] = button


func button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func refresh_actions(error_text: String) -> void:
	var testing := _test_area.is_testing()
	_editor.visible = _editing and not testing
	_overview.visible = not _editing or testing
	_subtitle.visible = not _editing or testing
	_subtitle.text = ("ENTRAINEMENT / " if training_mode else "") + ("2 JOUEURS" if two_players else "1 JOUEUR")
	_title.text = "ESSAI DES TOUCHES" if testing else ("MODIFIER LES TOUCHES" if _editing else "PRET A JOUER ?")
	if settings_only and not _editing and not testing:
		_title.text = "COMMANDES"
	_title.add_theme_font_size_override("font_size", 8 if _editing or testing else 10)
	for col in range(_indices.size()):
		var movement: Array[String] = []
		for action in ["ui_up", "ui_left", "ui_down", "ui_right"]:
			var key := PlayerInput.action_label(idx(col), action)
			movement.append({"UP": "^", "LEFT": "<", "DOWN": "v", "RIGHT": ">"}.get(key, key))
		var movement_text := "FLECHES" if movement == ["^", "<", "v", ">"] else "/".join(movement)
		var device := "CLAVIER " + movement_text if is_keyboard(col) else "MANETTE STICK / PAD"
		if not is_keyboard(col) and PlayerInput.gamepad_for(idx(col)) < 0:
			device = "MANETTE NON CONNECTEE"
		_summaries[col].text = "%s\nRAPIDE %s / LOURDE %s\nORAGE %s / DASH %s\nARME %s" % [device, PlayerInput.action_label(idx(col), "attack"), PlayerInput.action_label(idx(col), "attack_heavy"), PlayerInput.action_label(idx(col), "attack_mana"), PlayerInput.action_label(idx(col), "dash"), PlayerInput.action_label(idx(col), "weapon")]
	var home_rects := [Rect2(13, 74, 145, 16), Rect2(162, 74, 145, 16), Rect2(13, 94, 145, 16), Rect2(162, 94, 145, 16)]
	var edit_rects := [Rect2(12, 114, 66, 16), Rect2(82, 114, 66, 16), Rect2(152, 114, 76, 16), Rect2(232, 114, 76, 16)]
	for i in range(ACTION_ROWS.size()):
		var row: int = ACTION_ROWS[i]
		var button: Button = _buttons[row]
		button.visible = not testing or row == ROW_TEST
		button.disabled = _capturing or (row == ROW_START and error_text != "")
		var text_: String = {ROW_START: "JOUER", ROW_TEST: "TESTER LES TOUCHES", ROW_EDIT: "MODIFIER LES TOUCHES", ROW_BACK: "RETOUR AU MENU"}[row]
		if _editing:
			text_ = {ROW_START: "JOUER", ROW_TEST: "TESTER", ROW_EDIT: "TERMINE", ROW_BACK: "MENU"}[row]
		if settings_only:
			if row == ROW_START:
				text_ = "VALIDER"
			elif row == ROW_BACK:
				text_ = "RETOUR"
		if testing:
			text_ = "TERMINER LE TEST"
		var rect: Rect2 = Rect2(80, 80, 160, 16) if testing else (edit_rects[i] if _editing else home_rects[i])
		var selected := _row == row or testing
		button.position = rect.position
		button.size = rect.size
		ButtonStyle.apply(button, text_, selected)
	_message.position.y = 105.0 if _editing and not testing else 112.0


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
	if not _editing:
		return ACTION_ROWS.duplicate()
	var rows := []
	if any_keyboard():
		rows.append(ROW_LAYOUT)
	rows.append(ROW_DEVICE)
	for i in range(PlayerInput.ACTIONS.size()):
		if PlayerInput.is_remappable(idx(_col), PlayerInput.ACTIONS[i]):
			rows.append(ROW_FIRST_KEY + i)
	rows.append(ROW_START)
	rows.append(ROW_TEST)
	rows.append(ROW_EDIT)
	rows.append(ROW_BACK)
	return rows


func refresh() -> void:
	if not selectable_rows().has(_row):
		_row = ROW_DEVICE if _editing else ROW_START

	_layout_label.visible = any_keyboard()
	_layout_label.text = "CLAVIER   < " + PlayerInput.layout.to_upper() + " >"
	set_color(_layout_label, _row == ROW_LAYOUT)

	var conflicts := PlayerInput.conflicting_keys(_indices)
	for col in range(_indices.size()):
		var keyboard := is_keyboard(col)
		var button_conflicts := PlayerInput.conflicting_buttons(idx(col))
		var device_text := "< CLAVIER >" if keyboard else "< MANETTE >"
		if Game.is_mobile():
			device_text = "MANETTE"
		_values[col][ROW_DEVICE].text = device_text
		set_color(_values[col][ROW_DEVICE], _row == ROW_DEVICE and _col == col)

		for i in range(PlayerInput.ACTIONS.size()):
			var row := ROW_FIRST_KEY + i
			var action: String = PlayerInput.ACTIONS[i]
			var label: Label = _values[col][row]
			var selected := _row == row and _col == col
			if selected and _capturing:
				label.text = "UNE TOUCHE..." if keyboard else "UN BOUTON..."
			else:
				label.text = PlayerInput.action_label(idx(col), action)
			var editable := PlayerInput.is_remappable(idx(col), action)
			var error := conflicts.has(PlayerInput.players[idx(col)]["keys"][action]) if keyboard else button_conflicts.has(action)
			set_color(label, selected, COLOR_ERROR if error else (COLOR_NORMAL if editable else COLOR_DIM))
			_names[col][row].add_theme_color_override("font_color", COLOR_NORMAL if editable else COLOR_DIM)


	var error_text := PlayerInput.validation_error(_indices)
	error_text = error_text.replace("SAME KEY USED TWICE", "TOUCHE EN DOUBLE : MODIFIEZ LES TOUCHES").replace("SAME BUTTON USED TWICE", "BOUTON EN DOUBLE : MODIFIEZ LES TOUCHES").replace("PLUG A GAMEPAD FOR PLAYER", "BRANCHEZ LA MANETTE DU JOUEUR").replace("PLUG A GAMEPAD", "BRANCHEZ UNE MANETTE")
	if _test_area.is_testing():
		_message.text = "DEPLACEZ-VOUS !  ESC / START : TERMINER"
		_message.add_theme_color_override("font_color", COLOR_SELECTED)
	elif _capturing:
		_message.text = "APPUYEZ SUR UNE TOUCHE / ESC : ANNULER" if is_keyboard(_col) else "APPUYEZ SUR UN BOUTON / START : ANNULER"
		_message.add_theme_color_override("font_color", COLOR_SELECTED)
	elif error_text != "":
		_message.text = error_text
		_message.add_theme_color_override("font_color", COLOR_ERROR)
	else:
		_message.text = "ENTREE / A : MODIFIER   ESC / B : TERMINE" if _editing else "CHOISIR : FLECHES / PAD   VALIDER : ENTREE / A"
		_message.add_theme_color_override("font_color", Color("a3bdcd"))

	refresh_actions(error_text)
	place_highlight()


func set_color(label: Label, selected: bool, normal := COLOR_NORMAL) -> void:
	label.add_theme_color_override("font_color", COLOR_SELECTED if selected else normal)


func place_highlight() -> void:
	_highlight.visible = _editing and not _test_area.is_testing() and _row < ROW_START
	if not _highlight.visible:
		return
	var rect := Rect2()
	match _row:
		ROW_LAYOUT:
			rect = Rect2(90, Y_LAYOUT, 140, ROW_HEIGHT)
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
		if _editing:
			set_editing(false)
		else:
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
	if not _editing:
		_row = ACTION_ROWS[wrapi(ACTION_ROWS.find(_row) + direction * 2, 0, ACTION_ROWS.size())]
		Sound.play("menu_move", 0.0)
		refresh()
		return
	var rows := selectable_rows()
	var index := rows.find(_row)
	_row = rows[wrapi(index + direction, 0, rows.size())]
	Sound.play("menu_move", 0.0)
	refresh()


func horizontal(direction: int) -> void:
	if not _editing:
		_row = ACTION_ROWS[ACTION_ROWS.find(_row) ^ 1]
		Sound.play("menu_move", 0.0)
		refresh()
		return
	if _row in ACTION_ROWS:
		_row = ACTION_ROWS[wrapi(ACTION_ROWS.find(_row) + direction, 0, ACTION_ROWS.size())]
		Sound.play("menu_move", 0.0)
		refresh()
		return
	if _row == ROW_LAYOUT:
		cycle_layout(direction)
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
			if Game.is_mobile():
				return
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
		ROW_EDIT:
			set_editing(not _editing)
		_:
			if is_keyboard(_col) or PlayerInput.gamepad_for(idx(_col)) >= 0:
				_capturing = true
				Sound.play("menu_move", 0.0)
				refresh()


func set_editing(value: bool) -> void:
	_editing = value
	_row = ROW_DEVICE if value else ROW_EDIT
	Sound.play("menu_select", 0.0)
	refresh()


func start_test() -> void:
	_row = ROW_TEST
	# touches redéfinies juste avant : appliquées aux héros
	PlayerInput.apply()
	_test_area.set_testing(true)
	Sound.play("menu_select", 0.0)
	refresh()


func stop_test() -> void:
	_row = ROW_TEST
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
	if settings_only:
		leave(SETTINGS_SCENE)
		return
	if not training_mode:
		GlobalPlayer.reset_game()
	GlobalPlayer.two_players = two_players
	leave("res://src/Levels/Training.tscn" if training_mode else LEVEL_SCENE)


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
	if settings_only and path == MENU_SCENE:
		path = SETTINGS_SCENE
	if path in [MENU_SCENE, SETTINGS_SCENE]:
		if PlayerInput.validation_error(_indices) == "":
			PlayerInput.save_config()
		else:
			PlayerInput.players = _original_players.duplicate(true)
			PlayerInput.layout = _original_layout
		PlayerInput.apply()
	Sound.play("menu_select", 0.0)
	Transition.goto(path)
