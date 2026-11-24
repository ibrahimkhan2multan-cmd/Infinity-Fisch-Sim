#!/usr/bin/env bash
# Installs the Godot editor (headless use) and Android export templates.
# Used by .github/workflows/godot-android.yml, but also works on any Linux box.
#
#   GODOT_TAG   release tag on godotengine/godot-builds   (default: 4.7-stable)
#   GODOT_HOME  where to install                           (default: $HOME/godot-ci)
set -euo pipefail

GODOT_TAG="${GODOT_TAG:-4.7-stable}"
GODOT_HOME="${GODOT_HOME:-$HOME/godot-ci}"
BASE="https://github.com/godotengine/godot-builds/releases/download/${GODOT_TAG}"

mkdir -p "$GODOT_HOME/dl" "$GODOT_HOME/bin"
cd "$GODOT_HOME/dl"

if [ ! -f godot.zip ]; then
  echo "Downloading Godot ${GODOT_TAG} editor..."
  curl -fsSL --retry 4 --retry-delay 5 -o godot.zip "${BASE}/Godot_v${GODOT_TAG}_linux.x86_64.zip"
fi
if [ ! -f templates.tpz ]; then
  echo "Downloading Godot ${GODOT_TAG} export templates..."
  curl -fsSL --retry 4 --retry-delay 5 -o templates.tpz "${BASE}/Godot_v${GODOT_TAG}_export_templates.tpz"
fi

rm -rf editor tpl
unzip -oq godot.zip -d editor
BIN="$(find editor -maxdepth 1 -type f -name 'Godot_v*linux*x86_64*' ! -name '*.zip' | head -n1)"
[ -n "$BIN" ] || { echo "Godot binary not found in archive" >&2; exit 1; }
install -m 0755 "$BIN" "$GODOT_HOME/bin/godot"

# Templates live in  ~/.local/share/godot/export_templates/<version.txt contents>/
unzip -oq templates.tpz -d tpl
TPL_VERSION="$(tr -d '[:space:]' < tpl/templates/version.txt)"
DEST="$HOME/.local/share/godot/export_templates/${TPL_VERSION}"
mkdir -p "$DEST"
cp -r tpl/templates/. "$DEST/"
rm -rf tpl editor

echo "Godot:      $("$GODOT_HOME/bin/godot" --headless --version)"
echo "Templates:  $DEST"
ls "$DEST" | grep -i android || { echo "Android templates missing!" >&2; exit 1; }

if [ -n "${GITHUB_PATH:-}" ]; then
  echo "$GODOT_HOME/bin" >> "$GITHUB_PATH"
fi
