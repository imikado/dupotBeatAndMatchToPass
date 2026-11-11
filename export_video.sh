#!/bin/bash
# Génère la vidéo de démo pour YouTube (MP4 H.264 + son AAC) : le jeu joue tout
# seul (DemoTour.gd, clip « video » : lancement, niveau 1 + orage, bonus,
# niveau 3 + orage, puis mode 2 joueurs : menu, choix des touches, combat à
# deux + orage). Godot enregistre images et son (Movie Maker, PNG + WAV),
# puis ffmpeg assemble la vidéo sans lissage des pixels, avec un fondu au début
# et à la fin. Ouvre une fenêtre du jeu pendant l'enregistrement.
#
# Usage : ./export_video.sh [fichier.mp4]   (export/demo.mp4 par défaut)
# Variables : FPS (60), FADE (0.5 s), SCALE (3), DEMO_TIMEOUT (1800 s)
# Enregistré en 1280x720 (une fenêtre 1920x1080 ne tient pas sur un écran
# 1080p : Godot la réduirait), puis agrandi xSCALE sans lissage : 3840x2160
# par défaut (pixels nets, YouTube donne plus de débit aux vidéos 4K).
set -e

cd "$(dirname "$0")"

GODOT="${GODOT:-$(command -v godot || echo "$HOME/apps/Godot_v4.7.2-stable_linux.x86_64")}"
OUTPUT="${1:-export/demo.mp4}"
FPS="${FPS:-60}"
SCALE="${SCALE:-3}"
FADE="${FADE:-0.5}"
DEMO_TIMEOUT="${DEMO_TIMEOUT:-1800}"
WIDTH=1280
HEIGHT=720

if [ ! -x "$GODOT" ]; then
	echo "Godot introuvable ($GODOT) : définir la variable GODOT" >&2
	exit 1
fi

if ! command -v ffmpeg >/dev/null; then
	echo "ffmpeg introuvable : il sert à assembler la vidéo" >&2
	exit 1
fi

# Le Movie Maker enregistre à la taille de fenêtre du projet (window_width_override=1230) :
# override.cfg temporaire pour enregistrer en 1280x720
if [ -e override.cfg ]; then
	if pgrep -f -- "--write-movie" >/dev/null; then
		echo "Un enregistrement (update_demo.sh ou export_video.sh) est déjà en cours :" >&2
		echo "attendre sa fin, override.cfg sera retiré automatiquement" >&2
	else
		echo "override.cfg reste d'un enregistrement interrompu : le supprimer (rm override.cfg)" >&2
	fi
	exit 1
fi

# Godot ne doit pas importer les contenus de publication rangés sous export/
mkdir -p export "$(dirname "$OUTPUT")"
touch export/.gdignore

"$GODOT" --headless --path . --import

printf '[display]\n\nwindow/size/window_width_override=%d\nwindow/size/window_height_override=%d\n' "$WIDTH" "$HEIGHT" > override.cfg
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING" override.cfg' EXIT
mkdir -p "$STAGING/frames"

echo "Démo en cours (ne pas toucher à la fenêtre du jeu)…"
timeout "$DEMO_TIMEOUT" "$GODOT" --path . --resolution "${WIDTH}x${HEIGHT}" \
	--write-movie "$STAGING/frames/frame.png" --fixed-fps "$FPS" \
	-- --screenshots="$STAGING" --demo=video 2>&1 | tee "$STAGING/log.txt" | grep --line-buffered "^Demo clip" || true

RANGE="$(grep -oP '^Demo clip : \K[0-9]+ [0-9]+' "$STAGING/log.txt" || true)"
if [ -z "$RANGE" ]; then
	echo "Démo incomplète : pas de vidéo générée. Fin du journal de Godot :" >&2
	grep -v "^\s*$" "$STAGING/log.txt" | tail -n 20 >&2
	exit 1
fi
read -r START END <<< "$RANGE"
FRAMES=$((END - START))
DURATION=$(echo "$FRAMES $FPS" | awk '{printf "%.3f", $1/$2}')
OFFSET=$(echo "$START $FPS" | awk '{printf "%.3f", $1/$2}')
FADE_OUT=$(echo "$DURATION $FADE" | awk '{printf "%.3f", $1-$2}')
WAV="$(ls "$STAGING"/frames/*.wav 2>/dev/null | head -n1)"

if [ -n "$WAV" ]; then
	AUDIO_IN=(-ss "$OFFSET" -t "$DURATION" -i "$WAV")
	AUDIO_OUT=(-af "afade=t=in:d=$FADE,afade=t=out:st=$FADE_OUT:d=$FADE" -c:a aac -b:a 192k -shortest)
else
	echo "Pas de son enregistré : vidéo muette" >&2
	AUDIO_IN=()
	AUDIO_OUT=(-an)
fi

# pixels nets (neighbor), qualité haute recommandée par YouTube, lecture
# progressive (faststart)
ffmpeg -loglevel error -y -framerate "$FPS" -start_number "$START" -i "$STAGING/frames/frame%08d.png" "${AUDIO_IN[@]}" \
	-frames:v "$FRAMES" \
	-vf "scale=$((WIDTH*SCALE)):$((HEIGHT*SCALE)):flags=neighbor,fade=t=in:d=$FADE,fade=t=out:st=$FADE_OUT:d=$FADE,format=yuv420p" \
	-c:v libx264 -preset slow -crf 16 -tune animation -r "$FPS" -g $((FPS/2)) -bf 2 \
	"${AUDIO_OUT[@]}" -movflags +faststart "$OUTPUT"

echo "Vidéo : $OUTPUT ($(du -h "$OUTPUT" | cut -f1), ${DURATION} s, $FRAMES images)"
