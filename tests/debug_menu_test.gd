extends Node

var _failures := 0


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _ready() -> void:
	run.call_deferred()


func run() -> void:
	var enabled := OS.get_environment("DEBUG") == "1"
	var menu = load("res://src/UI/menu.tscn").instantiate()
	add_child(menu)
	check(menu.has_node("Control/debugButton") == enabled, "DEBUG menu visibility does not match environment")
	check(menu._buttonList.size() == (6 if enabled else 5), "Incorrect menu navigation entries")
	menu.queue_free()
	await get_tree().process_frame
	Transition._is_busy = true
	var selector = load("res://src/UI/DebugSelect.tscn").instantiate()
	add_child(selector)
	if enabled:
		selector.change_level(-10)
		check(selector._level == 1, "Level must stay positive")
		selector.change_level(6)
		check(selector._buttons[0].get_node("Label").text == "LEVEL 07", "Selected level is not displayed")
		for index in [1, 2]:
			selector._leaving = false
			GlobalPlayer.two_players = true
			GlobalPlayer.life = 3
			GlobalPlayer.save_score(100)
			selector.choose(index)
			check(GlobalPlayer.get_level() == 7, "Launch did not apply chosen level")
			check(not GlobalPlayer.two_players and GlobalPlayer.life == 100 and GlobalPlayer.get_score() == 0, "Launch did not reset solo game")
			var path := "res://src/Levels/LevelTemplate.tscn" if index == 1 else "res://src/Levels/LevelBonus.tscn"
			var level = load(path).instantiate()
			add_child(level)
			await get_tree().process_frame
			check(level.get_node("Node2D/Player").is_alive(), "Direct launch player is not alive")
			level.queue_free()
			await get_tree().process_frame
	else:
		check(selector._leaving and selector._buttons.is_empty(), "Debug selector must reject access without DEBUG=1")
	selector.queue_free()
	await get_tree().process_frame
	print("DEBUG MENU TESTS: ", "PASS" if _failures == 0 else "FAIL")
	get_tree().quit(0 if _failures == 0 else 1)
