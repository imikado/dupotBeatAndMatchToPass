extends Control

const NEXT_SCENE = "res://src/UI/title.tscn"

# heavy scenes loaded in background while the logo is displayed
const SCENES_TO_PRELOAD = [
	"res://src/UI/title.tscn",
	"res://src/UI/menu.tscn",
	"res://src/Levels/LevelTemplate.tscn",
	"res://src/Levels/LevelBonus.tscn",
	"res://src/UI/LevelCompleted.tscn",
	"res://src/UI/GameOver.tscn",
]

const MIN_DISPLAY_TIME = 2.2

const BAR_WIDTH = 120.0
const BAR_COLOR_BG = Color(0.55, 0.2, 0.0, 1)
const BAR_COLOR_FILL = Color(1, 0.9, 0.75, 1)

@onready var _logo := get_node("Sprite2D")

var _bar_fill: ColorRect
var _elapsed := 0.0
var _progress := 0.0
var _is_loaded := false
var _is_leaving := false


func _ready():
	build_progress_bar()
	animate_logo()

	for path in SCENES_TO_PRELOAD:
		ResourceLoader.load_threaded_request(path)


func build_progress_bar() -> void:
	var bar_bg := ColorRect.new()
	bar_bg.color = BAR_COLOR_BG
	bar_bg.position = Vector2((320 - BAR_WIDTH) / 2, 150)
	bar_bg.size = Vector2(BAR_WIDTH, 3)
	add_child(bar_bg)

	_bar_fill = ColorRect.new()
	_bar_fill.color = BAR_COLOR_FILL
	_bar_fill.size = Vector2(0, 3)
	bar_bg.add_child(_bar_fill)

	bar_bg.modulate.a = 0.0
	create_tween().tween_property(bar_bg, "modulate:a", 1.0, 0.4).set_delay(0.5)


func animate_logo() -> void:
	var final_scale: Vector2 = _logo.scale
	_logo.scale = final_scale * 0.6
	_logo.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_interval(0.15)
	tween.tween_callback(Sound.play.bind("logo", 0.0))
	tween.tween_property(_logo, "modulate:a", 1.0, 0.35)
	tween.parallel().tween_property(_logo, "scale", final_scale, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_logo, "position:y", _logo.position.y - 2, 1.0).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	_elapsed += delta

	if not _is_loaded:
		update_loading()

	# the bar moves smoothly even when loading is instant
	var shown_progress = min(_progress, _elapsed / MIN_DISPLAY_TIME)
	_bar_fill.size.x = lerp(_bar_fill.size.x, BAR_WIDTH * shown_progress, min(1.0, delta * 12))

	if _is_loaded and _elapsed >= MIN_DISPLAY_TIME:
		leave()


func update_loading() -> void:
	var total := 0.0
	var loaded_count := 0
	for path in SCENES_TO_PRELOAD:
		var progress_array := []
		var status = ResourceLoader.load_threaded_get_status(path, progress_array)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			total += 1.0
			loaded_count += 1
		elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS and progress_array.size() > 0:
			total += progress_array[0]
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			# fallback: the scene will be loaded synchronously when needed
			total += 1.0
			loaded_count += 1

	_progress = total / SCENES_TO_PRELOAD.size()

	if loaded_count == SCENES_TO_PRELOAD.size():
		for path in SCENES_TO_PRELOAD:
			if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
				Transition.cache_scene(path, ResourceLoader.load_threaded_get(path))
		_is_loaded = true


func _input(event: InputEvent) -> void:
	# skip the logo once everything is loaded
	if _is_loaded and _elapsed > 0.8 and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventScreenTouch) and event.is_pressed():
		leave()


func leave() -> void:
	if _is_leaving:
		return
	_is_leaving = true
	Transition.goto(NEXT_SCENE)
