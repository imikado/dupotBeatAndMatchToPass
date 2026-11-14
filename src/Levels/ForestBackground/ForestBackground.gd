extends Node2D

# Shared forest decor of LevelTemplate and LevelBonus: stepped sky, moon, twinkling stars,
# drifting clouds, 3 tree layers, bushes and the ground shading.
# Everything that scrolls stays a ParallaxLayer: Player.tint_world() darkens them during the storm.
# Instance it right after the ground TileMap: GroundShade is drawn over the ground, under the actors.

@export var tint := Color.WHITE    # multiplies every parallax layer (other mood for the bonus level)
@export var star_count := 15
@export var cloud_speed := 2.0     # pixels per second
@export_enum("Automatic:-1", "Forest:0", "Autumn:1", "Marsh:2", "Pines:3") var biome: int = -1

const BIOME_TEXTURES = [
	preload("res://src/Levels/LevelTemplate/background-trees-up.png"),
	preload("res://src/Levels/ForestBackground/biomes/autumn.png"),
	preload("res://src/Levels/ForestBackground/biomes/marsh.png"),
	preload("res://src/Levels/ForestBackground/biomes/pines.png"),
]
const BIOME_FOG = [Color("0a1926"), Color("30202b"), Color("102c30"), Color("192840")]
const BIOME_SKY = [Color("1c405a"), Color("65404b"), Color("28514c"), Color("39516c")]
const BIOME_GROUND = [Color.WHITE, Color("cbb18e"), Color("8db8a6"), Color("a3b5cf")]

const MIRROR := 620.0
const STAR_COLORS = [Color(0.85, 0.9, 1.0), Color(0.95, 0.92, 0.8), Color(0.7, 0.8, 1.0)]

@onready var _stars: ParallaxLayer = $ParallaxBackground/Stars
@onready var _moon: Sprite2D = $ParallaxBackground/Moon/moon
@onready var _clouds: ParallaxLayer = $ParallaxBackground/Clouds
@onready var _cloudsSprite: Sprite2D = $ParallaxBackground/Clouds/clouds

var _cloud_x := 0.0


func _ready() -> void:
	_apply_biome()
	for layer in find_children("*", "ParallaxLayer", true, false):
		layer.modulate *= tint
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	_moon.texture = _make_moon()
	_cloudsSprite.texture = _make_clouds(rng)
	_make_stars(rng)


func _apply_biome() -> void:
	var index := biome
	if index < 0:
		index = posmod(int(GlobalPlayer.get_level()) - 1, BIOME_TEXTURES.size())
	index = clampi(index, 0, BIOME_TEXTURES.size() - 1)
	if index == 0:
		return
	for layer_name in ["TreesFar", "TreesMid", "TreesNear"]:
		var tree := get_node("ParallaxBackground/" + layer_name + "/trees") as Sprite2D
		tree.texture = BIOME_TEXTURES[index]
		var shader_material := tree.material.duplicate() as ShaderMaterial
		shader_material.set_shader_parameter("fog_color", BIOME_FOG[index])
		tree.material = shader_material
	var sky := $ParallaxBackground/Sky/sky as Sprite2D
	var sky_texture := sky.texture.duplicate(true) as GradientTexture2D
	for i in sky_texture.gradient.get_point_count():
		var amount := float(i) / float(sky_texture.gradient.get_point_count() - 1)
		sky_texture.gradient.set_color(i, BIOME_FOG[index].darkened(0.65).lerp(BIOME_SKY[index], amount))
	sky.texture = sky_texture
	$ParallaxBackground2/Brushes/brushes.modulate = BIOME_GROUND[index]
	var ground := get_parent().get_node_or_null("ground") as CanvasItem
	if ground:
		ground.modulate = BIOME_GROUND[index]


func _process(delta: float) -> void:
	# whole pixels only, the mirroring wraps it around
	_cloud_x = fposmod(_cloud_x + cloud_speed * delta, MIRROR)
	_clouds.motion_offset.x = round(_cloud_x)


func _make_stars(rng: RandomNumberGenerator) -> void:
	var dot := _image_texture(PackedStringArray(["#"]))
	var cross := _image_texture(PackedStringArray([".+.", "+#+", ".+."]))
	for i in star_count:
		var star := Sprite2D.new()
		star.texture = cross if i % 5 == 0 else dot
		star.position = Vector2(rng.randi_range(-230, 389), rng.randi_range(22, 62))
		star.modulate = STAR_COLORS[rng.randi() % STAR_COLORS.size()]
		_stars.add_child(star)
		var low := rng.randf_range(0.15, 0.45)
		star.modulate.a = low
		var tween := star.create_tween().set_loops()
		tween.tween_interval(rng.randf_range(0.0, 2.5))
		tween.tween_property(star, "modulate:a", 1.0, rng.randf_range(0.4, 1.2))
		tween.tween_property(star, "modulate:a", low, rng.randf_range(0.6, 1.6))


# "#" full colour, "+" half alpha, anything else transparent
func _image_texture(rows: PackedStringArray) -> ImageTexture:
	var img := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in rows[y].length():
			match rows[y][x]:
				"#": img.set_pixel(x, y, Color.WHITE)
				"+": img.set_pixel(x, y, Color(1, 1, 1, 0.45))
	return ImageTexture.create_from_image(img)


func _make_moon() -> ImageTexture:
	var size := 21
	var c := (size - 1) / 2.0
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var light := Color(0.86, 0.87, 0.76)
	var shade := Color(0.68, 0.7, 0.64)
	var crater := Color(0.74, 0.75, 0.68)
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length()
			if d <= 6.0:
				# lit from the upper left: lower right rim a bit darker
				img.set_pixel(x, y, shade if Vector2(x - c - 1.5, y - c - 1.5).length() > 5.0 else light)
			elif d <= 7.5:
				img.set_pixel(x, y, Color(0.55, 0.65, 0.8, 0.22))
			elif d <= 10.0:
				img.set_pixel(x, y, Color(0.45, 0.55, 0.75, 0.08))
	for p in [Vector2i(-2, -1), Vector2i(-1, -1), Vector2i(2, 2), Vector2i(1, -3), Vector2i(-2, 3)]:
		img.set_pixelv(Vector2i(int(c), int(c)) + p, crater)
	return ImageTexture.create_from_image(img)


func _make_clouds(rng: RandomNumberGenerator) -> ImageTexture:
	var w := int(MIRROR)
	var h := 32
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var body := Color(0.13, 0.18, 0.27)
	var lit := Color(0.2, 0.25, 0.34)
	var x := rng.randi_range(10, 40)
	while x < w - 70:
		var cw := rng.randi_range(30, 60)
		var cy := rng.randi_range(8, h - 10)
		# a cloud = a few overlapping flat ellipses
		for k in rng.randi_range(2, 4):
			var ex := x + rng.randi_range(0, cw - 16)
			var ey := cy + rng.randi_range(-2, 2)
			var rx := rng.randi_range(8, 14)
			var ry := rng.randi_range(2, 4)
			for yy in range(ey - ry, ey + ry + 1):
				for xx in range(ex - rx, ex + rx + 1):
					if xx < 0 or xx >= w or yy < 0 or yy >= h:
						continue
					var q := pow((xx - ex) / float(rx), 2) + pow((yy - ey) / float(ry), 2)
					if q <= 1.0:
						img.set_pixel(xx, yy, body)
		x += cw + rng.randi_range(50, 130)
	# moonlit top edge
	for yy in range(1, h):
		for xx in w:
			if img.get_pixel(xx, yy).a > 0.0 and img.get_pixel(xx, yy - 1).a == 0.0:
				img.set_pixel(xx, yy, lit)
	return ImageTexture.create_from_image(img)
