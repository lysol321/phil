---
name: phil
description: Map a target project's real backlog onto loops.md's Loop/Block vocabulary, then run, author, or check the status of the right one — the entry point for both starting new autonomous dev work and checking on work already running. Resolve the repo, force a ground-truth check, map every open item to a Loop type and Pipeline phase before picking what to execute, then drive it. Named for Phil Connors (Groundhog Day) — repeats until the Stop condition is actually met. Triggers on "phil on X", "run phil on X", "resume phil on X", "git'r dun", "get 'er done", "put X on autopilot", "check on the X block", "how's the X loop doing".
---

# Phil — drive a Loop or Block

Named for Phil Connors (*Groundhog Day*): repeats the same work until the Stop condition — not a fixed count — is actually satisfied.

This skill is a thin pointer, not a copy of the loop library — see **Reference files** below. Read files fresh each time; don't rely on memory of their contents, that's the same staleness failure mode this whole system exists to avoid.

**Core focus, not a side effect:** the point of running phil is producing the mapping — every real open item in the target's backlog assigned to a Loop type (and Pipeline phase, chained per its rules) — before touching any single one of them. Don't gravitate to whatever's loosest or freshest in the working tree (an uncommitted file, the thing `git status` happens to show) just because it's the first concrete thing found. That's a shortcut around the mapping step, not a substitute for it.

## Procedure

0. **Resolve `<phil-repo>` and check `loops.md` exists** at `<phil-repo>/loops.md`. `<phil-repo>` is the phil repo root, resolved **once at activation** — never a hardcoded literal. It varies by host: e.g. a Windows box might have it at `C:/Users/<you>/Projects/phil`; the headless Ubuntu VPS (the other Hermes) has it wherever the repo was cloned — **never assume the Windows path off the Windows host.** Resolve it from where this skill was launched (the deployed shim — Claude Code default `~/.claude/skills/phil/`; other runtimes use their own skill dir, see `PORTABILITY.md` → Runtime adapters — records the machine-local path and points back here) or from the repo the user named. Every phil-repo path below is written `<phil-repo>/...` and resolved against this root. Missing entirely (fresh machine, first-ever invocation)? This system hasn't been bootstrapped yet — say so and stop; don't reconstruct it from memory. If this activation was launched from a deployed shim copy that contains real procedure text instead of a pointer, stop and report the drift — the deployed copy is a thin shim and should point back here.
1. **Resolve the target repo.** If the user named a project ("phil on myproject"), find its real path — don't assume a wiki/memory location is current. If ambiguous or unknown, ask.
1a. **Status-only invocation early exit:** If the user only wants to check progress ("check on X", "how's the X block/loop doing"), skip steps 2–3 and go straight to step 4's status-only handling in references/execution.md.
1b. **Model roster check** (work mode only, not status-only): verify `models.md` in the phil repo against the interview triggers defined in `blocks.md` → Model Roster (that list is the single definition). Trigger hit → interview the user (question list is in `models.md` itself) and rewrite the file; otherwise proceed silently — don't re-interview every activation.
2. **Ground truth, then map the backlog onto Loop/Block shape.** Mandatory, not skippable — see `references/ground-truth-and-mapping.md`.
3. **Build the roster: existing Block(s), or author what's missing.** Pick up to 3 path-disjoint claimable Blocks from the mapping (1 is fine) — see `references/block-selection.md` and `blocks.md` → Roster.
4. **Run the roster — or just check on it.** Driver Protocol, rotation on blocked/done, status-only invocation, autonomy default, reporting contract, contradiction check — see `references/execution.md`.

**Worktree decision (Block setup, not status-only):** when actually setting up a new Block, decide up front whether the Block runs on the primary checkout or in a dedicated isolation worktree (`<repo>/.claude/worktrees/<block-name>` on the Block's branch). The two-checkout pattern in `references/execution.md` is the default when isolation is wanted — user often steers this. Don't ask unless the choice has real consequences (existing parallel worktrees on the same branch, fragile repo state, or the Block already exists on the primary checkout and migration would orphan an in-flight commit). Record the choice in the Block state file's `worktree:` field either way so future fires re-verify the right checkout.

**Worktree-first branch creation order (a first-fire rule, not an authoring-time one):** branch creation happens on the Block's first Driver Protocol fire, not at authoring (see "Default behavior" below — authoring writes the state file, doesn't create the branch). When that first fire creates the branch for a Block whose `worktree:` field names an isolation worktree that doesn't exist yet, create the worktree AND branch in one step — `git worktree add .claude/worktrees/<block-name> -b block/<block-name>` from a primary on `main`. Never `git checkout -b` on the primary first; that forces a later migration (`execution.md` → two-checkout pattern documents it).

If any reference file listed below is missing or unreadable, stop and report it — don't guess at the missing procedure or improvise from what the other files imply.

## Default behavior when asked to author a Block

When the user asks phil to author a Block ("need a block for X," "set up a block for post-Y work," "author a block for the Z wave"), **pick the smallest well-scoped Block that fits the named work and write it.** Surface the sizing call in the reply ("I scoped this to A; B is a separate Block downstream if that's what you meant"), but do not pause to ask "what scope did you mean?" before drafting — that's the bottleneck posture `references/execution.md` is explicitly designed to avoid. The owner's working style is decisive; a clarifying question that could've been a default-sizing call burns a round-trip.

Authoring without an explicit fire request: do steps 1-3 of the Loop Authoring Loop (ground-truth → draft → write into the appropriate loop category file or `blocks.md` + state file; watchdog-registry append only when cron mode is active per `blocks.md` → Execution-mode status). Do **not** fire the Block — Driver Protocol creates the branch (and, in cron mode, assigns the cron) on first fire, not at authoring time (see `references/execution.md`). Surface the setup items the first fire will handle (branch creation; in cron mode also cron_job_id + watchdog arm-check) in the reply so the user knows what's NOT yet wired.

## Loop Authoring Loop — review passes are mandatory

The Loop Authoring Loop (in `loops-core.md`) says: ground-truth → draft → **independent quality review pass** (different agent/model than the author — redundancy, unenforceable Stops, undefined verbs, missing fields) → apply fixes → **independent gap review pass** (chaining/driver-protocol edge cases, missing loop types, what breaks in practice — not wording) → apply fixes → re-check ground truth → commit into the appropriate loop category file or `blocks.md`.

The review passes are **not optional.** A draft shipped without them is a draft a future agent has to re-review from scratch — defeats the point of authoring it once. If the user is in a hurry ("just write it"), the **minimum** is a self-pass checklist run on your own draft before writing it into the appropriate loop category file or `blocks.md`:

- Every loop has a Goal, a Checkpoint cadence, a Stop condition phrased as a testable predicate (not "until happy"), an Extras section if it has caveats, and a Track ledger path.
- Every Driver Protocol step is operable by a fresh agent dropped into the session with only the state file + `loops.md` index + the linked category file or `blocks.md` + this skill — no implicit context, no "you'd know what I mean."
- Every chaining rule names the loop types involved, the order, and the loop's `human_gates` entry (or the explicit `[]` with reasoning).
- Every `evidence.verify` method is a single concrete action (run command, read file, diff SHA) — not "check it works."

Call out in the chat reply which findings you couldn't validate without an independent model, and offer to run the independent pass via a fresh-context delegate at frontier tier (the runtime's delegate capability — `PORTABILITY.md` → Runtime adapters; no delegate capability → run it in a manually opened fresh session). Do not silently skip both passes — even the self-pass checklist catches the most common failure mode (an unenforceable Stop phrased as "until happy" that no Driver Protocol step can ever check).

## Pre-loop pre-checks — Block-authoring pattern

When a Block has a loop whose Acceptance depends on something that may or may not exist at fire time (a constants block, a feature wired in a sibling spec, a CI workflow file, a fixture), put that check in the loop's `pre_check` field in the state file's `loops[]` array (in cron mode, also mirror it as a gate in the driver prompt). On entering the loop, the driver runs it. Precondition fails → **set `status: blocked`** with a `blocked_reason` citing the missing thing — do NOT fabricate a source, skip the loop, or proceed past a failed gate. Make the check a one-line grep so a failure is a diagnosis the owner can act on without re-reading the spec. A failed pre-check should be visible from the state file's per-loop `status:` line (and, in cron mode, `cronjob list` + the watchdog) — one source of truth, not scattershot.

## Ground-truth gotchas — lesson bank

Concrete traps a fresh agent falls into on the ground-truth step — each hit at least once, encoded so the next agent doesn't re-pay:

- **Exclude `.claude/worktrees/` from grep/read.** Agent forks (`.claude/worktrees/agent-*`, `{phase-b-workers,sim-sweep-*}`) are NOT main-checkout evidence. `cd` to the main checkout, or filter with `grep -v ".claude/worktrees"` / `find . -not -path "*/.claude/worktrees/*"`.
- **Primary checkout must be non-bare — a bare primary silently orphans `git add`.** With `core.bare=true`, `git add`/`commit` succeed against the object store but files never hit the working dir and `git status` reports clean. `git worktree list` shows `(bare)` next to the path. Recovery: `git reset --merge <correct-commit>` (NOT `--hard` — destructive, blocked by smart-approval; `--merge` is safe against uncommitted changes), then re-apply. Verify: `git rev-parse --abbrev-ref HEAD` returns the block branch (not `main`) and `git config core.bare` returns `false` on the primary.
- **A "NOT built"/"blocked"/"pending" claim in a status doc can be stale against CHANGELOG.md.** CHANGELOG (append-only, harder to drift) usually leads; cross-check it + the spec + `git log` before believing the status doc. (Watch the GAP-stub layer: a WO can be "scaffolded" per CHANGELOG and "not built" per the status doc, both true.)
- **Read a status doc's own staleness footnote before trusting its body.** A doc that warns it's stale is last-week's truth — re-verify against `git log` + CHANGELOG.
- **A STALE Block in `instances.md` is not a Block to execute.** See `references/block-selection.md`.

## Reference files

- `references/ground-truth-and-mapping.md` — verify the target's real state (including that it's a writable git repo), then map its open items onto `loops.md` Loop templates + Pipeline phases, using the narrow human-gate bar. Load first, before picking anything to execute.
- `references/block-selection.md` — check for an existing Block vs. authoring a new one via the Loop Authoring Loop. Load once the mapping is done.
- `references/execution.md` — Driver Protocol pointer, status-only ("check on X") handling, the autonomous-by-default execution policy, the reporting contract, the contradiction-check rule, and the **two-checkout pattern** (isolation worktree + stable state-file location in primary checkout). Load when actually running or checking the chosen Block.
- `<phil-repo>/cron-mode.md` — Watchdog Loop, driver cron pre-flight template, cadence by Block class, provider/model picks, remote-deliver tiering, cross-instance watchdog gotcha. **Load only when `blocks.md` → Execution-mode status declares cron mode active** (currently inline-only — skip it).
- `<phil-repo>/loops.md` — the loop index. Follow its links to `loops-core.md`, `loops-ux.md`, `loops-pipeline.md`, `loops-hardening.md`, and `blocks.md` for the loop definitions, pipeline, and Block system. These are the owner's actively-edited files; copying them into this skill folder would create a second copy that goes stale exactly like the wiki did. Always read the linked files fresh from `<phil-repo>`; never quote them from memory or a prior session.
