#!/bin/bash
# Génère les assets de la fiche Amazon Appstore (Fire TV) dans export/firetv,
# à partir du logo pixel art (tools/generate_title.py) et des captures :
#   fire_tv_icon.png          1280x720  App icon (sans transparence)
#   screenshot_XX.png         1920x1080 Screenshots (min. 3, sans transparence)
#   background_image.png      1920x1080 Background image (sans texte ni transparence)
#   featured_logo.png         640x260   Featured content logo (transparent)
#   icon_114.png              114x114   Small icon (icône du jeu, icon.png)
#   featured_background.png   1920x720  Featured content background (sans transparence)
# Le jeu est rendu en 320x180 : agrandissements au plus proche (pixels nets).
#
# Usage : ./generate_firetv.sh        Variable : OUT_DIR
# Dépendance : python3-pil
set -e

SHOTS_DIR="export/linux/screenshots"
LOGO="src/UI/title/title.png"
APP_ICON="icon.png"
ICON_SHOT="Screenshot_02.png"
BACKGROUND_SHOT="Screenshot_02.png"
FEATURED_SHOT="Screenshot_02.png"

OUT_DIR="${OUT_DIR:-export/firetv}"

cd "$(dirname "$0")"

if ! python3 -c "import PIL" 2>/dev/null; then
	echo "Python Pillow requis (apt install python3-pil)" >&2
	exit 1
fi
if ! ls "$SHOTS_DIR"/*.png >/dev/null 2>&1; then
	echo "Aucune capture dans $SHOTS_DIR : lancer ./update_screenshots.sh capture" >&2
	exit 1
fi

mkdir -p "$OUT_DIR"
touch "$OUT_DIR/.gdignore"
rm -f "$OUT_DIR"/*.png

env SHOTS_DIR="$SHOTS_DIR" LOGO="$LOGO" APP_ICON="$APP_ICON" ICON_SHOT="$ICON_SHOT" BACKGROUND_SHOT="$BACKGROUND_SHOT" \
	FEATURED_SHOT="$FEATURED_SHOT" OUT_DIR="$OUT_DIR" python3 - <<'PY'
import os, glob
from PIL import Image, ImageFilter

E = os.environ
OUT = E["OUT_DIR"]


def shot(name):
    return Image.open(os.path.join(E["SHOTS_DIR"], name)).convert("RGB")


def scale(img, w, h):
    return img.resize((w, h), Image.NEAREST)


def cover(img, w, h):
    r = max(w / img.width, h / img.height)
    img = scale(img, round(img.width * r), round(img.height * r))
    x, y = (img.width - w) // 2, (img.height - h) // 2
    return img.crop((x, y, x + w, y + h))


def scenery(name):
    # décor sous le HUD (barres, score, niveau) et les messages : bande 16/9 du bas de la capture
    img = shot(name)
    top = img.height * 3 // 16
    h = img.height - top
    w = h * 16 // 9
    x = (img.width - w) // 2
    return img.crop((x, top, x + w, img.height))


def dim(img, amount, blur):
    if blur:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    return Image.blend(img, Image.new("RGB", img.size, (10, 6, 18)), amount)


def logo_fit(w, h, margin):
    lg = Image.open(E["LOGO"]).convert("RGBA")
    lg = lg.crop(lg.getbbox())
    k = max(1, min((w - 2 * margin) // lg.width, (h - 2 * margin) // lg.height))
    return scale(lg, lg.width * k, lg.height * k)


def paste_center(base, img):
    base.paste(img, ((base.width - img.width) // 2, (base.height - img.height) // 2), img)
    return base


def save(img, name, alpha=False):
    path = os.path.join(OUT, name)
    (img if alpha else img.convert("RGB")).save(path, optimize=True)
    print(f"  {path} ({img.width}x{img.height})")


# App icon 1280x720 : logo centré sur une capture assombrie
icon = dim(cover(scenery(E["ICON_SHOT"]), 1280, 720), 0.55, 6)
save(paste_center(icon, logo_fit(1280, 720, 80)), "fire_tv_icon.png")

# Screenshots 1920x1080
for i, p in enumerate(sorted(glob.glob(os.path.join(E["SHOTS_DIR"], "*.png"))), 1):
    save(cover(Image.open(p).convert("RGB"), 1920, 1080), f"screenshot_{i:02d}.png")

# Background 1920x1080 : sans texte, flouté et assombri (la fiche s'affiche par-dessus)
save(dim(cover(scenery(E["BACKGROUND_SHOT"]), 1920, 1080), 0.45, 10), "background_image.png")

# Small icon 114x114 : icône du jeu réduite (512 -> 114, pas un multiple entier : lissage)
save(Image.open(E["APP_ICON"]).convert("RGBA").resize((114, 114), Image.LANCZOS), "icon_114.png", alpha=True)

# Featured content logo 640x260, transparent
save(paste_center(Image.new("RGBA", (640, 260), (0, 0, 0, 0)), logo_fit(640, 260, 10)), "featured_logo.png", alpha=True)

# Featured content background 1920x720 : bande centrale de la capture (sans le HUD)
fb = cover(shot(E["FEATURED_SHOT"]), 1920, 1080).crop((0, 240, 1920, 960))
save(dim(fb, 0.25, 0), "featured_background.png")
PY

cat > "$OUT_DIR/FIRETV.md" <<'MD'
# Beat And Match To Pass — fiche Amazon Appstore (Fire TV)

Généré par `generate_firetv.sh` : régler les variables du script plutôt que modifier les images.

| Champ de la console Amazon | Fichier |
|---|---|
| App icon (1280x720) | `fire_tv_icon.png` |
| Screenshots (1920x1080, min. 3) | `screenshot_*.png` |
| Background image (1920x1080) | `background_image.png` |
| Small icon (114x114) | `icon_114.png` |
| Featured content logo (640x260, optionnel) | `featured_logo.png` |
| Featured content background (1920x720, optionnel) | `featured_background.png` |

APK : `./export_firetv.sh release` → `export/android/firetv/BeatAndMatchToPass-firetv.apk`
MD

echo "Assets Fire TV : $OUT_DIR"
