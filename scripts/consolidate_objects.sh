#!/bin/bash
# Consolidates duplicate items in a "You also see" string.
# Input: raw XML objects string (from stdin)
# Output: consolidated string with (xN) counts, XML tags preserved for first occurrence
# Items are comma-separated, last item joined with "and"

input=$(cat)

# Extract prefix ("  You also see ") and items
prefix=""
items="$input"
if [[ "$input" =~ ^([[:space:]]*You\ also\ see\ )(.*)$ ]]; then
    prefix="${BASH_REMATCH[1]}"
    items="${BASH_REMATCH[2]}"
fi

# Remove trailing period
items="${items%.}"

# Replace " and " before last item with ", " for uniform splitting
# Match ", and " or " and " at the last occurrence
items=$(echo "$items" | sed 's/, and \([^,]*\)$/, \1/; s/ and \([^,]*\)$/, \1/')

# Split on ", " and process
declare -A counts
declare -A first_seen
declare -a order

IFS=$'\n'
while read -r item; do
    # Strip XML tags for comparison key
    key=$(echo "$item" | sed 's/<[^>]*>//g' | sed 's/^ *//')

    if [[ -z "$key" ]]; then
        continue
    fi

    if [[ -z "${counts[$key]}" ]]; then
        counts[$key]=1
        first_seen[$key]="$item"
        order+=("$key")
    else
        counts[$key]=$(( ${counts[$key]} + 1 ))
    fi
done < <(echo "$items" | tr ',' '\n' | sed 's/^ *//')

# Rebuild
result=""
for key in "${order[@]}"; do
    if [[ -n "$result" ]]; then
        result="$result, "
    fi
    if [[ ${counts[$key]} -gt 1 ]]; then
        result="$result${first_seen[$key]} (x${counts[$key]})"
    else
        result="$result${first_seen[$key]}"
    fi
done

echo "${prefix}${result}."
