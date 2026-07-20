# Agent Loops

Reusable iteration patterns: run to a stop condition, checkpoint each significant step (validate/autoreview/commit), track progress in a ledger.

**Taste loops** — vague bar on purpose ("until happy"); judgment delegated to agent. Give-up bound: stop when a full pass adds no new signal.
**Ground-truth loops** (coverage/tests/perf) — numeric bar; the number is the bar.

Template fields (canonical definition + shared glossary live in [`loops.md`](loops.md) → Loop contract; this is the working restatement, kept in sync with it): **Goal** (task + boundaries) · **Checkpoint** (per-step cadence) · **Stop** (exact condition) · **Track** (ledger path, repo-relative `tmp/...` — never `/tmp/`, which is ambiguous outside Unix) · **Extras** (caveats/tools, if any).

Every ledger pass appends a one-line cost record — `cost: ~<wall-clock> / ~<tokens if known> / <N findings or units>` — and phil's ground-truth pass treats a loop whose cost-per-finding (discovery loops) or cost-per-unit (ground-truth loops, e.g. Test Coverage) degrades across passes as a demotion candidate: move its coverage to a cheaper rung, or retire it. A green regression suite is never a demotion candidate — staying green is its job (see rung ladder, Triage Loop) (2026-07-16).

**Before starting any loop**: if its Track ledger already exists, read it first and resume from the last checkpoint — don't restart. Every loop also carries an implicit wall-clock/budget bound: if the user gave one ("or until 23:00", "+500k tokens"), it caps the loop regardless of Stop.

**Glossary**: `autoreview` = run this repo's own review skill/command (e.g. `/code-review`) over the change since last checkpoint. `oracle review` = a second, independent agent pass in fresh context judging the artifact against its stated goal — never the same agent grading its own work.

See **Blocks** (below the loop library) for chaining loops into one callable, resumable unit of work.

---

## Full Production Loop
Goal: Create [N] realistic scenarios covering every major capability — or, if scenarios arrive continuously rather than as a fixed set, test them as they come. Define success criteria and a consistent evaluation method (pass/fail checks or scoring rubric) before testing.
Checkpoint: Run scenarios under identical conditions; record evidence per outcome. On any failure: document it, add regression + benchmark coverage, fix root cause (not symptom), rerun the affected scenario, then rerun the full set (or restart the streak, in streak mode).
Stop: Pick one mode up front. Full-sweep mode: every scenario in the fixed set meets the original quality bar. Streak mode: [N] successful cases in a row.
Track: tmp/production-{project}.md
Extras: Two Stop modes for one mechanism — full-sweep for a bounded scenario list, streak for an unbounded/ongoing one.

## Triage Loop
Goal: Read every taste/ledger-producing loop's Track file since the last Triage pass (e.g. User Test, Visual Inspection, Refactor Loop's smell notes) and emit one prioritized bug/task log with repro steps or a concrete next action per item.
Checkpoint: After each ledger processed: dedupe against existing log entries; tag each finding `rung: mech-sweep | fixture | sim | roleplay | human` — the cheapest verification rung that could have caught it, not the rung that did — and auto-spawn a coverage task at that rung (a new Mechanical Sweep invariant, a replay fixture, a sim assertion) into the target repo's task flow when a finding's rung is cheaper than the loop that found it: append to the target repo's backlog doc (e.g. `tasks/NEXT.md`) OR open as a claimable loop ledger `tmp/{rung}-{project}.md`, per repo convention, same session or logged as claimable (rung attribution, 2026-07-16 — see Chaining Rules); commit.
Stop: All ledgers since the last Triage pass are processed into the log.
Track: tmp/triage-{project}.md
Extras: Converts taste ledgers (not bug-log format) into something Fix Bugs From a Log can consume directly. The Product Pipeline's scoped Triage variant lives in [`loops-hardening.md`](loops-hardening.md).

## Fix Bugs From a Log
Goal: Fix bugs from bug log.
Checkpoint: After each significant fix: validate result, run autoreview, commit.
Stop: Every log item has a disposition — `fixed` (with evidence), `wontfix`/`by-design` (with a one-line reason), or `deferred` (logged as a claimable item elsewhere, not left silently open). Don't mark a Block-blocking non-bug `fixed` dishonestly, and don't block a whole Block on an unfixable-by-design item — disposition it and move on.
Track: tmp/bugfix-{project}.md

## Test Coverage Loop
Goal: Add tests for the current diff (or a caller-specified module, if no diff scope given).
Checkpoint: After each test added: run suite, record coverage delta, commit.
Stop: Diff-coverage hits 100%, or mutation score hits its target if a mutation-testing tool exists in the repo.
Track: tmp/coverage-{project}.md
Extras: Prefer mutation score over raw line/diff coverage when a mutation tool is available — line coverage only proves lines executed, not that assertions catch regressions, and is gameable with assertion-free tests.

## Refactor Loop
Goal: Refactor architecture.
Checkpoint: After each significant step: live-test system, run autoreview, commit.
Stop: Until happy with architecture; give up if 3 straight steps yield no architecture gain — report remaining smells.
Track: tmp/refactor-{project}.md

## Planning Loop
Goal: Design the project's build-plan doc (caller supplies the target path) until it's feature-rich, meets or exceeds design intent, and covers all facets. Do not code or execute — this loop touches docs only.
Checkpoint: After each significant step: review with oracle, then commit.
Stop: Until happy the plan is feature-rich, meets/exceeds design intent, and covers all facets. Stop if 3 straight passes change nothing you'd defend — report open design questions.
Track: tmp/plan-{project}.md
Extras: Delegate tasks, run in parallel. Each task states model tier (small/mid/frontier per `models.md`) and effort (low/medium/high/max where the runtime exposes it). This pass is design only — detailed review comes later.

## Spec Decomposition Loop
Goal: Turn a design/spec doc (caller supplies the path) into a mapped requirement ledger — every normative clause becomes a claimable backlog item with a testable Stop predicate, a proposed Loop template, a Pipeline phase, and a live current-state (`unmet | partial | met | needs-human`). Doc-in, backlog-out: do not implement — this loop produces the backlog the other loops consume. It is the spec-driven front-end the backlog-mapping step (`skill/references/ground-truth-and-mapping.md`) otherwise assumes already happened.
Checkpoint: After each spec section: append its normative clauses to the ledger as `{clause-id, spec-ref, requirement, proposed-loop, phase, stop-predicate, current-state, evidence-if-met}`; verify each `current-state` against the live repo (does the code already satisfy the clause?); oracle-review the decomposition — every normative clause captured, each Stop testable, descriptive/rationale prose correctly excluded; commit.
Stop: Every normative clause maps to a ledger item with a testable Stop predicate and a verified current-state, and a full re-scan of the spec surfaces no uncaptured normative clause. A clause that resists a testable predicate after one honest attempt is set `current-state: needs-human` with the ambiguity named — it does not block the rest of the decomposition.
**Generator step (runs on Stop, before setting the loop `done`):** append one `loops[]` entry to the Block state file per `unmet`/`partial` clause — `name:` the clause's `proposed-loop`, its own `ledger:` + `pre_check:` (the clause's `stop-predicate`), `status: pending`, **in spec order** (this generator fires before the Planning Loop, so it can't know a build order yet; the following Planning Loop re-sequences these still-`pending` entries into build order as the one sanctioned reorder — see `blocks.md` → Driver Protocol step 8). This is what makes the `spec-conformance` chain's per-clause middle executable — the Driver Protocol's loop-append clause (`blocks.md` → Driver Protocol) then drives the appended entries like any other loop. `met` and `needs-human` clauses get no `loops[]` entry (already satisfied, or parked for a human).
Track: tmp/spec-decomp-{project}.md — the requirement ledger is the hand-off artifact; downstream Build/Validate loops consume it directly.
Extras: A **generator loop** — unusual in that its Stop mutates the Block's own `loops[]` array (most loops only read it). Runs only inside a spec-authoritative Block (`authority: spec` in the state file — see `blocks.md` → `spec-conformance` Block and State File Schema). The live current-state check is still ordinary ground truth; what `authority: spec` flips is the *fix direction* — an unmet clause is a work item to build toward the spec, not a doc-drift finding to reconcile backward (reconciling backward is Design Doc Alignment, the `authority: code` default). Only normative clauses (MUST/SHALL/"the system does X") become items; log the excluded descriptive sections so re-scans are stable and don't re-litigate what was already ruled non-normative. A mid-Block spec change re-queues this loop as a backward feedback edge (see the `spec-conformance` Block) — the re-scan appends new/changed clauses as fresh `loops[]` entries and retires deleted clauses' entries, same generator step. Chains into the `spec-conformance` Block.

## Design Doc Alignment
Goal: Align project design docs with current implementation; continue until satisfied with consistency.
Checkpoint: After each significant update: review running system, reconcile designs with observed behavior, run autoreview, commit.
Stop: A full pass finds no new drift — list any drift you chose to leave.
Track: tmp/design-sync-{project}.md

## Doc Sweep
Goal: Scan codebase; align all docs with current implementation. Update stale sections, verify accuracy against code, open a pull request.
Checkpoint: After each doc/section reconciled: verify the claim against the live code, run autoreview, commit.
Stop: A full scan surfaces no stale section — note any deferred.
Track: tmp/docs-{project}.md

## Refine the Threat Model
Goal: Refine threat model. Define assumptions, assets, and attack surfaces explicitly.
Checkpoint: After each significant update: research open questions (use the repo's own research command if it has one, else the `deep-research` skill / web search), close identified gaps, oracle review.
Stop: A full pass over the current system surfaces no new assumption, asset, or attack surface, and every one already listed has a stated mitigation or an accepted-risk note. Give-up bound: 3 straight passes add nothing — report the model as current and list any open questions.
Track: tmp/threatmodel-{project}.md

## The Test-Suite Speed Loop
Goal: Optimize test suite runtime to be as fast as possible. Constraints: no coverage reduction, no behavior change.
Checkpoint: After each optimization: run the full suite (confirm same pass set — no behavior change), record the wall-clock delta, run autoreview, commit.
Stop: A full pass finds no change yielding a measurable speedup within the constraints. Give-up bound: 3 straight passes each land under a ~2% improvement — report the suite as optimized and list any speedups that would need a coverage or behavior trade-off (out of scope here).
Track: tmp/testspeed-{project}.md

## Loop Authoring Loop
Goal: Design a new Loop or Block for a target project/workflow. Before drafting: verify ground truth (git log, actual current task/doc files, actual test/build state) against the live repo — never draft from a wiki, memory, or design doc alone. State what was checked and when.
Checkpoint: After drafting: independent quality review pass (different agent/model than the author — redundancy, unenforceable Stops, undefined verbs, missing fields), apply fixes. Independent gap review pass (chaining/driver-protocol edge cases, missing loop types, what breaks in practice — not wording), apply fixes.
Stop: Both review passes return no new findings, ground truth is re-checked immediately before Stop (confirms nothing drifted since step 1), and the Loop/Block is written into its home file with Track path populated.
Track: tmp/loop-authoring-{target}.md
Extras: If the target project already has its own loop/pipeline infrastructure, check for collision before drafting — extend or wire into the existing system rather than building a parallel one (see `blocks.md` → Git Convention's one-actively-driven-Block rule + Roster). Reviewer should differ from the author when possible — fresh eyes catch what the author missed.

## Campaign Loop
Goal: Drive a target project toward its campaign Stop by repeated orchestration ticks. One tick = ground-truth delta check → mapping delta-update (`tmp/mapping-{project}.md`) → roster rebuild → drive the roster to exhaustion or budget → process standing queues (un-ratified provisional verdicts, decision-card auto-adopts, model-roster staleness, and — cron mode only, never without an explicit owner ask per `blocks.md` → Execution-mode status — watchdog re-arm). Outer loop wrapping ground truth → map → roster → drive → process into a tick; repeats until `campaign_stop` is met, every mapped avenue is hard-blocked, or budget is exhausted (2026-07-17).
Checkpoint: After each tick, append a tick record to the campaign file: date, ground-truth delta summary (what changed since last tick), Blocks advanced/completed/authored, queue actions taken, cost line (`cost: ~wall / ~tokens / units`), next-tick intent (one line, same role as `next_hint`). Tick records drive recovery re-prompts (Watchdog campaign-stalled strike 1); stale intent misdirects recovery like a stale `next_hint`.
Stop: `campaign_stop` predicate verified true against live repo state (ground-truth check on Stop condition), OR every mapped avenue is hard-blocked with all `blocked_reason`s surfaced in one terminal report, OR campaign budget bound is exhausted, OR no-progress bound reached: 3 consecutive ticks with zero ground-truth delta AND no measurable campaign_stop progress (tick records show no Blocks advanced/completed/authored or queue actions taken, only stagnation) — park the campaign, surface to human with the reasoning (mirrors the library's 3-pass give-up convention). Each terminal is reported explicitly — which one fired and the evidence.
Track: tmp/campaign-{project}.md (in the TARGET repo, not phil repo — ledgers live alongside their projects, `blocks.md` → State File Schema).
Extras: (a) Tick source is EXTERNAL — human invocation or owner-armed scheduled task; this loop defines what a tick does, not self-scheduling. Crons currently unarmed (`blocks.md` → Execution-mode status). (b) Campaign file is the fifth standing-duty surface — a phil activation finding an existing `tmp/campaign-{project}.md` resumes it as a tick rather than running a bare one-pass activation. (c) Authoring the next Block from the standing mapping during a tick is sanctioned continuation (blocks.md → Driver Protocol step 9 amendment); review passes still mandatory. The no-progress bound (3 consecutive ticks with zero delta + no progress) applies to continuation cycles as well — reaching it surfaces the campaign for human decision before looping forever on an unreachable Stop. Work OUTSIDE mapping/campaign scope remains human-only design shift. (d) Campaign never overrides narrow bar, `human_gates` semantics, or contradiction check (`blocks.md` → Default posture, Emulated gates).

---
