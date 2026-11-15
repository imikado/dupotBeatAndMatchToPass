class_name Bomb
extends Node2D

# Bombe lancée par le joueur : vole en cloche jusqu'au sol (le nœud suit le sol pour
# le tri en profondeur, le sprite porte la hauteur), mèche qui clignote, puis explosion
# qui blesse tous les ennemis de la zone (ellipse, comme les coups de zone).

const FLIGHT = 0.42
const ARC = 24.0
const FUSE = 0.55
const DAMAGE = 26
const DAMAGE_HEAVY = 36
const RADIUS = Vector2(34, 15)
const RADIUS_HEAVY = Vector2(44, 19)
const FIRE = Color(1.0, 0.62, 0.25)
const FIRE_LIGHT = Color(1.0, 0.9, 0.55)
const SMOKE = Color(0.35, 0.33, 0.38)
const OUTLINE = Color("140c1c")
const BODY = Color("2b2d42")
const BODY_LIGHT = Color("5c6380")
const FUSE_COLOR = Color("aa703e")

static var _texture: ImageTexture

var thrower: Player
var heavy := false
var _sprite: Sprite2D
var _spark: CPUParticles2D
var _start_height := 0.0
var _exploded := false


func _ready() -> void:
	Fx.shadow(self, 8).position = Vector2(0, 1)
	_sprite = Sprite2D.new()
	_sprite.texture = texture()
	_sprite.offset = Vector2(0, -4)
	add_child(_sprite)

	_spark = CPUParticles2D.new()
	_spark.amount = 8
	_spark.lifetime = 0.25
	_spark.position = Vector2(2, -9)
	_spark.direction = Vector2.UP
	_spark.spread = 60.0
	_spark.gravity = Vector2(0, 40)
	_spark.initial_velocity_min = 10.0
	_spark.initial_velocity_max = 25.0
	_spark.color = FIRE_LIGHT
	_spark.material = Fx.additive_material()
	_sprite.add_child(_spark)


# from : position de la main (en l'air), to : point d'impact au sol
func launch(from: Vector2, to: Vector2) -> void:
	var ground_start := Vector2(from.x, to.y)
	global_position = ground_start.round()
	_start_height = from.y - to.y
	_sprite.position.y = _start_height
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", to.round(), FLIGHT)
	tween.tween_method(_set_flight, 0.0, 1.0, FLIGHT)
	tween.tween_property(_sprite, "rotation", TAU * signf(to.x - from.x), FLIGHT)
	tween.chain().tween_callback(_landed)


func _set_flight(t: float) -> void:
	_sprite.position.y = roundf(lerpf(_start_height, 0.0, t) - ARC * 4.0 * t * (1.0 - t))


func _landed() -> void:
	_sprite.rotation = 0.0
	Fx.dust(get_parent(), global_position, -1)
	var tween := create_tween()
	tween.tween_property(_sprite, "position:y", -4.0, 0.08).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "position:y", 0.0, 0.08).set_ease(Tween.EASE_IN)
	# mèche : clignote de plus en plus vite
	var blink := create_tween()
	var step := 0.12
	var elapsed := 0.16
	while elapsed < FUSE:
		blink.tween_property(_sprite, "modulate", Color(2.0, 0.6, 0.5), step * 0.5)
		blink.tween_property(_sprite, "modulate", Color.WHITE, step * 0.5)
		elapsed += step
		step = maxf(step * 0.75, 0.04)
	get_tree().create_timer(FUSE, false).timeout.connect(explode)


func explode() -> void:
	if _exploded:
		return
	_exploded = true
	var radius := RADIUS_HEAVY if heavy else RADIUS
	var world := get_parent()
	var center := global_position

	var impact := preload("res://src/Common/Effects/GroundImpact.gd").new()
	impact.radius = radius
	world.add_child(impact)
	impact.global_position = center.round()
	Fx.burst(world, center + Vector2(0, -6), FIRE, 22)
	Fx.burst(world, center + Vector2(0, -10), FIRE_LIGHT, 10)
	Fx.burst(world, center + Vector2(0, -14), SMOKE, 10)
	Fx.ring(world, center, FIRE, radius.x, 0.35)
	Fx.scorch(world, center, int(radius.x * 0.7), 1.6)
	flash(world, center)
	Sound.play("thunder", 0.1, -2.0, 1.6)
	Sound.play("hit", 0.05, 3.0, 0.55)
	Game.hit_stop(0.04)

	if is_instance_valid(thrower):
		thrower.shake_camera(4.0 if heavy else 3.0, 0.25)
		for enemy in get_tree().get_nodes_in_group(Game.GROUP_ENEMY):
			if is_instance_valid(enemy) and enemy is Node2D and _inside(enemy.global_position, center, radius):
				enemy.last_attacker = thrower
				enemy.set("last_hit_by_storm", false)
				Events.emit_signal("actor_took_damage", enemy, thrower.attack_damage(DAMAGE_HEAVY if heavy else DAMAGE))
	queue_free()


func _inside(point: Vector2, center: Vector2, radius: Vector2) -> bool:
	return ((point - center) / radius).length_squared() <= 1.0


# éclair orange bref, additif (pas de PointLight2D)
func flash(world: Node, center: Vector2) -> void:
	var glow := Sprite2D.new()
	glow.texture = Fx.radial_texture()
	glow.material = Fx.additive_material()
	glow.modulate = Color(FIRE, 0.8)
	glow.scale = Vector2(0.7, 0.4)
	glow.z_index = 40
	world.add_child(glow)
	glow.global_position = center + Vector2(0, -6)
	var tween := glow.create_tween().set_parallel(true)
	tween.tween_property(glow, "modulate:a", 0.0, 0.3)
	tween.tween_property(glow, "scale", Vector2(1.0, 0.55), 0.3)
	tween.chain().tween_callback(glow.queue_free)


# Bombe 9x10 : boule sombre détourée, reflet, mèche
static func texture() -> ImageTexture:
	if _texture == null:
		var rows := [
			"......f..",
			".....f...",
			"....ooo..",
			"..ooBBBo.",
			".oBLBBBBo",
			".oLBBBBBo",
			".oBBBBBBo",
			".oBBBBBBo",
			"..oBBBBo.",
			"...oooo..",
		]
		var palette := {"o": OUTLINE, "B": BODY, "L": BODY_LIGHT, "f": FUSE_COLOR}
		var image := Image.create(9, rows.size(), false, Image.FORMAT_RGBA8)
		for y in range(rows.size()):
			for x in range(9):
				if rows[y][x] != ".":
					image.set_pixel(x, y, palette[rows[y][x]])
		_texture = ImageTexture.create_from_image(image)
	return _texture
