#!/bin/bash
# Extract candidate priority names from a GSTinTin char config file.
# Prints one lowercase name per line. See priority_sort.tin for context.
#
# Grabs the last brace group on each line containing [patterns], then
# splits on semicolons. Single-value groups (no semicolon) are included.
path="$1"
[ -f "$path" ] || exit 0
grep 'patterns' "$path" \
  | grep -oE '\{[^{}]+\}$' \
  | tr ';{}' '\n' \
  | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
  | awk 'NF' \
  | tr '[:upper:]' '[:lower:]' \
  | sort -u
