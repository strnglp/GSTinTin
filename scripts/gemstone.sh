#!/usr/bin/env bash
# Launch GemStone IV: starts lich-5 then connects tt++ via GSTinTin

LICH_DIR="${LICH_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/lich-5}"
GSTIN_DIR="${GSTIN_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/GSTinTin}"
CHAR="${1:-YourCharName}"
PORT="${2:-8000}"

# Start lich in the background
cd "$LICH_DIR"
ruby lich.rbw --gtk --login "$CHAR" --detachable-client="$PORT" --without-frontend --gemstone &
LICH_PID=$!

_port_listening() {
    if command -v ss >/dev/null 2>&1; then
        ss -tln | grep -q ":${1} "
    elif command -v lsof >/dev/null 2>&1; then
        lsof -iTCP:"${1}" -sTCP:LISTEN >/dev/null 2>&1
    else
        return 1
    fi
}

# Wait for lich to start listening
for i in $(seq 1 30); do
    _port_listening "$PORT" && break
    if ! kill -0 "$LICH_PID" 2>/dev/null; then
        echo "lich-5 exited before opening port $PORT."
        echo "Run manually to debug: cd \"$LICH_DIR\" && ruby lich.rbw --login \"$CHAR\" --detachable-client=$PORT --without-frontend --gemstone"
        exit 1
    fi
    sleep 1
done

if ! _port_listening "$PORT"; then
    echo "Lich failed to start on port $PORT"
    kill "$LICH_PID" 2>/dev/null
    exit 1
fi

# Launch tt++
cd "$GSTIN_DIR"
tt++ gstin.tin

# When tt++ exits, clean up lich
kill "$LICH_PID" 2>/dev/null
