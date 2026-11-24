#!/usr/bin/env bash
# Points Godot's editor settings at the Android SDK + JDK and makes sure the
# SDK has the components Godot 4.7 needs for a (non-Gradle) APK export.
#
# Required tools (per Godot 4.7 docs): platform-tools >= 35, build-tools 35.0.1,
# platform android-35, cmdline-tools latest, CMake 3.10.2.4988404, NDK r28b.
set -euo pipefail

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/usr/local/lib/android/sdk}}"
JDK="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")}"
PROJECT_DIR="${1:-game}"

echo "Android SDK: $SDK"
echo "JDK:         $JDK"
[ -d "$SDK" ] || { echo "Android SDK not found at $SDK" >&2; exit 1; }

SDKMANAGER="$(find "$SDK/cmdline-tools" -name sdkmanager -type f 2>/dev/null | head -n1 || true)"
if [ -n "$SDKMANAGER" ]; then
  yes | "$SDKMANAGER" --sdk_root="$SDK" --licenses >/dev/null 2>&1 || true
  "$SDKMANAGER" --sdk_root="$SDK" \
    "platform-tools" "build-tools;35.0.1" "platforms;android-35" \
    "cmake;3.10.2.4988404" "ndk;28.1.13356709" >/dev/null
else
  echo "WARNING: sdkmanager not found; assuming the SDK already has the required components."
fi

# Let Godot create its editor settings file once, then patch it.
godot --headless --editor --quit --path "$PROJECT_DIR" >/dev/null 2>&1 || true

CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/godot"
mkdir -p "$CFG_DIR"
shopt -s nullglob
FILES=("$CFG_DIR"/editor_settings-*.tres)
if [ ${#FILES[@]} -eq 0 ]; then
  FILES=("$CFG_DIR/editor_settings-4.tres")
  printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' > "${FILES[0]}"
fi

for f in "${FILES[@]}"; do
  sed -i '/^export\/android\/android_sdk_path/d;/^export\/android\/java_sdk_path/d' "$f"
  printf 'export/android/android_sdk_path = "%s"\nexport/android/java_sdk_path = "%s"\n' "$SDK" "$JDK" >> "$f"
  echo "Patched $f"
done
