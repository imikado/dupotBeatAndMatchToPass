extends Node2D

signal fall_ended

const BOLT_COLOR = Color(0.55, 0.75, 1.0)
const SPARK_COLOR = Color(0.8, 0.92, 1.0)
const GLOW_PEAK = 0.45
const IMPACT_TIME = 0.5

@onready var _sprite:=get_node("Sprite2D")
@onready var _hitBox:=get_node("HitBox/CollisionShape2D")
@onready var _bolt:=get_node("AnimatedSprite2D")


var _damage:=20

var _glow: Sprite2D
var _impact_glow: Sprite2D
var _light: PointLight2D
var _has_light := false
var _glow_tween: Tween

func _ready() -> void:
	build_light_effects()
	hide_impact()


func build_light_effects() -> void:
	# soft beam of light around the bolt
	_glow = Sprite2D.new()
	_glow.texture = Fx.column_texture()
	_glow.material = Fx.additive_material()
	_glow.position = _bolt.position
	_glow.scale = Vector2(0.55, 25)
	_glow.modulate = Color(BOLT_COLOR, 0.0)
	_glow.show_behind_parent = true
	add_child(_glow)
	move_child(_glow, 0)

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


func start_fall():

	hide_impact()

	$AnimationPlayer.stop(true)
	$AnimationPlayer.play("storm")

	if _glow_tween:
		_glow_tween.kill()
	_glow.modulate.a = 0.0
	_glow_tween = create_tween()
	# the bolt sprite draws itself downward until 0.5s, then the full bolt hits the ground
	_glow_tween.tween_interval(IMPACT_TIME)
	_glow_tween.tween_property(_glow, "modulate:a", GLOW_PEAK, 0.02)
	_glow_tween.tween_property(_glow, "modulate:a", GLOW_PEAK * 0.3, 0.05)
	_glow_tween.tween_property(_glow, "modulate:a", GLOW_PEAK, 0.03)
	_glow_tween.tween_interval(0.05)
	_glow_tween.tween_property(_glow, "modulate:a", 0.0, 0.2)


func end_fall():
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
	Fx.burst(world, _sprite.global_position, SPARK_COLOR, 10)

func hide_impact():
	_sprite.visible=false
	_hitBox.disabled=true

	#emit_signal("fall_ended")


func _on_HitBox_body_entered(body: Node) -> void:
	if body.is_in_group(Game.GROUP_ENEMY):
		Events.emit_signal("actor_took_damage",body,_damage)
	pass # Replace with function body.
