#!/usr/bin/env python3
"""Generate the forest ground textures (lot C, decor).

Outputs, in src/Levels/LevelTemplate/:
  - ground.png       : atlas of 4 tiles 96x96 (same tileable base, different rare details)
  - ground_edge.png  : 96x8 grass fringe drawn over the ground / tree line border

    python3 tools/generate_ground.py                 # writes the PNGs
    python3 tools/generate_ground.py --retile a.tscn  # also picks a random variant per ground cell

The base is a soft tileable value noise quantised to a muted palette with an ordered
dither (pixel art, no smooth gradient). Every variant shares the same base, so any
variant can sit next to any other one: edges always match.
"""
import random
import re
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "src" / "Levels" / "LevelTemplate"

TILE = 96
VARIANTS = 4

# muted night greens, dark -> light (low saturation so the characters stand out)
PALETTE = [
	(30, 48, 33),
	(37, 58, 38),
	(44, 68, 42),
	(52, 78, 47),
	(61, 88, 52),
]

BAYER4 = [
	[0, 8, 2, 10],
	[12, 4, 14, 6],
	[3, 11, 1, 9],
	[15, 7, 13, 5],
]


def value_noise(size, period, rng):
	"""Tileable smooth value noise in [0, 1], `period` cells across `size` pixels."""
	grid = [[rng.random() for _ in range(period)] for _ in range(period)]
	cell = size / period
	out = [[0.0] * size for _ in range(size)]
	for y in range(size):
		gy = y / cell
		y0 = int(gy) % period
		y1 = (y0 + 1) % period
		ty = gy - int(gy)
		ty = ty * ty * (3 - 2 * ty)
		for x in range(size):
			gx = x / cell
			x0 = int(gx) % period
			x1 = (x0 + 1) % period
			tx = gx - int(gx)
			tx = tx * tx * (3 - 2 * tx)
			a = grid[y0][x0] + (grid[y0][x1] - grid[y0][x0]) * tx
			b = grid[y1][x0] + (grid[y1][x1] - grid[y1][x0]) * tx
			out[y][x] = a + (b - a) * ty
	return out


def base_tile(rng):
	octaves = [(3, 0.55), (6, 0.30), (12, 0.15)]
	layers = [value_noise(TILE, p, rng) for p, _ in octaves]
	img = Image.new("RGBA", (TILE, TILE))
	px = img.load()
	levels = len(PALETTE)
	for y in range(TILE):
		for x in range(TILE):
			v = sum(layer[y][x] * w for layer, (_, w) in zip(layers, octaves))
			# stretch around the middle, keep the extremes rare
			v = min(max((v - 0.5) * 1.35 + 0.5, 0.0), 0.999)
			f = v * (levels - 1)
			i = int(f)
			# ordered dither between two neighbour colours (tileable: 96 % 4 == 0)
			if f - i > (BAYER4[y % 4][x % 4] + 0.5) / 16.0 and i + 1 < levels:
				i += 1
			px[x, y] = PALETTE[i] + (255,)
	# short grass strokes, one shade off the pixel below them (coordinates wrap: still tileable)
	index = {c: n for n, c in enumerate(PALETTE)}
	for _ in range(520):
		x, y = rng.randrange(TILE), rng.randrange(TILE)
		n = index[px[x, y][:3]]
		n = min(max(n + rng.choice((-1, 1, 1)), 0), levels - 1)
		for k in range(rng.choice((1, 2, 2, 3))):
			px[x, (y - k) % TILE] = PALETTE[n] + (255,)
	return img


def put(px, x, y, color):
	if 0 <= x < TILE and 0 <= y < TILE:
		px[x, y] = color + (255,)


def tuft(px, x, y, rng):
	dark = (26, 42, 29)
	light = (70, 98, 58)
	for dx, h in ((-2, 2), (-1, 3), (0, 4), (1, 3), (2, 2)):
		if rng.random() < 0.8 or dx == 0:
			for k in range(h):
				put(px, x + dx, y - k, light if k == h - 1 and dx in (-1, 0) else dark)


def pebble(px, x, y, rng):
	body = (78, 80, 74)
	shade = (52, 54, 52)
	top = (104, 104, 96)
	w = rng.choice((2, 3))
	for dx in range(w):
		put(px, x + dx, y, shade)
		put(px, x + dx, y - 1, body)
	put(px, x, y - 1, top)
	put(px, x + w, y, (28, 44, 30))  # little shadow


def flower(px, x, y, rng):
	petal = rng.choice(((176, 168, 112), (132, 150, 184), (172, 128, 150)))
	put(px, x, y + 1, (34, 60, 36))
	put(px, x, y, petal)
	put(px, x - 1, y, tuple(int(c * 0.75) for c in petal))
	put(px, x + 1, y, tuple(int(c * 0.75) for c in petal))
	put(px, x, y - 1, tuple(int(c * 0.85) for c in petal))


DETAILS = [tuft, pebble, flower]


def variant(base, index, rng):
	img = base.copy()
	if index == 0:
		return img
	px = img.load()
	count = rng.randint(2, 4)
	for _ in range(count):
		# margin: details never touch the tile edges, so the tiling stays perfect
		x = rng.randint(5, TILE - 6)
		y = rng.randint(6, TILE - 4)
		rng.choice(DETAILS)(px, x, y, rng)
	return img


def edge_strip(rng):
	"""Grass blades rising above the ground line (rows 0..5), sparse specks below."""
	w, h = TILE, 8
	img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	px = img.load()
	line = 6  # first row of the ground in this strip
	x = 0
	while x < w:
		height = rng.choice((1, 1, 2, 2, 3, 4, 5))
		color = rng.choice(PALETTE[:3])
		for k in range(1, height + 1):
			px[x, line - k] = color + (255,)
		x += rng.choice((1, 1, 2, 2, 3))
	for x in range(w):
		if rng.random() < 0.35:
			px[x, line + rng.randint(0, 1)] = PALETTE[0] + (255,)
	return img


def retile(path, rng):
	"""Give every ground cell of a scene a random variant (atlas x). Cells stay put."""
	text = path.read_text()
	match = re.search(r"(layer_0/tile_data = PackedInt32Array\()([^)]*)(\))", text)
	if not match:
		print("no tile_data in", path)
		return
	values = [int(v) for v in match.group(2).split(",")]
	weights = [4, 2, 2, 2]
	for i in range(0, len(values), 3):
		atlas_x = rng.choices(range(VARIANTS), weights)[0]
		values[i + 1] = (values[i + 1] & 0xFFFF) | (atlas_x << 16)
	new = match.group(1) + ", ".join(str(v) for v in values) + match.group(3)
	path.write_text(text[: match.start()] + new + text[match.end():])
	print("retiled", path)


def main():
	rng = random.Random(1307)
	base = base_tile(rng)
	atlas = Image.new("RGBA", (TILE * VARIANTS, TILE))
	for i in range(VARIANTS):
		atlas.paste(variant(base, i, rng), (i * TILE, 0))
	atlas.save(OUT / "ground.png")
	edge_strip(rng).save(OUT / "ground_edge.png")
	print("wrote", OUT / "ground.png", OUT / "ground_edge.png")

	args = sys.argv[1:]
	if args and args[0] == "--retile":
		for scene in args[1:]:
			retile(Path(scene), random.Random(scene))


if __name__ == "__main__":
	main()
