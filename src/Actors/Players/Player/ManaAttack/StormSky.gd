class_name StormSky
extends Node2D

# Ciel d'orage de l'attaque mana : bande de nuages sombres en haut de l'écran
# et pluie fine, en espace caméra (le nœud suit le coin haut gauche de l'écran).
# Créé par le joueur (mana_cast_begin), retiré par close().

const CLOUD_HEIGHT = 40
const CLOUD_MARGIN = 32
const CLOUD_DRIFT = 4.0
# avant CanvasModulate (assombri par l'orage)
const CLOUD_DARK = Color(0.26, 0.27, 0.38)
const CLOUD_MID = Color(0.40, 0.42, 0.56)
const CLOUD_RIM = Color(0.62, 0.66, 0.82)
const CLOUD_FLASH = Color(1.6, 1.6, 1.9)
const FLASH_COLOR = Color(0.55, 0.75, 1.0, 0.55)
const RAIN_COLOR = Color(0.85, 0.92, 1.0, 0.6)
const FADE_IN = 0.35
const FADE_OUT = 0.4

static var _cloud_texture: ImageTexture
static var _rain_texture: ImageTexture

var _clouds: Sprite2D
var _rain: CPUParticles2D
var _cloud_y := 0.0
var _cloud_x := 0.0
var _flash_tween: Tween
var _closing := false


func _ready() -> void:
	top_level = true
	# au-dessus des personnages et des éclairs (40), sous les anneaux de Fx (50)
	z_index = 45
	var screen := get_viewport_rect().size

	_clouds = Sprite2D.new()
	_clouds.texture = cloud_texture(int(screen.x) + CLOUD_MARGIN)
	_clouds.centered = false
	_clouds.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_clouds.modulate.a = 0.0
	add_child(_clouds)
	_cloud_y = -CLOUD_HEIGHT

	_rain = CPUParticles2D.new()
	_rain.texture = rain_texture()
	_rain.local_coords = true
	_rain.amount = 70
	_rain.lifetime = 0.75
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(screen.x * 0.5 + 40, 2)
	_rain.position = Vector2(screen.x * 0.5 + 30, -4)
	_rain.direction = Vector2(-0.4, 1.0)
	_rain.spread = 0.0
	_rain.gravity = Vector2.ZERO
	_rain.initial_velocity_min = 260.0
	_rain.initial_velocity_max = 320.0
	_rain.color = RAIN_COLOR
	_rain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_rain)
	# pluie derrière les nuages
	move_child(_rain, 0)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_clouds, "modulate:a", 1.0, FADE_IN)
	tween.tween_property(self, "_cloud_y", 0.0, FADE_IN).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_follow_camera()


func _process(delta: float) -> void:
	_cloud_x = fmod(_cloud_x + CLOUD_DRIFT * delta, CLOUD_MARGIN)
	_follow_camera()


func _follow_camera() -> void:
	global_position = (get_viewport().get_canvas_transform().affine_inverse() * Vector2.ZERO).round()
	_clouds.position = Vector2(-roundf(_cloud_x), roundf(_cloud_y))


# éclair au sol à la position x (globale) : les nuages s'éclairent, plus fort au-dessus de l'éclair
func flash(global_x: float) -> void:
	if _closing:
		return
	if _flash_tween:
		_flash_tween.kill()
	_clouds.self_modulate = CLOUD_FLASH
	_flash_tween = create_tween()
	_flash_tween.tween_property(_clouds, "self_modulate", Color.WHITE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	var glow := Sprite2D.new()
	glow.texture = Fx.radial_texture()
	glow.material = Fx.additive_material()
	glow.modulate = FLASH_COLOR
	glow.scale = Vector2(0.7, 0.3)
	add_child(glow)
	glow.position = Vector2(roundf(global_x - global_position.x), roundf(CLOUD_HEIGHT * 0.45))
	var tween := glow.create_tween()
	tween.tween_property(glow, "modulate:a", 0.0, 0.2)
	tween.tween_callback(glow.queue_free)


func close() -> void:
	if _closing:
		return
	_closing = true
	_rain.emitting = false
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_clouds, "modulate:a", 0.0, FADE_OUT)
	tween.tween_property(self, "_cloud_y", -CLOUD_HEIGHT * 0.5, FADE_OUT).set_ease(Tween.EASE_IN)
	tween.chain().tween_interval(maxf(_rain.lifetime - FADE_OUT, 0.0))
	tween.chain().tween_callback(queue_free)


# Bande de nuages en pixels : dessus uni, dessous bosselé (disques), liseré clair sous les bosses
static func cloud_texture(width: int) -> ImageTexture:
	if _cloud_texture != null and _cloud_texture.get_width() == width:
		return _cloud_texture
	var height := CLOUD_HEIGHT
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# disques : [centre x, centre y, rayon]
	var lumps := []
	var x := -6.0
	while x < width + 12:
		lumps.append([x, rng.randf_range(10, 20), rng.randf_range(8, 15)])
		x += rng.randf_range(12, 22)
	# petites bosses plus basses, qui pendent sous la bande
	x = rng.randf_range(0, 20)
	while x < width:
		lumps.append([x, rng.randf_range(22, 28), rng.randf_range(4, 8)])
		x += rng.randf_range(26, 50)

	# indice du disque le plus bas qui contient chaque pixel (-1 sinon), une ligne de plus
	# en bas pour le liseré ; rempli disque par disque sur sa boîte (pas pixel × disques)
	var stride := width
	var owner_index := PackedInt32Array()
	owner_index.resize(width * (height + 1))
	owner_index.fill(-1)
	var owner_y := PackedFloat32Array()
	owner_y.resize(width * (height + 1))
	owner_y.fill(-1000.0)
	for i in range(lumps.size()):
		var lump: Array = lumps[i]
		var radius: float = lump[2]
		for py in range(maxi(9, floori(lump[1] - radius)), mini(height + 1, ceili(lump[1] + radius) + 1)):
			for px in range(maxi(0, floori(lump[0] - radius)), mini(width, ceili(lump[0] + radius) + 1)):
				var dx: float = px + 0.5 - lump[0]
				var dy: float = py + 0.5 - lump[1]
				var cell := py * stride + px
				if dx * dx + dy * dy <= radius * radius and lump[1] > owner_y[cell]:
					owner_index[cell] = i
					owner_y[cell] = lump[1]
	for cell in range(9 * stride):
		owner_index[cell] = 0

	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for py in range(height):
		for px in range(width):
			var index: int = owner_index[py * stride + px]
			if index < 0:
				continue
			var color := CLOUD_DARK
			if owner_index[(py + 1) * stride + px] < 0:
				color = CLOUD_RIM
			elif index > 0:
				var lump: Array = lumps[index]
				# moitié basse des bosses : plus claire, avec un damier de transition
				var rel: float = (py + 0.5 - lump[1]) / lump[2]
				if rel > 0.35 or (rel > 0.05 and (px + py) % 2 == 0):
					color = CLOUD_MID
			image.set_pixel(px, py, color)
	_cloud_texture = ImageTexture.create_from_image(image)
	return _cloud_texture


# goutte : trait penché de 6 px (même pente que la direction de la pluie)
static func rain_texture() -> ImageTexture:
	if _rain_texture == null:
		var image := Image.create(3, 6, false, Image.FORMAT_RGBA8)
		for point in [Vector2i(2, 0), Vector2i(2, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(0, 4), Vector2i(0, 5)]:
			image.set_pixelv(point, Color.WHITE)
		_rain_texture = ImageTexture.create_from_image(image)
	return _rain_texture
