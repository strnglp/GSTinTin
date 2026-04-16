#!/usr/bin/env bash
# Launch GemStone IV: starts lich-5 then connects tt++ via GSTinTin

LICH_DIR="$HOME/Projects/lich-5"
GSTIN_DIR="$HOME/Projects/GSTinTin"
CHAR="${1:-YourCharName}"
PORT="${2:-8000}"

# Start lich in the background
cd "$LICH_DIR"
ruby lich.rbw --login "$CHAR" --detachable-client="$PORT" --without-frontend --gemstone &
LICH_PID=$!

# Wait for lich to start listening
for i in $(seq 1 30); do
    if ss -tln | grep -q ":$PORT "; then
        break
    fi
    sleep 1
done

if ! ss -tln | grep -q ":$PORT "; then
    echo "Lich failed to start on port $PORT"
    kill "$LICH_PID" 2>/dev/null
    exit 1
fi

# Launch tt++
cd "$GSTIN_DIR"
tt++ gstin.tin

# When tt++ exits, clean up lich
kill "$LICH_PID" 2>/dev/null
