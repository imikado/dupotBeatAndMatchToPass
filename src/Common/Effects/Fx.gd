class_name Fx
extends RefCounted

const FONT := preload("res://src/Common/UI/fonts/littleFont.tres")

const ENEMY_COLORS = {
	Game.ENEMY_TYPE_LIST.ANT: Color("c8553d"),
	Game.ENEMY_TYPE_LIST.BEETLE: Color("6ab04c"),
	Game.ENEMY_TYPE_LIST.SPIDER: Color("9b59b6"),
}


static func floating_text(parent: Node, text: String, global_pos: Vector2, color: Color = Color.WHITE, font_size: int = 5) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 100
	label.size = Vector2(60, 12)
	parent.add_child(label)
	label.global_position = global_pos - Vector2(30, 6)

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 16, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)


static func burst(parent: Node, global_pos: Vector2, color: Color, amount: int = 20) -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.amount = amount
	particles.lifetime = 0.5
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 70.0
	particles.gravity = Vector2(0, 160)
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.0
	particles.color = color
	particles.z_index = 50
	parent.add_child(particles)
	particles.global_position = global_pos
	particles.finished.connect(particles.queue_free)
	particles.emitting = true


static func enemy_color(type) -> Color:
	return ENEMY_COLORS.get(type, Color.WHITE)


# ambient glowing dots drifting over a 320x180 screen
static func fireflies(parent: Node, amount: int = 24) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.amount = amount
	particles.lifetime = 6.0
	particles.preprocess = 6.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(170, 100)
	particles.position = Vector2(160, 90)
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, -3)
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 8.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0

	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 1.0, 0.4, 0.0))
	ramp.set_color(1, Color(0.85, 1.0, 0.4, 0.0))
	ramp.add_point(0.3, Color(0.9, 1.0, 0.5, 0.9))
	ramp.add_point(0.7, Color(0.9, 1.0, 0.5, 0.6))
	particles.color_ramp = ramp

	parent.add_child(particles)
	return particles


static var _radial_texture: GradientTexture2D
static var _column_texture: GradientTexture2D
static var _additive_material: CanvasItemMaterial


# soft white disc, used for 2D lights and glows
static func radial_texture() -> GradientTexture2D:
	if _radial_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.35, Color(1, 1, 1, 0.55))
		_radial_texture = GradientTexture2D.new()
		_radial_texture.gradient = gradient
		_radial_texture.fill = GradientTexture2D.FILL_RADIAL
		_radial_texture.fill_from = Vector2(0.5, 0.5)
		_radial_texture.fill_to = Vector2(1.0, 0.5)
		_radial_texture.width = 128
		_radial_texture.height = 128
	return _radial_texture


# vertical beam: bright in the middle, fading on both sides
static func column_texture() -> GradientTexture2D:
	if _column_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 0))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.5, Color(1, 1, 1, 1))
		_column_texture = GradientTexture2D.new()
		_column_texture.gradient = gradient
		_column_texture.width = 32
		_column_texture.height = 8
	return _column_texture


static func additive_material() -> CanvasItemMaterial:
	if _additive_material == null:
		_additive_material = CanvasItemMaterial.new()
		_additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive_material


static func light(parent: Node, color: Color, texture_scale: float = 1.0) -> PointLight2D:
	var point_light := PointLight2D.new()
	point_light.texture = radial_texture()
	point_light.color = color
	point_light.texture_scale = texture_scale
	point_light.energy = 0.0
	point_light.enabled = false
	parent.add_child(point_light)
	return point_light
