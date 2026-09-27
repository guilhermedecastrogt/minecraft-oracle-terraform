#!/usr/bin/env bash
set -uo pipefail

INTERVAL="${INTERVAL:-180}"
MAX_TRIES="${MAX_TRIES:-0}"

cd "$(dirname "$0")/../terraform"

try=0
while true; do
  try=$((try + 1))
  printf '\n[%s] attempt %d\n' "$(date +%H:%M:%S)" "$try"

  output=$(terraform apply -auto-approve -input=false -no-color 2>&1)
  status=$?

  if [ $status -eq 0 ]; then
    echo "$output" | tail -12
    printf '\nserver provisioned on attempt %d\n' "$try"
    exit 0
  fi

  if echo "$output" | grep -q "Out of host capacity"; then
    printf 'no ARM capacity right now; retrying in %ss\n' "$INTERVAL"
  else
    echo "$output" | tail -25
    printf '\nfailed for a different reason; see the error above\n'
    exit 1
  fi

  if [ "$MAX_TRIES" -gt 0 ] && [ "$try" -ge "$MAX_TRIES" ]; then
    printf 'giving up after %s attempts\n' "$MAX_TRIES"
    exit 1
  fi

  sleep "$INTERVAL"
done
