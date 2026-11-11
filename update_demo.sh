#!/bin/bash
# Régénère la démo du README (docs/media/) : le jeu joue tout seul (DemoTour.gd),
# Godot enregistre chaque image (Movie Maker) puis ffmpeg en fait des gifs.
#   launch.gif    : logo de boot, écran titre puis menu
#   gameplay.gif  : combo, kills et orage d'éclairs
#   coop.gif      : mode 2 joueurs (menu, choix des touches, essai des héros en bas
#                   de l'écran des contrôles, combat à deux, orage de chaque joueur
#                   avec sa propre jauge de mana)
#   lightning.png : capture de l'orage
#
# Usage :
#   ./update_demo.sh                 # tous les clips
#   ./update_demo.sh launch          # un seul clip (launch, gameplay ou coop)
set -e

cd "$(dirname "$0")"

GODOT="${GODOT:-$(command -v godot || echo "$HOME/apps/Godot_v4.7.2-stable_linux.x86_64")}"
MEDIA_DIR="docs/media"
# Images enregistrées en 1280x720 à 30 i/s, gif en 640x360 à 12 i/s (128 couleurs :
# le défilement de la forêt alourdit vite le gif)
MOVIE_FPS=30
GIF_FPS=12
GIF_WIDTH=640
DEMO_TIMEOUT="${DEMO_TIMEOUT:-300}"

if [ ! -x "$GODOT" ]; then
	echo "Godot introuvable ($GODOT) : définir la variable GODOT" >&2
	exit 1
fi
if ! command -v ffmpeg >/dev/null; then
	echo "ffmpeg introuvable : sudo apt install ffmpeg" >&2
	exit 1
fi

# Le Movie Maker enregistre à la taille de fenêtre du projet (window_width_override=1230) :
# override.cfg temporaire pour enregistrer en 1280x720, comme les captures
if [ -e override.cfg ]; then
	if pgrep -f -- "--write-movie" >/dev/null; then
		echo "Un enregistrement (update_demo.sh ou export_video.sh) est déjà en cours :" >&2
		echo "attendre sa fin, override.cfg sera retiré automatiquement" >&2
	else
		echo "override.cfg reste d'un enregistrement interrompu : le supprimer (rm override.cfg)" >&2
	fi
	exit 1
fi
printf '[display]\n\nwindow/size/window_width_override=1280\nwindow/size/window_height_override=720\n' > override.cfg

staging="$(mktemp -d)"
trap 'rm -rf "$staging" override.cfg' EXIT

record() {
	local clip="$1"
	local dir="$staging/$clip"
	mkdir -p "$dir/frames"

	echo "Démo « $clip » en cours (ne pas toucher à la fenêtre du jeu)…"
	timeout "$DEMO_TIMEOUT" "$GODOT" --path . \
		--write-movie "$dir/frames/frame.png" --fixed-fps "$MOVIE_FPS" \
		-- --screenshots="$dir" --demo="$clip" | tee "$dir/log.txt" | grep --line-buffered "^Demo clip\|^Capture" || true

	local range start end
	range="$(grep -oP '^Demo clip : \K[0-9]+ [0-9]+' "$dir/log.txt" || true)"
	if [ -z "$range" ]; then
		echo "Démo « $clip » incomplète : rien n'est remplacé" >&2
		exit 1
	fi
	read -r start end <<< "$range"

	# Palette calculée sur le clip : couleurs fidèles au pixel art, gif plus léger
	ffmpeg -loglevel error -y -framerate "$MOVIE_FPS" -start_number "$start" \
		-i "$dir/frames/frame%08d.png" -frames:v "$((end - start))" \
		-vf "fps=$GIF_FPS,scale=$GIF_WIDTH:-1:flags=neighbor,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=none:diff_mode=rectangle" \
		-loop 0 "$dir/$clip.gif"

	cp "$dir/$clip.gif" "$MEDIA_DIR/$clip.gif"
	echo "  $MEDIA_DIR/$clip.gif ($(du -h "$MEDIA_DIR/$clip.gif" | cut -f1), $(((end - start) / MOVIE_FPS)) s)"

	if [ -f "$dir/lightning.png" ]; then
		cp "$dir/lightning.png" "$MEDIA_DIR/lightning.png"
		if command -v optipng >/dev/null; then
			optipng -quiet -o2 "$MEDIA_DIR/lightning.png"
		fi
		echo "  $MEDIA_DIR/lightning.png"
	fi
}

clips=("$@")
if [ ${#clips[@]} -eq 0 ]; then
	clips=(launch gameplay coop)
fi
for clip in "${clips[@]}"; do
	case "$clip" in
		launch|gameplay|coop) record "$clip" ;;
		*)
			sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
			exit 1
			;;
	esac
done
