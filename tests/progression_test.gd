extends Node

var failures := 0
var _discharges := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _ready() -> void:
	run.call_deferred()


func on_discharged(_bolt) -> void:
	_discharges += 1


func run() -> void:
	GlobalPlayer.reset_game()
	var attack := GlobalPlayer.PROGRESS_ATTACK
	var mana := GlobalPlayer.PROGRESS_MANA
	check(GlobalPlayer.progress_level(attack) == 1 and GlobalPlayer.progress_level(mana) == 1, "Progress must start at level 1")
	check(is_equal_approx(GlobalPlayer.attack_level_factor(), 0.45), "Attack must start weak")
	var per_level := GlobalPlayer.POWER_UPS_PER_LEVEL
	check(per_level == 4 and GlobalPlayer.POWER_UP_XP == 1, "4 power-ups per level")
	check(GlobalPlayer.add_xp(attack, per_level - 1) == 0 and GlobalPlayer.add_xp(attack, 1) == 1, "Level-up threshold")
	check(GlobalPlayer.progress_xp(attack) == 0 and GlobalPlayer.attack_level_factor() > 0.45, "Level 2 must hit harder")
	check(GlobalPlayer.add_xp(attack, 100000) > 0 and GlobalPlayer.is_progress_maxed(attack), "Attack level must cap")
	var salvos := []
	for level in range(1, GlobalPlayer.MANA_MAX_LEVEL + 1):
		GlobalPlayer.progress[0][mana]["level"] = level
		salvos.append([GlobalPlayer.storm_salvos(), GlobalPlayer.storm_bolts()])
	check(salvos == [[1, 8], [2, 8], [3, 8], [3, 9], [3, 10]], "Storm growth: " + str(salvos))

	GlobalPlayer.reset_game()
	GlobalPlayer.set_level(1)
	var level = load("res://src/Levels/LevelTemplate.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	level._spawnTimer.stop()
	level._manaTimer.stop()
	level._ephemeral_timer.stop()
	var power_ups: Array = level.find_children("*", "PowerUp", true, false)
	var kinds := power_ups.map(func(p): return p.kind)
	check(kinds == [attack, mana, attack], "Power-ups on the path: " + str(kinds))

	var player: Player = level._player
	player.global_position = power_ups[0].global_position
	for i in range(4):
		await get_tree().physics_frame
	check(GlobalPlayer.progress_xp(attack) == GlobalPlayer.POWER_UP_XP, "Power-up pickup must give attack XP")
	await get_tree().create_timer(0.4).timeout
	check(not is_instance_valid(power_ups[0]), "Power-up must disappear once taken")
	check(level._hud._progress_rows[0][attack]["count"] == 1, "HUD must light one pip")

	for other in power_ups:
		if is_instance_valid(other):
			other.free()
	var ephemeral: PowerUp = level.spawn_ephemeral_power_up()
	check(ephemeral != null and ephemeral.is_ephemeral(), "Ephemeral power-up must spawn")
	check(ephemeral.global_position.x > player.global_position.x, "Ephemeral power-up must appear ahead")
	ephemeral.lifetime = 0.5
	await get_tree().create_timer(0.3).timeout
	check(is_instance_valid(ephemeral) and ephemeral.light() < 0.6 and ephemeral._glow.self_modulate.a < 0.6, "Ephemeral light must fade")
	await get_tree().create_timer(0.7).timeout
	check(not is_instance_valid(ephemeral), "Ephemeral power-up must vanish")
	var first: PowerUp = level.spawn_ephemeral_power_up()
	check(first != null and level.spawn_ephemeral_power_up() == null, "Ephemeral power-ups must keep 400 px apart")
	var permanent: PowerUp = level.spawn_power_up(attack, first.global_position + Vector2(level.POWER_UP_MIN_SPACING - 1, 0))
	check(not level.is_power_up_spot_free(first.global_position + Vector2(level.POWER_UP_MIN_SPACING * 2 - 2, 0)), "Spacing must count permanent power-ups")
	permanent.free()
	player.global_position.x += level.POWER_UP_MIN_SPACING * 1.5
	check(level.spawn_ephemeral_power_up() == null, "Only one ephemeral power-up at a time")
	first.free()
	check(level.spawn_ephemeral_power_up() != null, "Ephemeral power-up must spawn once far enough")
	for node in level._ysort.get_children():
		if node is PowerUp:
			node.queue_free()

	for bolt in player._manaFalling.get_children():
		bolt.discharged.connect(on_discharged)
	for mana_level in [1, 2, 3]:
		GlobalPlayer.progress[0][mana]["level"] = mana_level
		_discharges = 0
		var start := Time.get_ticks_msec()
		player._stateMachine._change_state(Player.STATE_ATTACK_MANA01)
		while player._stateMachine.current_state.name == Player.STATE_ATTACK_MANA01 and Time.get_ticks_msec() - start < 4000:
			await get_tree().process_frame
		var duration := (Time.get_ticks_msec() - start) / 1000.0
		await get_tree().create_timer(0.6).timeout
		print("mana level %d : %d discharges, %.2f s" % [mana_level, _discharges, duration])
		check(_discharges == 8 * mana_level, "Storm level %d must strike %d salvo(s)" % [mana_level, mana_level])

	level.queue_free()
	await get_tree().process_frame
	print("progression_test failures: ", failures)
	get_tree().quit(failures)
