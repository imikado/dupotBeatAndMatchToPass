extends Node

class Target:
	extends CharacterBody2D
	var last_attacker: Node

var _hits := 0
var _received_damage := 0
var _failures := 0
var player: Player


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _ready() -> void:
	run.call_deferred()


func press(kind: String) -> void:
	var event := InputEventAction.new()
	event.action = player.action("attack_heavy" if kind == "H" else "attack")
	event.pressed = true
	player.get_node("StateMachine")._input(event)


func wait_seconds(seconds: float) -> void:
	for frame in range(ceili(seconds * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame


func on_damage(actor: Node, damage: int) -> void:
	if actor is Target:
		_hits += 1
		_received_damage = damage


func run() -> void:
	Events.actor_took_damage.connect(on_damage)
	var input = get_tree().root.get_node("PlayerInput")
	input.save_enabled = false
	for index in range(3):
		check(InputMap.has_action(input.prefix(index) + "attack_heavy"), "Missing heavy input for player %d" % index)
	for scene in ["Player", "Player2"]:
		player = load("res://src/Actors/Players/%s.tscn" % scene).instantiate()
		add_child(player)
		await wait_seconds(0.2)
		var machine: PlayerStateMachine = player.get_node("StateMachine")
		var sprite: AnimatedSprite2D = player.get_node("BodyPivot/AnimatedSprite2D")
		check(sprite.sprite_frames.get_frame_count("attacking_heavy") == 6, "Missing heavy frames: " + scene)
		for recipe in CombatChain.RECIPES:
			machine._change_state("Idle")
			press(recipe[0])
			for i in range(recipe.length()):
				var prefix: String = recipe.substr(0, i + 1)
				check(machine.combo_sequence == prefix, "Wrong chain: %s actual=%s state=%s" % [prefix, machine.combo_sequence, machine.current_state.name])
				var strike := CombatChain.strike(prefix)
				check(player._damage == strike.damage, "Wrong strike damage: " + prefix)
				await wait_seconds(float(strike.duration) - 0.12)
				if i + 1 < recipe.length():
					press(recipe[i + 1])
				await wait_seconds(0.15)
			await wait_seconds(0.15)
			check(machine.combo_sequence == "", "Finisher must end chain: " + recipe)
			check(player._hitBox.disabled, "Hitbox left active after finisher")
		machine._change_state("Idle")
		press("H")
		press("R")
		await wait_seconds(0.77)
		check(machine.combo_sequence == "", "Early buffered input did not expire")
		press("H")
		await wait_seconds(0.42)
		check(not player._hitBox.disabled, "Heavy active window missing")
		machine.set_damaged()
		await get_tree().physics_frame
		check(player._hitBox.disabled and player._strike.is_empty(), "Damage failed to cancel strike")
		await wait_seconds(0.4)
		machine._change_state("Idle")
		press("R")
		await wait_seconds(0.1)
		var dash := InputEventAction.new()
		dash.action = player.action("dash")
		dash.pressed = true
		machine._input(dash)
		await get_tree().physics_frame
		check(machine.current_state.name == "Dash" and player._hitBox.disabled, "Dash failed to cancel strike")
		await wait_seconds(0.5)
		machine._change_state("Idle")
		var target := Target.new()
		target.collision_layer = 2
		target.collision_mask = 0
		target.add_to_group(Game.GROUP_ENEMY)
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 4.0
		shape.shape = circle
		target.add_child(shape)
		add_child(target)
		target.global_position = player.global_position + Vector2(22, -6)
		_hits = 0
		press("H")
		await wait_seconds(0.48)
		check(_hits == 1 and _received_damage == 24, "Heavy collision failed to deal exactly 24 damage")
		player._on_HitBox_body_entered(target)
		check(_hits == 1, "Same target damaged twice by one swing")
		check(target.last_attacker == player, "Incorrect hit attribution")
		target.queue_free()
		await wait_seconds(0.5)
		player.setup_coop(0 if scene == "Player" else 1, player.get_node("Camera2D"))
		machine._change_state("Idle")
		var other_input := InputEventAction.new()
		other_input.action = "p2_attack_heavy" if player.player_index == 0 else "p1_attack_heavy"
		other_input.pressed = true
		machine._input(other_input)
		check(machine.current_state.name == "Idle", "Other player input triggered an attack")
		press("H")
		check(machine.combo_sequence == "H", "Coop heavy attack failed")
		await wait_seconds(0.8)
		player.queue_free()
		await get_tree().process_frame
	print("COMBAT TESTS: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
