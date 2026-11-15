class_name WeaponIcons
extends RefCounted

# Icônes pixel art 11x11 des armes (HUD, présentoirs de la boutique), détourées de noir

const COLORS := {
	GlobalPlayer.WEAPON_SWORD: Color("a6eaff"),
	GlobalPlayer.WEAPON_AXE: Color("ff9f43"),
	GlobalPlayer.WEAPON_BOMB: Color("ff6b5a"),
}
const OUTLINE := Color("140c1c")
const STEEL := Color("dfe6ee")
const STEEL_DARK := Color("8d97a8")
const WOOD := Color("aa703e")
const GOLD := Color("ffd34d")
const BOMB := Color("2b2d42")
const BOMB_LIGHT := Color("5c6380")
const SPARK := Color("ffd34d")

# lettre -> couleur ; « . » transparent
const PIXELS := {
	GlobalPlayer.WEAPON_SWORD: [
		".........s.",
		"........sS.",
		".......sS..",
		"......sS...",
		".....sS....",
		"..g.sS.....",
		"...gS......",
		"...wg......",
		"..w..g.....",
		".w.........",
		"...........",
	],
	GlobalPlayer.WEAPON_AXE: [
		"...........",
		".SS.....SS.",
		"Sss..w..ssS",
		"Ssssswsssss",
		"Sss..w..ssS",
		".SS..w..SS.",
		".....w.....",
		".....w.....",
		".....w.....",
		".....w.....",
		"...........",
	],
	GlobalPlayer.WEAPON_BOMB: [
		"........y..",
		".......y.y.",
		"......w....",
		".....w.....",
		"...bbbb....",
		"..bLbbbb...",
		"..bLbbbb...",
		"..bbbbbb...",
		"..bbbbbb...",
		"...bbbb....",
		"...........",
	],
}

static var _textures := {}


static func texture(weapon: String) -> ImageTexture:
	if _textures.has(weapon):
		return _textures[weapon]
	var palette := {"s": STEEL, "S": STEEL_DARK, "w": WOOD, "g": GOLD, "b": BOMB, "L": BOMB_LIGHT, "y": SPARK}
	var rows: Array = PIXELS[weapon]
	var image := Image.create(rows[0].length() + 2, rows.size() + 2, false, Image.FORMAT_RGBA8)
	var filled := []
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			if rows[y][x] != ".":
				filled.append(Vector2i(x + 1, y + 1))
	for point in filled:
		for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			image.set_pixelv(point + offset, OUTLINE)
	for point in filled:
		image.set_pixelv(point, palette[rows[point.y - 1][point.x - 1]])
	_textures[weapon] = ImageTexture.create_from_image(image)
	return _textures[weapon]
