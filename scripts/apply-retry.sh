#!/usr/bin/env bash
set -uo pipefail

INTERVAL="${INTERVAL:-180}"
MAX_TRIES="${MAX_TRIES:-0}"
MAX_TRANSIENT="${MAX_TRANSIENT:-20}"
LOG_FILE="${LOG_FILE:-}"

cd "$(dirname "$0")/../terraform"

# Capacity is the expected failure: the free ARM pool is full right now.
CAPACITY='Out of host capacity'

# Network blips, throttling and Oracle's own 5xx are worth sitting through too.
# A dropped Wi-Fi connection should not end a retry loop that has run for hours.
TRANSIENT='no such host|dial tcp|i/o timeout|TLS handshake timeout|connection reset|connection refused|unexpected EOF|EOF$|TooManyRequests|429-|503-|502-|504-|ServiceUnavailable|RequestTimeout'

log() {
  printf '%s\n' "$1"
  [ -n "$LOG_FILE" ] && printf '%s\n' "$1" >> "$LOG_FILE"
  return 0
}

started=$(date +%s)
try=0
transient_streak=0

while true; do
  try=$((try + 1))
  log ""
  log "[$(date +%H:%M:%S)] attempt $try"

  output=$(terraform apply -auto-approve -input=false -no-color 2>&1)
  status=$?

  if [ $status -eq 0 ]; then
    echo "$output" | tail -12
    elapsed=$(( ($(date +%s) - started) / 60 ))
    log "provisioned on attempt $try after ${elapsed}m"
    exit 0
  fi

  if echo "$output" | grep -q "$CAPACITY"; then
    transient_streak=0
    log "no ARM capacity right now; retrying in ${INTERVAL}s"
  elif echo "$output" | grep -qE "$TRANSIENT"; then
    transient_streak=$((transient_streak + 1))
    log "transient error (${transient_streak}/${MAX_TRANSIENT}), likely network; retrying in ${INTERVAL}s"

    if [ "$transient_streak" -ge "$MAX_TRANSIENT" ]; then
      echo "$output" | tail -25
      log "gave up after $MAX_TRANSIENT transient failures in a row"
      exit 1
    fi
  else
    echo "$output" | tail -25
    log "failed for a different reason; see the error above"
    exit 1
  fi

  if [ "$MAX_TRIES" -gt 0 ] && [ "$try" -ge "$MAX_TRIES" ]; then
    log "giving up after $MAX_TRIES attempts"
    exit 1
  fi

  sleep "$INTERVAL"
done
