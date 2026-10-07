extends Node2D

const NEXT_SCENE = "res://src/UI/menu.tscn"

@onready var _title := get_node("Title")

var _press_label: Label
var _can_continue := false


func _ready():
	var keyboardOsList=["HTML5","Web","X11","Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD","Windows"]

	var osName= OS.get_name()
	if(keyboardOsList.find(osName)!=-1):
		Game.setControlsEnabled(false)

	Fx.fireflies(self)
	build_press_label()
	animate_intro()

	Sound.play_music()


func build_press_label() -> void:
	_press_label = Label.new()
	_press_label.text = "PRESS START" if not Game.isControlsEnabled() else "TOUCH TO START"
	_press_label.add_theme_font_override("font", Fx.FONT)
	_press_label.add_theme_font_size_override("font_size", 5)
	_press_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_press_label.add_theme_constant_override("outline_size", 3)
	_press_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_press_label.position = Vector2(0, 156)
	_press_label.size = Vector2(320, 12)
	_press_label.modulate.a = 0.0
	add_child(_press_label)


func animate_intro() -> void:
	var final_scale: Vector2 = _title.scale
	var final_y: float = _title.position.y
	_title.scale = final_scale * 0.2
	_title.position.y = final_y - 60
	_title.modulate.a = 0.0

	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.size = Vector2(320, 180)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 10
	add_child(flash)

	var tween := create_tween()
	tween.tween_interval(0.3)
	tween.tween_property(_title, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(_title, "scale", final_scale, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_title, "position:y", final_y, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(Sound.play.bind("thunder", 0.0))
	tween.tween_property(flash, "color:a", 0.7, 0.04)
	tween.parallel().tween_callback(shake.bind(4.0))
	tween.tween_property(flash, "color:a", 0.0, 0.35)
	tween.tween_callback(func(): _can_continue = true)
	tween.tween_property(_press_label, "modulate:a", 1.0, 0.3)
	tween.tween_callback(start_idle_animation.bind(final_y))


func shake(strength: float) -> void:
	var tween := create_tween()
	for i in range(6):
		var decay = 1.0 - i / 6.0
		tween.tween_property(self, "position", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * decay, 0.04)
	tween.tween_property(self, "position", Vector2.ZERO, 0.04)


func start_idle_animation(final_y: float) -> void:
	var bob := create_tween().set_loops()
	bob.tween_property(_title, "position:y", final_y - 3, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_title, "position:y", final_y, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var blink := create_tween().set_loops()
	blink.tween_property(_press_label, "modulate:a", 0.2, 0.5)
	blink.tween_property(_press_label, "modulate:a", 1.0, 0.5)


func _input(event: InputEvent) -> void:
	if not _can_continue:
		return
	if (event is InputEventKey or event is InputEventJoypadButton or event is InputEventScreenTouch or event is InputEventMouseButton) and event.is_pressed():
		_can_continue = false
		Sound.play("menu_select", 0.0)
		Transition.goto(NEXT_SCENE)
