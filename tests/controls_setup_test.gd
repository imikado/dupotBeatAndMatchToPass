extends Node

class Setup:
	extends "res://src/UI/coop_setup.gd"
	var destination := ""
	func leave(path: String) -> void:
		destination = path

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func action(name_: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name_
	event.pressed = true
	return event

func snapshot(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"):
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/controls-%s.png" % label)

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	PlayerInput.save_enabled = false
	for i in range(3):
		PlayerInput.set_device(i, PlayerInput.Device.KEYBOARD)
	PlayerInput.set_layout("qwerty")
	for scene in ["solo_setup", "coop_setup", "training_solo_setup", "training_coop_setup"]:
		var screen = load("res://src/UI/%s.tscn" % scene).instantiate()
		var coop: bool = screen.two_players
		var training: bool = screen.training_mode
		screen.set_script(Setup)
		screen.two_players = coop
		screen.training_mode = training
		add_child(screen)
		await get_tree().process_frame
		check(screen._row == screen.ROW_START and not screen._editing, "Play should be the initial selection")
		check(screen._overview.visible and not screen._editor.visible, "Controls list should have its own editor")
		check(screen._summaries.size() == (2 if coop else 1), "Incorrect player summary count")
		for row in screen.ACTION_ROWS:
			var button: Button = screen._buttons[row]
			check(button.visible and button.get_rect().end.y <= 126, "Action is clipped or hidden")
		check(screen._buttons[screen.ROW_START].get_node("Label").get_theme_color("font_color") == screen.BUTTON_LABEL_SELECTED, "Play must be highlighted initially")
		await snapshot(scene)
		screen._input(action("ui_right"))
		check(screen._row == screen.ROW_TEST, "Grid right should select test")
		screen._input(action("ui_down"))
		check(screen._row == screen.ROW_BACK, "Grid down should select menu")
		screen._row = screen.ROW_EDIT
		var accept := InputEventJoypadButton.new()
		accept.button_index = JOY_BUTTON_A
		accept.pressed = true
		screen._input(accept)
		check(screen._editing and screen._editor.visible, "Edit button does not open controls")
		check(not screen._overview.visible, "Overview overlaps editor")
		await snapshot(scene + "-edit")
		for row in screen.ACTION_ROWS:
			check(screen._buttons[row].get_rect().end.y <= screen.PANEL_RECT.end.y, "Editor footer exceeds the panel")
		screen._col = 1 if coop else 0
		screen._row = screen.ROW_FIRST_KEY + PlayerInput.ACTIONS.find("attack_heavy")
		screen.activate()
		check(screen._capturing, "Heavy attack cannot be remapped")
		var key := InputEventKey.new()
		key.keycode = KEY_P
		key.pressed = true
		screen._input(key)
		check(not screen._capturing and PlayerInput.players[screen.idx(screen._col)].keys.attack_heavy == KEY_P, "Remapping targets the wrong player")
		screen._buttons[screen.ROW_TEST].pressed.emit()
		check(screen._test_area.is_testing() and screen._overview.visible and not screen._editor.visible, "Testing should have its own clear layout")
		check(screen._buttons[screen.ROW_TEST].get_node("Label").text == "TERMINER LE TEST", "Testing needs an explicit stop button")
		check(not screen._buttons[screen.ROW_START].visible, "Play must not intercept test actions")
		await snapshot(scene + "-test")
		key.keycode = KEY_ESCAPE
		screen._input(key)
		check(not screen._test_area.is_testing() and screen._editing and screen.destination == "", "Escape should return from test to editor")
		screen._input(action("ui_cancel"))
		check(not screen._editing and screen.destination == "", "Cancel should close editor before leaving setup")
		screen._buttons[screen.ROW_TEST].pressed.emit()
		screen._buttons[screen.ROW_TEST].pressed.emit()
		check(not screen._test_area.is_testing() and not screen._editing, "Mouse stop button should return to overview")
		if Input.get_connected_joypads().is_empty():
			PlayerInput.set_device(screen.idx(0), PlayerInput.Device.GAMEPAD)
			screen.refresh()
			check(screen._buttons[screen.ROW_START].disabled, "Missing gamepad should disable Play")
			PlayerInput.set_device(screen.idx(0), PlayerInput.Device.KEYBOARD)
		PlayerInput.set_layout("qwerty")
		var index: int = screen.idx(0)
		PlayerInput.set_key(index, "attack_heavy", PlayerInput.players[index].keys.attack)
		screen.refresh()
		check(screen._buttons[screen.ROW_START].disabled, "Conflicting controls must disable Play")
		screen.start_game()
		check(screen.destination == "", "Invalid controls should block launch")
		PlayerInput.set_layout("qwerty")
		screen.refresh()
		screen._buttons[screen.ROW_START].pressed.emit()
		check(screen.destination == ("res://src/Levels/Training.tscn" if training else screen.LEVEL_SCENE), "Play opens the wrong game mode")
		check(GlobalPlayer.two_players == coop, "Play opens the wrong player count")
		screen.destination = ""
		screen._buttons[screen.ROW_BACK].pressed.emit()
		check(screen.destination == screen.MENU_SCENE, "Menu button has wrong destination")
		screen.queue_free()
		await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	print("CONTROLS SETUP TESTS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	get_tree().quit(0 if failures == 0 else 1)
