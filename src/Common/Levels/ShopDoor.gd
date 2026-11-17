class_name ShopDoor
extends Node2D

# Petite porte du niveau bonus : un joueur qui y entre ouvre la boutique (ShopMenu)

signal player_entered(player)

# Sprites de tools/generate_doors.py (style de la Gate) : 32x48, pieds en bas au centre,
# panneau du libellé sur Rect2(-15, -38, 30, 10)
const DOOR_TEXTURE := preload("res://src/Common/Levels/Doors/shop_door.png")
const DOOR_SIZE := Vector2(32, 48)
const KNOB_COLOR := Color("ffd34d")

var _gem: Polygon2D
var _label: Label
# porte qui apparaît sous les pieds d'un joueur : entrée ignorée pendant ce délai
var arm_delay := 0.0
var _armed_at_ms := 0


func _ready() -> void:
	_armed_at_ms = Time.get_ticks_msec() + int(arm_delay * 1000.0)
	var sprite := Sprite2D.new()
	sprite.texture = get_door_texture()
	sprite.centered = false
	sprite.offset = Vector2(-DOOR_SIZE.x / 2.0, -DOOR_SIZE.y)
	add_child(sprite)
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 12)
	shape.shape = rect
	shape.position = Vector2(0, 4)
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)

	_label = Label.new()
	_label.text = "SHOP"
	_label.add_theme_font_override("font", Fx.FONT)
	_label.add_theme_font_size_override("font_size", 5)
	_label.add_theme_color_override("font_color", KNOB_COLOR)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# add_child AVANT de fixer la taille : hors de l'arbre, le Label calcule sa taille
	# minimale avec la police par défaut (44x23) et garde cette taille, ce qui décalait
	# le texte vers la droite et sur la porte. Pixeled à 5 px a une ligne de 14 px
	# (glyphes sur les lignes 5 à 10) : la boîte démarre à -41 pour centrer les
	# lettres dans le panneau (-37 à -30).
	add_child(_label)
	_label.size = Vector2(28, 14)
	_label.position = Vector2(-14, -41)

	_gem = Fx.gem_icon(self, Vector2(0, -45), 3.0)
	var tween := create_tween().set_loops()
	tween.tween_property(_gem, "position:y", -48.0, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_gem, "position:y", -45.0, 0.6).set_trans(Tween.TRANS_SINE)

	# ombre au sol sous l'arche (largeur du socle)
	move_child(Fx.shadow(self, 28), 0)


func get_door_texture() -> Texture2D:
	return DOOR_TEXTURE


func _on_body_entered(body: Node) -> void:
	if body is Player and Time.get_ticks_msec() >= _armed_at_ms:
		player_entered.emit(body)
