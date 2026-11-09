#!/usr/bin/env bash
# Installer for the When Prayer Times DankMaterialShell plugin.
#
# Usage:
#   ./install.sh              copy the plugin into the DMS plugins dir
#   ./install.sh --link       symlink instead of copy (live editing)
#   ./install.sh --uninstall  remove the plugin
#   ./install.sh --no-reload  skip the DMS reload step
#   ./install.sh --help
set -euo pipefail

PLUGIN_ID="whenPrayer"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS_DIR="${DMS_PLUGINS_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell/plugins}"
DEST="$PLUGINS_DIR/$PLUGIN_ID"
FILES=(plugin.json WhenWidget.qml WhenSettings.qml README.md)

MODE="copy"
RELOAD=1

if [ -t 1 ]; then
  B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
else
  B=""; G=""; Y=""; R=""; N=""
fi
info() { printf '%s==>%s %s\n' "$G$B" "$N" "$*"; }
warn() { printf '%swarning:%s %s\n' "$Y$B" "$N" "$*" >&2; }
die()  { printf '%serror:%s %s\n' "$R$B" "$N" "$*" >&2; exit 1; }

usage() { sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

for arg in "$@"; do
  case "$arg" in
    --link)       MODE="link" ;;
    --uninstall)  MODE="uninstall" ;;
    --no-reload)  RELOAD=0 ;;
    -h|--help)    usage; exit 0 ;;
    *)            usage; die "unknown option: $arg" ;;
  esac
done

reload_dms() {
  [ "$RELOAD" -eq 1 ] || return 0
  if ! command -v dms >/dev/null 2>&1; then
    warn "'dms' not found in PATH; restart the shell manually."
    return 0
  fi
  if dms ipc call plugins reload "$PLUGIN_ID" >/dev/null 2>&1; then
    info "Reloaded plugin in the running shell."
  else
    warn "Live reload failed (plugin may not be enabled yet). Run 'dms restart' if it doesn't appear."
  fi
}

if [ "$MODE" = "uninstall" ]; then
  if [ -e "$DEST" ] || [ -L "$DEST" ]; then
    rm -rf "$DEST"
    info "Removed $DEST"
    command -v dms >/dev/null 2>&1 && [ "$RELOAD" -eq 1 ] && { dms restart >/dev/null 2>&1 || true; }
  else
    info "Nothing to remove at $DEST"
  fi
  exit 0
fi

# ── Sanity checks ──
for f in "${FILES[@]}"; do
  [ -f "$SRC_DIR/$f" ] || die "missing $f next to install.sh"
done

if ! command -v dms >/dev/null 2>&1; then
  warn "DankMaterialShell ('dms') not found. Installing files anyway."
fi

WHEN_BIN="$(command -v when 2>/dev/null || true)"
if [ -z "$WHEN_BIN" ] && [ -x "$HOME/go/bin/when" ]; then
  WHEN_BIN="$HOME/go/bin/when"
  warn "'when' is not in PATH but exists at $WHEN_BIN."
  warn "DMS may not see ~/go/bin: set that absolute path in the plugin settings."
fi
if [ -z "$WHEN_BIN" ]; then
  warn "'when' CLI not found. Install it with: go install github.com/MAHcodes/when@latest"
elif "$WHEN_BIN" next --json >/dev/null 2>&1; then
  info "when CLI OK ($WHEN_BIN)"
else
  warn "'$WHEN_BIN next --json' failed (network or cache?). The widget will show an error until it works."
fi

for dep in pgrep pkill; do
  command -v "$dep" >/dev/null 2>&1 || warn "'$dep' not found: alarm toggle won't work (install procps)"
done

# ── Install ──
mkdir -p "$PLUGINS_DIR"
if [ -e "$DEST" ] || [ -L "$DEST" ]; then
  rm -rf "$DEST"
fi

if [ "$MODE" = "link" ]; then
  ln -s "$SRC_DIR" "$DEST"
  info "Linked $DEST -> $SRC_DIR"
else
  mkdir -p "$DEST"
  for f in "${FILES[@]}"; do
    install -m 0644 "$SRC_DIR/$f" "$DEST/$f"
  done
  info "Installed to $DEST"
fi

reload_dms

cat <<MSG

${B}Next steps${N}
  1. DMS Settings → Plugins → "Scan for Plugins"
  2. Enable "When Prayer Times"
  3. Add the widget to DankBar (Settings → Dank Bar)
  4. If it doesn't show up: dms restart
MSG
