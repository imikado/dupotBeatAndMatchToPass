#!/usr/bin/env python3
"""Génère le logo pixel art de l'écran titre et du menu.

Produit, en 320x180 (même cadre que les anciennes images, centrées par les scènes) :
  src/UI/title/title-sans-persos.png  logo seul (menu : les personnages y sont des nœuds animés)
  src/UI/title/title.png              logo + Gordon sur « BEAT » et une fourmi sur « MATCH »

Usage : python3 tools/generate_title.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "src/UI/title"

W, H = 320, 180
CELL = 4  # taille d'une case de glyphe en pixels

# même contour que character.gdshader
OUTLINE = (20, 12, 28, 255)
SHADOW = (20, 12, 28, 110)

# dégradé de haut en bas (paliers), bord éclairé, bord ombré, profondeur
GOLD = {
	"bands": [(255, 232, 128), (252, 200, 72), (240, 158, 44), (214, 112, 34)],
	"light": (255, 250, 214),
	"shade": (160, 66, 28),
	"depth": [(122, 44, 30), (92, 30, 36), (66, 22, 40)],
}
ELECTRIC = {
	"bands": [(214, 240, 255), (150, 200, 255), (98, 150, 245), (70, 104, 222)],
	"light": (250, 254, 255),
	"shade": (48, 62, 170),
	"depth": [(40, 44, 132), (32, 30, 100), (26, 20, 72)],
}

GLYPHS = {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	# C, E, P, S sur 4 colonnes : le logo garde la largeur de l'ancien
	"C": [".###", "#...", "#...", "#...", "#...", "#...", ".###"],
	"E": ["####", "#...", "#...", "###.", "#...", "#...", "####"],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["###.", "#..#", "#..#", "###.", "#...", "#...", "#..."],
	"S": [".###", "#...", "#...", ".##.", "...#", "...#", "###."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
}
GLYPH_W = 5 * CELL
GLYPH_H = 7 * CELL
SPACING = 1
# petit décalage vertical lettre par lettre, pour un logo moins rigide
BOUNCE = [0, -1, 1, 0, -1]


class Layer:
	"""Masque d'un mot + sa palette, sur toute la toile."""

	def __init__(self, scheme):
		self.scheme = scheme
		self.mask = set()
		self.tops = {}  # pixel -> y du haut de sa lettre (pour le dégradé)

	def add_glyph(self, char, x0, y0):
		rows = GLYPHS[char]
		cells = {(cx, cy) for cy, row in enumerate(rows) for cx, c in enumerate(row) if c == "#"}
		for cx, cy in cells:
			for py in range(CELL):
				for px in range(CELL):
					x = x0 + cx * CELL + px
					y = y0 + cy * CELL + py
					# coins extérieurs arrondis d'un pixel
					corner_x = px == 0 and (cx - 1, cy) not in cells or px == CELL - 1 and (cx + 1, cy) not in cells
					corner_y = py == 0 and (cx, cy - 1) not in cells or py == CELL - 1 and (cx, cy + 1) not in cells
					if corner_x and corner_y:
						dx = -1 if px == 0 else 1
						dy = -1 if py == 0 else 1
						if (cx + dx, cy + dy) not in cells:
							continue
					self.mask.add((x, y))
					self.tops[(x, y)] = y0

	def add_word(self, word, x0, y0, skip=()):
		"""Renvoie le x de départ de chaque lettre."""
		xs = []
		x = x0
		for i, char in enumerate(word):
			xs.append(x)
			if i not in skip:
				self.add_glyph(char, x, y0 + BOUNCE[i % len(BOUNCE)])
			x += len(GLYPHS[char][0]) * CELL + SPACING
		return xs


def word_width(word):
	return sum(len(GLYPHS[c][0]) * CELL for c in word) + SPACING * (len(word) - 1)


def neighbours4(x, y):
	return ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))


def band_color(scheme, y, top):
	bands = scheme["bands"]
	t = (y - top) / GLYPH_H * len(bands)
	i = min(int(t), len(bands) - 1)
	# tramage en damier sur la ligne de transition entre deux paliers
	if i + 1 < len(bands) and t - i > 0.82 and (y % 2 == 0):
		return bands[i + 1]
	return bands[i]


def draw_layers(img, layers, extra_solid=()):
	"""Ombre portée, profondeur, contour puis remplissage de chaque mot."""
	depth_px = {}
	for layer in layers:
		for (x, y) in layer.mask:
			for d, color in enumerate(layer.scheme["depth"], start=1):
				p = (x, y + d)
				if p not in layer.mask:
					depth_px.setdefault(p, color)
	solid = set(depth_px) | set(extra_solid)
	for layer in layers:
		solid |= layer.mask

	outline = {n for p in solid for n in neighbours4(*p) if n not in solid}
	shape = solid | outline
	for (x, y) in shape:
		p = (x + 2, y + 2)
		if p not in shape:
			put(img, p, SHADOW)
	for p in outline:
		put(img, p, OUTLINE)
	for p, color in depth_px.items():
		put(img, p, color)

	for layer in layers:
		s = layer.scheme
		for (x, y) in layer.mask:
			if (x, y - 1) not in layer.mask:
				color = s["light"]
			elif (x, y + 1) not in layer.mask:
				color = s["shade"]
			elif (x - 1, y) not in layer.mask and (x, y - 2) in layer.mask:
				color = s["bands"][0]  # reflet sur le bord gauche
			else:
				color = band_color(s, y, layer.tops[(x, y)])
			put(img, (x, y), color)


def put(img, p, color):
	x, y = p
	if 0 <= x < W and 0 <= y < H:
		if len(color) == 4 and color[3] < 255:
			img.alpha_composite(Image.new("RGBA", (1, 1), color), (x, y))
		else:
			img.putpixel((x, y), color if len(color) == 4 else color + (255,))


# --- épée : la lame pointe vers le haut, la garde fait la barre du « T » ---------

BLADE = [(236, 240, 248), (196, 204, 220), (140, 148, 170)]
GUARD = [(255, 222, 110), (226, 160, 52), (150, 84, 30)]
GRIP = [(132, 74, 44), (96, 50, 32), (66, 34, 26)]


def sword_pixels(cx, guard_y):
	"""cx = centre de la barre du T, guard_y = haut de la garde. Renvoie {pixel: couleur}."""
	px = {}
	blade_top = guard_y - 36
	for y in range(blade_top, guard_y):
		half = 1 if y < blade_top + 4 else 2  # pointe plus fine
		for x in range(cx - half, cx + half + 1):
			if x == cx - half:
				px[(x, y)] = BLADE[0]
			elif x == cx + half:
				px[(x, y)] = BLADE[2]
			else:
				px[(x, y)] = BLADE[1]
		px[(cx, y)] = BLADE[0] if y % 6 else BLADE[1]  # fil de la lame
	px[(cx, blade_top - 1)] = BLADE[0]
	# garde = barre du T, même largeur qu'une lettre
	for y in range(guard_y, guard_y + CELL):
		for x in range(cx - GLYPH_W // 2, cx + GLYPH_W // 2):
			px[(x, y)] = GUARD[0] if y == guard_y else GUARD[2] if y == guard_y + CELL - 1 else GUARD[1]
	# poignée = jambage du T, avec des bandes de cuir
	for y in range(guard_y + CELL, guard_y + GLYPH_H - 3):
		for x in range(cx - 2, cx + 2):
			wrap = (y - guard_y) % 4 == 0
			px[(x, y)] = GRIP[2] if wrap else GRIP[0] if x == cx - 2 else GRIP[1]
	# pommeau
	for y in range(guard_y + GLYPH_H - 3, guard_y + GLYPH_H + 1):
		for x in range(cx - 3, cx + 3):
			px[(x, y)] = GUARD[0] if y == guard_y + GLYPH_H - 3 else GUARD[1]
	return px


SPARK = [(255, 255, 255), (170, 214, 255)]


def spark(img, x, y, size):
	"""Petite étoile en croix : centre blanc, branches bleu clair."""
	put(img, (x, y), SPARK[0])
	for d in range(1, size + 2):
		color = SPARK[0] if d <= size - 1 else SPARK[1]
		for p in ((x + d, y), (x - d, y), (x, y + d), (x, y - d)):
			put(img, p, color)


# --- personnages ------------------------------------------------------------------

def sprite_frame(path, frame=0):
	sheet = Image.open(ROOT / path).convert("RGBA")
	return sheet.crop((frame * 64, 0, frame * 64 + 64, 64))


def paste_standing(img, sprite, feet_x, feet_y):
	"""Pose un sprite pour que le bas de sa silhouette touche feet_y, centré sur feet_x."""
	box = sprite.getbbox()
	sprite = sprite.crop(box)
	# contour d'un pixel comme en jeu
	outlined = Image.new("RGBA", (sprite.width + 2, sprite.height + 2))
	for y in range(sprite.height):
		for x in range(sprite.width):
			if sprite.getpixel((x, y))[3] > 25:
				for nx, ny in neighbours4(x + 1, y + 1):
					outlined.putpixel((nx, ny), OUTLINE)
	outlined.alpha_composite(sprite, (1, 1))
	img.alpha_composite(outlined, (feet_x - outlined.width // 2, feet_y - outlined.height + 1))


def build(with_characters):
	img = Image.new("RGBA", (W, H))

	beat = Layer(GOLD)
	match = Layer(ELECTRIC)
	to = Layer(ELECTRIC)
	pas = Layer(GOLD)

	# même disposition en 2x2 que l'ancien logo (les scènes placent les personnages dessus)
	row1, row2 = 66, 110
	left, gap = 60, 8
	t_x = beat.add_word("BEAT", left, row1, skip=(3,))[3]
	sword = sword_pixels(t_x + GLYPH_W // 2, row1 + BOUNCE[3])
	match_x = left + word_width("BEAT") + gap
	match.add_word("MATCH", match_x, row1)
	# deuxième ligne centrée sous la première
	row1_center = (left + match_x + word_width("MATCH")) // 2
	row2_width = word_width("TO") + 10 + word_width("PASS")
	to_x = row1_center - row2_width // 2
	to.add_word("TO", to_x, row2)
	pas.add_word("PASS", to_x + word_width("TO") + 10, row2)

	draw_layers(img, [beat, match, to, pas], extra_solid=sword.keys())
	for p, color in sword.items():
		put(img, p, color)
	# reflet sur la lame et étincelles autour des mots électriques
	right = match_x + word_width("MATCH")
	for x, y, size in ((t_x + GLYPH_W // 2, row1 - 26, 2), (match_x - 5, row1 + 6, 1), (right + 3, row1 + 20, 1),
			(to_x - 7, row2 + 18, 1), (to_x + word_width("TO") + 4, row2 + 2, 1), (right - 6, row1 - 5, 1)):
		spark(img, x, y, size)

	if with_characters:
		paste_standing(img, sprite_frame("src/Actors/Players/Player/player-idle.png"), 78, row1 - 2)
		ant = sprite_frame("src/Actors/SimpleEnemies/Ant/ant-idle.png")
		paste_standing(img, ant.transpose(Image.FLIP_LEFT_RIGHT), right - 26, row1 - 2)

	return img


def main():
	build(False).save(OUT_DIR / "title-sans-persos.png")
	build(True).save(OUT_DIR / "title.png")
	print("Logo écrit dans", OUT_DIR)


if __name__ == "__main__":
	main()
