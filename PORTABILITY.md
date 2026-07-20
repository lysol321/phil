# Portability

phil is runtime- and OS-agnostic. This is the one place the cross-platform
and cross-runtime rules live; the doctrine files assume it.

**Hosts (example deployment — any host/runtime combination works):**
- **Windows local box** — Claude Code + a local Hermes. Repo at e.g. `C:/Users/<you>/Projects/phil`.
- **Headless Ubuntu VPS** — a second Hermes. Repo wherever it was cloned.

## Bootstrap a host

Two one-time steps per clone (each records this host's own paths):

```bash
git config core.hooksPath .githooks      # arm the pre-commit lint gate
bash scripts/deploy-skill.sh             # (re)generate ~/.claude/skills/phil/ shim with THIS host's repo path
```

Re-run `deploy-skill.sh` after any structural change to `skill/references/` or
the repo-root docs — it regenerates the deployed shim from current repo state
(prunes deleted references, adds new ones) so the pointer never drifts.

## Paths — resolve, never hardcode

`<phil-repo>` is the phil repo root, **resolved once at activation** (SKILL.md
step 0), not a literal. Every phil-repo reference is written `<phil-repo>/...`
and resolves against that root. Never write an absolute `C:\...` or `/home/...`
path into doctrine — it's wrong on the other host. Use forward slashes
throughout; git-bash, PowerShell, and Linux all accept them.

`lint-phil.sh` check E fails the build on any hardcoded `C:\Users` / `/home/<user>`
absolute path, so this can't regress.

## Line endings — LF everywhere

`.gitattributes` pins all text to `eol=lf` on checkout, on every host. Shell
scripts and `.githooks/pre-commit` **must** be LF: a CRLF `#!/usr/bin/env bash\r`
is a "bad interpreter" error under Linux bash. Without this, a Windows checkout
with `core.autocrlf` silently breaks every script on the Ubuntu clone.

## Scripts — GNU coreutils

`watchdog-scan.sh` uses `date -d`. Both hosts satisfy it (git-bash ships GNU
coreutils; Ubuntu is GNU). BSD/macOS would need `date -j -f` — not a supported
host today; the script's header notes the swap if one is added.

## The watchdog registry is per-host, not shared

`<phil-repo>/tmp/watchdog-registry.md` contains **absolute, OS-native** state-file
paths (absolute because a Block runs in a *target* repo elsewhere on that host).
Those paths are machine-local: a `C:\...` path is meaningless on the VPS and a
`/home/...` path is meaningless on Windows. **The two hosts do not share a
registry** — each host's Watchdog monitors only the Blocks on its own machine.
The existing cross-instance gotcha (`cron-mode.md`) covers two instances on the
*same* host; this covers two hosts.

## Runtime adapters — capabilities, not products

phil's hard requirements are only a POSIX-ish shell (bash + GNU coreutils), git, and a filesystem. Everything else the doctrine names as an abstract **capability**; each agent runtime maps it — and every capability has an explicit fallback when absent, so any agent system (Claude Code, OpenCode, Hermes, OpenClaw, ...) with any model can run the skill:

| Capability (doctrine name) | Doctrine uses it for | Example mappings | Absent → fallback |
|---|---|---|---|
| **delegate** — spawn a fresh-context subagent at a named tier (`models.md`) | emulated gates, oracle/independent reviews, simulated-user personas, mechanical delegation | Claude Code: Agent tool (`model:` per tier); Hermes: `delegate_task`; OpenCode/OpenClaw: their subagent/task facility | gates stop emulating — `human_gates` halt for the human; reviews run in a manually opened fresh session |
| **scheduler** — durable timers | driver crons + Watchdog (`cron-mode.md`) | Claude Code: `CronCreate`/`CronDelete`/`CronList`; Hermes: `cronjob(...)`; bare host: OS cron/systemd | inline-only mode (the default anyway) — `cron-mode.md` never loads |
| **notify** — push a message off-host | remote deliver tiering (`cron-mode.md`) | Hermes: `hermes send --to ...`; others: mail/webhook if available | state file + ledger only (the reporting contract's durable default) |
| **skill discovery** — auto-load the skill on a trigger phrase | activation ("phil on X") | Claude Code: `~/.claude/skills/phil/` shim (`deploy-skill.sh` default target); other runtimes: pass their skill dir as `deploy-skill.sh` arg 2 | point the agent at `<phil-repo>/skill/SKILL.md` manually each session |

A runtime-specific tool named in doctrine is always an *example* of a capability, never the required path — `delegate_task` is Hermes-only and inert elsewhere; the Agent tool is Claude-Code-only and inert elsewhere. Model choices route through `models.md` capability tiers the same way.
