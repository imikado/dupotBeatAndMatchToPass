extends Node

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	var level = load("res://src/Levels/LevelTemplate.tscn").instantiate()
	for coop in [false, true]:
		GlobalPlayer.two_players = coop
		var previous_delay := INF
		var previous_speed := 0.0
		var previous_damage := 0
		for n in range(1, 41):
			GlobalPlayer.set_level(n)
			var wave_min := 100
			var wave_max := 0
			for sample in range(100):
				var size: int = level.get_wave_size()
				wave_min = mini(wave_min, size)
				wave_max = maxi(wave_max, size)
			check(wave_min >= 2 and wave_max <= 10, "Wave size outside safe bounds")
			if n >= 5:
				check(wave_min >= mini(6 + (n - 5) / 2, 10), "Late waves lost their minimum pressure")
			check(level.get_enemy_limit() >= 5 and level.get_enemy_limit() <= 8, "Enemy limit outside safe bounds")
			level._total_wave_number = 0
			var delay: float = level.get_spawn_delay()
			check(delay <= previous_delay, "Spawn cadence regressed")
			if n >= 5 and n <= 15:
				check(delay < previous_delay, "Late spawn cadence plateaued too early")
			previous_delay = delay
			level._total_wave_number = 9
			check(is_equal_approx(level.get_spawn_delay(), delay / 2.0), "Within-group acceleration lost")
			var enemy = load("res://src/Actors/SimpleEnemies/Beetle.tscn").instantiate()
			enemy.apply_difficulty(GlobalPlayer.get_difficulty())
			check(enemy._walk_speed >= previous_speed and enemy._damage >= previous_damage, "Enemy strength regressed")
			if n >= 5 and n <= 12:
				check(enemy._walk_speed > previous_speed and enemy._damage > previous_damage, "Enemy strength plateaued too early")
			check(enemy.get_life() == 50, "Difficulty changed combo kill requirements")
			previous_speed = enemy._walk_speed
			previous_damage = enemy._damage
			enemy.free()
	GlobalPlayer.reset_game()
	GlobalPlayer.two_players = false
	level.free()
	print("DIFFICULTY TESTS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	get_tree().quit(0 if failures == 0 else 1)
