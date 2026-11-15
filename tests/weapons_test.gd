extends Node

class Target:
	extends CharacterBody2D
	var last_attacker: Node
	var last_hit_by_storm := false
	func took_damage(_damage): pass

var failures := 0
var _hits := {}


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _ready() -> void:
	run.call_deferred()


func on_damage(actor: Node, damage: int) -> void:
	_hits[actor] = _hits.get(actor, 0) + damage


func target(at: Vector2) -> Target:
	var node := Target.new()
	node.add_to_group(Game.GROUP_ENEMY)
	add_child(node)
	node.global_position = at
	return node


func run() -> void:
	GlobalPlayer.reset_game()
	var axe := GlobalPlayer.WEAPON_AXE
	var bomb := GlobalPlayer.WEAPON_BOMB
	check(not GlobalPlayer.buy_weapon(axe), "Axe bought without gems")
	GlobalPlayer.add_gems(500)
	check(GlobalPlayer.buy_weapon(axe) and GlobalPlayer.get_weapon() == axe, "Axe purchase must equip it")
	check(GlobalPlayer.get_gems() == 500 - GlobalPlayer.WEAPON_PRICES[axe], "Axe price not charged")
	check(GlobalPlayer.buy_weapon(bomb) and not GlobalPlayer.buy_weapon(bomb), "Bomb bought twice")
	GlobalPlayer.set_weapon(GlobalPlayer.WEAPON_SWORD)
	check(GlobalPlayer.next_weapon() == axe, "Weapon cycle order")

	Events.actor_took_damage.connect(on_damage)
	var level = load("res://src/Levels/LevelTemplate.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	level._spawnTimer.stop()
	level._manaTimer.stop()
	var player: Player = level._player
	var sprite: AnimatedSprite2D = player.get_node("BodyPivot/AnimatedSprite2D")
	var sword_frames := sprite.sprite_frames
	player.select_weapon(axe)
	check(sprite.sprite_frames != sword_frames, "Axe frames not applied")
	var texture: AtlasTexture = sprite.sprite_frames.get_frame_texture("combo_cross", 2)
	check(texture.atlas.resource_path.ends_with("-axe.png"), "Axe combo frames still show the sword")
	var strike := CombatChain.strike("R")
	var slow := player.weapon_strike(strike)
	check(is_equal_approx(slow.duration, strike.duration * Player.AXE_SLOW) and slow.damage > strike.damage, "Axe must be slower and stronger")
	player.cycle_weapon()
	check(GlobalPlayer.get_weapon() == bomb and sprite.sprite_frames == sword_frames, "Cycle to bombs")

	player.global_position = Vector2(300, 160)
	await get_tree().physics_frame
	player.get_node("BodyPivot").scale.x = 1
	var near := target(player.global_position + Vector2(Player.THROW_DISTANCE + 6, 2))
	var far := target(player.global_position + Vector2(Player.THROW_DISTANCE + 120, 0))
	var machine: PlayerStateMachine = player.get_node("StateMachine")
	machine.get_node("Throw").heavy = false
	machine._change_state(PlayerStateMachine.STATE_THROW)
	check(player.get_node("BodyPivot/AnimationPlayer").current_animation == Player.ANIM_THROW, "Throw animation not played")
	await get_tree().create_timer(0.3).timeout
	check(get_tree().get_nodes_in_group(Game.GROUP_ENEMY).size() >= 2 and level.find_children("*", "Bomb", true, false).size() + player.get_parent().find_children("*", "Bomb", true, false).size() >= 1, "Bomb not thrown")
	await get_tree().create_timer(1.2).timeout
	check(_hits.get(near, 0) > 0, "Bomb explosion missed the nearby enemy")
	check(_hits.get(far, 0) == 0, "Bomb explosion reached a far enemy")
	check(machine.current_state.name != PlayerStateMachine.STATE_THROW, "Throw state did not end")
	near.queue_free()
	far.queue_free()
	level.queue_free()
	await get_tree().process_frame

	GlobalPlayer.reset_game()
	var shop = load("res://src/Levels/LevelShop.tscn").instantiate()
	add_child(shop)
	await get_tree().process_frame
	var buy: Button = shop._entries.filter(func(e): return e.weapon == axe)[0].button
	check(shop._entries.size() == 3, "Shop must show two weapon buttons and CONTINUE")
	check(buy.disabled, "Buy button enabled without gems")
	GlobalPlayer.add_gems(GlobalPlayer.WEAPON_PRICES[axe] - 1)
	shop.refresh()
	check(buy.disabled, "Buy button enabled with too few gems")
	GlobalPlayer.add_gems(1)
	shop.refresh()
	check(not buy.disabled, "Buy button disabled with enough gems")
	buy.pressed.emit()
	check(GlobalPlayer.has_weapon(axe) and GlobalPlayer.get_weapon() == axe and GlobalPlayer.get_gems() == 0, "Shop did not sell and equip the axe")
	check(buy.disabled, "Buy button still enabled after purchase")
	shop.queue_free()
	await get_tree().process_frame
	print("weapons_test failures: ", failures)
	get_tree().quit(failures)
