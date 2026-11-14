class_name CastShadow
extends AnimatedSprite2D

# Ombre portée : copie de l'image courante du personnage, retournée et aplatie
# sous ses pieds, penchée dans le sens de la lumière. Suit l'animation, le sens
# du regard, l'écrasement du pivot et la dissolution à la mort.

const SHADER := preload("res://src/Common/Effects/cast_shadow.gdshader")
const FLATTEN := 0.3
# Direction de la lumière (radians) : la lune est haute, l'ombre part un peu vers la gauche, quel que soit le regard
const LEAN := 0.55

var _source: AnimatedSprite2D
var _pivot: Node2D
var _source_material: ShaderMaterial


func setup(source: AnimatedSprite2D) -> void:
	_source = source
	_pivot = source.get_parent()
	_source_material = source.material as ShaderMaterial
	sprite_frames = source.sprite_frames
	centered = source.centered
	offset = source.offset
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = SHADER
	shadow_material.set_shader_parameter("frame_height", Fx.frame_height(source))
	material = shadow_material
	_sync()


func _process(_delta: float) -> void:
	_sync()


func _sync() -> void:
	if not is_instance_valid(_source):
		queue_free()
		return
	visible = _source.is_visible_in_tree()
	if not visible:
		return
	if animation != _source.animation:
		animation = _source.animation
	if frame != _source.frame:
		frame = _source.frame
	flip_h = _source.flip_h

	var pivot_scale := _pivot.scale
	scale = Vector2(pivot_scale.x, -FLATTEN * absf(pivot_scale.y))
	skew = LEAN
	# l'image est retournée autour de la ligne des pieds (origine du personnage)
	var feet := -_source.position.y
	position = _pivot.position + Vector2(
		_source.position.x * pivot_scale.x + feet * scale.y * sin(LEAN),
		-feet * scale.y * cos(LEAN))

	var alpha := 1.0
	if _source_material:
		var dissolve = _source_material.get_shader_parameter("dissolve")
		if dissolve != null:
			alpha = 1.0 - clampf(dissolve, 0.0, 1.0)
	modulate.a = alpha
