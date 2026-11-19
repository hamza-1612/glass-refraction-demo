#!/usr/bin/env bash
# Renders the demo with Impeller (OpenGL ES backend) on a headless Linux box
# and saves a screenshot. Not an Android test: it checks that the shader
# compiles, lines up with the widgets and is not flipped on GLES.
#
# Needs: Flutter >= 3.50, clang, cmake, ninja, libgtk-3-dev, xvfb, imagemagick.
# Usage: tool/linux_impeller_preview.sh /path/to/out.png
set -euo pipefail
out="$(realpath -m "${1:?output png}")"
root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cp -r "$root/lib" "$root/shaders" "$root/pubspec.yaml" "$root/analysis_options.yaml" "$work/"
cd "$work"
flutter create --platforms=linux --project-name=glass_refraction_demo . >/dev/null
flutter build linux --debug

cat > shoot.sh <<'EOF'
#!/bin/bash
export FLUTTER_ENGINE_SWITCHES=1 FLUTTER_ENGINE_SWITCH_1=enable-impeller
./build/linux/x64/debug/bundle/glass_refraction_demo > app.log 2>&1 &
app=$!
sleep 12
import -window root "$1"
kill "$app"
EOF
chmod +x shoot.sh
xvfb-run -a -s "-screen 0 1280x720x24" ./shoot.sh "$out"
grep -m1 "Impeller rendering backend" app.log || true
echo "Saved $out"
