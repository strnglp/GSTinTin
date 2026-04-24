#!/bin/bash
# Extract candidate priority names from a GSTinTin char config file.
# Prints one lowercase name per line. See priority_sort.tin for context.
path="$1"
[ -f "$path" ] || exit 0
grep -oE '\{[^{}]*;[^{}]*\}' "$path" \
  | tr ';{}' '\n' \
  | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
  | awk 'NF' \
  | tr '[:upper:]' '[:lower:]' \
  | sort -u
