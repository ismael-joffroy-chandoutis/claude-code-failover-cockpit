#!/usr/bin/env bash
# Claude Code — OFFLINE fallback (sovereign, no network).
# Starts local Ollama and launches Claude Code on a model sized for THIS machine.
# Usage: claude-offline.sh [claude args...]   |   override: OLLAMA_OFFLINE_MODEL=xxx
# Dry-run (does not launch claude): CLAUDE_OFFLINE_DRYRUN=1 claude-offline.sh

OLLAMA_URL="http://127.0.0.1:11434"
NAME="$(scutil --get ComputerName 2>/dev/null || hostname)"

# Map this machine to a local model. Adapt the patterns and model names to yours.
case "$NAME" in
  *laptop*|*MacBook*|*Air*) MODEL="a-small-model" ;;   # e.g. a 7-12B model with tool support
  *gpu*|*workstation*)      MODEL="a-large-model" ;;   # e.g. a 24-32B coding model
  *)                        MODEL="a-small-model" ;;
esac
MODEL="${OLLAMA_OFFLINE_MODEL:-$MODEL}"

# 1. Ensure Ollama is serving
if ! curl -s -o /dev/null --max-time 2 "$OLLAMA_URL/api/tags"; then
  echo "[offline] starting Ollama..."
  (ollama serve >/dev/null 2>&1 &)
  for i in $(seq 1 8); do curl -s -o /dev/null --max-time 2 "$OLLAMA_URL/api/tags" && break; sleep 1; done
fi

# 2. Fall back to any locally available capable model if the mapped one is missing
if ! ollama list 2>/dev/null | awk '{print $1}' | grep -qx "$MODEL"; then
  ALT="$(ollama list 2>/dev/null | awk 'NR>1{print $1}' | head -1)"
  echo "[offline] $MODEL not found locally -> falling back to ${ALT:-none}"
  MODEL="${ALT:-$MODEL}"
fi

echo "[offline] machine=$NAME  model=$MODEL  endpoint=$OLLAMA_URL"

if [ -n "$CLAUDE_OFFLINE_DRYRUN" ]; then
  echo "[dry-run] would launch: ANTHROPIC_BASE_URL=$OLLAMA_URL ANTHROPIC_MODEL=$MODEL claude $*"
  exit 0
fi

# Ollama exposes the Anthropic Messages API natively; point Claude Code at it.
exec env ANTHROPIC_BASE_URL="$OLLAMA_URL" ANTHROPIC_AUTH_TOKEN=ollama \
  ANTHROPIC_MODEL="$MODEL" ANTHROPIC_SMALL_FAST_MODEL="$MODEL" \
  command claude "$@"
