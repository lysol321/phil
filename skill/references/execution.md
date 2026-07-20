# Execution

## Roster rotation

Running a roster (up to 3 path-disjoint Blocks)? Mechanics, terminal states, and the roster file format live in `blocks.md` → Roster — read them there, don't work from a summary. Execution-layer rule only: each rotation gets one line in the chat report (inline mode) — which Block parked, why, which picked up.

## A Block exists and fits

Follow `blocks.md` → `## Blocks` → `### Driver Protocol` exactly: read/create the state file, verify prior evidence before trusting it, run the active loop, checkpoint at its own cadence, handle `blocked` status, apply chaining rules.

When creating a *new* Block's state file: first read the execution-mode status in `blocks.md`. Inline-only mode (the current default): skip all registry/watchdog wiring. Cron mode active: registry append, watchdog arm-check, cadence, provider/model, and the cross-instance ownership gotcha all live in `cron-mode.md` — read it there.

## Pre-flight on first fire of any Block

Run these checks *before any git operation in a Block* (author, first-fire, resume, or any subsequent driver run). The order matters — cheap checks first, expensive ones only if needed.

1. **`git status --porcelain`** — should be clean OR show only files this Block just produced. Unrelated uncommitted files = a previous session didn't clean up; treat as a stall signal, surface to human.
2. **`git worktree list`** on the primary checkout — confirm the primary is on the Block's branch (or on `main` for read-only steps), not on a stale worktree branch from a prior failed isolation. A 2026-07-14 INCIDENT note records an isolated worktree renaming itself to `main`, orphaning an in-flight approval chain. If a Block reports a commit and the primary's branch doesn't match what the Block's state file claims, **stop and reflog** — do not trust the hash.
3. **`git config core.bare`** — must be `false`. The same INCIDENT flipped this to `true`; it breaks subsequent `git worktree` operations silently. If `true`, restore it before continuing.
4. **`git log --oneline -5`** on `main` — confirm HEAD is at or after the SHA recorded in the Block's pre-flight. Main moving ahead is fine for read context, but don't rebase without explicit human approval.

These checks are cheap (<1s total) and prevent the most common class of Block self-destruction. In cron mode, encode them in the driver cron prompt so every fire runs them — see `cron-mode.md`, which also covers the state-file co-writer race when a driver cron fires while an inline session is patching.

## Two-checkout pattern (isolation worktree + stable state-file location)

When a Block runs in a dedicated isolation worktree (typically `<repo>/.claude/worktrees/<block-name>` on the Block's branch), **the Block has two checkouts simultaneously and they play distinct roles.** Mixing them up is the single most common way this pattern breaks:

- **The worktree is the only place commits land.** Every TDD step (`git add … && git commit …`), every `pnpm verify`, every source grep happens here. Driver cron's `workdir` parameter points at this path, not the primary checkout.
- **The primary checkout stays on `main`.** It holds the canonical repo state and is where `git worktree list` and `git config core.bare` should always report healthy (`core.bare=false`).
- **Block state file + Track ledgers live in the PRIMARY checkout's `tmp/` dir.** Not the worktree's `tmp/`. The Watchdog reads them at stable absolute paths registered in `<phil-repo>/tmp/watchdog-registry.md` (`<phil-repo>` resolved per SKILL.md step 0 — not a hardcoded Windows path); if those paths drift (state file moves with the worktree, or worse, gets accidentally committed to the Block's branch), the watchdog silently stops seeing updates. Keeping state files in the primary checkout's `tmp/` gives the watchdog one stable absolute path per Block that survives worktree churn.
- **The driver cron prompt MUST distinguish the two on every fire.** Standard discipline: run `pwd` and verify the path ends in `.claude/worktrees/<block-name>`; run `git rev-parse --abbrev-ref HEAD` and verify it's the Block's branch; run `git config core.bare` and verify `false`; run `git status --porcelain` and verify clean or only-this-Block-changes. Any of these wrong → STOP and surface to human, do not proceed silently.

**Migration story** (when a Block was authored on the primary checkout and isolation is requested later): primary must `git checkout main` first (releasing the Block's branch from the primary), then `git worktree add .claude/worktrees/<block-name> <block-branch>` creates the dedicated worktree. State files at the primary's `tmp/` don't move — they're already in the right place. Driver cron's `workdir` is updated to the worktree path. Do NOT use `git worktree remove` — known-fragile on Windows.

If a Block's state file records `worktree: <path>` in its YAML, that path is the source of truth on where the Block should run. Future fires re-verify `pwd` against it. If `git worktree list` shows the worktree missing, STOP and surface — do not silently re-create, the prior worktree's content (uncommitted files, hidden refs) may matter.

**`core.bare` on a worktree returns the parent repo's setting, not the worktree's own.** When you run `git -C <worktree> config core.bare`, it returns the parent repo's value — `true` for a bare primary, `false` for a normal primary. A worktree's `core.bare` is always the parent repo's value because `core.bare` is a repo-level property, not a per-worktree one. Interpreting a `true` result as "this worktree is bare" is wrong — a bare repo *cannot* have a proper linked worktree (it has no working directory to attach to). The correct way to verify a worktree is properly linked is the three-command pattern:

```bash
# Correct verification — three commands, all must pass
git worktree list                                          # shows path + branch, not (bare)
git -C <worktree> rev-parse --git-dir                    # returns .git/worktrees/<name>, not .git
git -C <worktree> rev-parse --abbrev-ref HEAD            # returns block-branch, not main (if block worktree)
```

**Bare-primary + worktree coexists** is a valid and common pattern (primary is bare to prevent accidental commits, worktrees do all real work). When `git worktree list` shows `(bare)` next to the primary and the worktree shows `[block/<name>]`, everything is correct. The bare primary's object store holds all branch refs including the worktree's branch — commits still succeed because git writes to the object store, not the worktree. The worktree's working directory is the actual files being edited.

## Execution mode defaults to autonomous

Execute the Block using the execution mode (inline vs. cron) that `blocks.md` currently declares — read it fresh each time, don't assume a mode from a prior session. Report what execution mode was used and what happened after the fact rather than asking before.

Only pause to ask when the situation meets the bar defined in `blocks.md` → "Default posture: autonomous," or when the target repo already has its own explicit human-review policy (respect it, don't override it).

## Driver cron mechanics — cron mode only

Cadence selection by Block class, the still-running pre-flight check, provider/model picks, and remote-deliver tiering all live in `cron-mode.md`. Don't read them in inline mode — nothing arms a cron.

## Status-only invocation

If the user just wants to check progress ("how's the X block doing," "check on phil on myproject") rather than start or advance work: read the target Block's `tmp/block-{block-name}.md` state file and its loops' ledgers, summarize current phase/status/evidence, and stop there. Don't run the Driver Protocol's mutating steps unless actually asked to advance the work.

Note: "resume phil on X" means advance the work (full Driver Protocol), not status-only — "resume" implies picking up where it left off and moving forward.

## Reporting contract

Every Driver Protocol checkpoint already writes to the Block's state file and the active loop's Track ledger — that's the durable record for a cron run nobody is watching live. Don't invent a separate notification channel for it. When the run is inline (a live session is watching), also summarize in chat what was done, drawn from the state file's own fields rather than re-derived from memory. Emulated-gate verdicts and direction calls (`blocks.md` → Emulated gates / Default posture) each get one heads-up line: verdict or direction, why it fits design intent, and that "adjust" course-corrects.

## Contradiction check

If new information surfaces that contradicts what a wiki/memory said (like the staleness incident this pattern was built from), stop and say so before proceeding — that's a correctness check, not a taste gate, and it's cheap to do every time.

**Common contradiction sources to look for, in priority order:**

1. **Canonical status doc vs. CHANGELOG.** A project's `tasks/NEXT.md` (or equivalent) is the entry point for "what to work on next," but it's also a doc a human edits after-the-fact and can drift. CHANGELOG.md (append-only, harder to forge retroactively) is usually more current. If they disagree, treat the CHANGELOG as ground truth and the status doc as "needs an update." Don't trust either in isolation — the repo state (`git log`, `grep` for WO IDs) is the third leg.
2. **Canonical status doc's own staleness window.** A real failure mode: a `NEXT.md` claim like "T2SIM-02..07 NOT built" was true at authoring, became false when the GAP-stub wave landed 2026-07-10, and the status doc was last touched 2026-07-09. A 1-day gap between work landing and the doc catching up is normal in fast-moving repos — the canonical doc itself usually flags its own staleness in a footnote. Read the footnote before trusting the body.
3. **Spec ↔ repo state drift.** Specs at `docs/design/specs/...` define what should be true. Code at `packages/...` shows what is true. When they disagree, check the Block's `authority` field (see `blocks.md` → State File Schema): under `authority: spec`, the spec is the conformance target (unmet clauses are work items); otherwise the system defaults to code-authoritative (see `ground-truth-and-mapping.md` → Authority direction). In code-authoritative mode, if the target repo has its own divergence-annotation convention (a commit-message tag or a decision ledger recording *why* code and spec diverged), follow it; when none exists, code + git log are ground truth and the divergence gets surfaced, not auto-resolved. Look for a commit message that explains the divergence before assuming either side is the source of truth.
4. **Block state file vs. current loop reality.** A `tmp/block-*.md` records the last-known status from the previous fire. If 24+ hours have passed since `updated:`, trust nothing in the state file's `evidence` paths or `verify_failures` counts until a fresh Driver Protocol step re-verifies them.

**Named pitfall: prose verdict vs. `loops[]` array drift.** When a human or authoring session logs a verdict or state change as prose in the state file's comment block (e.g., `# VERDICT: T2SIM-04 BLOCKED → ACTIVE`) but never patches the `loops[]` array entry itself, the authoritative data (`status`, `blocked_reason`) stays stale. The next driver pass re-runs pre_check against the old state and re-flags `blocked` (in cron mode this also fires a duplicate alert) — the array, not the comment, is what the driver reads.

Trigger: state file has a prose verdict/note in the header section (lines above the `loops:` YAML block) that contradicts the `loops[]` array entry. Detection is visual on read: a comment says X but `status` field says Y.

Fix: patch the `loops[]` entry to match the verdict prose immediately when the verdict lands. The `loops[]` array is authoritative — it is what the driver reads. The header comment is the *explanation*, not the *source of truth*.

Whenever you catch a contradiction, surface it in the chat reply *before* taking any action that depends on the corrected information. Don't silently overwrite the stale source.
