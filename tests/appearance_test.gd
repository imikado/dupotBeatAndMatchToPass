extends Node

var _failures := 0


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _ready() -> void:
	run.call_deferred()


func run() -> void:
	PlayerInput.save_enabled = false
	for scene in ["Player", "Player2"]:
		var player: Player = load("res://src/Actors/Players/%s.tscn" % scene).instantiate()
		add_child(player)
		await get_tree().process_frame
		player.get_node("StateMachine").set_active(false)
		player.get_node("BodyPivot/AnimationPlayer").stop()
		var sprite: AnimatedSprite2D = player.get_node("BodyPivot/AnimatedSprite2D")
		var frames := sprite.sprite_frames
		for attack in range(1, 5):
			for i in range(4):
				var source_index := i if attack % 2 == 1 else i + 4
				var actual := frames.get_frame_texture("attacking%02d" % attack, i).get_image()
				var approved := frames.get_frame_texture("combo_cross", source_index).get_image()
				check(actual.get_data() == approved.get_data(), "Basic sword attack uses a different character design")
		for animation in ["idle", "walk_right", "damaged_right", "attacking_mana01", "getLifeBootle", "gameover"]:
			for i in range(frames.get_frame_count(animation)):
				var image := frames.get_frame_texture(animation, i).get_image()
				var bottom := image.get_used_rect().end.y
				var ground := sprite.to_global(Vector2(0, bottom - 32))
				check(absf(ground.y - player.global_position.y) < 0.01, "Floating or sinking feet in " + animation)
		var raised_blade := frames.get_frame_texture("attacking_mana01", 2).get_image()
		var top := raised_blade.get_used_rect().position.y
		var tip := sprite.to_global(Vector2(0, top - 32))
		check(absf(tip.y - player.to_global(Player.SWORD_TIP).y) <= 1.0, "Lightning origin misses the raised sword")
		player.queue_free()
		await get_tree().process_frame
	print("APPEARANCE TESTS: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
