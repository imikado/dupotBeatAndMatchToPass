class_name BonusDoor
extends ShopDoor

# Porte de la boutique propre au niveau bonus : même comportement que ShopDoor
# (zone d'entrée, panneau, gemme), mais arche à vortex et runes comme la Gate

const EXIT_DOOR_TEXTURE := preload("res://src/Common/Levels/Doors/exit_door.png")
const BONUS_LABEL_COLOR := Color("7bed9f")


func _ready() -> void:
	super._ready()
	_label.add_theme_color_override("font_color", BONUS_LABEL_COLOR)


func get_door_texture() -> Texture2D:
	return EXIT_DOOR_TEXTURE
