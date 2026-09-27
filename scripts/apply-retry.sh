#!/usr/bin/env bash
set -uo pipefail

INTERVAL="${INTERVAL:-180}"
MAX_TRIES="${MAX_TRIES:-0}"

cd "$(dirname "$0")/../terraform"

try=0
while true; do
  try=$((try + 1))
  printf '\n[%s] tentativa %d\n' "$(date +%H:%M:%S)" "$try"

  output=$(terraform apply -auto-approve -input=false -no-color 2>&1)
  status=$?

  if [ $status -eq 0 ]; then
    echo "$output" | tail -12
    printf '\nservidor provisionado na tentativa %d\n' "$try"
    exit 0
  fi

  if echo "$output" | grep -q "Out of host capacity"; then
    printf 'sem capacidade ARM agora; nova tentativa em %ss\n' "$INTERVAL"
  else
    echo "$output" | tail -25
    printf '\nfalhou por outro motivo; veja o erro acima\n'
    exit 1
  fi

  if [ "$MAX_TRIES" -gt 0 ] && [ "$try" -ge "$MAX_TRIES" ]; then
    printf 'limite de %s tentativas atingido\n' "$MAX_TRIES"
    exit 1
  fi

  sleep "$INTERVAL"
done
