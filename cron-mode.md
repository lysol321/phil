# Cron Mode

Everything here applies **only when `blocks.md` → Execution-mode status declares cron mode active.** In inline-only mode (the current default) none of this loads — don't read this file, don't arm anything. phil's SKILL.md step 4 and the Driver Protocol gate on the declared mode; when it's inline, skip straight past every cron reference.

Contents: Watchdog Loop, driver cron pre-flight template, cadence selection by Block class, provider/model picks, remote-deliver tiering, and the cross-instance watchdog-ownership gotcha.

---

## Watchdog Loop

The orchestration layer over all category loops — while multiple Blocks run unattended (`blocks.md` → Default posture), something must notice when one goes unhealthy. Modeled on a prior target project's own loop-pipeline watchdog and repetition detector — proven pattern, reused not invented. Unlike those, this runs on the runtime's scheduler (PORTABILITY.md → Runtime adapters), so each fire costs a small LLM call even though the check is deterministic — the mechanical half is delegated to `scripts/watchdog-scan.sh` (one bash invocation reads the registry, prints one line per Block: `healthy` or which signal tripped). The LLM part only triages tripped lines; an all-healthy fire appends the ledger line and ends.

Two deliberate departures from the standard template: **Stop** is an idle/wake condition for a daemon that never finishes, not a completion condition; and it carries a **Cadence** field (fixed background poll interval) no other loop needs.

Goal: Scan every Block and campaign in the registry (`tmp/watchdog-registry.md`, this repo — one absolute `tmp/block-*.md` or campaign-file path per line, appended by phil when it creates a Block/campaign; anything hand-authored without phil isn't seen unless added by hand). Per registered Block, flag:
- **stale** — `updated` older than 2× the Block's cron cadence (cron died silently).
- **stalled-blocked** — `status: blocked` unresolved past 24h for an ordinary reason; unresolved past the *next* scan (no 24h wait) when `blocked_reason` is "feedback-edge iteration cap reached" (a known terminal state needing a human decision, not idle waiting).
- **thrashing** — any loop's `verify_failures` exceeds 3 (evidence production is broken, not just a flaky check).
- **campaign-stalled** (script-side approximation, 2026-07-17): `updated` older than 7 days AND no `closed:` field AND no registered Block for that project has an `active` loop. LLM triage on the tripped line confirms `campaign_stop` unmet AND mapping lists claimable items before acting.

Deterministic checks only — run `bash scripts/watchdog-scan.sh`, falling back to manual per-file checks only if it's missing/errors (report that as a finding itself).

Checkpoint: After each scan, append one line per Block to `tmp/watchdog.md` (healthy, or which signal tripped). A tripped Block enters the **recovery ladder** — strike count = consecutive scans the same signal tripped for the same Block, read straight from the ledger's recent lines (no new counter field). Recover before pausing:
- **Strike 1 — recover, don't pause.** `stale`: re-arm/re-fire the driver with a recovery prompt filled purely from the state file (goal, active loop step N of total, ledger tail, `next_hint` as suggested pivot, instruction *continue from last checkpoint, preserve context, do not restart*). `thrashing`: one targeted re-prompt naming the failing `evidence.verify` method, fix how evidence is produced. `campaign-stalled`: re-fire a phil tick with the campaign file as context. `stalled-blocked` has no recovery rung — blocked means human input by definition; handle per the 24h/cap rules and surface.
- **Strike 2 — recovery didn't take** (same signal next scan): one re-fire with stronger direction — state what did not change since strike 1, instruct a different approach. Still no restart-from-scratch.
- **Strike 3 — auto-pause and surface.** Set `status: blocked` with the reason, cancel `cron_job_id` via the scheduler if recorded, surface to human. Blocks predating `cron_job_id` won't have one; log `"legacy Block, no cron_job_id — cron may still be firing, needs a manual CronList/CronDelete pass"`. Setting `status: blocked` still stops the work — Driver Protocol step 2 refuses to advance a blocked loop.

(Recovery-ladder pattern adopted from the VPS meta-controller-dispatch skill's stall protocol — the one capability this system lacked; the old behavior paused a sick Block on first trip and waited.)

Stop: Standing background loop, no completion. Idles (skips work, stays scheduled) when 5 consecutive scans find zero registered Blocks or every registered Block is `done`/removed; wakes the next time phil registers a new Block.
Cadence: every 30 minutes default (`recurring: true`) — fast enough to flag a stale Block from a 15-minute-cadence Block within one 2×-cadence window, without per-scan LLM cost adding up. Tune to the repo's Block cadences.
Track: `tmp/watchdog.md` — one shared cross-repo ledger. Registry alongside at `tmp/watchdog-registry.md`.
Extras: phil appends to the registry when it creates a Block/campaign, and checks the Watchdog's own cron is armed and not near its 7-day durable-cron expiry — re-arm if idled/missing/expiring so a new Block isn't unwatched. **Re-arm only if you're the same instance that armed it** (see cross-instance gotcha below). **Accepted limitation:** nothing watches the Watchdog itself — if its cron dies silently, Blocks go unmonitored with no alert. The cheapest mitigation is that same re-arm check every phil run, which bounds the blind spot to "however long since phil was last invoked."

---

## Driver cron pre-flight — canonical template

Drop this into every driver cron prompt as the FIRST step, before any git operation or LLM work. Two cheap shell commands, ~1s total, prevent overlap and stale-state corruption. Encode into every driver prompt by default — not just first fires.

```bash
# Step A.1 — STILL-RUNNING CHECK  (scheduler list — e.g. cronjob action='list' / CronList — find this cron's last_status)
#   last_status == 'ok'  (or last_run_at == null = first-ever fire) → prior session clean. Proceed.
#   last_status == null AND last_run_at != null → started but no terminal status: died/hung/cut off. ABORT, surface.
#   last_status == anything else (error/timeout) → prior session errored. ABORT, surface.

# Step A.2 — WORKTREE CLEAN CHECK
git -C "<worktree-path>" status --porcelain
#   empty → clean. Proceed.
#   files in this Block's expected scope (state file's per-loop evidence) → mid-step from a prior fire, normal;
#     next checkpoint commit captures them. Proceed.
#   files outside expected scope → prior session left work half-done. ABORT, surface, list files in the ledger note.
```

**Why `last_status`, not `last_run_at` recency:** on any cadence ≤ the cron interval, `last_run_at` is *always* recent — it doesn't tell you the prior fire is alive. A threshold like "abort if last_run_at < 20 minutes ago" trips every fire on a 15-minute cadence (this mistake cost the sim-ext-t2-impl session one wrong fire). `last_status` catches actual hangs/errors and stays silent on healthy fires.

**Why the worktree check too:** it catches a failure `last_status` misses — the prior session completed "ok" but its last commit failed (pre-commit hook timeout, killed commit shell), leaving uncommitted work. Without this, the next fire sees clean `last_status` and wrongly assumes the loop is ready to advance.

**Pre-check vs. still-running are two different gates — don't conflate:**
- **Pre-check** (per-loop, `loops[].pre_check`): do this loop's acceptance preconditions exist? Failure → `status: blocked` citing the missing item. A real signal needing human review.
- **Still-running** (per-fire, driver prompt): is the prior fire dead? Failure → exit cleanly, one-line ledger note, don't advance. A stall signal.

Worked example (sim-ext-t2-impl, 2026-07-14): T2SIM-04's pre_check grepped for the `SIM_T2` constants block, found it missing, set `status: blocked` with the exact missing item. When the owner asked "is T2SIM-04 blocked?" the answer was a direct state-file read — no memory, no spec re-read.

---

## Cadence — pick by Block class

Cadence is a real design choice, not a default:

| Block class | Typical cadence | Why |
|---|---|---|
| **Build-Until-Gate-Unblocked** | every 2h, waking hours (`0 8-22/2 * * *`) | A WO red→green→commit on a TS monorepo is 15–60 min wall (`pnpm verify` ~96s + commit + ledger). Hourly risks partial-state thrash; 4h wastes time on done loops. Waking-hours-only avoids night silence. |
| **Gate-Clear Block** with human User Test | 3–4×/day waking | Active loop between user-test sessions is mostly sim sweeps (~7–8 min parallel); a few fires/day suffices. The human_gate runs provisionally (async ratify), so cadence isn't gated on a reply. |
| **Continuous / Doc Sweep / Design Doc Alignment** | daily or every 12h | Slow-moving; over-firing wastes tokens on no-op passes. |
| **Adversarial hunt / BUGHUNT-like** | every 4h waking (`0 7-22/4 * * *`) | Cheap static + sim-soak finders run <3 min; 4h catches regressions within a workday without spam. |

**Cadence cap:** never schedule a driver faster than its slowest loop's verify wall (`pnpm verify`-class), or concurrent fires step on each other.

`deliver=local` is the default — cron output is a working record, not chat spam. User reads `tmp/{state-file,track-ledger}.md` on demand.

**Remote deliver (Telegram/Discord/Slack) needs a Tier filter or the cron spams.** A driver on `every 30m` produces ~48 messages/day raw. With `attach_to_session=true` each becomes a repliable thread — useful for milestones, exhausting for routine progress. Default the prompt to Tier-3 silent:
- **Tier-1 (always announce):** pre-flight aborts, loop → `blocked`, watchdog 3-strike escalation, Block-wide stop needing human input, P0 build-gate regression, a needed constant block missing. Terse alert: loop name, one-line reason, what was tried, what wasn't touched, state-file path.
- **Tier-2 (announce on state change):** loop status flip (`pending→active`, `active→done`), new commit + evidence, P0 gate landed, active loop advanced to next in chain.
- **Tier-3 (silent):** fire ran, pre-flight passed, no state change, no new commit, loop still in progress.

Delivery: the runtime's notify capability (PORTABILITY.md → Runtime adapters; e.g. Hermes `hermes send --to <target>:<chat_id> --subject "<subj>" "<body>"` — non-interactive, no LLM call). No notify capability → state file + ledger only, per the reporting contract. Always `attach_to_session=true` so user replies re-enter the cron as a directive.

---

## Provider + model on the driver cron

The driver cron accepts provider/model overrides where the scheduler supports them. Tier rules (`models.md`):
- **Long-running autonomous Blocks** (multi-hour, many tool calls): the runtime's cheapest **mid-tier** driver with strong tool adherence (e.g. Hermes `MiniMax-M2.7` via `provider=minimax` — free/unlimited). Tool-call reliability matters more than reasoning depth here.
- **Blocks needing adversarial review / hard reasoning on demand:** keep the mid-tier driver, escalate specific subtasks to **frontier** via the runtime's delegate capability (PORTABILITY.md → Runtime adapters) — don't switch the driver's own model mid-flight (the cron is pinned; switching re-arms it and loses built-up context).
- **Don't pin the driver itself to frontier unless the Block is short-horizon high-reasoning** (frontier's edge is per-call, not per-cron).
---

## Cross-instance watchdog-ownership gotcha (2026-07-14)

The Watchdog cron can be owned by a *different* Claude Code instance than the one driving the Block — the owner runs Claude Code separately, and its profile owned the `08eccc77` watchdog cron. From another session, `cronjob list` shows your own jobs, not necessarily the other instance's. The Watchdog scans absolute state-file paths from the registry, so a new Block is visible to whichever instance fires it — **re-arming from a second session creates a duplicate, not coverage.**

Signs it's owned elsewhere: (a) watchdog ledger has fresh entries but the cron is missing from your `cronjob list`, (b) a state file names a watchdog cron id you didn't create. Action: append to `watchdog-registry.md` (the watching loop sees it regardless of owner); do NOT create a new watchdog cron. Ask the owner only if the ledger has gone cold AND your `cronjob list` shows no watchdog at all.

**State-file co-writer race** (driver cron firing while an inline session patches the same state file): the patch tool warns ("file modified by sibling subagent…"). Treat it as real. An authoring session `read_file` immediately before `patch`, preserve any checkpoint the driver just landed, patch only the fields you intend. The driver, seeing a non-driver touch since its last fire, reads the comment block first to understand intent, then resumes — doesn't blindly overwrite. Same discipline on Track ledgers. No race for one-shot edits when no driver cron is firing.
