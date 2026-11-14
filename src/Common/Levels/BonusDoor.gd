class_name BonusDoor
extends ShopDoor

# Porte de la boutique propre au niveau bonus : même comportement que ShopDoor
# (zone d'entrée, panneau, gemme), mais porte cintrée en pierre et bois violet

const STONE_COLOR := Color("4a4e69")
const STONE_DARK_COLOR := Color("363a52")
const BONUS_DOOR_COLOR := Color("6a3d9a")
const BAND_COLOR := Color("2b2d42")
const WINDOW_COLOR := Color("7bed9f")
const BONUS_SIGN_COLOR := Color("2a1f3d")
const BONUS_LABEL_COLOR := Color("7bed9f")


func _ready() -> void:
	super._ready()
	_label.add_theme_color_override("font_color", BONUS_LABEL_COLOR)


func _draw() -> void:
	# encadrement en pierre
	draw_rect(Rect2(-10, -28, 20, 28), STONE_COLOR)
	for brick in [Rect2(-10, -20, 2, 1), Rect2(8, -14, 2, 1), Rect2(-10, -8, 2, 1), Rect2(8, -4, 2, 1)]:
		draw_rect(brick, STONE_DARK_COLOR)
	# porte cintrée
	draw_rect(Rect2(-5, -26, 10, 1), BONUS_DOOR_COLOR)
	draw_rect(Rect2(-7, -25, 14, 2), BONUS_DOOR_COLOR)
	draw_rect(Rect2(-8, -23, 16, 23), BONUS_DOOR_COLOR)
	draw_rect(Rect2(-5, -26, 10, 1), BONUS_DOOR_COLOR.lightened(0.25))
	draw_rect(Rect2(0, -26, 1, 26), BAND_COLOR)
	# ferrures
	for y in [-19, -7]:
		draw_rect(Rect2(-8, y, 16, 1), BAND_COLOR)
	# petite lucarne et poignée
	draw_rect(Rect2(-3, -23, 2, 2), WINDOW_COLOR)
	draw_rect(Rect2(2, -23, 2, 2), WINDOW_COLOR)
	draw_rect(Rect2(3, -13, 2, 2), WINDOW_COLOR)
	# panneau (mêmes dimensions que celui de ShopDoor pour le libellé)
	draw_rect(Rect2(-15, -38, 30, 10), Color.BLACK)
	draw_rect(Rect2(-14, -37, 28, 8), BONUS_SIGN_COLOR)
	draw_rect(Rect2(-14, -37, 28, 1), BONUS_SIGN_COLOR.lightened(0.2))
