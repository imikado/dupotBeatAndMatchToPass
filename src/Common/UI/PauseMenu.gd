class_name PauseMenu
extends CanvasLayer

const COLOR_SELECTED = Color("ffd34d")
const COLOR_NORMAL = Color(1, 1, 1, 0.7)

var _options := []
var _selected := 0
var _root: Control


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_root = Control.new()
	_root.size = Vector2(320, 180)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0.05, 0.88)
	dim.size = Vector2(320, 180)
	_root.add_child(dim)

	var title := build_label("PAUSE", 10, Vector2(0, 50))
	title.add_theme_color_override("font_color", Color("7fdbff"))

	_options = [
		build_label("RESUME", 5, Vector2(0, 88)),
		build_label("QUIT TO MENU", 5, Vector2(0, 104)),
	]
	for i in range(_options.size()):
		_options[i].mouse_filter = Control.MOUSE_FILTER_STOP
		_options[i].gui_input.connect(_on_option_gui_input.bind(i))


func build_label(text_: String, font_size: int, position_: Vector2) -> Label:
	var label := Label.new()
	label.text = text_
	label.add_theme_font_override("font", Fx.FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = position_
	label.size = Vector2(320, 14)
	_root.add_child(label)
	return label


func is_open() -> bool:
	return visible


func open() -> void:
	if visible or Transition.is_busy():
		return
	visible = true
	_selected = 0
	refresh()
	get_tree().paused = true
	get_tree().call_group("hud", "hide_banner")
	Sound.play("pause", 0.0)

	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.12)


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	Sound.play("menu_select", 0.0)


func refresh() -> void:
	for i in range(_options.size()):
		var label: Label = _options[i]
		var is_selected = i == _selected
		label.add_theme_color_override("font_color", COLOR_SELECTED if is_selected else COLOR_NORMAL)
		label.text = ("> " + label.text.trim_prefix("> ") + " <") if is_selected else label.text.trim_prefix("> ").trim_suffix(" <")


func validate() -> void:
	if _selected == 0:
		close()
	else:
		Sound.play("menu_select", 0.0)
		visible = false
		Transition.goto("res://src/UI/menu.tscn")


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if Game.isInputPauseButton(event):
		close()
	elif event.is_action_pressed(PlayerAbstractState.INPUT_UP) or event.is_action_pressed(PlayerAbstractState.INPUT_DOWN):
		_selected = (_selected + 1) % _options.size()
		Sound.play("menu_move", 0.0)
		refresh()
	elif Game.isInputValidateButton(event):
		validate()
	else:
		return
	get_viewport().set_input_as_handled()


func _on_option_gui_input(event: InputEvent, index: int) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		_selected = index
		refresh()
		validate()
