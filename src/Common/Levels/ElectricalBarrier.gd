extends Node2D

signal is_visible
signal opened(barrier)

var energy_count=0
var max_energy=6

# La jauge a 7 images (0 à 6) quel que soit max_energy
const PROGRESS_LAST_FRAME=6

@export var type :=   Game.ENEMY_TYPE_LIST.ANT # (Game.ENEMY_TYPE_LIST)

@onready var _animatedSprite :=get_node("AnimatedSprite2D")
@onready var _animatedSpriteProgress :=get_node("AnimatedSprite2")

@onready var _barrier := get_node("barrier")
@onready var _bolt: Bolt = get_node("barrier/Bolt")
@onready var _bolt_back: Bolt = get_node("barrier/BoltBack")
@onready var _halo: Sprite2D = get_node("barrier/Halo")
@onready var _sparks_top: CPUParticles2D = get_node("barrier/SparksTop")
@onready var _sparks_bottom: CPUParticles2D = get_node("barrier/SparksBottom")
@onready var _arc_timer: Timer = get_node("barrier/Timer")
@onready var _collisision := get_node("StaticBody2D/CollisionShape2D")

@onready var _icons := get_node("icons")


var _type_icon_list :={}

# Arc vertical, en coordonnées du nœud barrier (comme l'ancien Line2D)
const ARC_TOP := Vector2(1, 1)
const ARC_BOTTOM := Vector2(1, 85)
# Instabilité selon la charge (0 = vide, 1 = pleine)
const JAGGEDNESS_MIN := 0.035
const JAGGEDNESS_MAX := 0.09
const REGEN_SLOW := 0.08
const REGEN_FAST := 0.05
const SHORT_CIRCUIT_TIME := 0.4

var _color := Color.WHITE
# 1 juste après un increment(), redescend à 0
var _flash := 0.0
var _flash_tween: Tween
var _short_circuit_tween: Tween
var _short_circuit := false

func _ready() -> void:
	if Game.DEBUG_ENABLED:
		max_energy=1
	
	_animatedSprite.play()
	
	_type_icon_list ={
		Game.ENEMY_TYPE_LIST.ANT : get_node("icons/ant"),
		Game.ENEMY_TYPE_LIST.SPIDER : get_node("icons/spider"),
		Game.ENEMY_TYPE_LIST.BEETLE : get_node("icons/beetle")
	}
	
	for icon_loop in _icons.get_children():
		icon_loop.visible=false
		
	_type_icon_list[type].visible=true

	_arc_timer.timeout.connect(_on_arc_tick)
	var notifier: VisibleOnScreenNotifier2D = get_node("barrier/VisibleOnScreenNotifier2D")
	notifier.screen_entered.connect(func(): _arc_timer.paused = false)
	notifier.screen_exited.connect(func(): _arc_timer.paused = true)
	_apply_color()
	_reset_arcs()
	
func build():
	return
	
	_type_icon_list ={
		Game.ENEMY_TYPE_LIST.ANT : get_node("icons/ant"),
		Game.ENEMY_TYPE_LIST.SPIDER : get_node("icons/spider"),
		Game.ENEMY_TYPE_LIST.BEETLE : get_node("icons/beetle")
	}
	
	for icon_loop in _icons.get_children():
		icon_loop.visible=false
		
	_type_icon_list[type].visible=true

func set_type(type_):
	type=type_
	
	build()
	if is_node_ready():
		_apply_color()


func get_type():
	return type


func set_max_energy(value):
	if Game.DEBUG_ENABLED:
		return
	max_energy=value


func is_open() -> bool:
	return energy_count >= max_energy


func enable_barrier():
	if _short_circuit_tween:
		_short_circuit_tween.kill()
	_short_circuit=false
	_barrier.visible=true
	_collisision.disabled=false
	_arc_timer.start()
	_reset_arcs()
	
# La collision tombe tout de suite ; seul l'effet visuel (court-circuit) dure un peu
func disable_barrier():
	_collisision.disabled=true
	_start_short_circuit()
	
func increment():
	energy_count+=1
	if energy_count > max_energy:
		return
		energy_count=0
		enable_barrier()
		
	_animatedSpriteProgress.frame=int(floor(energy_count * PROGRESS_LAST_FRAME / float(max_energy)))
	Sound.play("energy", 0.0, 0.0, 1.0 + 0.08 * energy_count)
	pulse()
	if energy_count < max_energy:
		_charge_arc()
	
	if energy_count==max_energy:
		disable_barrier()
		Sound.play("barrier_open", 0.0)
		emit_signal("opened", self)


func pulse() -> void:
	var tween := create_tween()
	tween.tween_property(_animatedSpriteProgress, "scale", Vector2(1.4, 1.4), 0.08)
	tween.tween_property(_animatedSpriteProgress, "scale", Vector2.ONE, 0.12)


func _on_VisibilityNotifier2D_screen_entered() -> void:
	emit_signal("is_visible")
	pass # Replace with function body.


func _charge_ratio() -> float:
	return clampf(energy_count / float(max_energy), 0.0, 1.0)


func _apply_color() -> void:
	_color = Fx.enemy_color(type)
	_bolt.color = _color
	_bolt_back.color = _color.lightened(0.2)
	var spark := _color.lightened(0.5)
	_sparks_top.color = Color(spark.r * 1.5, spark.g * 1.5, spark.b * 1.5)
	_sparks_bottom.color = _sparks_top.color
	_update_look()


func _reset_arcs() -> void:
	_bolt.set_ends(ARC_TOP, ARC_BOTTOM)
	_bolt_back.set_ends(ARC_TOP, ARC_BOTTOM)
	_regenerate_arcs()
	_update_look()


# Plus la barrière est chargée, plus l'arc est tordu et change vite
func _regenerate_arcs() -> void:
	var ratio := _charge_ratio()
	var jaggedness := lerpf(JAGGEDNESS_MIN, JAGGEDNESS_MAX, ratio) * (1.0 + 1.5 * _flash)
	_bolt.jaggedness = jaggedness
	# branche seulement en fin de charge ou sur un arc de charge : elle déborde sur la barrière voisine
	_bolt.branch_count = 1 if ratio >= 0.8 or _flash > 0.5 else 0
	_bolt_back.jaggedness = jaggedness * 1.4
	_bolt.regenerate()
	_bolt_back.regenerate()
	_arc_timer.wait_time = lerpf(REGEN_SLOW, REGEN_FAST, ratio) * randf_range(0.8, 1.2)


func _update_look() -> void:
	if _short_circuit:
		return
	var ratio := _charge_ratio()
	_bolt.set_intensity(1.0 + 0.25 * ratio + 0.5 * _flash)
	_bolt_back.set_intensity(0.55 + 0.25 * ratio + 0.4 * _flash)
	_halo.self_modulate = Color(_color, 0.16 + 0.12 * ratio + 0.15 * _flash)
	var sparks := ratio >= 0.5 or _flash > 0.0
	_sparks_top.emitting = sparks
	_sparks_bottom.emitting = sparks
	_sparks_top.speed_scale = 0.6 + ratio
	_sparks_bottom.speed_scale = _sparks_top.speed_scale


func _on_arc_tick() -> void:
	if _short_circuit:
		_short_circuit_tick()
	else:
		_regenerate_arcs()


# Arc bref et plus brillant à chaque énergie reçue
func _charge_arc() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash = 1.0
	_regenerate_arcs()
	_update_look()
	_flash_tween = create_tween()
	_flash_tween.tween_method(func(value: float):
		_flash = value
		_update_look()
	, 1.0, 0.0, 0.25)


# Ouverture : arcs brisés qui crépitent puis s'éteignent
func _start_short_circuit() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash = 0.0
	_short_circuit = true
	_sparks_top.emitting = true
	_sparks_bottom.emitting = true
	_sparks_top.speed_scale = 2.0
	_sparks_bottom.speed_scale = 2.0
	var middle: Vector2 = _barrier.global_position + (ARC_TOP + ARC_BOTTOM) * 0.5
	Fx.burst(self, _barrier.global_position + ARC_TOP, _color.lightened(0.4), 14)
	Fx.burst(self, middle, _color.lightened(0.4), 10)
	_bolt.set_intensity(2.0)
	_bolt_back.set_intensity(1.6)
	_halo.self_modulate = Color(_color, 0.6)
	_short_circuit_tick()
	# le minuteur peut être en pause hors écran : un tween garantit la fin
	_arc_timer.paused = false
	_arc_timer.start(0.04)

	if _short_circuit_tween:
		_short_circuit_tween.kill()
	_short_circuit_tween = create_tween()
	_short_circuit_tween.tween_method(func(value: float):
		_bolt.set_intensity(value)
		_bolt_back.set_intensity(value * 0.8)
		_halo.self_modulate = Color(_color, 0.3 * value)
	, 2.0, 0.0, SHORT_CIRCUIT_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_short_circuit_tween.tween_callback(_end_short_circuit)


func _short_circuit_tick() -> void:
	# coupure à une hauteur au hasard : deux tronçons séparés par un trou
	var cut := randi_range(int(ARC_TOP.y) + 16, int(ARC_BOTTOM.y) - 24)
	var gap := randi_range(5, 14)
	_bolt.jaggedness = 0.3
	_bolt.branch_count = 1
	_bolt_back.jaggedness = 0.3
	_bolt.set_ends(ARC_TOP, Vector2(ARC_TOP.x, cut))
	_bolt_back.set_ends(Vector2(ARC_TOP.x, cut + gap), ARC_BOTTOM)
	_bolt.regenerate()
	_bolt_back.regenerate()
	_arc_timer.wait_time = 0.04


func _end_short_circuit() -> void:
	_short_circuit = false
	_arc_timer.stop()
	_sparks_top.emitting = false
	_sparks_bottom.emitting = false
	_barrier.visible = false
