# ============================================================
# Claude Code failover cockpit — shell functions (zsh)
# Source this from your ~/.zshrc:
#   [ -f ~/path/to/failover.zsh ] && source ~/path/to/failover.zsh
#
#   cc                -> Claude Code routed via claude-code-router (model = router default)
#   ai-deepseek / ai-gpt / ai-gemini / ai-claude -> switch model + launch
#   ccmodel <id>      -> change the router default (e.g. ccmodel openrouter,openai/gpt-5)
#   cl                -> offline: local model via Ollama (see claude-offline.sh)
#   in-session switch: /model openrouter,openai/gpt-5
#
# The non-Anthropic models are billed per token through your API/OpenRouter key,
# NOT through any consumer subscription.
# ============================================================

export CCR_URL="http://127.0.0.1:3456"

# Launch Claude Code routed through claude-code-router (starts it if needed)
cc() {
  ccr status >/dev/null 2>&1 || ccr start >/dev/null 2>&1
  ANTHROPIC_BASE_URL="$CCR_URL" ANTHROPIC_API_KEY="anything" claude "$@"
}

# Change the router's default model
ccmodel() {
  [ -z "$1" ] && { echo "usage: ccmodel <provider,model>"; return 1; }
  python3 - "$1" <<'PY'
import json,sys,os
p=os.path.expanduser("~/.claude-code-router/config.json")
d=json.load(open(p)); d["Router"]["default"]=sys.argv[1]
json.dump(d,open(p,"w"),indent=2); print("router default =",sys.argv[1])
PY
  ccr restart >/dev/null 2>&1
}

# Shortcuts: set model then launch
ai-deepseek(){ ccmodel openrouter,deepseek/deepseek-v4-flash >/dev/null; cc "$@"; }
ai-gpt(){      ccmodel openrouter,openai/gpt-5 >/dev/null;               cc "$@"; }
ai-gemini(){   ccmodel openrouter,google/gemini-3.1-pro-preview >/dev/null; cc "$@"; }
ai-claude(){   ccmodel openrouter,anthropic/claude-opus-4.7 >/dev/null;  cc "$@"; }

# Offline fallback (no network): local Ollama, model per machine
cl(){ ~/path/to/claude-offline.sh "$@"; }
alias claude-offline='cl'
