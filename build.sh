#!/bin/bash
# claude-desktop-monterey: build a Monterey-compatible copy of Claude Desktop.
#
# Runs the app code from your own, official Claude.app on an older Electron
# runtime that still supports macOS 12. Nothing from Anthropic is redistributed:
# the app is read from a copy you downloaded yourself.
#
# Usage:
#   SRC_APP=/Volumes/Claude/Claude.app ./build.sh [--install] [electron-version]
#
# Env:
#   SRC_APP    path to the official Claude.app  (default: /Applications/Claude.app)
#   WORKDIR    build directory                  (default: ~/claude-monterey)
set -euo pipefail

INSTALL=0
ELECTRON_VERSION="43.7.10"   # newest Electron major that supports macOS 12 (44+ needs macOS 13)
for a in "$@"; do
  case "$a" in
    --install) INSTALL=1 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) ELECTRON_VERSION="$a" ;;
  esac
done

SRC_APP="${SRC_APP:-/Applications/Claude.app}"
WORKDIR="${WORKDIR:-$HOME/claude-monterey}"
BUNDLE_ID="com.anthropic.claudefordesktop.monterey"
OUT="$WORKDIR/Claude-Monterey.app"

case "$(uname -m)" in x86_64) EARCH=x64;; arm64) EARCH=arm64;; *) echo "Unsupported arch"; exit 1;; esac
for t in node npm npx curl unzip codesign; do command -v "$t" >/dev/null || { echo "Missing dependency: $t (install Node from https://nodejs.org)"; exit 1; }; done
[ -d "$SRC_APP" ] || { echo "Claude.app not found at $SRC_APP. Download it from https://claude.ai/download, mount the .dmg and set SRC_APP."; exit 1; }

mkdir -p "$WORKDIR/cache"; cd "$WORKDIR"
pgrep -f "Claude-Monterey.app/Contents/MacOS" >/dev/null && { echo "Quit Claude-Monterey first (Cmd+Q), then re-run."; exit 1; }
echo "Source Claude: $(defaults read "$SRC_APP/Contents/Info.plist" CFBundleShortVersionString)  (bundled Electron $(defaults read "$SRC_APP/Contents/Frameworks/Electron Framework.framework/Resources/Info.plist" CFBundleVersion))"
echo "Target runtime: Electron $ELECTRON_VERSION ($EARCH)"

# 1. Electron runtime (official GitHub release only)
ZIP="cache/electron-v$ELECTRON_VERSION-darwin-$EARCH.zip"
[ -f "$ZIP" ] || curl -fL -o "$ZIP" "https://github.com/electron/electron/releases/download/v$ELECTRON_VERSION/electron-v$ELECTRON_VERSION-darwin-$EARCH.zip"
rm -rf electron-x "$OUT" && mkdir electron-x && unzip -q "$ZIP" -d electron-x && mv electron-x/Electron.app "$OUT" && rm -rf electron-x

# 2. App code + resources (skip locale dirs and Electron's default_app)
rm -rf Claude-orig.app && cp -R "$SRC_APP" Claude-orig.app
O=Claude-orig.app/Contents; M="$OUT/Contents"
for f in "$O"/Resources/*; do b=$(basename "$f"); case "$b" in *.lproj|default_app.asar) continue;; esac; cp -R "$f" "$M/Resources/"; done
[ -d "$O/Helpers" ] && cp -R "$O/Helpers" "$M/Helpers"

# 3. Patch: disable the in-app updater (an update would replace this build with an unsupported one)
rm -rf app-src && npx --yes @electron/asar extract "$M/Resources/app.asar" app-src
node - <<'JS'
const fs = require("fs"), path = require("path");
const dir = "app-src/.vite/build"; let n = 0;
const re = /if\((\w+)\.autoUpdate\.disabled\)\{(\w+)\.info\("\[updater\] Auto-updates disabled by enterprise policy"\)/;
for (const f of fs.readdirSync(dir).filter(f => f.endsWith(".js"))) {
  const p = path.join(dir, f); let s = fs.readFileSync(p, "utf8");
  if (re.test(s)) { s = s.replace(re, 'if(!0){$2.info("[updater] Auto-updates disabled (monterey patch)")'); fs.writeFileSync(p, s); n++; }
}
if (n !== 1) { console.error("Auto-update patch did not match (" + n + "). Claude changed its updater code; see README > Troubleshooting."); process.exit(2); }
console.log("auto-update patch applied");
JS
npx @electron/asar pack app-src "$M/Resources/app.asar"

# 4. Info.plist: name, id, icon, claude:// URL scheme. The executable must not be called "Electron",
#    otherwise app.isPackaged is false and the app cannot find its resources.
P="$M/Info.plist"; PB=/usr/libexec/PlistBuddy
mv "$M/MacOS/Electron" "$M/MacOS/Claude"
$PB -c "Set :CFBundleExecutable Claude" -c "Set :CFBundleName Claude" -c "Set :CFBundleIdentifier $BUNDLE_ID" -c "Set :CFBundleIconFile electron.icns" "$P"
$PB -c "Add :CFBundleDisplayName string Claude" "$P" 2>/dev/null || $PB -c "Set :CFBundleDisplayName Claude" "$P"
$PB -c "Delete :CFBundleURLTypes" "$P" 2>/dev/null || true
$PB -c "Add :CFBundleURLTypes array" -c "Add :CFBundleURLTypes:0 dict" -c "Add :CFBundleURLTypes:0:CFBundleURLName string Claude" \
    -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string claude" "$P"

# 5. Ad-hoc sign
xattr -cr "$OUT"
codesign --force --deep --sign - "$OUT"
rm -rf app-src Claude-orig.app
echo "Built: $OUT"

if [ "$INSTALL" = 1 ]; then
  rm -rf /Applications/Claude-Monterey.app && cp -R "$OUT" /Applications/ && echo "Installed: /Applications/Claude-Monterey.app"
else
  echo "Run it:      open '$OUT'"
  echo "Install it:  re-run with --install, or: cp -R '$OUT' /Applications/"
fi
