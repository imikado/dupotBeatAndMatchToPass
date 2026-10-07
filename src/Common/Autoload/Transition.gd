extends CanvasLayer

const FADE_OUT_DURATION = 0.2
const FADE_IN_DURATION = 0.25

var _fade: ColorRect
var _is_busy := false
var _scene_cache := {}


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)


func cache_scene(path: String, scene: PackedScene) -> void:
	_scene_cache[path] = scene


func get_scene(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	return _scene_cache[path]


func is_busy() -> bool:
	return _is_busy


func goto(path: String, fade_color: Color = Color.BLACK) -> void:
	if _is_busy:
		return
	_is_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP

	_fade.color = Color(fade_color, 0.0)
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_OUT_DURATION)
	await tween.finished

	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_packed(get_scene(path))
	await get_tree().process_frame
	await get_tree().process_frame

	tween = create_tween()
	tween.tween_property(_fade, "color:a", 0.0, FADE_IN_DURATION)
	await tween.finished

	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_busy = false
