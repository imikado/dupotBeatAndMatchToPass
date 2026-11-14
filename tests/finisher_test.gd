extends Node

class Target:
	extends Node2D
	var last_attacker: Node

var _failures := 0
var _hits := {}
var _real_enemy: Enemy
var _real_hits: Array = []
var _real_recoil: Array = []
var player: Player


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func wait_seconds(seconds: float) -> void:
	for frame in range(ceili(seconds * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame


func press_attack(kind: String) -> void:
	var input := InputEventAction.new()
	input.action = player.action("attack_heavy" if kind == "H" else "attack")
	input.pressed = true
	player.get_node("StateMachine")._input(input)


func target(at: Vector2) -> Target:
	var body := Target.new()
	body.position = at
	add_child(body)
	body.add_to_group(Game.GROUP_ENEMY)
	_hits[body.get_instance_id()] = []
	return body


func on_damage(body: Node, damage: int) -> void:
	if body is Target:
		_hits[body.get_instance_id()].append(damage)
	elif body == _real_enemy:
		_real_hits.append(damage)
		_real_recoil.append(player.melee_knockback())
		_real_enemy.took_damage(damage)


func start_finisher(recipe: String) -> void:
	var machine: PlayerStateMachine = player.get_node("StateMachine")
	machine._change_state("Idle")
	machine.combo_sequence = recipe
	machine._change_state("Attack%02d" % recipe.length())


func _ready() -> void:
	run.call_deferred()


func run() -> void:
	PlayerInput.save_enabled = false
	Events.actor_took_damage.connect(on_damage)
	for scene in ["Player", "Player2"]:
		player = load("res://src/Actors/Players/%s.tscn" % scene).instantiate()
		add_child(player)
		await wait_seconds(0.2)
		var frames: SpriteFrames = player.get_node("BodyPivot/AnimatedSprite2D").sprite_frames
		check(frames.get_frame_count("combo_flurry") == 32, "Flurry is missing sword or recovery poses")
		check(frames.get_frame_count("combo_cross") == 24, "Alternating combo is missing sword poses")
		for i in range(4):
			check(frames.get_frame_texture("combo_flurry", i + 4) == frames.get_frame_texture("followups_sheet", i), "Missing horizontal sword cut")
			check(frames.get_frame_texture("combo_flurry", i + 28) == frames.get_frame_texture("followups_sheet", i + 4), "Missing thrust follow-through")
		for recipe in ["RRRR", "RHR", "HRH", "RRRH"]:
			player.position = Vector2.ZERO
			var nearby := target(Vector2(24, 0))
			var flank := target(Vector2(-20, 0))
			var far := target(Vector2(100, 0))
			var other_lane := target(Vector2(24, 55))
			start_finisher(recipe)
			var expected: Array = {"RRRR": [8, 8, 8, 8, 8, 8, 8, 8], "RHR": [8, 12, 8, 12, 8, 12], "HRH": [10, 14, 10, 14, 10, 14], "RRRH": [64]}[recipe]
			var animator: AnimationPlayer = player.get_node("BodyPivot/AnimationPlayer")
			check(animator.current_animation == CombatChain.strike(recipe).animation, "Wrong finisher animation")
			await wait_seconds(float(CombatChain.strike(recipe).duration) + 0.3)
			check(_hits[nearby.get_instance_id()] == expected, "Incorrect multi-hit damage: " + recipe)
			check(_hits[far.get_instance_id()].is_empty(), "Enemy outside range was hit")
			check(_hits[other_lane.get_instance_id()].is_empty(), "Enemy on another depth lane was hit")
			check(nearby.last_attacker == player, "Incorrect finisher attacker")
			if recipe == "RRRH":
				check(_hits[flank.get_instance_id()] == [64], "Slam did not damage surrounding enemy")
			else:
				check(_hits[flank.get_instance_id()].is_empty(), "Sword finisher hit behind player")
			check(player._hitBox.disabled, "Finisher leaked melee hitbox")
			for body in [nearby, flank, far, other_lane]:
				body.queue_free()
			await get_tree().process_frame
		for recipe in ["RRRR", "RHR"]:
			player.position = Vector2.ZERO
			_real_enemy = load("res://src/Actors/SimpleEnemies/Ant.tscn").instantiate()
			_real_enemy.setPlayer(player)
			_real_enemy._walk_speed = 0.0
			_real_enemy._life = 200.0
			_real_enemy.position = Vector2(24, 0)
			_real_hits.clear()
			_real_recoil.clear()
			add_child(_real_enemy)
			_real_enemy.add_to_group(Game.GROUP_ENEMY)
			player.get_node("StateMachine")._change_state("Idle")
			press_attack(recipe[0])
			for i in range(recipe.length()):
				var duration: float = CombatChain.strike(recipe.substr(0, i + 1)).duration
				if i + 1 < recipe.length():
					await wait_seconds(duration - 0.12)
					press_attack(recipe[i + 1])
					var prefix: String = recipe.substr(0, i + 2)
					for frame in range(90):
						await get_tree().physics_frame
						if player.get_node("StateMachine").combo_sequence == prefix:
							break
					check(player.get_node("StateMachine").combo_sequence == prefix, "Combo input did not chain")
				else:
					await wait_seconds(duration + 0.35)
			var expected_hits: Array = [8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8] if recipe == "RRRR" else [8, 24, 8, 12, 8, 12, 8, 12]
			check(_real_hits == expected_hits, "Full combo misses real enemy: %s got %s" % [recipe, str(_real_hits)])
			var total_damage := 88 if recipe == "RRRR" else 92
			check(_real_enemy.get_life() == 200 - total_damage, "Real enemy missed full combo damage")
			var finisher_hits := 8 if recipe == "RRRR" else 6
			check(not _real_recoil.is_empty() and _real_recoil.back() > 2.0, "Final combo hit should push the enemy back")
			for i in range(maxi(0, _real_recoil.size() - finisher_hits), _real_recoil.size() - 1):
				check(_real_recoil[i] == 2.0, "Early finisher hit pushes enemy out of reach")
			_real_enemy.queue_free()
			_real_enemy = null
			await get_tree().process_frame
		for recipe in ["RRRR", "RHR"]:
			start_finisher(recipe)
			await wait_seconds(float(CombatChain.strike(recipe).duration) - 0.12)
			var next_attack := InputEventAction.new()
			next_attack.action = player.action("attack")
			next_attack.pressed = true
			player.get_node("StateMachine")._input(next_attack)
			await wait_seconds(0.15)
			check(player.get_node("StateMachine").combo_sequence == "R", "Buffered attack failed to continue after finisher")
			check(player.get_node("StateMachine").current_state.name == "Attack01", "Unexpected idle gap after finisher")
			await wait_seconds(0.35)
		player.position = Vector2.ZERO
		var cancelled_target := target(Vector2(24, 0))
		start_finisher("RRRH")
		await wait_seconds(0.3)
		player.get_node("StateMachine").set_damaged()
		await wait_seconds(1.0)
		check(_hits[cancelled_target.get_instance_id()].is_empty(), "Cancelled slam still dealt damage")
		check(player.get_node("BodyPivot/AnimatedSprite2D").position == Player.SPRITE_POSITION, "Cancelled slam left sprite floating")
		cancelled_target.queue_free()
		player.queue_free()
		await get_tree().process_frame
	print("FINISHER TESTS: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
