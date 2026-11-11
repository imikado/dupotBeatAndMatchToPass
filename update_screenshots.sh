#!/bin/bash
# Met à jour les captures d'écran de Beat and Match to Pass
# (export/linux/screenshots/Screenshot_NN.png) et leurs URLs dans l'appdata Flathub.
#
# Usage :
#   ./update_screenshots.sh capture   # lance le jeu en mode visite : il joue tout seul et
#                                     # remplace Screenshot_01..09.png (aucune action requise)
#   ./update_screenshots.sh manual    # lance le jeu : F12 = capture, quitter le jeu pour finir,
#                                     # puis choix des captures qui remplacent Screenshot_NN.png
#   ./update_screenshots.sh appdata   # après commit + push des captures : pointe les URLs de
#                                     # l'appdata vers le dernier commit qui les a modifiées
set -e

cd "$(dirname "$0")"

GODOT="${GODOT:-$(command -v godot || echo "$HOME/apps/Godot_v4.7.2-stable_linux.x86_64")}"
# Une visite complète dure environ 3 minutes
TOUR_TIMEOUT="${TOUR_TIMEOUT:-600}"
SCREENSHOT_DIR="export/linux/screenshots"
APPDATA="export/linux/flatpak/org.dupot.beatmatchtopass.appdata.xml"
REPO_RAW_URL="https://raw.githubusercontent.com/imikado/dupotBeatAndMatchToPass"

check_godot() {
	if [ ! -x "$GODOT" ]; then
		echo "Godot introuvable ($GODOT) : définir la variable GODOT" >&2
		exit 1
	fi
}

# Écrit les captures données, dans l'ordre, en Screenshot_01.png, Screenshot_02.png…
install_screenshots() {
	rm -f "$SCREENSHOT_DIR"/Screenshot_*.png
	local i
	local files=("$@")
	for i in "${!files[@]}"; do
		cp "${files[$i]}" "$(printf "%s/Screenshot_%02d.png" "$SCREENSHOT_DIR" $((i + 1)))"
	done
	# .import des captures en trop (Godot régénère les autres)
	for i in "$SCREENSHOT_DIR"/Screenshot_*.png.import; do
		[ -f "${i%.import}" ] || rm -f "$i"
	done

	if command -v optipng >/dev/null; then
		optipng -quiet -o2 "$SCREENSHOT_DIR"/Screenshot_*.png
	fi

	echo
	echo "${#files[@]} captures écrites dans $SCREENSHOT_DIR"
	if [ "${#files[@]}" -ne 9 ]; then
		echo "Attention : le tableau du README.md affiche 9 captures, l'adapter"
	fi
	echo "Ensuite : commit + push, puis ./update_screenshots.sh appdata"
}

capture() {
	check_godot

	local staging
	staging="$(mktemp -d)"
	trap 'rm -rf "$staging"' EXIT

	echo "Visite automatique en cours (ne pas toucher à la fenêtre du jeu)…"
	timeout "$TOUR_TIMEOUT" "$GODOT" --path . -- --screenshots="$staging" --tour \
		| grep --line-buffered "^Capture" || true

	local expected=9
	local shots=("$staging"/Screenshot_*.png)
	if [ ! -f "${shots[0]}" ] || [ "${#shots[@]}" -ne "$expected" ]; then
		echo "Visite incomplète : ${#shots[@]}/$expected captures, rien n'est remplacé" >&2
		exit 1
	fi

	install_screenshots "${shots[@]}"
}

manual() {
	check_godot

	local staging
	staging="$(mktemp -d)"
	trap 'rm -rf "$staging"' EXIT

	echo "Jouer jusqu'aux scènes voulues, F12 pour capturer, puis quitter le jeu."
	"$GODOT" --path . -- --screenshots="$staging"

	local captures=("$staging"/capture_*.png)
	if [ ! -f "${captures[0]}" ]; then
		echo "Aucune capture prise : rien à mettre à jour" >&2
		exit 1
	fi

	echo
	echo "Captures prises :"
	local i
	for i in "${!captures[@]}"; do
		echo "  $((i + 1)) : $(basename "${captures[$i]}")"
	done
	if command -v xdg-open >/dev/null; then
		xdg-open "$staging" >/dev/null 2>&1 || true
	fi

	echo
	echo "Numéros des captures à garder, dans l'ordre (la 1re devient l'image par défaut)"
	read -r -p "[Entrée = toutes] : " selection
	if [ -z "$selection" ]; then
		selection="$(seq -s ' ' 1 "${#captures[@]}")"
	fi

	local selected=()
	local n
	for n in $selection; do
		if ! [[ "$n" =~ ^[0-9]+$ ]] || [ "$n" -lt 1 ] || [ "$n" -gt "${#captures[@]}" ]; then
			echo "Numéro invalide : $n" >&2
			exit 1
		fi
		selected+=("${captures[$((n - 1))]}")
	done

	install_screenshots "${selected[@]}"
}

appdata() {
	local commit
	commit="$(git log -1 --format=%H -- "$SCREENSHOT_DIR")"
	if [ -z "$commit" ]; then
		echo "Aucun commit ne contient $SCREENSHOT_DIR" >&2
		exit 1
	fi
	if [ -n "$(git status --porcelain -- "$SCREENSHOT_DIR")" ]; then
		echo "Captures modifiées non commitées dans $SCREENSHOT_DIR : les commiter d'abord" >&2
		exit 1
	fi

	# Les URLs raw.githubusercontent.com doivent exister côté GitHub
	git fetch --quiet origin
	if [ -z "$(git branch -r --contains "$commit")" ]; then
		echo "Le commit $commit n'est pas encore poussé sur origin" >&2
		exit 1
	fi

	local block="  <screenshots>"
	local file type
	type=' type="default"'
	for file in "$SCREENSHOT_DIR"/Screenshot_*.png; do
		block+=$'\n'"    <screenshot$type>"
		block+=$'\n'"      <image>$REPO_RAW_URL/$commit/$file</image>"
		block+=$'\n'"    </screenshot>"
		type=""
	done
	block+=$'\n'"  </screenshots>"

	# Remplace le bloc <screenshots>…</screenshots> existant
	BLOCK="$block" perl -0pi -e 's/^  <screenshots>.*?<\/screenshots>/$ENV{BLOCK}/ms' "$APPDATA"

	if command -v appstreamcli >/dev/null; then
		appstreamcli validate --no-net "$APPDATA" || true
	fi

	echo "URLs des captures de $APPDATA pointées sur le commit $commit"
}

case "$1" in
	capture) capture ;;
	manual) manual ;;
	appdata) appdata ;;
	*)
		sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
		exit 1
		;;
esac
