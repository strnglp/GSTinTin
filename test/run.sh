#!/bin/bash
# Replays /tmp/gstin_raw.log through a local tt++ harness and captures the
# post-substitute output (with ANSI codes) to /tmp/gstin_test.log.
#
# Usage: test/run.sh [lines]
set -u
cd "$(dirname "$0")/.."

LINES="${1:-500}"
PORT=9999
RAWLOG="/tmp/gstin_raw.log"
OUTLOG="/tmp/gstin_test.log"

pkill -9 -f "tt\+\+.*harness.tin" 2>/dev/null || true
pkill -9 -f "nc -l $PORT" 2>/dev/null || true
sleep 0.2

: > "$OUTLOG"
rm -f /tmp/gstin_test_marker.log

# Fake server: stream the last N raw log lines, then hold briefly so tt++
# has time to consume.
( tail -n "$LINES" "$RAWLOG"; sleep 3 ) | nc -l "$PORT" >/dev/null 2>&1 &
SERVER_PID=$!
sleep 0.4

# tt++ with -H -G runs without needing a pty or greeting screen. Give it
# enough time to process the whole replay, then kill it.
tt++ -H -G test/harness.tin < /dev/null > /tmp/tt_stdout.txt 2>&1 &
TT_PID=$!

sleep 6
kill "$TT_PID" 2>/dev/null
wait "$TT_PID" 2>/dev/null
kill "$SERVER_PID" 2>/dev/null
wait "$SERVER_PID" 2>/dev/null

if [ -f /tmp/gstin_test_marker.log ]; then
    echo "Markers:"
    sed 's/^/  /' /tmp/gstin_test_marker.log
fi
echo "Output: $OUTLOG ($(wc -l <"$OUTLOG") lines)"
