[English](README.md) · **Français**

# Claude Code Failover Cockpit

**Gardez un seul cockpit. Changez le moteur en dessous.**

Une configuration pratique, anti-verrouillage, pour utiliser [Claude Code](https://www.anthropic.com/claude-code) comme cockpit de code unique tout en pouvant basculer, à la demande ou automatiquement, vers d'autres modèles, afin qu'une panne fournisseur ou un forfait épuisé n'arrête jamais votre travail.

La cascade, du défaut au dernier recours :

```
Abonnement Anthropic  →  Anthropic sur AWS Bedrock  →  API moins chère (DeepSeek / GPT / Gemini)  →  modèle local  →  CLI concurrentes
```

Les niveaux 1 à 4 conservent votre **environnement exact** (vos skills, serveurs MCP, agents, règles de projet). Seul le modèle derrière l'API change.

---

## L'idée que la plupart des gens ratent : le harnais ≠ le modèle

Un outil de code agentique a deux couches distinctes :

- **Le harnais** — le CLI lui-même (Claude Code), avec vos skills, serveurs MCP, sous-agents, hooks et instructions de projet.
- **Le modèle** — le LLM qui répond aux appels de l'API.

Claude Code parle à un modèle via l'API Messages d'Anthropic. Si vous redirigez ce point de terminaison (`ANTHROPIC_BASE_URL`), vous conservez **l'intégralité du harnais** et ne changez que le cerveau derrière. C'est toute l'astuce.

### Le mur : abonnement ≠ API

Un **abonnement grand public** (Claude Pro/Max, ChatGPT Plus/Pro, abonnements Gemini/AI) est verrouillé sur les applications propres à son fournisseur. Vous ne pouvez généralement **pas** brancher un abonnement dans un harnais tiers. Ce que vous *pouvez* faire transiter dans un harnais, c'est :

- une **clé API facturée à l'usage** (paiement au token),
- un **agrégateur** comme OpenRouter (une clé, plusieurs modèles, facturé à l'usage),
- une **passerelle cloud** que vous payez déjà (par ex. AWS Bedrock),
- un **modèle local** sur votre propre matériel (gratuit, fonctionne hors ligne).

Donc « même environnement + l'abonnement de mon concurrent » est impossible. « Même environnement + un modèle différent via API/local » est exactement ce que ce dépôt met en place.

> Remarque sur les conditions d'utilisation : rediriger le CLI officiel Claude Code vers un modèle non-Anthropic via `ANTHROPIC_BASE_URL` est le pattern documenté de « passerelle LLM ». Ce que les fournisseurs interdisent, c'est d'utiliser le jeton OAuth d'un abonnement *dans un outil tiers*. Utilisez des clés API facturées à l'usage, une passerelle cloud ou des modèles locaux pour les backends alternatifs, jamais le OAuth de votre abonnement.

---

## La cascade

| Niveau | Quand | Ce qui tourne | Même environnement ? |
|---|---|---|---|
| 0 | Normal | Claude Code sur votre abonnement Anthropic | oui |
| 1 | API Anthropic en panne (auto) | Claude sur AWS Bedrock | oui (toujours Claude) |
| 2 | Bedrock trop coûteux / vous voulez moins cher (manuel) | DeepSeek / GPT / Gemini via un routeur + OpenRouter | oui |
| 3 | Entièrement hors ligne | Un modèle local via Ollama, dimensionné par machine | oui |
| 4 | Vous voulez un autre abonnement payant | Le CLI propre au fournisseur (par ex. Codex pour ChatGPT) | non (harnais différent) |

Les niveaux 0 à 3 forment un seul cockpit. Le niveau 4 est un cockpit jumeau, par contrainte du fournisseur.

---

## Mise en place

### Niveau 1 — bascule automatique vers Bedrock

Claude Code prend nativement en charge AWS Bedrock via `CLAUDE_CODE_USE_BEDROCK=1` plus un profil AWS et une région configurés. Le principe : encapsuler la commande `claude` pour qu'elle ping l'API Anthropic au lancement ; si elle est up, utiliser l'abonnement ; si elle est down, exporter les variables Bedrock et continuer sur les mêmes modèles. Un petit watchdog launchd/cron peut basculer les sessions automatiquement et vous notifier.

```bash
# Forcer Bedrock pour une session (nécessite un profil AWS avec accès aux modèles Bedrock) :
CLAUDE_CODE_USE_BEDROCK=1 AWS_PROFILE=your-bedrock-profile AWS_REGION=us-east-1 \
  ANTHROPIC_MODEL=us.anthropic.claude-... claude
```

### Niveau 2 — API moins chères via un routeur

Utilisez [`claude-code-router`](https://github.com/musistudio/claude-code-router) (MIT) comme proxy local. Il écoute sur `127.0.0.1:3456`, accepte le format Anthropic, et redirige vers n'importe quel fournisseur via des transformateurs. Une seule clé OpenRouter donne accès à DeepSeek, GPT, Gemini et Claude-via-API.

Voir [`examples/claude-code-router.config.example.json`](examples/claude-code-router.config.example.json). La clé API est lue depuis une variable d'environnement, jamais codée en dur. Ensuite, pointez Claude Code vers le proxy :

```bash
ANTHROPIC_BASE_URL=http://127.0.0.1:3456 ANTHROPIC_API_KEY=anything claude
```

Changez le modèle actif en direct avec `/model openrouter,openai/gpt-5` dans la session, ou modifiez `Router.default` dans la config.

### Niveau 3 — entièrement hors ligne, modèle local par machine

Quand il n'y a aucun réseau, faites tourner un modèle local avec [Ollama](https://ollama.com), qui parle nativement l'API Messages d'Anthropic. Le script inclus [`examples/claude-offline.sh`](examples/claude-offline.sh) détecte la machine, choisit un modèle dimensionné en conséquence (petit sur un portable, grand sur une machine GPU), démarre Ollama si nécessaire, et lance Claude Code contre `localhost`.

Une propriété utile : quand vous êtes réellement hors ligne, le OAuth de l'abonnement ne peut pas s'authentifier, donc Claude Code est forcé sur le point de terminaison local.

### Niveau 4 — un autre abonnement, dans son propre CLI

Pour réellement dépenser un abonnement ChatGPT ou Gemini, utilisez le CLI agentique propre à ce fournisseur (Codex CLI pour OpenAI, l'outillage Gemini pour Google). Ce sont des harnais distincts avec leur propre config, skills et MCP, maintenus en parallèle. Un orchestrateur multi-CLI (par ex. CLI Agent Orchestrator d'AWS Labs) peut en piloter plusieurs ensemble.

### Fonctions pratiques

[`examples/failover.zsh`](examples/failover.zsh) relie le tout : `cc` (routeur), `ai-gpt` / `ai-gemini` / `ai-deepseek` (changer de modèle), `cl` (hors ligne). Sourcez-le depuis votre shell rc.

---

## Fichiers

| Fichier | Contenu |
|---|---|
| `examples/claude-code-router.config.example.json` | Config du routeur, clé depuis l'env, seulement des placeholders |
| `examples/failover.zsh` | Fonctions shell : `cc`, `ai-*`, `cl` |
| `examples/claude-offline.sh` | Lanceur hors ligne conscient de la machine (Ollama) |

Aucun secret, clé, identifiant de compte, adresse IP ou nom d'hôte n'est inclus. Copiez les exemples et remplissez avec les vôtres.

---

## Licence & citation

- **Texte et documentation :** [CC BY-NC-ND 4.0](LICENSE.md)
- **Code et exemples de configuration :** [PolyForm Noncommercial 1.0.0](LICENSE.md)

Voir [`LICENSE.md`](LICENSE.md) pour les termes canoniques et [`CITATION.cff`](CITATION.cff) pour citer ce travail.

Écrit par Ismaël Joffroy Chandoutis.

Par [Ismaël Joffroy Chandoutis](https://ismaeljoffroychandoutis.com).
