extends Node

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _ready() -> void:
	run.call_deferred()


func wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func run() -> void:
	PlayerInput.save_enabled = false
	GlobalPlayer.reset_game()
	GlobalPlayer.set_level(3)
	var level = load("res://src/Levels/LevelTemplate.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	level._spawnTimer.stop()
	level._manaTimer.stop()
	level._ephemeral_timer.stop()

	check(not level.is_gate_open(), "Gate must start closed")
	var player: Player = level._player
	var lives_before: float = player._life

	var boss: MechaMantis = level.spawn_boss()
	check(boss != null and boss.is_in_group(Game.GROUP_ENEMY), "Boss must spawn as an enemy")
	check(boss.global_position.x < level._gate.global_position.x, "Boss must land before the gate")
	check(boss.get_node("BodyPivot/AnimatedSprite2D").sprite_frames.get_frame_texture(&"idle", 0).get_width() == 128, "Boss frames must be 128 px (2x)")
	check(boss.get_life() > 400.0, "Boss must be tough")
	check(level.spawn_boss() == boss, "Only one boss")
	check(boss.is_intro(), "Boss starts with its intro")
	boss.took_damage(50)
	check(is_equal_approx(boss.get_life(), boss._max_life), "Boss is invulnerable during intro")
	await wait_seconds(boss.INTRO_FALL + boss.INTRO_PAUSE + 0.2)
	check(not boss.is_intro(), "Intro must end")

	level._on_Gate_player_entered_gate()
	check(not Transition.is_busy(), "Gate stays locked while the boss lives")

	player.global_position = boss.global_position + Vector2(-20, 0)
	boss._next_slam_ms = 0
	await wait_seconds(boss.SLAM_WINDUP + 0.6)
	check(player._life < lives_before, "Slam must hurt a close player")

	boss.took_damage(roundi(boss._max_life * 0.6))
	check(boss.is_enraged(), "Boss must enrage under half life")
	check(boss.is_in_group(Game.GROUP_ENEMY), "Boss still alive")
	player.global_position = boss.global_position + Vector2(-120, 0)
	var score_before: int = GlobalPlayer.get_score()
	boss.took_damage(roundi(boss._max_life))
	check(level.is_gate_open(), "Gate must open once the boss is defeated")
	check(GlobalPlayer.get_score() >= score_before + 250, "Boss must give a big reward")
	await wait_seconds(2.0)
	check(not is_instance_valid(boss), "Boss must disappear after death")

	print("boss_test failures: ", failures)
	get_tree().quit(failures)
