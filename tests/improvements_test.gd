extends Node

class Victim:
	extends CharacterBody2D
	var last_hit_by_storm := false
	var attacker: Player
	func get_attacker(): return attacker
	func get_type(): return Game.ENEMY_TYPE_LIST.ANT
	func update_enemy_life(_before, _after): pass
	func reset_combo_count(): pass

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	PlayerInput.save_enabled = false
	if not FileAccess.file_exists(Game.PATH_SETTINGS):
		check(Game.isControlsEnabled() == Game.is_mobile(), "Mouse touch emulation enabled touch controls on desktop")
		var controls = load("res://src/Common/UI/Controls.tscn").instantiate()
		add_child(controls)
		check(controls.visible == Game.is_mobile(), "Incorrect default touch overlay visibility")
		controls.queue_free()
	GlobalPlayer.reset_game()
	var level = load("res://src/Levels/LevelTemplate.tscn").instantiate()
	for coop in [false, true]:
		GlobalPlayer.two_players = coop
		var expected := [24, 32, 36] if coop else [18, 24, 27]
		for i in range(3):
			GlobalPlayer.set_level(i + 1)
			check(level.get_barrier_group_count() * level.get_barrier_types().size() * level.get_barrier_energy() == expected[i], "Incorrect introductory kill requirement")
		var previous: int = expected[2]
		for n in range(4, 40):
			GlobalPlayer.set_level(n)
			var count: int = level.get_barrier_group_count() * level.get_barrier_types().size() * level.get_barrier_energy()
			check(count >= previous and level.get_barrier_energy() <= 10, "Progression decreases or exceeds energy cap")
			previous = count
	GlobalPlayer.reset_game()
	GlobalPlayer.two_players = true
	add_child(level)
	await get_tree().process_frame
	level._spawnTimer.stop()
	level._manaTimer.stop()
	var first: Player = level._players[0]
	var second: Player = level._players[1]
	check(not first._canvas_modulate.has_meta("tint_tween"), "Storm test must start without a tint tween")
	first.mana_cast_begin()
	var initial_tween: Tween = first._canvas_modulate.get_meta("tint_tween")
	check(initial_tween.is_valid(), "First storm did not create a tint tween")
	second.mana_cast_begin()
	check(first._canvas_modulate == second._canvas_modulate, "Coop storm tint is not shared")
	check(not initial_tween.is_valid(), "Second storm did not replace the previous tint tween")
	check(first._canvas_modulate.get_meta("storm_count") == 2, "Overlapping storms are not counted")
	first.mana_cast_end()
	check(second._canvas_modulate.get_meta("storm_count") == 1, "Ending one storm cleared the other")
	second.mana_cast_end()
	await get_tree().create_timer(0.5).timeout
	check(first._canvas_modulate.color.is_equal_approx(Color.WHITE), "Storm tint did not return to normal")
	for index in [0, 1]:
		for storm in [false, true]:
			var victim := Victim.new()
			victim.attacker = level._players[index]
			victim.last_hit_by_storm = storm
			level.add_child(victim)
			level._players[1 - index]._storm_active = true
			GlobalPlayer.set_mana(0, index)
			GlobalPlayer.set_mana(0, 1 - index)
			level._on_actor_healt_changed(victim, 8, 0)
			check(is_equal_approx(GlobalPlayer.get_mana(index), 0.0 if storm else 0.5), "Mana must follow the killing blow, not the partner's storm")
			check(GlobalPlayer.get_mana(1 - index) == 0, "Mana awarded to the wrong player")
			level._players[1 - index]._storm_active = false
			victim.queue_free()
	await get_tree().create_timer(0.15, true, false, true).timeout
	level.queue_free()
	await get_tree().process_frame
	Engine.time_scale = 1.0

	var real_settings_path := Game.settings_path
	var previous_touch: bool = Game.isControlsEnabled()
	Game.settings_path = "user://test_settings.cfg"
	Game.setControlsEnabled(true, true)
	Game.setControlsEnabled(false)
	Game.load_settings()
	check(Game.isControlsEnabled(), "Touch preference did not survive reload")
	Game.setControlsEnabled(false, true)
	Game.setControlsEnabled(true)
	Game.load_settings()
	check(not Game.isControlsEnabled(), "Disabled touch preference did not survive reload")
	DirAccess.remove_absolute(Game.settings_path)
	Game.settings_path = real_settings_path
	Game.setControlsEnabled(previous_touch)

	PlayerInput.set_layout("qwerty")
	for i in range(3):
		PlayerInput.set_device(i, PlayerInput.Device.KEYBOARD)
	PlayerInput.set_key(PlayerInput.SOLO, "attack", KEY_P)
	PlayerInput.apply()
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	check(not InputMap.event_is_action(key, "solo_attack"), "Remapping left the old default key active")
	key.keycode = KEY_P
	check(InputMap.event_is_action(key, "solo_attack"), "Remapped key is inactive")
	PlayerInput.set_key(PlayerInput.SOLO, "attack_heavy", KEY_P)
	check(PlayerInput.validation_error(PlayerInput.SOLO_INDICES) != "", "Duplicate keys accepted")
	PlayerInput.set_key(PlayerInput.SOLO, "attack_heavy", KEY_X)
	PlayerInput.save_enabled = true
	PlayerInput.save_config()
	PlayerInput.set_key(PlayerInput.SOLO, "attack", KEY_Z)
	PlayerInput.load_config()
	check(PlayerInput.players[PlayerInput.SOLO].keys.attack == KEY_P, "Controls did not survive reload")

	for mode in ["solo", "coop"]:
		var setup = load("res://src/UI/settings_%s_setup.tscn" % mode).instantiate()
		add_child(setup)
		await get_tree().process_frame
		check(setup.settings_only and setup._editing, "Settings did not open shared editor")
		check(setup._buttons[setup.ROW_START].get_node("Label").text == "VALIDER", "Settings offers Play instead of Save")
		GlobalPlayer.save_score(123)
		Transition._is_busy = true
		setup.start_game()
		check(GlobalPlayer.get_score() == 123, "Saving settings reset the campaign")
		check(setup._leaving, "Valid settings did not close")
		Transition._is_busy = false
		setup.queue_free()
		await get_tree().process_frame

	var invalid = load("res://src/UI/settings_solo_setup.tscn").instantiate()
	add_child(invalid)
	var old_key: int = PlayerInput.players[PlayerInput.SOLO].keys.attack
	PlayerInput.set_key(PlayerInput.SOLO, "attack", PlayerInput.players[PlayerInput.SOLO].keys.attack_heavy)
	Transition._is_busy = true
	invalid.leave(invalid.MENU_SCENE)
	Transition._is_busy = false
	check(PlayerInput.players[PlayerInput.SOLO].keys.attack == old_key, "Leaving invalid edits did not restore the previous controls")
	PlayerInput.load_config()
	check(PlayerInput.players[PlayerInput.SOLO].keys.attack == old_key, "Invalid controls were saved")
	invalid.queue_free()
	await get_tree().process_frame

	var settings = load("res://src/UI/settings.tscn").instantiate()
	add_child(settings)
	await get_tree().process_frame
	check(get_viewport().gui_get_focus_owner() is Button, "Settings is not keyboard/gamepad navigable")
	var settings_real_path := Game.settings_path
	var settings_previous_touch: bool = Game.isControlsEnabled()
	Game.settings_path = "user://test_settings.cfg"
	Game.setControlsEnabled(false)
	settings.toggle_touch()
	Game.load_settings()
	check(Game.isControlsEnabled(), "Settings toggle did not persist")
	DirAccess.remove_absolute(Game.settings_path)
	Game.settings_path = settings_real_path
	Game.setControlsEnabled(settings_previous_touch)
	settings.queue_free()
	await get_tree().process_frame
	print("IMPROVEMENTS TESTS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	get_tree().quit(0 if failures == 0 else 1)
