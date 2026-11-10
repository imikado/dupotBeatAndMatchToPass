#!/usr/bin/env python3
"""Joueur 2 (mode 2 joueurs) : copie des planches du joueur avec la fourrure grise
passée en bleu-gris. Seuls les gris neutres opaques changent (contour noir, blanc des
yeux, écharpe, pantalon et effets bleus restent identiques).

Usage : python3 tools/generate_player2.py
Sortie : src/Actors/Players/Player2/player-*.png
"""
import colorsys
import glob
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE_DIR = os.path.join(ROOT, "src/Actors/Players/Player")
TARGET_DIR = os.path.join(ROOT, "src/Actors/Players/Player2")

# gris de la fourrure : saturation faible, ni noir (contour) ni blanc (yeux)
MAX_SATURATION = 0.08
MIN_VALUE = 0.15
MAX_VALUE = 0.8

HUE = 0.60
SATURATION = 0.30
BRIGHTNESS = 1.08


def recolor(pixel):
    r, g, b, a = pixel
    if a < 255:
        return pixel
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    if s > MAX_SATURATION or v < MIN_VALUE or v > MAX_VALUE:
        return pixel
    nr, ng, nb = colorsys.hsv_to_rgb(HUE, SATURATION, min(1.0, v * BRIGHTNESS))
    return (round(nr * 255), round(ng * 255), round(nb * 255), a)


def main():
    os.makedirs(TARGET_DIR, exist_ok=True)
    for path in sorted(glob.glob(os.path.join(SOURCE_DIR, "player-*.png"))):
        image = Image.open(path).convert("RGBA")
        image.putdata([recolor(p) for p in image.getdata()])
        target = os.path.join(TARGET_DIR, os.path.basename(path))
        image.save(target)
        print(target)


if __name__ == "__main__":
    main()
