extends Node

var _failures := 0


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func wait_seconds(seconds: float) -> void:
	for frame in range(ceili(seconds * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame


func attack(player: Player, heavy: bool) -> void:
	var event := InputEventAction.new()
	event.action = player.action("attack_heavy" if heavy else "attack")
	event.pressed = true
	player.get_node("StateMachine")._input(event)


func _ready() -> void:
	run.call_deferred()


func run() -> void:
	PlayerInput.save_enabled = false
	for path in ["training_solo_setup", "training_coop_setup"]:
		var setup = load("res://src/UI/%s.tscn" % path).instantiate()
		check(setup.training_mode, "Training setup does not select training mode")
		check(setup.two_players == path.contains("coop"), "Incorrect training player count")
		setup.free()
	for coop in [false, true]:
		GlobalPlayer.two_players = coop
		GlobalPlayer.save_score(137)
		var arena = load("res://src/Levels/Training.tscn").instantiate()
		add_child(arena)
		await wait_seconds(0.3)
		check(arena.players.size() == (2 if coop else 1), "Wrong arena player count")
		var dummy = arena.dummy
		var origin: Vector2 = dummy.global_position
		var bar: ProgressBar = dummy.get_node("BodyPivot/Control/ProgressBar")
		check(dummy.get_life() == 100 and bar.value == 100, "Dummy must start at full health")
		var player: Player = arena.players[0]
		player.global_position = origin - Vector2(22, 0)
		player.get_node("BodyPivot").scale.x = 1.0
		attack(player, false)
		await wait_seconds(0.6)
		check(dummy.get_life() == 92, "Actual quick attack did not damage practice enemy")
		check(bar.visible and bar.value < bar.max_value, "Damage did not reduce visible health bar")
		check(dummy.global_position.is_equal_approx(origin), "Practice enemy moved after attack")
		check(player.is_alive() and player._life == Player.MAX_LIFE, "Practice enemy attacked player")
		Events.actor_took_damage.emit(dummy, 32)
		await wait_seconds(0.4)
		check(dummy.get_life() == 60, "Training damage routing failed")
		var combo_button: Button
		for candidate in arena.find_children("*", "Button", true, false):
			if candidate.text.begins_with("COMBOS"):
				combo_button = candidate
		check(combo_button != null, "Missing clickable combo button")
		if combo_button:
			combo_button.pressed.emit()
		check(arena.combos_panel.visible, "Combos panel did not open")
		var help_text := ""
		for label in arena.combos_panel.find_children("*", "Label", true, false):
			help_text += label.text + "\n"
		for recipe_name in CombatChain.RECIPES.values():
			check(help_text.contains(recipe_name), "Missing combo: " + recipe_name)
		arena.toggle_combos()
		check(not arena.combos_panel.visible, "Combos panel did not close")
		var keyboard_help := InputEventKey.new()
		keyboard_help.keycode = KEY_C
		keyboard_help.pressed = true
		arena._input(keyboard_help)
		check(arena.combos_panel.visible, "Keyboard combo shortcut failed")
		var pad_help := InputEventJoypadButton.new()
		pad_help.button_index = JOY_BUTTON_LEFT_SHOULDER
		pad_help.pressed = true
		arena._input(pad_help)
		check(not arena.combos_panel.visible, "Gamepad combo shortcut failed")
		Events.actor_took_damage.emit(dummy, 1000)
		await wait_seconds(0.05)
		check(dummy.get_life() <= 0 and dummy.is_respawning, "Death phase missing")
		var instance_id: int = dummy.get_instance_id()
		for frame in range(240):
			if dummy.respawn_count > 0:
				break
			await get_tree().physics_frame
		check(dummy.respawn_count == 1, "Practice enemy did not respawn once")
		check(dummy.get_instance_id() == instance_id and dummy.global_position.is_equal_approx(origin), "Respawn changed target or position")
		check(dummy.get_life() == 100 and bar.visible and bar.value == bar.max_value, "Respawn did not restore full health bar")
		if coop:
			player.global_position = origin - Vector2(80, 0)
			var player2: Player = arena.players[1]
			player2.global_position = origin + Vector2(22, 0)
			player2.get_node("BodyPivot").scale.x = -1.0
			attack(player2, true)
			await wait_seconds(0.9)
			check(dummy.get_life() == 76 and dummy.last_attacker == player2, "Player 2 heavy attack failed")
		check(dummy.global_position.is_equal_approx(origin), "Enemy drifted from its spawn")
		check(GlobalPlayer.get_score() == 137, "Training changed campaign score")
		arena.queue_free()
		await get_tree().process_frame
	GlobalPlayer.two_players = false
	print("TRAINING TESTS: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
