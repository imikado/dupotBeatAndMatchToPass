class_name ShopDoor
extends Node2D

# Petite porte du niveau bonus : un joueur qui y entre ouvre la boutique (ShopMenu)

signal player_entered(player)

const FRAME_COLOR := Color("3b2a22")
const DOOR_COLOR := Color("8a5a36")
const PLANK_COLOR := Color("6b4428")
const KNOB_COLOR := Color("ffd34d")
const SIGN_COLOR := Color("241a2c")

var _gem: Polygon2D
var _label: Label


func _ready() -> void:
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

	Fx.shadow(self, 22)


func _draw() -> void:
	draw_rect(Rect2(-10, -28, 20, 28), FRAME_COLOR)
	draw_rect(Rect2(-8, -26, 16, 26), DOOR_COLOR)
	for x in [-3, 2]:
		draw_rect(Rect2(x, -26, 1, 26), PLANK_COLOR)
	draw_rect(Rect2(-8, -26, 16, 2), DOOR_COLOR.lightened(0.2))
	draw_rect(Rect2(4, -13, 2, 2), KNOB_COLOR)
	draw_rect(Rect2(-15, -38, 30, 10), Color.BLACK)
	draw_rect(Rect2(-14, -37, 28, 8), SIGN_COLOR)


func _on_body_entered(body: Node) -> void:
	if body is Player:
		player_entered.emit(body)
