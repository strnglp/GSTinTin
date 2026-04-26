#!/usr/bin/env bash
# GSTinTin uninstaller
#
# Removes the launcher, the GSTinTin clone, and (optionally) the lich-5 clone.
# Does NOT remove: Ruby, system packages, Nerd Fonts, or your lich credentials
# in ~/.lich (those are reusable across reinstalls).

set -euo pipefail

# When invoked via `curl | bash`, stdin IS the script. Re-exec from a temp file
# so stdin becomes the real TTY and interactive prompts work.
if [[ ! -t 0 ]]; then
    _self=$(mktemp "${TMPDIR:-/tmp}/gstintin-uninstall.XXXXXX")
    cat > "$_self"
    export _GSTINTIN_UNINSTALL_TMPSCRIPT="$_self"
    exec bash "$_self" "$@"
fi
# Clean up the temp file we were re-exec'd from
[[ -n "${_GSTINTIN_UNINSTALL_TMPSCRIPT:-}" ]] && trap 'rm -f "$_GSTINTIN_UNINSTALL_TMPSCRIPT"' EXIT

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
LICH_DIR="$DATA_HOME/lich-5"
GSTIN_DIR="$DATA_HOME/GSTinTin"
LAUNCHER="$BIN_DIR/gemstone"

YES=0
REMOVE_LICH=0

usage() {
    cat <<EOF
GSTinTin uninstaller

Usage: uninstall.sh [options]

  --yes              Don't prompt; remove without confirmation
  --remove-lich      Also remove $LICH_DIR
  --lich-dir DIR     Override lich-5 dir
  --gstin-dir DIR    Override GSTinTin dir
  -h, --help         Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes) YES=1; shift;;
        --remove-lich) REMOVE_LICH=1; shift;;
        --lich-dir) LICH_DIR="$2"; shift 2;;
        --gstin-dir) GSTIN_DIR="$2"; shift 2;;
        -h|--help) usage; exit 0;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2;;
    esac
done

confirm() {
    local q="$1"
    (( YES )) && return 0
    local a
    if [[ -t 0 ]]; then
        read -r -p "$q [y/N] " a
    else
        read -r -p "$q [y/N] " a < /dev/tty
    fi
    [[ "$a" =~ ^[Yy]$ ]]
}

remove_path() {
    local p="$1"
    if [[ -e "$p" ]]; then
        rm -rf "$p"
        echo "removed $p"
    else
        echo "skip   $p (not found)"
    fi
}

# Ask about removing lich if not already set by flag and not in --yes mode
if (( ! REMOVE_LICH )) && (( ! YES )); then
    if [[ -d "$LICH_DIR" ]]; then
        echo "lich-5 is installed at: $LICH_DIR"
        if confirm "Also remove lich-5?"; then
            REMOVE_LICH=1
        fi
    fi
fi

echo
echo "Will remove:"
echo "  $LAUNCHER"
echo "  $GSTIN_DIR"
(( REMOVE_LICH )) && echo "  $LICH_DIR"
echo
confirm "Proceed?" || { echo "Aborted."; exit 1; }

remove_path "$LAUNCHER"
remove_path "$GSTIN_DIR"
(( REMOVE_LICH )) && remove_path "$LICH_DIR"

cat <<EOF

Done. Not touched:
  • Ruby, gems, system packages
  • Nerd Fonts
  • Saved lich credentials (stored within lich-5 directory)
  • PATH/shell rc additions (remove manually if desired)
EOF
