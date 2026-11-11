#!/bin/bash
# Exporte Beat and Match to Pass pour le Snap Store : génère l'exécutable et le .pck
# (preset « Linux ») dans export/linux/snap/, puis construit le .snap avec
# export/linux/snap/build-snap.sh.
#
# Usage :
#   ./export_snap.sh            # export + pack
#   ./export_snap.sh --install  # export + pack + installation locale
set -e

cd "$(dirname "$0")"

GODOT="${GODOT:-$(command -v godot || echo "$HOME/apps/Godot_v4.7.2-stable_linux.x86_64")}"
PRESET="Linux"
SNAP_DIR="export/linux/snap"
BINARY="$SNAP_DIR/beatmatchtopass.x86_64"
PCK="$SNAP_DIR/beatmatchtopass.pck"

if [ ! -x "$GODOT" ]; then
	echo "Godot introuvable ($GODOT) : définir la variable GODOT" >&2
	exit 1
fi

if ! command -v snapcraft >/dev/null; then
	echo "snapcraft introuvable : sudo snap install snapcraft --classic" >&2
	exit 1
fi

# export_presets.cfg n'est pas versionné : il doit contenir le preset « Linux »
if ! grep -q "^name=\"$PRESET\"" export_presets.cfg 2>/dev/null; then
	echo "Preset « $PRESET » absent de export_presets.cfg : le créer dans Godot (Projet > Exporter)" >&2
	exit 1
fi

# Les modèles d'export Linux doivent correspondre à la version de Godot
GODOT_VERSION="$("$GODOT" --version | sed "s/\.official.*//")"
TEMPLATES="$HOME/.local/share/godot/export_templates/$GODOT_VERSION"
if [ ! -f "$TEMPLATES/linux_release.x86_64" ]; then
	echo "Modèles d'export Linux absents pour Godot $GODOT_VERSION ($TEMPLATES)" >&2
	exit 1
fi

# La version du snap suit celle du jeu
"$SNAP_DIR/update-version.sh"

# Godot ne doit pas importer (ni embarquer dans le .pck) les fichiers exportés
mkdir -p export
touch export/.gdignore

# Import des ressources puis export release (le preset n'embarque pas le pck :
# l'exécutable et le .pck sont générés côte à côte, comme l'attend snapcraft.yaml)
rm -f "$BINARY" "$PCK"
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --export-release "$PRESET" "$BINARY"

for f in "$BINARY" "$PCK"; do
	if [ ! -f "$f" ]; then
		echo "Échec de l'export ($f)" >&2
		exit 1
	fi
done
chmod 755 "$BINARY"

echo "Binaire : $BINARY ($(du -h "$BINARY" | cut -f1))"
echo "Pck     : $PCK ($(du -h "$PCK" | cut -f1))"

"$SNAP_DIR/build-snap.sh" "$@"
