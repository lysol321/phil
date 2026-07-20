# phil

Agent loop/Block orchestration system. Named for Phil Connors (*Groundhog Day*) — repeats until the Stop condition is actually met, not a fixed count.

- **`loops.md`** — the small index and shared loop contract.
- **`loops-core.md`** — general-purpose loops such as triage, bug fixing, coverage, review, and documentation.
- **`loops-pipeline.md`** — the Product Pipeline and build/validate loops.
- **`loops-ux.md`** — UX and validation loops (UI design, visual inspection, mechanical sweeps, simulated-user passes, user tests, onboarding).
- **`loops-hardening.md`** — hardening, compatibility, observability, and release loops.
- **`blocks.md`** — the Blocks system: state-file schema, Driver Protocol, and reusable Block templates. (Live instantiated-Block records go in `instances.md`, an owner-local file excluded from delivered artifacts.)
- **`cron-mode.md`** — cron-only machinery (Watchdog Loop, driver cron pre-flight, cadence, deliver tiering). Read only when crons are armed; inline mode ignores it.
- **`tmp/watchdog.md`** / **`tmp/watchdog-registry.md`** — the Watchdog Loop's cross-repo health ledger and registry of Blocks it monitors (runtime state, created on first watchdog use; absent from the delivered artifact — cron mode only).
- **`models.md`** — the available model/provider roster used by judgment loops and drivers.
- **`PORTABILITY.md`** — cross-platform + cross-runtime rules (Windows local / Ubuntu VPS, Claude Code / Hermes): path resolution, LF line endings, per-host watchdog registry, runtime tool forks.
- **`PARALLEL.md`** — **design record, not active doctrine**: the deterministic architecture for running multiple Blocks in parallel on one repo (per-Block worktree cells, leases, fixed merge-order + CAS integration, verify-isolation contract). phil today is still sequential-per-repo; this is the spec for when it's built.

The deployable skill shim (`phil`, the thing that turns "phil on myproject, git'r dun" into action) lives wherever your runtime discovers skills — Claude Code: `~/.claude/skills/phil/` (the `deploy-skill.sh` default); other runtimes (OpenCode, Hermes, OpenClaw, ...): pass their skill dir as `deploy-skill.sh` arg 2, or point the agent at `skill/SKILL.md` directly. The shim points back into this repo rather than duplicating it.

Everything here is meant to be read fresh each time, not cached or quoted from memory. Start with `loops.md`, then follow its category links.

## Install

Prerequisites: `bash` + GNU coreutils (Windows: use git-bash, which ships both) and any agent runtime that can load a skill file (Claude Code, OpenCode, Hermes, OpenClaw, ...) with any model roster (`models.md` maps models to capability tiers).

**From a git clone** (recommended — keeps the pre-commit lint gate):

```bash
git clone <this-repo> phil && cd phil
git config core.hooksPath .githooks      # arm the pre-commit lint gate
bash scripts/deploy-skill.sh             # generate the ~/.claude/skills/phil/ shim for THIS machine
```

**From a release archive** (no `.git`, so skip the hooks step):

```bash
unzip phil-release.zip -d phil && cd phil
bash scripts/deploy-skill.sh
```

Then say `phil on <your-project>` in an agent session. Re-run `deploy-skill.sh` after any structural change to `skill/references/` or the repo-root docs. Full cross-platform rules: `PORTABILITY.md`.

Build a release archive from a clone: `git archive HEAD -o phil-release.zip` (owner-local state — `tmp/`, `archive/`, `instances.md` — is excluded via `.gitattributes` `export-ignore`).
