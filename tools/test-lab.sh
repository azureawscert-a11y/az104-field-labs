#!/usr/bin/env bash
# Maintainer test harness: run a lab's scripts in order, log everything, print a one-line result.
# Usage: bash tools/test-lab.sh <lab folder> [script ...]
#   default scripts: deploy.sh verify.sh cleanup.sh
#   example: bash tools/test-lab.sh labs/04-file-share-snapshots deploy.sh restore.sh verify.sh cleanup.sh
# Logs go to ~/lab-logs/<lab>.log (colour codes removed). Results are appended to ~/lab-logs/summary.txt.
set -uo pipefail
DIR="${1:?Usage: bash tools/test-lab.sh <lab folder> [script ...]}"
shift
STEPS=("$@")
[[ ${#STEPS[@]} -eq 0 ]] && STEPS=(deploy.sh verify.sh cleanup.sh)
NAME="$(basename "$DIR")"
LOGDIR="$HOME/lab-logs"
mkdir -p "$LOGDIR"
LOG="$LOGDIR/$NAME.log"
: > "$LOG"
RESULT=""
cd "$DIR" || { echo "No such folder: $DIR"; exit 1; }
for s in "${STEPS[@]}"; do
  start=$SECONDS
  echo "### $s" >> "$LOG"
  bash "./$s" 2>&1 | sed -r 's/\x1B\[[0-9;]*[mK]//g' >> "$LOG"
  rc=${PIPESTATUS[0]}
  echo "### $s exit=$rc ($((SECONDS - start))s)" >> "$LOG"
  RESULT="$RESULT $s=$rc"
  # stop before verify if deploy failed, but always allow cleanup
  if [[ $rc -ne 0 && "$s" == deploy.sh ]]; then
    for c in "${STEPS[@]}"; do [[ "$c" == cleanup.sh ]] && { echo "### cleanup.sh (after failed deploy)" >> "$LOG"; bash ./cleanup.sh >> "$LOG" 2>&1; RESULT="$RESULT cleanup.sh=$?"; }; done
    break
  fi
done
LINE="$(date +%H:%M) $NAME:$RESULT"
echo "$LINE" | tee -a "$LOGDIR/summary.txt"
grep -E "FAIL|ERROR|Error|error:" "$LOG" | head -15
