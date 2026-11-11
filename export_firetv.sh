#!/bin/bash
# Exporte Beat and Match to Pass pour Amazon Fire TV (preset « FireTV ») : APK
# armeabi-v7a seul (recommandation Amazon, < 50 Mo), bibliothèques compressées, lanceur Android TV (leanback, build Gradle), sans contrôles tactiles.
#
# Usage : ./export_firetv.sh [release] [install]
#   release : APK signé avec le keystore release (Amazon Appstore), mot de passe
#             demandé (ou GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD) ; sinon export debug
#   install : adb install -r sur le Fire TV connecté
# Keystore : GODOT_ANDROID_KEYSTORE_RELEASE_PATH / _USER (alias) pour changer les valeurs par défaut
set -e

RELEASE=false
INSTALL=false
for arg in "$@"; do
	case "$arg" in
		release) RELEASE=true ;;
		install) INSTALL=true ;;
		*) echo "Argument inconnu : $arg (release, install)" >&2; exit 1 ;;
	esac
done

cd "$(dirname "$0")"

GODOT="${GODOT:-$(command -v godot || echo "$HOME/apps/Godot_v4.7.2-stable_linux.x86_64")}"
PRESET="FireTV"
EXPORT_DIR="export/android/firetv"
APK="$EXPORT_DIR/BeatAndMatchToPass-firetv.apk"

if [ ! -x "$GODOT" ]; then
	echo "Godot introuvable ($GODOT) : définir la variable GODOT" >&2
	exit 1
fi

if ! grep -q "^name=\"$PRESET\"" export_presets.cfg 2>/dev/null; then
	echo "Preset « $PRESET » absent de export_presets.cfg : le créer dans Godot (Projet > Exporter)" >&2
	exit 1
fi

GODOT_VERSION="$("$GODOT" --version | sed "s/\.official.*//")"
TEMPLATES="$HOME/.local/share/godot/export_templates/$GODOT_VERSION"
if [ ! -f "$TEMPLATES/android_source.zip" ]; then
	echo "Modèles d'export Android absents pour Godot $GODOT_VERSION ($TEMPLATES)" >&2
	exit 1
fi

# Chemins Java / Android SDK dans les paramètres de l'éditeur (l'éditeur ouvert peut les
# écraser à sa fermeture) : remis à chaque export
SDK_ROOT="${SDK_ROOT:-/home/mika/code/SDK}"
JAVA_SDK="${JAVA_SDK:-$SDK_ROOT/jdk17}"
ANDROID_SDK="${ANDROID_SDK:-$SDK_ROOT/android-sdk}"
EDITOR_SETTINGS="$HOME/.config/godot/editor_settings-$(echo "$GODOT_VERSION" | grep -oE '^[0-9]+\.[0-9]+').tres"
if [ ! -x "$JAVA_SDK/bin/java" ] || [ ! -d "$ANDROID_SDK/build-tools" ] || [ ! -d "$ANDROID_SDK/platform-tools" ]; then
	echo "Java ($JAVA_SDK) ou Android SDK ($ANDROID_SDK) incomplet" >&2
	exit 1
fi
if [ ! -f "$EDITOR_SETTINGS" ]; then
	echo "Paramètres de l'éditeur introuvables ($EDITOR_SETTINGS) : ouvrir Godot une fois" >&2
	exit 1
fi
if pgrep -f "^[^ ]*[Gg]odot[^ ]* .*--editor" >/dev/null; then
	echo "Attention : l'éditeur Godot est ouvert, il peut écraser les chemins SDK à sa fermeture" >&2
fi
for kv in "java_sdk_path=$JAVA_SDK" "android_sdk_path=$ANDROID_SDK"; do
	key="${kv%%=*}"; val="${kv#*=}"
	if grep -q "^export/android/$key = " "$EDITOR_SETTINGS"; then
		sed -i "s|^export/android/$key = .*|export/android/$key = \"$val\"|" "$EDITOR_SETTINGS"
	else
		echo "export/android/$key = \"$val\"" >> "$EDITOR_SETTINGS"
	fi
done

if $RELEASE; then
	export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-$HOME/Documents/sync/android/androidstudio.keystore}"
	export GODOT_ANDROID_KEYSTORE_RELEASE_USER="${GODOT_ANDROID_KEYSTORE_RELEASE_USER:-key0}"
	if [ ! -f "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" ]; then
		echo "Keystore release introuvable : $GODOT_ANDROID_KEYSTORE_RELEASE_PATH" >&2
		exit 1
	fi
	if [ -z "$GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD" ]; then
		read -r -s -p "Mot de passe du keystore ($GODOT_ANDROID_KEYSTORE_RELEASE_USER) : " GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
		echo
		export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
	fi
fi

# Version du jeu reprise de l'appdata
./update_version.sh
VERSION="$(grep -oP '^config/version="\K[^"]+' project.godot)"
# version/code : unique et croissant pour chaque APK envoyé à l'Appstore.
# Base X.Y.Z -> X*1000000 + Y*10000 + Z*100, puis +1 à chaque release de la même version.
# Le dernier code publié est conservé (versionné) dans $VERSION_CODE_FILE.
VERSION_CODE_FILE="export/firetv_version_code.txt"
IFS=. read -r V_MAJOR V_MINOR V_PATCH <<< "$VERSION"
BASE_CODE=$((V_MAJOR * 1000000 + V_MINOR * 10000 + ${V_PATCH:-0} * 100))
LAST_CODE="$(grep -oE '^[0-9]+' "$VERSION_CODE_FILE" 2>/dev/null || echo 0)"
if [ "$BASE_CODE" -gt "$LAST_CODE" ]; then
	VERSION_CODE=$BASE_CODE
elif $RELEASE; then
	VERSION_CODE=$((LAST_CODE + 1))
else
	VERSION_CODE=$LAST_CODE
fi
awk -v name="$PRESET" -v code="$VERSION_CODE" -v ver="$VERSION" '
	/^\[preset\.[0-9]+\]$/ { in_preset = 0 }
	/^name=/ { in_preset = ($0 == "name=\"" name "\"") }
	in_preset && /^version\/code=/ { $0 = "version/code=" code }
	in_preset && /^version\/name=/ { $0 = "version/name=\"" ver "\"" }
	{ print }
' export_presets.cfg > export_presets.cfg.tmp && mv export_presets.cfg.tmp export_presets.cfg
echo "Version : $VERSION (code $VERSION_CODE)"

mkdir -p export
touch export/.gdignore
mkdir -p "$EXPORT_DIR"
rm -f "$APK"

"$GODOT" --headless --path . --import
# Build Gradle (requis pour le lanceur Android TV / leanback) : modèle dans res://android
INSTALL_TEMPLATE=""
if [ ! -f android/build/build.gradle ] || ! grep -q "^$GODOT_VERSION" android/.build_version 2>/dev/null; then
	rm -rf android
	INSTALL_TEMPLATE="--install-android-build-template"
fi
if $RELEASE; then
	"$GODOT" --headless --path . $INSTALL_TEMPLATE --export-release "$PRESET" "$APK"
	MODE="release"
else
	"$GODOT" --headless --path . $INSTALL_TEMPLATE --export-debug "$PRESET" "$APK"
	MODE="debug"
fi

if [ ! -f "$APK" ]; then
	echo "Échec de l'export (SDK Android configuré dans Éditeur > Paramètres > Export > Android ?)" >&2
	exit 1
fi
echo "APK ($MODE) : $APK ($(du -h "$APK" | cut -f1))"
if $RELEASE; then
	echo "$VERSION_CODE" > "$VERSION_CODE_FILE"
	echo "Version code $VERSION_CODE enregistré dans $VERSION_CODE_FILE (à commiter)"
fi
# Amazon Appstore avertit au-delà de 50 Mo
if $RELEASE && [ "$(stat -c %s "$APK")" -gt $((50 * 1024 * 1024)) ]; then
	echo "Attention : APK > 50 Mo (avertissement Amazon Appstore)" >&2
fi

if $INSTALL; then
	"${ADB:-$(command -v adb || echo /home/mika/code/SDK/android-sdk/platform-tools/adb)}" install -r "$APK"
fi
