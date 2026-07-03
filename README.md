# Claude Code Failover Cockpit

**Keep one cockpit. Swap the engine underneath.**

A practical, anti-lock-in setup for running [Claude Code](https://www.anthropic.com/claude-code) as your single coding cockpit while being able to fall back, on demand or automatically, to other model backends, so a provider outage or an exhausted plan never stops your work.

The cascade, from default to last resort:

```
Anthropic subscription  →  Anthropic on AWS Bedrock  →  cheaper API (DeepSeek / GPT / Gemini)  →  fully-local model  →  sibling CLIs
```

Levels 1 to 4 keep your **exact environment** (your skills, MCP servers, agents, project rules). Only the model behind the API changes.

---

## The one idea most people miss: harness ≠ model

An agentic coding tool has two separate layers:

- **The harness** — the CLI itself (Claude Code), with your skills, MCP servers, subagents, hooks, and project instructions.
- **The model** — the LLM that answers the API calls.

Claude Code talks to a model over the Anthropic Messages API. If you redirect that API endpoint (`ANTHROPIC_BASE_URL`), you keep the **entire harness** and only change the brain behind it. That is the whole trick.

### The wall: subscription ≠ API

A **consumer subscription** (Claude Pro/Max, ChatGPT Plus/Pro, Gemini/AI subscriptions) is locked to its vendor's own apps. You generally **cannot** pipe a subscription into a third-party harness. What you *can* feed into a harness is:

- a **metered API key** (pay per token),
- an **aggregator** like OpenRouter (one key, many models, metered),
- a **cloud gateway** you already pay for (e.g. AWS Bedrock),
- a **local model** on your own hardware (free, works offline).

So "same environment + my competitor subscription" is impossible. "Same environment + a different model via API/local" is exactly what this repo sets up.

> Note on terms of service: redirecting the official Claude Code CLI to a non-Anthropic model via `ANTHROPIC_BASE_URL` is the documented "LLM gateway" pattern. What vendors prohibit is using a subscription's OAuth token *inside a third-party tool*. Use metered API keys, a cloud gateway, or local models for the alternative backends, never your subscription's OAuth.

---

## The cascade

| Level | When | What runs | Same env? |
|---|---|---|---|
| 0 | Normal | Claude Code on your Anthropic subscription | yes |
| 1 | Anthropic API down (auto) | Claude on AWS Bedrock | yes (still Claude) |
| 2 | Bedrock too costly / you want cheaper (manual) | DeepSeek / GPT / Gemini via a router + OpenRouter | yes |
| 3 | Fully offline | A local model via Ollama, sized per machine | yes |
| 4 | You want another paid subscription | The vendor's own CLI (e.g. Codex for ChatGPT) | no (different harness) |

Levels 0 to 3 are one cockpit. Level 4 is a sibling cockpit, by vendor constraint.

---

## Setup

### Level 1 — automatic Bedrock fallback

Claude Code natively supports AWS Bedrock via `CLAUDE_CODE_USE_BEDROCK=1` plus a configured AWS profile and region. The pattern: wrap the `claude` command so it pings the Anthropic API on launch; if it is up, use the subscription; if it is down, export the Bedrock variables and continue on the same models. A small launchd/cron watchdog can flip sessions automatically and notify you.

```bash
# Force Bedrock for one session (requires an AWS profile with Bedrock model access):
CLAUDE_CODE_USE_BEDROCK=1 AWS_PROFILE=your-bedrock-profile AWS_REGION=us-east-1 \
  ANTHROPIC_MODEL=us.anthropic.claude-... claude
```

### Level 2 — cheaper APIs via a router

Use [`claude-code-router`](https://github.com/musistudio/claude-code-router) (MIT) as a local proxy. It listens on `127.0.0.1:3456`, accepts the Anthropic format, and forwards to any provider via transformers. One OpenRouter key gives you DeepSeek, GPT, Gemini and Claude-via-API.

See [`examples/claude-code-router.config.example.json`](examples/claude-code-router.config.example.json). The API key is read from an environment variable, never hard-coded. Then point Claude Code at the proxy:

```bash
ANTHROPIC_BASE_URL=http://127.0.0.1:3456 ANTHROPIC_API_KEY=anything claude
```

Switch the active model live with `/model openrouter,openai/gpt-5` inside the session, or change `Router.default` in the config.

### Level 3 — fully offline, local model per machine

When there is no network at all, run a local model with [Ollama](https://ollama.com), which speaks the Anthropic Messages API natively. The included [`examples/claude-offline.sh`](examples/claude-offline.sh) detects the machine, picks a model sized for it (small on a laptop, large on a GPU box), starts Ollama if needed, and launches Claude Code against `localhost`.

A useful property: when you are truly offline, the subscription's OAuth cannot authenticate, so Claude Code is forced onto the local endpoint.

### Level 4 — a different subscription, in its own CLI

To actually spend a ChatGPT or Gemini subscription, use that vendor's own agentic CLI (Codex CLI for OpenAI, the Gemini tooling for Google). These are separate harnesses with their own config, skills and MCP, maintained in parallel. A cross-CLI orchestrator (e.g. AWS Labs' CLI Agent Orchestrator) can drive several of them together.

### Convenience functions

[`examples/failover.zsh`](examples/failover.zsh) wires it together: `cc` (router), `ai-gpt` / `ai-gemini` / `ai-deepseek` (switch model), `cl` (offline). Source it from your shell rc.

---

## Files

| File | What |
|---|---|
| `examples/claude-code-router.config.example.json` | Router config, key from env, placeholders only |
| `examples/failover.zsh` | Shell functions: `cc`, `ai-*`, `cl` |
| `examples/claude-offline.sh` | Machine-aware offline launcher (Ollama) |

No secrets, keys, account IDs, IP addresses or hostnames are included. Copy the examples and fill in your own.

---

## License & citation

- **Text and documentation:** [CC BY-NC-ND 4.0](LICENSE.md)
- **Code and configuration examples:** [PolyForm Noncommercial 1.0.0](LICENSE.md)

See [`LICENSE.md`](LICENSE.md) for the canonical terms and [`CITATION.cff`](CITATION.cff) to cite this work.

Authored by Ismaël Joffroy Chandoutis.

By [Ismaël Joffroy Chandoutis](https://ismaeljoffroychandoutis.com).
