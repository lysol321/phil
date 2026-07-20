## Blocks
A Block is a named, ordered chain of loops meant to be invoked as one unit — a small useful chunk of work, or a full pipeline. A generic driver protocol executes any Block from a resumable state file, so a fresh agent dropped into a session with no memory picks up exactly where the last one stopped. This is the callable-system layer on top of the loop category files linked from `loops.md`.

**Default posture: autonomous.** The human is the bottleneck if every taste call stops and waits for them — don't do that. Run the Block to completion without pausing for approval unless the Stop condition is genuinely a **major design shift**: abandon or redesign a core approach/architecture, spend money, delete significant work, or take an action outside this Block's authority (external submission, standing config beyond this Block). Routine taste calls — is it fun, does it feel right, is this good enough — are the agent's to make. Document the reasoning in the ledger so a human can spot-check later; don't block progress waiting for that check. Same for direction calls: when a design choice is ambiguous but the documented intent covers it, pick the direction that fits the intent, log the reasoning, send a one-line heads-up, and keep moving — course-correcting a logged direction is cheap; idling isn't.

**Emulated gates — provisional verdicts (2026-07-15).** A loop listed in `human_gates` no longer halts the Block waiting for a human. On reaching its Stop, the driver:

1. **Emulate the gate's question** — a fresh-context delegate at frontier tier (the runtime's delegate capability — see `PORTABILITY.md` → Runtime adapters; tier per `models.md`; a runtime with no delegate capability doesn't emulate — its `human_gates` halt for the human), prompted with the gate's own Stop question (a User Test sign-off runs as an independent reviewer/simulated-user pass against that question). Never the building agent grading its own diff, and never the same context as an earlier pre-filter in the chain (e.g. Gate-Clear step 3's Simulated User Pass) — the gate isn't re-graded by the same eyes.
2. **Record it**: write `verdict: "provisional: <verdict> — <one-line direction + why it fits design intent> (<date>)"` on the loop's entry, plus one line naming which downstream loops an override would re-run.
3. **Heads-up**: one line to the human (inline: chat; unattended: state file + ledger per the reporting contract) — verdict, direction taken, proceeding, "adjust" course-corrects.
4. Mark the loop `done` and proceed. A provisional **FAIL** is not done-and-forget: its findings feed the chain's fix loop, and the gate re-queues to re-emulate after the fix lands (backward feedback edge; the initial emulation doesn't count toward the iteration cap, re-queues do). A Block cannot close while any gate still reads `provisional: FAIL`.

**Ratify / override.** Inline: the human replies in chat. Durable: the human edits the loop's `verdict:` field in the state file — `ratified: <verdict>` or `overridden: <verdict + new direction>`. The human's verdict outranks the emulation: on override, do NOT re-emulate — take the human verdict as the gate's resolution and re-run only the downstream loops named in step 2's note (overrides count toward the iteration cap). A Block that completes with un-ratified `provisional:` verdicts is done-pending-ratification: its final report leads with the provisional-verdict queue, it stays listed in the watchdog registry (cron mode) until every verdict is ratified/overridden, and every later phil activation's ground-truth pass re-reads done-Blocks' un-ratified verdicts (recorded in `instances.md` — see Project Instances) — an `overridden:` found there queues the backward edge then. Rationale: Block work is branch-isolated and evidence-logged, so a wrong provisional direction costs a re-run, not lost work — proceeding within design intent beats idling on a verdict.

**Not emulatable — still hard-blocks:** the narrow bar in Default posture above (its full enumeration — nothing dropped) and a genuine canon contradiction between design sources (that's the contradiction check — surface it, don't pick a side).

**Human queue format (2026-07-16).** Every item routed to the human decision queue is written as a decision card for not-yet-decided questions: the question in one line, options A/B (max A/B/C), a recommended default with one-line rationale, and a `safe-to-default: yes|no` flag. (Emulated-gates provisional verdicts are a different shape — already-acted directions, not queue items.) `safe-to-default: yes` items auto-adopt the recommended default as a **provisional decision** (recorded so the owner can still veto it — same posture as an emulated-gate provisional verdict) if unruled after 7 days — day-count evaluated at each phil ground-truth pass, no cron involved (crons unarmed) — the card records the adoption date and which pass adopted it. `safe-to-default: no` (pure taste, canon, narrow-bar-adjacent) items never auto-adopt; they batch — the reporting contract surfaces them as one list so the human can clear the queue in a single sitting. Narrow-bar items (Default posture's enumeration) are NOT queue items at all — they hard-block, unchanged.

**Execution-mode status: declared in `instances.md` (owner-local live state, not shipped).** Default is inline-only: no durable crons. Don’t arm any Block’s driver cron or the Watchdog without an explicit owner ask (and only where the runtime has a scheduler capability — PORTABILITY.md → Runtime adapters); each authorization is scoped to the named Block or campaign, never a global flip back to cron mode. When a scoped cron authorization is live, `cron-mode.md` applies to that Block/campaign only. Known limitation: a local scheduler may fire only while the runtime is idle (runtime-dependent), so crons are best-effort — real progress still comes from inline passes. Block state files in target repos’ `tmp/block-*.md` remain the resumable record regardless. Current mode, live cron topology, and per-project records: `instances.md` — if it is absent (fresh clone or delivered artifact), the mode is the inline-only default.

### State File Schema
One file per Block: `tmp/block-{block-name}.md`.
```yaml
block: <block-name>
phase: <current phase, if pipeline-scoped>
branch: block/<block-name>              # git convention below
touches: [<path globs this Block's loops edit — the Roster disjointness check diffs these lists, so keep it honest>]
cron_job_id: <id returned by the runtime's scheduler (PORTABILITY.md → Runtime adapters), so a watchdog or anyone else can check/cancel it>
cadence: <driver cron interval, e.g. 30m — Watchdog computes its 2×-cadence stale window from this; without it the watchdog can only guess>
next: <block-name | ask>                # successor chaining (Driver Protocol step 9). "ask" (or absent) = report what's claimable and stop — the default. A name = auto-start that Block on completion; the named Block must already be authored in blocks.md (the Block library), NOT merely referenced here
loops:
  - name: <loop name>
    status: pending | active | done | blocked
    ledger: <path to that loop's own Track file>
    pre_check: <one-line test of this loop's acceptance preconditions — run on entering the loop and on Roster re-checks; failure → status: blocked citing the exact missing thing>
    evidence: {path: <commit SHA / test output / screenshot>, verify: <how to re-check it — "run tests", "diff screenshot", "check SHA is on branch head">}
    reach: merged | wired | usable   # optional; Build-phase loops shipping user-facing systems only — what the evidence actually proves. merged = on main, green; wired = an entry point imports it; usable = a Simulated User Pass or Mechanical Sweep spec actually reaching the system (name it in evidence.verify). Evidence proving only "merged" on a user-facing WO is not release evidence. Reach is re-evaluated at each Gate-Clear ground-truth pass; progression merged→wired→usable as wiring lands — not set-once at Build time. (2026-07-16)
    iterations: <count, for feedback-edge loops>
    verify_failures: <count, increments each time step 3 re-verifies evidence and it fails, bouncing the loop from done back to active — this is what Watchdog Loop's "thrashing" signal reads>
    blocked_reason: <why, only when status: blocked>
    verdict: <human_gates loops only — "provisional: <verdict> — <direction + why it fits intent> (<date>)" per Emulated gates, replaced by the human's own verdict on ratify/override>
    next_hint: <one line, refreshed at every checkpoint on the active loop: what the driver would do next, or where it's stuck — Watchdog recovery re-prompts are built from this, so a stale one misdirects recovery>
feedback_pending: [<loop name>, ...]   # queued by a backward feedback edge
human_gates: [<loop name>, ...]        # empty by default. Listed ⇒ Emulated-gates protocol (provisional verdict + heads-up, proceed); only a narrow-bar Stop (see "Default posture") or canon contradiction hard-blocks
authority: code | spec                  # default code (absent = code). code = ground-truth's doc-suspicion applies: verify docs against live state, drift reconciles backward (doc follows code — Design Doc Alignment). spec = the spec is the conformance target: an unmet clause is a work item, not doc-drift, and fixes build toward the spec. Set spec ONLY on a spec-conformance Block; it inverts fix direction for this Block's scope, never skips ground truth (see skill/references/ground-truth-and-mapping.md → Authority direction)
updated: <ISO timestamp>               # REAL UTC from `date -u`, never composed from memory or local time — a future-dated timestamp silently defeats Watchdog stale detection (observed 2026-07-14: a driver wrote local-time-as-Z, +12h off)
# ─ parallel mode only (Parallel Mode section); absent/ignored in sequential mode ─
driver: {id: <session/host id>, expires: <ISO>}   # anti-double-drive lease; refreshed each checkpoint, claimed/released ONLY under the roster lease
slot: <int>                            # assigned at roster build in merge_order order; derives per-worktree scratch/ports in later phases
integration: pending | landed | conflict   # Parallel Mode integration-protocol state; absent until the Block's loops are all done. conflict = an Integration-Conflict or Partition-Rescope work loop was appended and awaits its own driver
```

### Campaign File Schema
One file per active campaign: `tmp/campaign-{project}.md` in the TARGET repo.
```yaml
campaign: <campaign name>
project: <repo path>
campaign_stop: <testable predicate — same bar as loop Stops: verifiable by command/file/state check, never "until happy">
phase: <current Product Pipeline phase, if pipeline-scoped>
budget: <optional; format: "N tokens total", "N tokens/tick", "N ticks", or "ISO deadline"; evaluated at tick entry by summing tick log cost lines or comparing tick count/date; absent = unbounded>
mapping: <path to tmp/mapping-{project}.md>
owner_host: <host id, set only while a parallel wave is live — claims this project's parallel Blocks for one host, since leases are files that don't span hosts; unset = free, or this host = ok to drive here (see Parallel Mode qualification)>
started: <ISO timestamp, REAL UTC from `date -u`>
updated: <ISO timestamp, REAL UTC from `date -u`>
closed: <ISO timestamp, REAL UTC from `date -u`, only when campaign_stop verified met or campaign abandoned by owner — see ground-truth-and-mapping.md Campaign check>
ticks:
  - date: <ISO>
    delta: <one-line ground-truth delta summary — what changed since last tick>
    blocks: <Blocks advanced/completed/authored, e.g. "gate-GF3 active loop 4/5, authored next-block">
    queues: <queue actions taken, e.g. "ratified 1 provisional, auto-adopted 2 safe-to-default decision cards">
    cost: <~wall / ~tokens / units>
    next_intent: <one line — next-tick direction, drives recovery re-prompts>
```
One campaign per project at a time. A Block belongs to a campaign implicitly by being claimed from the campaign's mapping — no per-Block campaign field needed. The campaign file is a **standing-duty surface** — one of the five a phil activation checks for and resumes rather than starting fresh: (1) Block state files `tmp/block-*.md`, (2) the roster file `tmp/roster-{project}.md`, (3) the mapping `tmp/mapping-{project}.md`, (4) the model roster `models.md`, (5) the campaign file. Finding an existing campaign file resumes it as a tick rather than running a bare one-pass activation. Campaign files are registered in the watchdog registry (same file as Block state paths, cron mode only) so the Watchdog monitors them for stall signals.

### Git Convention
One Block = one branch (`block/{block-name}`), created at Block start. Every loop's Checkpoint commits happen on that branch — evidence `path` SHAs are branch-relative. If the branch gets rebased or force-pushed between sessions, a stored SHA can go stale; that's exactly why step 3 below re-verifies evidence instead of trusting the stored claim. One Block actively *driven* at a time per repo **in the default sequential mode**; up to 3 Blocks may be open concurrently (attention-switched) when their loops touch disjoint code paths — see Roster (below). The opt-in **Parallel Mode** (below) lifts the one-driven rule to up to 2 concurrently *driven* path-disjoint Blocks, each in its own isolation worktree — but only when its qualification checks pass; otherwise this sequential rule stands. Before starting or rotating, check other `tmp/block-*.md` files for an `active` loop touching the same code path. Execution mode (inline vs cron) is whatever the Execution-mode status note above currently declares — don't stop to ask about it on routine dev Blocks, just use the declared mode and report what was done. Still respect any human-review policy the target repo has already set for itself (e.g. an existing "PRs stay open for review" convention) — that's the repo owner's prior explicit decision, not this system's gate to override.

**Tree lease (2026-07-16).** Multiple concurrent sessions (NON-phil actors: interactive sessions, other agents; NOT concurrent phil drivers — see Roster's one-actively-driven rule) sharing one working tree race on the git index and on the repo's verify suite — observed: two branch-rename/`core.bare` incidents (2026-07-14) and index-race commit failures + 5× verify flakes under concurrent load (2026-07-15/16). Rule: before any WRITE operation against a shared checkout (stage, commit, checkout, or running the repo's full verify), a session checks `tmp/tree-lease.json` in the target repo: `{ "holder": "<session/block id>", "purpose": "...", "expires": "<ISO>" }`. Live foreign lease → do not write; rotate to another roster Block or queue the write until the lease clears. Expired lease → claim it (write your own, note the takeover in your ledger). Claim a lease before your write burst, refresh `expires` at each Checkpoint (~2× your cron cadence in cron mode; inline Blocks have no cadence — use ~2× your Checkpoint interval, or a 30m default), delete it when the burst ends. Read-only work needs no lease. Verify mutex is the same rule applied to `pnpm verify`-class suite runs: never start one while a foreign lease is live — a flaky-by-contention verify wastes a full run and poisons evidence.

### Roster — multi-Block rotation

phil may open a roster of up to 3 claimable Blocks per activation instead of one — enough that a single `blocked` doesn't idle the session, few enough to hold in one head. Rules:

- **Sequential attention by default.** In the default sequential mode one Block is actively driven at a time; the others wait — rotation is attention-switching, no shared-file races, no worktree fleet. The opt-in **Parallel Mode** (below) is the exception: up to 2 path-disjoint Blocks driven concurrently, each in its own isolation worktree, when its qualification checks pass. Parallel mode is off unless the roster file says `mode: parallel`.
- **Disjointness required.** Roster Blocks must not touch overlapping code paths (the Git Convention's same-code-path check is the real rule). The check is mechanical, not an inference: diff the Blocks' `touches:` lists (state-file schema); a Block missing its `touches:` gets it filled at roster-build time. Can't find 2-3 disjoint claimables from the mapping? A roster of 1 is fine — don't force it.
- **Rotate on `blocked` or `done`.** The active Block hitting `blocked` still halts per Driver Protocol (state file gets `blocked_reason` as usual) — rotation changes what the *session* does next, not what the Block does: mark it blocked in the roster file, note the reason, move to the next non-blocked entry. A Block completing rotates the same way, minus the reason.
- **Re-check blocked entries at each rotation.** Before picking the next entry, re-test each blocked entry's `blocked_reason` condition once (re-run its `pre_check` or equivalent) — external work may have unblocked it since. If it now passes, flip the roster entry back to `queued`, clear its roster blocked note, **AND reset the blocked loop in that Block's state file — `status: blocked` → `pending` and clear `blocked_reason`.** Both writes are required: Driver Protocol step 2 halts on any `blocked` loop, so a roster entry marked `queued` while its loop still reads `blocked` would re-halt at step 2 forever — the external unblock could never actually resume.
- **Roster × Driver Protocol step 9.** Inside a roster, a completed Block rotates first — step 9's park / `next:` auto-start applies only once the roster is exhausted, and a `next: <name>` successor then starts only under the same cap + disjointness rules.
- **Terminal states.** Every roster entry `done` → rotate to the next entry per step 9 rules (Roster × Driver Protocol step 9 above). If all entries are `done`, campaign continuation is handled by Driver Protocol step 9 (check for active campaign, re-map → re-author → rebuild roster if applicable, 2026-07-17); step 9 is the single owner of continuation logic to avoid double-triggering. Every remaining entry `blocked` → **before parking, re-check for unclaimed disjoint claimables:** if the mapping (or, under a campaign, the standing mapping) still lists path-disjoint items not yet in the roster, build a fresh roster from them and drive it — an all-blocked roster is a spent roster, not a spent backlog. Only when no claimable remains: report all `blocked_reason`s in one summary ("all avenues blocked") and park; that summary is the human's queue, in roster order.
- **Track:** `tmp/roster-{project}.md` in the target repo — ordered entries, one line each: Block name, status (`active | queued | blocked | done`), one-line reason when blocked, timestamp of last rotation. Block state files stay authoritative for per-Block detail; the roster file only orders attention. If it already exists at activation, resume it (same rule as any ledger) — re-verify each entry's status against its Block state file first. **Parallel mode** adds a header (`mode: parallel`, `wave: <n>`, `merge_order: [names, fixed at build]`, `owner_host` (campaign-less waves only — otherwise the campaign file is its authoritative home), and the prior-`gc.auto` record) and, per entry, `slot: <int>` + `driver: <id or ->` + `integration: pending|landed|conflict` — see Parallel Mode.

### Parallel Mode (Phase 0 — opt-in, owner-enabled, fail-closed to sequential)

Default is **sequential** (everything above: one Block actively driven per repo, roster = attention-switching). Parallel mode drives up to **2 path-disjoint Blocks at once** on one repo. It activates ONLY when the roster file declares `mode: parallel`. **Only the owner sets `mode: parallel` — phil never writes it autonomously** (enabling parallelism is a standing-config decision, the Default-posture narrow bar). Absent that flag, or if any qualification below fails, phil runs sequential — unchanged. Full design + later phases (shared-file manifest, certified parallel verify, N>2): `<phil-repo>/PARALLEL.md` — Phase 0 is the operable subset here; treat the rest as not-yet-built.

**The scheduler** = the phil activation building/driving the parallel roster; there's no separate daemon in Phase 0, "scheduler" just names the activation while it does roster-level work under the roster lease.

**Qualification (all must hold; checked at roster build AND re-checked on every resume — a stale `mode: parallel` roster must NOT resume into parallel against a repo that no longer qualifies; any fail → this activation runs sequential):**
- ≥2 path-disjoint claimables (disjoint declared `touches:`).
- Normal writable git repo, **no submodules** in worked paths (submodules share `.git/modules/`, unsafe under concurrency).
- Primary quiesced off `main`: `git worktree list` shows no checkout of `main`, so `main` is advanceable by `git update-ref` without desyncing a working copy. **Re-checked again immediately before every CAS (integration step 7)** — if `main` got checked out since, abort integration and surface; never CAS under a live `main` working copy.
- Single host: campaign `owner_host` unset or this host (leases are files in the target repo — they don't span hosts).

**Atomic lease acquisition — the mutual exclusion everything rests on.** The gate is an **atomic-exclusive directory create**, not a write-then-readback (write+rename+readback does NOT exclude: two claimants can each rename then each read back their own id and both proceed). Acquire = `mkdir <lease>.d` — atomic and fails-if-exists on both hosts, so exactly one of N concurrent claimants succeeds; the winner writes `{holder: <your id>, purpose, expires}` as `<lease>.d/lease.json`. `mkdir` fails (dir exists) → read `lease.json`: unexpired → you don't hold it, back off/rotate; **expired** (dead holder) → steal it with a single atomic rename `mv <lease>.d <lease>.d.dead.<your id>` (only one stealer's `mv` can win the one directory name), then re-create fresh and record the takeover in your ledger. Release = remove the dir. This is real exclusion: the `mkdir` (or the single steal-rename) has exactly one winner, and the loser gets a create/rename failure, not a false success.

**Cell model.** Each parallel Block runs in its own isolation worktree (`worktree:` populated, worktree-first per Driver Protocol step 1) on its own branch with its own git index — the index race is gone. The primary stays quiesced, shared infra no driver writes except through the serialized leases below.

**Git-op denylist.** The 2026-07-14 corruption (`core.bare` flip, branch rename) was repo-level shared-state writes from inside a worktree, NOT the index. In parallel mode a Block driver MUST NOT run: `git config` (write), `git branch -m/-d` on any branch but its own, `git worktree add/remove/prune` (except its own step-1 create), `git gc/prune/maintenance`, `git stash`, `git pack-refs`, any `fetch`/`push`. Network ops + gc are integration-lease-only (gc only when zero driver leases are live). Permitted: `git rebase --abort`/`--continue` on the Block's own branch in its own worktree (sanctioned integration cleanup). At parallel-mode entry the scheduler records the prior `gc.auto` and sets `git config gc.auto 0` once under the roster lease.

**Four leases** (all use the atomic acquisition above + the Tree lease `{holder,purpose,expires}` shape + ~2×-checkpoint/30m refresh):
- **driver** — state field `driver: {id, expires}`. A driver executes Driver Protocol steps on a Block only while holding it; refreshes it in every checkpoint write (step 5). Claimed/released ONLY under the roster lease. **Released** when the Block lands (step 9), when the driver rotates away (blocked / integration-pending / no claimable), or on session end — a rotated-away or crashed Block must not stay lease-held or nobody can pick it up; expiry (~2× checkpoint) is the backstop.
- **roster** — `tmp/roster-lease.d/`. Every scheduler mutation (claim/release a Block, rotate, rebuild, edit `merge_order`, flip pending-integration entries) happens under it, held for seconds. **"What's running" = the set of entries with live driver leases, read under this lease** — never inferred from process state or timestamps.
- **verify** — `tmp/verify-lease.d/`. Serializes every `pnpm verify`-class run across worktrees; builds/edits/commits stay parallel. **In parallel mode a verify run checks BOTH `tmp/verify-lease.d/` AND the Tree lease `tmp/tree-lease.json`** (non-phil actors serialize on the file-based tree lease) — a live foreign lease in either blocks the run. **Evidence rule:** a verify run records its verify-lease holder + acquisition time in `evidence`; step-3 re-verification rejects evidence whose recorded holder isn't the runner (produced under contention) rather than retrying it green.
- **integration** — `tmp/integration-lease.d/`, held during the protocol below; its holder **also holds the verify lease** for the step-6 run, so main-bound evidence is never under contention.

**Merge order fixed at roster build.** The roster records `merge_order: [block names]` — the order Blocks land on `main`, fixed at build. Merged `main` is a function of branch contents + this order + the recorded conflict/defer set. Land order mostly follows `merge_order`; a conflict-deferred Block re-enters and lands after the Blocks it waited on (recorded, so still replayable — see PARALLEL.md L2), so it's not fully finish-order-independent.

**Atomic state writes.** Every state-file / roster / lease write is temp-file-then-rename (atomic on both hosts) — a crash mid-write can't leave a half-written file another driver reads.

**Integration protocol** (invoked from Driver Protocol step 9, parallel mode only, when a Block's loops are all `done`). Fixed `merge_order`; self-merge:
1. **Order gate:** proceed only if every earlier `merge_order` Block is `landed` or `conflict` (deferred). Else set `integration: pending`, release the driver lease, rotate — the driver that lands ahead of you re-opens the gate for your retry.
2. Acquire the integration lease AND the verify lease (both atomic).
3. **Rebase-in-progress recovery:** if this worktree has a rebase in progress (a prior crash), `git rebase --abort` first.
4. **Idempotence:** `git merge-base --is-ancestor <branch-head> main` → already landed → mark `landed`, release both leases, done.
5. Rebase the branch onto `main` in the Block's own worktree. **Conflict:** `git rebase --abort`, release both leases, append an `Integration-Conflict` work loop (`status: pending`, Goal "resolve the rebase conflict on `<paths>` and re-land", conflict paths + both SHAs recorded in its ledger — a plain pending work loop, NOT a `pre_check` and NOT `blocked`, so step 2 drives it instead of halting), set `integration: conflict`; its own driver resolves it as ordinary work, then re-enter at step 1.
6. **Partition check (realized-diff, catches a lying `touches:`):** `git diff --name-only <merge-base>..HEAD` intersected with the union of **other** already-landed wave Blocks' realized diffs (exclude this Block's own prior landed diff — an override re-land re-touches its own files and must not self-trip). Non-empty → a partition violation (a clean rebase silently text-merged a shared file): release both leases, append a `Partition-Rescope` work loop (`status: pending`, naming the overlapping files), set `integration: conflict`. Empty → run verify on the rebased tree under the held verify lease.
7. Green → **re-check the primary has no `main` checkout, then briefly claim the Tree lease `tmp/tree-lease.json`** (per the Tree lease claim-before-write protocol) so no non-phil actor can claim the tree and check out `main` during the advance — this fully closes the checkout-during-advance window rather than just narrowing it. Then advance `main` by compare-and-swap: `git update-ref refs/heads/main <new-sha> <expected-old-sha>` — atomic, fails if `main` moved → release both leases, retry from step 1. Release the Tree lease immediately after the CAS. (The CAS is still the safety net for any residual race; the tree-lease claim closes the checkout window.) Lease = liveness, CAS = safety: even a lease bug can't lose an update, only fail the CAS.
8. Write evidence (`main` SHA before/after, verify path + lease holder), set `integration: landed` under the roster lease, release integration + verify leases.

**Wave lifecycle.** A wave ends when every roster Block is `landed` or terminally `blocked`. On wave end the scheduler (under the roster lease): restores `git config gc.auto <prior recorded value>`, unsets campaign `owner_host`, increments `wave:`. Worktrees are left in place (`git worktree remove` stays banned — fragile on Windows; owner prunes manually). A crashed wave resumes: re-run qualification, rebuild "what's running" from live driver leases, continue.

**owner_host — both halves.** While `owner_host` names *another* host, this host does NOT open Blocks on that project, parallel OR sequential (the two hosts' clones would diverge `main`). Unset or this host → proceed; a parallel wave sets it at build, clears it at wave end. Home: the campaign file when one exists (authoritative — qualification reads it there); a campaign-less wave records it in the roster header instead. One home per wave — never both, so there's nothing to drift.

**Failure atomicity.** Each Block's mutable surface = {its worktree, its branch, its state file + ledgers, the leases it holds} — pairwise disjoint, leases expire by time, writes atomic. One Block failing/blocking can't corrupt another's surface; the failed one resumes from its files.

**Rotation.** A parallel driver whose Block hits `blocked` or `integration: pending` **releases that Block's driver lease** and rotates to any entry with no live driver lease that isn't `landed`. `integration: conflict` is NOT a rotate-away trigger — the appended `Integration-Conflict`/`Partition-Rescope` loop is that Block's own work, so its driver keeps the lease and drives that pending loop (re-entering integration when it's done). A pending-integration Block is retried when its order gate opens: the driver that lands an earlier `merge_order` Block, still under the roster lease, flips waiting `integration: pending` entries back to claimable so the next rotation drives their integration. Roster all-`blocked` / all-`landed` terminal states are per the Roster section (`landed` is parallel-mode "done").

### Model Roster

Which models/providers are actually available — and what each is for — lives in `models.md` (this repo): provider, model, access path, tier, cost, use-for. Loops and drivers that need a model *class* (Simulated User Pass wants frontier; mechanical sweeps run cheap) consult it rather than hardcoding names — pinned model ids go stale, `models.md` is the one place they're allowed to live. phil verifies it at activation — interview triggers (this list is the single definition; skill files point here): file missing, `updated:` older than ~30 days, `status:` reads UNCONFIRMED, or the user signals a change → interview the user (which providers/models, budget limits, routing preferences) and rewrite the file; otherwise proceed without asking. "One place" applies to *current* ids — archived Blocks keep their historical pins as records.

### Driver Protocol
1. Read `tmp/block-{block-name}.md`. If missing, create it from the Block's loop list, all `status: pending`. Then ensure the Block's branch exists — create/checkout it if it doesn't yet (this covers the authored-but-never-fired case too: phil authors a Block by writing its state file and defers branch creation to this first fire, so a *present* state file whose `branch` doesn't exist still needs it created here). If the branch **also** doesn't exist yet and the state file's `worktree:` field names an isolation worktree, create branch + worktree together, worktree-first: `git worktree add <worktree-path> -b block/<block-name>` from a primary on `main` (never `git checkout -b` on the primary first — see `skill/SKILL.md` worktree-first rule). **But if the branch already exists and the recorded `worktree:` is missing** (a previously-fired Block whose worktree vanished), do NOT re-create it — STOP and surface per `skill/references/execution.md` → two-checkout pattern; the vanished worktree's uncommitted files / hidden refs may matter, and silent re-creation loses them. **Parallel mode (roster `mode: parallel`):** the FIRST action of step 1 — before reading/creating the state file or any git op above — is to claim this Block's `driver` lease under the roster lease (Parallel Mode → Four leases). Lost or live-foreign claim → another agent owns this Block; pick a different roster entry and touch nothing here (don't create its branch/worktree).
2. **Scan for a `blocked` loop first.** Any loop with `status: blocked` → stop, do not re-run it, surface its `blocked_reason` to the human (a blocked loop is `blocked`, not `active` — checking only the `active` slot would silently skip it and drive the chain past an unmet precondition). No blocked loop → **drain `feedback_pending` next:** if it's non-empty, take its first entry, set that loop back to `active`, remove it from the list, and run it (its `iterations` was already incremented when the backward edge queued it, step 7) — a queued feedback re-run takes priority over advancing to a new loop, so a re-queued gate/clause actually re-runs instead of being stranded. Empty `feedback_pending` → find the `active` loop (resume it) or, if none, the first `pending` loop and set it `active`. (First loop in the Block: skip step 3, there's nothing prior to verify.)
3. Before trusting the *previous* loop's `status: done`, re-verify its `evidence` using the method in `evidence.verify` — a bare stored path is not sufficient, re-check it. If verification fails, increment that loop's `verify_failures`, set it back to `active`, and re-run it instead of advancing. **Inline thrashing cap:** `verify_failures > 3` on a loop → set `status: blocked`, `blocked_reason: "evidence re-verify thrashing (>3) — evidence.verify method or the work producing it is broken"`, and halt. (In cron mode the Watchdog also reads this as its "thrashing" signal; inline, this cap is the only backstop, so it lives here in the protocol — don't rely on the Watchdog, it doesn't load inline.) After any worktree-isolated agent (one run in its own git worktree) reports a commit, also check `git worktree list` + `git config core.bare` + that the shared ref wasn't renamed before trusting the hash (gate-GF3's INCIDENT lesson, promoted from ledger note to protocol, 2026-07-16).
4. Run the active loop's Goal. If the Goal turns out impossible or is contradicted by what's actually in the repo/build, set `status: blocked`, write `blocked_reason`, and halt the Block for human input — never guess or mark it `done` anyway. **`authority: spec` carve-out:** under a Block whose state file reads `authority: spec`, a clause the repo doesn't yet satisfy is NOT a blocking contradiction — it's the expected `unmet` work item this Block exists to close. Only a genuine spec-vs-spec contradiction between two design sources hard-blocks (the contradiction check — surface it, don't pick a side).
5. Checkpoint the state file at the loop's own Checkpoint cadence, not just at Stop — a session death then loses at most one checkpoint interval. Refresh the active loop's `next_hint` in the same write (one line: next intended step, or where stuck) — it's what the Watchdog's recovery re-prompt is built from, and a stale hint misdirects recovery. Refresh the tree-lease `expires` in the same write if a lease is held (per the Tree lease rule — ~2× cron cadence, or ~2× Checkpoint interval / 30m default inline). **Parallel mode:** in the same write, refresh this Block's `driver` lease `expires`, and the verify/integration lease `expires` if held (Parallel Mode → Four leases) — a checkpoint that doesn't refresh a held lease lets it expire mid-work and invites a takeover.
6. On Stop: write `evidence` (`path` + `verify` method), set `status: done`. A loop listed in `human_gates` runs the Emulated-gates protocol (above): independent emulation of the gate's question, provisional `verdict` recorded, heads-up sent, then proceed — never the building agent's self-assessment, and never a silent skip. Only narrow-bar Stops and canon contradictions hard-block. Doc-flip (2026-07-16): on setting a loop `done`, also grep the target repo's status docs (e.g. `tasks/NEXT.md` + the owning task/spec file) for the WO id / feature name; if the status entry doesn't reflect the new state, flip it in the same commit as the evidence — a code change without its doc-status flip is the known staleness failure mode (`tasks/NEXT.md`'s own 2026-07-09 note; ~15h of reconciliation churn per 6 weeks measured 2026-07-16). **`authority: spec` carve-out:** the doc-flip reconciles the *status doc* forward as always, but under `authority: spec` it never edits the *spec doc itself* backward to match code — an unmet clause means code is behind the spec, so the fix is a Build-phase work item, not a spec edit (that's the whole point of `authority: spec`; under the default `authority: code`, spec/design docs follow code via Design Doc Alignment). Delete the tree-lease when the Block's write burst ends (all loops done or blocked).
7. Apply the relevant Chaining Rules: forward/backward feedback re-queues an earlier loop and increments `iterations`. **Iteration cap 3 — beyond that, write state, don't just stop:** set the capped loop `status: blocked`, `blocked_reason: "feedback-edge iteration cap reached"`, then report. The state write is mandatory (not optional as "stop and report" once implied) — without it a fresh session finds the loop mid-flight and re-runs the capped edge; the specific reason string is also what the Watchdog uses, in cron mode, to tell a capped-out loop from an ordinary block. Hand-offs route one loop's ledger into the next loop's Goal input.
8. Repeat from step 2. Block ends when every loop is `done` **and `feedback_pending` is empty** (a queued feedback re-run keeps the Block open — step 2 drains it before this end-check can pass, so a Block can't close with an un-processed re-queue or a gate still reading `provisional: FAIL`), or a feedback edge hits its iteration cap, or a loop is `blocked` awaiting human input. **Loop-append (generator loops):** the `loops[]` array is not frozen at step 1 — a generator loop (e.g. Spec Decomposition Loop) may append new `loops[]` entries on its Stop. Because step 2 re-reads the array and re-scans for the first `pending` loop on every pass, appended entries are picked up and driven automatically, in array order, after the generator that produced them. This is the only sanctioned way to *grow* the array mid-Block; every appended entry still needs the full schema (`name`/`status`/`ledger`/`pre_check`/`evidence`) so a fresh driver can operate it. **One sanctioned reorder exception:** a Planning Loop (in the `spec-conformance` chain) may re-sequence `pending`-only appended entries into build order — never reordering an `active`/`done` entry — since step 2 re-scans for the first `pending` loop each pass, a reordered pending tail is picked up correctly. **Two more sanctioned appends** (Parallel Mode integration protocol): an `Integration-Conflict` or `Partition-Rescope` work loop, appended `status: pending` when a Block's rebase conflicts or a realized-diff overlap is found — driven like any other pending loop, not a generator. Their `pre_check` is intentionally absent (treat as always-pass) — they're resolution work, not precondition gates, so step 2 drives them rather than blocking.
9. On completion (every loop `done`): **parallel mode first** — if the roster is `mode: parallel`, the Block is not complete until it has landed: run the **Integration protocol** (Parallel Mode section), then release the `driver` lease under the roster lease. A Block parked `integration: pending` (waiting on an earlier `merge_order` Block) is not done — rotate to another entry, retry its integration when its order gate opens. The `integration: landed` short-circuit is guarded: skip the protocol only if `integration: landed` AND the branch head is still the landed SHA; if new commits landed after (a gate override re-queued work — Ratify/override), reset `integration: pending` and re-run the protocol (step 4's ancestor check makes the re-run safe). Only once `integration: landed` at the current head does the rest of this step apply. Then: driving under a Roster? Rotate first — this step applies only once the roster is exhausted (see Roster). **Exactly one continuation path fires — campaign supersedes `next`:**
   - **Campaign active** (live `tmp/campaign-{project}.md`, `campaign_stop` unmet) — **campaign continuation (2026-07-17):** if the standing mapping still lists claimable items, re-run ground-truth delta, delta-update the mapping, author the next Block(s) from the mapping's top-ranked claimables via the Loop Authoring Loop (review passes mandatory), rebuild the roster, resume driving. This is continuation toward the campaign Stop, not a design shift (the design-shift bar applies to work OUTSIDE the mapping/campaign scope or a NEW campaign). Under a campaign, per-Block `next` fields are ignored — the mapping drives, so an in-flight `next` can't double-fire alongside a rebuilt roster.
   - **No campaign** — consult the just-completed Block's `next` field. `ask` or absent: the final report names the next claimable Block (if the Stop text or backlog suggests one) and parks — human decides. A Block name: auto-start it, but only if that Block is **already authored in `blocks.md`** (this repo's Block library, not the state file) — bootstrap it as phil would (create its state file per step 1 with `cadence` + `next` populated; in cron mode only: append its path to the watchdog registry, verify the Watchdog cron is armed, arm its driver cron, record `cron_job_id`), then fire its first Driver Protocol pass. Guards: a `next` naming a Block not authored in `blocks.md` → treat as `ask`, report, never improvise one; a successor whose state file already exists with every loop `done` → report and stop, don't re-fire (breaks A→B→A cycles); Git Convention's actively-driven + disjointness check still applies. If several done Blocks each carried a `next`, only the last-completed Block's `next` is consulted — one successor at a time under the cap.

### Gate-Clear Block (template)

Reusable pattern for clearing any single named pipeline gate (a `GFx`/`Gx`/project-specific gate ID) — instantiate one per gate rather than drafting a bespoke Block each time. Chains:

1. **Calibration / Tuning Loop** (or the project's own sweep tooling) — confirm ground-truth metrics land in the gate's target band on the build the gate covers.
2. **Mechanical Sweep Loop** — Playwright, no LLM — deterministic pre-filter for the DOM/event-state bug class (focus traps, toggle-state mismatches, swallowed input, dialog tab-order). Iterate to its own Stop before handing off. Skip this step only if the gate has no user-facing UI surface at all (e.g. a sim/calibration-only gate) — note the skip in the Block's `Extras`, don't silently omit it.
3. **Simulated User Pass** — roleplay pre-filter (frontier tier via the delegate capability, `PORTABILITY.md` → Runtime adapters) against the UX bar (3 clicks/keys, 5s to something useful or fun). Iterate to its own Stop before handing off.
4. **User Test** — `human_gate`; Stop is the gate's actual question ("does X hold up," "is Y right"), not a generic user test. Runs provisional by default — emulated verdict + heads-up, human ratifies/overrides async (see Emulated gates).
5. **Fix Bugs From a Log** — fed by steps 2-4's findings; Triage skipped when it's a single gate's fire (nothing to merge yet), included if the Block runs gates back-to-back and findings pile up across them.

Track: `tmp/block-gate-<gate-id>-{project}.md`
Stop: All five loops `done` — metrics in band, Mechanical Sweep green, Simulated User Pass clean, the User Test gate's own question answered (provisional verdict recorded per Emulated gates, not held for human ratification), and every finding dispositioned per Fix Bugs From a Log (fixed, or logged `wontfix`/`by-design`/`deferred` with a reason — an honest non-fix doesn't deadlock the gate). For a milestone-release gate, also every milestone user-facing WO at `reach: usable` (see Extras). The gate is cleared when its own design-doc question reads satisfied on the covered build, not merely when the loops ran.
Extras: One instantiation per gate — same 5-loop chain, different sweep target and different User Test question per the gate's own design doc. If a project runs several gates back-to-back (e.g. a numbered gate series), route their Fix-Bugs ledgers through one shared Triage Loop instead of duplicating it per gate. A milestone-release gate asserts `reach: usable` on the era's user-facing WOs — merged-and-green is not the bar for release gates; reach is re-evaluated at each Gate-Clear pass as a ground-truth check. A 2026-07-16 project review found ~half an 83-WO build wave merged-but-unreachable (zero entry-point imports / flag-gated off), invisible to every existing loop.

**Verification-cost pyramid (2026-07-16, frontier-tier review of one project's scenario corpus).** Step 3's live/roleplay tier is the most expensive rung and should carry the least re-verification weight, not the most — a corpus where nearly every re-check falls to live browser runs because cheaper rungs (a headless replay oracle, step 2's Mechanical Sweep) went unextended is an inverted pyramid, even when each individual loop's own Stop condition is green. At each Gate-Clear ground-truth pass, check the *shape*, not just each loop's status: (a) is a cheap deterministic oracle (fixture/replay cache) available and extended past its original pilot scope, or stalled? (b) do a meaningful fraction of passing scenarios' beats duplicate what step 2's Mechanical Sweep could assert for free — if so that's a retroactive-audit candidate (see Triage Loop's rung attribution — it fires forward on new findings only; a one-time backward sweep over already-passing evidence is a distinct, worth-scheduling task); (c) is there a wall-clock staleness herd about to fire (many scenarios sharing one `last_run_at` crossing the same threshold at once) — if so, a cheap repo-quiet check (no commits touched the covered paths since the last pass — one `git log` call) can waive a re-run instead of burning the expensive tier on a build that provably didn't change. None of this replaces a rung's own Stop condition; it's the ground-truth pass noticing that "every loop is green" and "the cost distribution is sane" are different questions. **No silent caps:** if any of this bounds coverage (a fixture corpus that only covers 2 of N scenarios, an audit that only covers the loudest beats), the Block's report says so explicitly — a partial rung migration reading as "pyramid fixed" is the same staleness failure mode as an unflipped status doc.

### Watchdog Loop — cron mode only

The health-monitor daemon over all unattended Blocks. Inert in inline mode (nothing scans the registry), so its full definition — Goal, recovery ladder, cadence, cross-instance ownership gotcha — lives in `cron-mode.md`, loaded only when Execution-mode status declares cron mode active. `scripts/watchdog-scan.sh` is its deterministic scan half. Registry + ledger at `tmp/watchdog-registry.md` / `tmp/watchdog.md`.

---

## Reusable Block Templates

These are generic, claimable Block shapes. Instantiate one only after phil's ground-truth mapping confirms that the target project has work matching the chain. They are intentionally smaller than the full Product Pipeline.

### `progression-hardening` Block
Scope: turn a working content build into a reachable, persistent, and recoverable progression path.

Chain:
1. Asset and Data Integrity Loop
2. Progression Integrity Loop
3. Save/Load Integrity Loop
4. Failure-Recovery Loop
5. Simulated User Pass
6. Triage Loop
7. Fix Bugs From a Log
8. Regression Soak Loop

`human_gates: [Simulated User Pass]` only when the target's existing review policy requires a human gate; ordinary roleplay remains autonomous under the default posture.
Track: `tmp/block-progression-hardening-{project}.md`
Stop: Progression paths are complete, persistent, recoverable, and survive the configured soak.
Extras: The Asset/Data loop is first so later progression failures are not caused by invalid content references. Save/Load and Failure-Recovery are separate because valid serialized data does not prove safe interruption behavior.

### `deterministic-sim-cert` Block
Scope: certify a simulation-heavy system's repeatability, metric behavior, performance, and diagnosability.

Chain:
1. Determinism / Replay Fidelity Loop
2. Calibration / Tuning Loop
3. Performance / Profiling Loop
4. Regression Soak Loop
5. Observability Contract Loop

`human_gates: []` by default — the chain uses executable evidence and spec-defined metric bands, not a taste decision.
Track: `tmp/block-deterministic-sim-cert-{project}.md`
Stop: Replays are deterministic, metrics remain in band, performance meets budget, soak is clean, and critical failures are diagnosable.
Extras: If the target is multi-client, append Network Sync Loop after Determinism and before Soak. Do not use this Block to tune values that the governing spec says the simulation must only measure.

### `first-session-ready` Block
Scope: verify that a clean-profile novice can reach the first meaningful milestone through supported controls.

Chain:
1. Asset and Data Integrity Loop
2. Onboarding / First-Session Loop
3. Input and Control Compatibility Loop
4. Mechanical Sweep Loop
5. Simulated User Pass
6. User Test
7. Triage Loop
8. Fix Bugs From a Log

`human_gates: [User Test]` — the gate asks whether the first-session experience is understandable and compelling enough to continue.
Track: `tmp/block-first-session-ready-{project}.md`
Stop: A clean-profile user reaches the intended first milestone through every supported control path without intervention, unexplained blocker, or critical friction.
Extras: Mechanical Sweep precedes roleplay so deterministic interaction failures do not consume the expensive user-simulation pass. User Test remains the final judgment gate.

### `clean-build-release` Block
Scope: establish that the release candidate works from clean environments across the declared support matrix.

Chain:
1. Dependency and Clean-Build Reproducibility Loop
2. Compatibility Matrix Loop
3. Performance / Profiling Loop
4. Accessibility Pass Loop
5. Localization Loop
6. Release Certification Loop

`human_gates: []` — Release Certification stops at the agent-side local checklist and flags the external submission for the human.
Track: `tmp/block-clean-build-release-{project}.md`
Stop: Required environments install, launch, pass smoke checks, meet budgets, and pass the local release checklist.
Extras: Keep the matrix explicit. An unsupported environment must be documented as excluded rather than silently omitted.

### `incident-to-regression` Block
Scope: convert a crash, corruption issue, exploit, or production-like failure into durable coverage.

Chain:
1. Failure-Recovery Loop or Abuse and Boundary-Case Loop, selected by incident class
2. Fix Bugs From a Log
3. Test Coverage Loop
4. Determinism / Replay Fidelity Loop, when the failure is reproducible
5. Regression Soak Loop
6. Observability Contract Loop

`human_gates: []` unless the fix changes a major design or security policy.
Track: `tmp/block-incident-to-regression-{project}.md`
Stop: The failure has a minimal reproducer, a root-cause fix, permanent regression coverage, verified diagnostics, and a clean soak.
Extras: Do not force Determinism when the incident is inherently nondeterministic; record why it was skipped and preserve the best available reproduction evidence.

### `telemetry-ready-gate` Block
Scope: make a new subsystem observable before it is relied on by downstream gates or unattended operation.

Chain:
1. Observability Contract Loop
2. Mechanical Sweep Loop or simulation assertions
3. Performance / Profiling Loop
4. Regression Soak Loop
5. Doc Sweep

`human_gates: []` by default.
Track: `tmp/block-telemetry-ready-{project}.md`
Stop: The subsystem's success, failure, latency, and state transitions can all be observed from a real run, and the diagnostic contract is documented.
Extras: Use this before shipping complex simulation, economy, AI, or orchestration features. Otherwise the first bug becomes archaeology.

### `spec-conformance` Block
Scope: drive a target's implementation to conform to a design/spec doc — decompose the spec into a requirement backlog, build the unmet clauses, gate on full conformance. This is the **proactive** counterpart to phil's backlog-driven default: reach for it when the target has a rich spec but a thin or empty enumerated backlog (the mapping step's proactive trigger — see `skill/references/ground-truth-and-mapping.md` → Spec-driven trigger).

Chain (the middle is generated, not fixed — see step 1):
1. **Spec Decomposition Loop** (`loops-core.md`) — spec → requirement ledger, one item per normative clause with a testable Stop and a live current-state. It is a **generator loop**: on Stop it appends one `loops[]` entry per `unmet`/`partial` clause (the step-3 loops below) **in spec order** (it fires before Planning has run, so it can't know a build order yet — spec order is the provisional sequence), so the fixed chain materializes into `decomposition → planning → N per-clause loops → gate` in the state file. `met` and `needs-human` clauses get no entry.
2. **Planning Loop** — re-sequence the pending appended per-clause entries into build order. This is a **sanctioned reorder of `pending`-only entries** (the one exception to loop-append being append-only — see Driver Protocol step 8): Planning may reorder entries not yet `active`/`done`, never touch already-driven ones. Skip when the ledger is small and its items are independent (spec order stands).
3. **Per-clause Build/Validate loops (appended by step 1)** — each appended `loops[]` entry `name:`s the Loop template its clause's `proposed-loop` field chose (Content Pipeline, Fix Bugs From a Log, Test Coverage, Mechanical Sweep, UI Design Loop, …); the Driver Protocol drives them in order via its loop-append clause. These run sequentially inside this one Block — they are loops, not Blocks, so they do NOT populate a Roster (the Roster holds path-disjoint *Blocks*; clauses of one spec typically share code paths anyway). Genuinely path-disjoint clause clusters big enough to parallelize are a separate call: author them as sibling `spec-conformance` Blocks over spec subsets and let the normal Roster cap arbitrate — not a sub-roster inside this Block.
4. **Conformance Gate** — Full Production Loop in full-sweep mode, the ledger's clause set as the fixed scenario list, each clause a pass/fail check against its `stop-predicate`. Runs *after* step 3 has driven every clause to `met` — it is a verification sweep, not a second build stage. A clause that fails at the gate re-queues its owning step-3 loop as a backward feedback edge (`feedback_pending` + `iterations`, cap 3), rather than Full Production Loop fixing it in place — this keeps re-verification off the expensive rung and avoids O(N) full sweeps (the verification-cost-pyramid warning above). Stop: every clause reads `met` with verified evidence **or is parked `needs-human`** — the gate excludes `needs-human` clauses (a human-parked clause can't be gate-satisfied, so gating on it would deadlock the Block; this matches the Block Stop below). Only an `unmet`/`partial` clause keeps the gate open.

`authority: spec` (state-file field) — this Block conforms code to the spec; ground-truth's doc-suspicion is inverted for its scope (see `skill/references/ground-truth-and-mapping.md` → Authority direction). It does NOT skip ground truth — every clause's `current-state` is still checked live, and the Driver Protocol reads `authority` at step 4 (contradiction carve-out) and step 6 (doc-flip carve-out).
`human_gates: []` by default — conformance is evidence-checkable per clause. A clause whose Stop is a genuine taste call lists that clause's validate-loop as a gate, emulated per Emulated gates.
Track: `tmp/block-spec-conformance-{project}.md`
Stop: Every normative clause reads `met` with evidence, or is `needs-human` (ambiguous-spec, or a narrow-bar design shift). Gate arithmetic: only an `unmet`/`partial` clause fails the gate — those keep the Block open (they re-queue their step-3 loop); `needs-human` parks the clause and is surfaced in the report but does NOT hold the Block open (a human can't be blocked-on and progress-gating at once). The Block closes when every clause is `met`-or-`needs-human` with no `unmet`/`partial` remaining.
Extras: When the spec itself changes mid-Block, re-queue Spec Decomposition Loop as a backward feedback edge (`feedback_pending`, counts toward the `iterations` cap) — its re-scan appends new/changed clauses as fresh `unmet` `loops[]` entries and retires deleted clauses' entries (same generator step). A contradiction between two design sources still hard-blocks (the contradiction check — surface it, don't pick a side). Distinct from Content Pipeline Loop (that fills a content quota against a design doc; this drives arbitrary system conformance) and from Design Doc Alignment (that reconciles docs backward to code; this drives code forward to the spec).


## Project Instances

Instantiated Block records, campaign/cron topology, and un-ratified provisional verdicts live in `instances.md` — owner-local live state, export-ignored (absent from delivered artifacts) and intentionally outside the lint SURFACE. Ground-truth passes read instance and verdict state there, not here. Future instance records go to `instances.md`, never back into this file.

## Example Invocations

/goal Run the <project> visual user tests until every scenario in e2e/user test/scenarios.json passes with screenshot evidence, or until 23:00 local time. Treat any failure as a task to fix. Track progress in tmp/visual-testing-<project>.md

/goal Author the <project> visual user tests until every possible user action is covered by scenarios in e2e/user test/scenarios.json, or until 23:00 local time — whichever comes first (given the codebase's current state). Track progress in tmp/scenario-authoring-<project>.md
