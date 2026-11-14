extends Node

var failures := 0
var checked := 0


func _ready() -> void:
	run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func scan(path: String) -> void:
	var directory := DirAccess.open(path)
	check(directory != null, "Cannot open " + path)
	if directory == null:
		return
	for file in directory.get_files():
		if file.get_extension() not in ["gd", "tscn", "tres"]:
			continue
		checked += 1
		var resource := load(path.path_join(file))
		check(resource != null, "Cannot load " + path.path_join(file))
		if resource is GDScript:
			check(resource.can_instantiate(), "Invalid script: " + path.path_join(file))
	for folder in directory.get_directories():
		scan(path.path_join(folder))


func run() -> void:
	PlayerInput.save_enabled = false
	for path in ["res://src", "res://tests", "res://addons"]:
		scan(path)
	var previous: bool = Game.isControlsEnabled()
	for enabled in [false, true]:
		Game.setControlsEnabled(enabled)
		var navigation = load("res://src/Common/UI/navigation.tscn").instantiate()
		add_child(navigation)
		check(navigation.get_node("joystick-big").visible == Game.isControlsEnabled(), "Navigation ignores touch settings")
		check(navigation.get_node("button").visible == Game.isControlsEnabled(), "Navigation button ignores touch settings")
		navigation.queue_free()
		await get_tree().process_frame
	Game.setControlsEnabled(previous)
	print("RESOURCE LOAD TESTS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures, " (", checked, " resources)")
	get_tree().quit(0 if failures == 0 else 1)
