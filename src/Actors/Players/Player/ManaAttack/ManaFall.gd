extends Node2D

# Un éclair de l'orage : l'origine du nœud est le point d'impact au sol.
# start_fall() lance une frappe d'environ 0,35 s (traceur, décharge, scintillement, extinction)

signal fall_ended
# émis au moment de la décharge (éclair complet, dégâts actifs)
signal discharged(bolt)

const BOLT_COLOR = Color(0.55, 0.75, 1.0)
const SPARK_COLOR = Color(0.8, 0.92, 1.0)
const RING_COLOR = Color(1.3, 1.5, 1.9)

# minutage d'une frappe (secondes, après le délai)
const TRACER_TIME = 0.10
const TRACER_STEPS = 5
const FLICKER_TIMES = [0.13, 0.18]
const FADE_START = 0.25
const FADE_TIME = 0.10
const IMPACT_DURATION = 0.2

const TRACER_INTENSITY = 0.4
const DISCHARGE_INTENSITY = 1.3
# l'éclair part de ce nombre de pixels au-dessus du haut de l'écran
const TOP_MARGIN = 6.0

@onready var _sprite:=get_node("Sprite2D")
@onready var _hitBox:=get_node("HitBox/CollisionShape2D")


var _damage:=20

var _bolt: Bolt
var _impact_glow: Sprite2D
var _light: PointLight2D
var _has_light := false
var _tween: Tween
var _striking := false
var _thickness := 1.0

func _ready() -> void:
	build_light_effects()
	hide_impact()


func build_light_effects() -> void:
	_bolt = Bolt.new()
	_bolt.color = BOLT_COLOR
	_bolt.jaggedness = 0.18
	_bolt.branch_count = 1
	# devant les personnages, sous les anneaux de Fx (50)
	_bolt.z_index = 40
	_bolt.set_intensity(0.0)
	add_child(_bolt)

	# flash on the ground where the bolt hits
	_impact_glow = Sprite2D.new()
	_impact_glow.texture = Fx.radial_texture()
	_impact_glow.material = Fx.additive_material()
	_impact_glow.position = _sprite.position
	_impact_glow.modulate = Color(BOLT_COLOR, 0.0)
	add_child(_impact_glow)

	_light = Fx.light(self, BOLT_COLOR, 1.1)
	_light.position = _sprite.position


# only some bolts carry a real 2D light, to keep the cost low on mobile
func set_has_light(value: bool) -> void:
	_has_light = value


func is_striking() -> bool:
	return _striking


# delay : attente avant le traceur (désynchronise les éclairs d'une salve)
func start_fall(delay := 0.0):

	hide_impact()

	if _tween:
		_tween.kill()
	_striking = true
	_bolt.set_intensity(0.0)
	_bolt.reveal(0.0)

	_tween = create_tween()
	if delay > 0.0:
		_tween.tween_interval(delay)
	_tween.tween_callback(_begin_tracer)
	# traceur : descend par paliers
	for i in range(1, TRACER_STEPS + 1):
		_tween.tween_interval(TRACER_TIME / TRACER_STEPS)
		_tween.tween_callback(_bolt.reveal.bind(float(i) / TRACER_STEPS))
	# décharge
	_tween.tween_callback(_discharge)
	# scintillement : nouvelle forme, intensité qui oscille
	var at := TRACER_TIME
	var flicker_values := [[0.7, 1.15], [0.9, 1.05]]
	for i in range(FLICKER_TIMES.size()):
		_tween.tween_interval(FLICKER_TIMES[i] - at)
		_tween.tween_callback(_flicker.bind(flicker_values[i][0]))
		_tween.tween_interval(0.025)
		_tween.tween_callback(_bolt.set_intensity.bind(flicker_values[i][1]))
		at = FLICKER_TIMES[i] + 0.025
	_tween.tween_interval(FADE_START - at)
	# extinction
	_tween.tween_method(_fade, 1.0, 0.0, FADE_TIME)
	_tween.tween_callback(end_fall)


func _begin_tracer() -> void:
	_thickness = randf_range(0.8, 1.15)
	_bolt.thickness = _thickness * 0.6
	# 0 ou 1 branche : une salve compte 8 éclairs, plus de branches blanchissent l'écran
	_bolt.branch_count = randi_range(0, 1)
	# le haut de l'éclair part au-dessus de l'écran visible, légèrement décalé
	var screen_top := (get_viewport().get_canvas_transform().affine_inverse() * Vector2.ZERO).y
	var top := Vector2(roundf(randf_range(-18, 18)), roundf(screen_top - global_position.y - TOP_MARGIN))
	_bolt.set_ends(top, Vector2.ZERO)
	_bolt.regenerate()
	_bolt.reveal(0.0)
	_bolt.set_intensity(TRACER_INTENSITY)


func _discharge() -> void:
	_bolt.thickness = _thickness
	_bolt.reveal(1.0)
	_bolt.set_intensity(DISCHARGE_INTENSITY)
	display_impact()
	emit_signal("discharged", self)


func _flicker(intensity: float) -> void:
	_bolt.regenerate()
	_bolt.set_intensity(intensity)


func _fade(value: float) -> void:
	_bolt.thickness = _thickness * value
	_bolt.set_intensity(1.2 * value)
	if value < 0.5 and not _hitBox.disabled:
		hide_impact()


func end_fall():
	_striking = false
	hide_impact()
	_bolt.set_intensity(0.0)
	emit_signal("fall_ended")


func display_impact():
	_hitBox.disabled=false
	_sprite.visible=true

	_impact_glow.scale = Vector2(0.1, 0.05)
	_impact_glow.modulate.a = 0.6
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_impact_glow, "scale", Vector2(0.35, 0.14), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(_impact_glow, "modulate:a", 0.0, 0.4)

	if _has_light:
		_light.enabled = true
		_light.energy = 1.3
		tween.tween_property(_light, "energy", 0.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tween.chain().tween_callback(func(): _light.enabled = false)

	# sparks live in the world, not in the bolt list (which is iterated by the player)
	var world = get_tree().current_scene if get_tree().current_scene else owner.get_parent()
	var ground := global_position
	Fx.burst(world, _sprite.global_position, SPARK_COLOR, 10)
	Fx.ring(world, ground, RING_COLOR, randf_range(16, 22), 0.3)
	# marque brûlée sous les personnages (conteneur y-sort du joueur)
	var characters = owner.get_parent() if owner and owner.get_parent() else world
	Fx.scorch(characters, ground, randi_range(12, 16), 1.4)

func hide_impact():
	_sprite.visible=false
	_hitBox.disabled=true

	#emit_signal("fall_ended")


func _on_HitBox_body_entered(body: Node) -> void:
	if body.is_in_group(Game.GROUP_ENEMY):
		Events.emit_signal("actor_took_damage",body,_damage)
		Events.emit_signal("actor_struck_by_lightning",body)
	pass # Replace with function body.
