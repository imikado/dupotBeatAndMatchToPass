extends Control

const ButtonStyle = preload("res://src/Common/UI/MenuButtonStyle.gd")

var _touch_button: Button


func _ready() -> void:
	var buttons: Array[Button] = []
	if not OS.has_feature("firetv"):
		_touch_button = add_option("", 50, toggle_touch)
		refresh_touch()
		buttons.append(_touch_button)
	buttons.append(add_option("COMMANDES SOLO", 76, open_controls.bind(false)))
	buttons.append(add_option("COMMANDES COOP", 102, open_controls.bind(true)))
	buttons.append(add_option("MENU", 128, goto_menu))
	buttons[0].grab_focus()


func add_option(caption: String, y: float, callback: Callable) -> Button:
	var button := Button.new()
	button.position = Vector2(64, y)
	button.size = Vector2(192, ButtonStyle.HEIGHT)
	button.pressed.connect(callback)
	add_child(button)
	ButtonStyle.bind_interaction(button, caption)
	return button


func refresh_touch() -> void:
	var caption := "TACTILE : " + ("OUI" if Game.isControlsEnabled() else "NON")
	_touch_button.set_meta("caption", caption)
	ButtonStyle.apply(_touch_button, caption, _touch_button.has_focus() or _touch_button.is_hovered())


func toggle_touch() -> void:
	Game.setControlsEnabled(not Game.isControlsEnabled(), true)
	refresh_touch()


func open_controls(coop: bool) -> void:
	Transition.goto("res://src/UI/settings_%s_setup.tscn" % ("coop" if coop else "solo"))


func goto_menu() -> void:
	Transition.goto("res://src/UI/menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or Game.isInputPauseButton(event):
		goto_menu()
	elif event.is_action_pressed("attack"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button:
			focused.pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()
