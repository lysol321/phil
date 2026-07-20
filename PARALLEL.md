# Parallel Blocks on One Repo — Design Record

> **STATUS: Phase 0 is now live doctrine** (`blocks.md` → Parallel Mode); Phases
> 1–3 below remain design-only. Default is still sequential — parallel mode is
> opt-in (`roster mode: parallel`) and fail-closed, so nothing changes unless a
> repo qualifies and the owner enables it. This file is the full design of
> record; `blocks.md` → Parallel Mode is the operable Phase-0 subset. A fresh
> phil activation executes `blocks.md`, not this file — treat §2 mechanisms
> beyond Phase 0 (M5 cap formula, M7 manifest, §3 repo contract) as not-yet-built.
>
> Origin: frontier-tier design pass, grounded in `blocks.md`, `execution.md`,
> `PORTABILITY.md`, `loops.md`. Ship path in §6; Phase 0 shipped in blocks.md.

## The problem, and the sharp finding

Today: "One Block actively driven at a time per repo"; the Roster opens up to 3
path-disjoint Blocks but drives them one at a time. Two documented blockers:
git **index races** and **verify-suite contention** (both scarred into the Tree
lease after real incidents).

The finding that unlocks this: **the index race was never the real problem.**
Per-Block isolation worktrees already give each driver its own git index. The
observed corruption (`core.bare` flips, branch renames) was **repo-level shared
state written from inside a worktree** — `git config`, `gc`, `pack-refs`,
cross-branch ops. Ban those and per-worktree isolation is genuinely safe.

## 1. Recommended architecture

Every roster Block runs in its own **worktree cell** — own branch, own index —
driven by exactly one agent holding a **driver lease**. The primary checkout is
**quiesced off `main`** (bare, or parked detached) and becomes shared
infrastructure no driver writes except through two narrow serialized doors: a
**roster lease** (scheduler-state) and an **integration lease + ref-CAS**
(advancing `main`). Edit/commit/build/red-green is fully parallel; verify runs
parallel only when the target repo declares+certifies a slot-parameterized verify
contract, else serializes under a **verify lease** (fail-closed). Merge order is
**fixed at roster-build time** (wave order), so the merged tree is a function of
branch contents + a recorded order, never of runtime timing. Shared files are
handled by a three-class manifest with **no textual merge, ever**. Every new
primitive reuses the existing tree-lease JSON shape; every rule is a
shell-checkable predicate a fresh driver runs from the state file alone; every
uncovered case reverts mechanically to today's sequential mode.

## 2. Mechanism set

All leases reuse the tree-lease shape `{holder, purpose, expires}` — one
primitive, four named instances; expiry/refresh reuse the existing ~2×-checkpoint
rule. All state-file writes gain **temp-file-then-rename** (atomic on both hosts)
so a crash mid-checkpoint can't leave a half-written file.

**M1 — Per-Block cell.** Parallel mode requires `worktree:` populated on every
roster Block (worktree-first creation, Driver Protocol step 1) and the primary
**not on `main`**. Checkable: `git worktree list` shows no checkout of `main` —
so `main` is advanceable by `git update-ref` without desyncing any working copy.

**M2 — Git-op denylist (kills the residual shared-state incidents).** A Block
driver may never: `git config` (write), `git branch -m/-d` on another branch,
`git worktree add/remove/prune` (except its own step-1 create), `git
gc/prune/maintenance`, `git stash`, `git pack-refs`, any `fetch`/`push`. Network
ops + gc are integrator-lease-only (gc only when zero driver leases live).
Auto-gc disabled once at parallel-mode entry (`gc.auto=0`) by the scheduler under
roster lease. What worktrees share and whether it's safe:

| Shared state | Safe under N drivers? |
|---|---|
| index / HEAD / MERGE_HEAD | per-worktree — **index race dead** |
| object store `.git/objects` | yes — content-addressed, atomic; only unsafe under concurrent gc → M2 bans it |
| per-branch refs | yes **by partition** — one branch per Block, one writer |
| packed-refs | safe if pack-refs/gc banned (M2) |
| `.git/config` incl. `core.bare` | unsafe if written → M2 bans writes; reads fine |
| hooks (`core.hooksPath`) | safe if hooks write only inside the invoking worktree (repo-contract C4) |
| remote-tracking refs / stash | contended → integrator-only / banned (M2) |
| submodule gitdirs `.git/modules/` | **not safe** → fail-closed sequential (L3) |

**M3 — Driver lease (anti-double-drive).** New state field `driver: {id,
expires}`. A driver executes Driver Protocol steps only while holding it;
refreshes it in every checkpoint write (piggybacks step 5). Claim/release happen
**only under the roster lease**, so two agents can never both claim one Block.
Fresh-driver rule: live foreign driver lease → don't touch, pick another entry;
expired → claim under roster lease, note takeover in ledger. Watchdog gains one
signal: `active` + expired driver lease + stale `updated` → existing recovery
ladder.

**M4 — Roster lease + roster-as-scheduler.** `tmp/roster-lease.json`; all
scheduler mutations (claim/release/rotate/rebuild/edit merge_order) happen under
it, held for seconds. Roster file gains `mode: parallel|sequential`, `wave:`,
`merge_order: [names, fixed at build]`, per-entry `slot:` + `driver:`.
**Crash-reconstruction determinism:** "what's running" = the set of entries with
live driver leases, read under the roster lease — never inferred from process
state or timestamps.

**M5 — Parallel cap, mechanical.** `N = min(3, repo max_parallel_verify,
count of path-disjoint claimables)`. Slots assigned at roster build in
merge_order order, recorded per state file; slot number derives ports/DB names
(C2). No judgment call.

**M6 — Verify modes, fail-closed.** Field `verify_mode:
parallel-certified | lease | sequential`, set by repo-contract detection (§3).
`lease`: `tmp/verify-lease.json` serializes verify-class runs across worktrees;
builds stay parallel. `parallel-certified`: each Block runs verify with its slot
injected — no lease. **Evidence rule (closes the retry-masking hole):** every
verify evidence records its mode; evidence produced while a foreign verify lease
was live (in `lease` mode) is **invalid** — step 3 rejects it rather than
retrying it green.

**M7 — Shared-file manifest, three classes, no textual merge.** Repo contract
(C3) declares every legitimately-shared file with one policy:
- **fragment** — append-class (CHANGELOG, list-registries). Blocks never edit the
  file; each writes `changelog.d/<block>.md` (towncrier) in its own scope;
  integration assembles fragments in merge_order. Pure function of fragments +
  order.
- **regen** — generated (lockfiles, type barrels, codegen) with a declared
  deterministic regen command. Blocks may edit on their branch (own worktree, no
  race); integration discards the branch version and re-runs regen on the rebased
  tree. Function of merged source, not merge text order.
- **forbidden** — hand-edited non-regenerable hotspots. Any file not in the
  manifest appearing in ≥2 wave Blocks' **realized diffs** (`git diff
  --name-only merge-base..HEAD` — ground truth, not the declared `touches:`) is a
  partition violation: the later Block in merge_order gets an appended conflict
  loop (M8) and is skipped this pass; the pair thereafter serializes.

**M8 — Integration protocol (Driver Protocol step 8.5, when a Block's loops are
all done).** Fixed wave order; each Block self-merges under the integration lease
(no dedicated integrator Block — self-merge + CAS + fixed order is single-writer-
main with less machinery). Each step checkable:
1. **Order gate:** proceed only if every earlier merge_order Block is `landed` or
   `skipped-recorded`. Else park `done-pending-integration`; rotation continues.
2. Acquire `tmp/integration-lease.json`.
3. **Idempotence first:** `git merge-base --is-ancestor <branch-head> main` →
   already landed (post-crash) → mark landed, release, done.
4. Rebase the Block branch onto `main` in the Block's own worktree.
5. **Conflict → work item, never in-lease resolution:** abort rebase, release
   lease immediately, append an `Integration-Conflict` loop (full schema;
   `pre_check` = "rebase onto current main applies clean", `blocked_reason` =
   conflicting paths + two SHAs). Roster records `skipped: conflict`. Resolved
   off-lease by the Block's own driver, then re-enter at step 1.
6. Clean rebase → apply M7 (assemble fragments, run regens, commit).
7. Run verify on the rebased tree — authoritative pre-merge verify, serialized by
   the integration lease regardless of verify_mode (main-bound evidence never
   under contention).
8. Green → advance main by **CAS**: `git update-ref refs/heads/main <new>
   <expected-old>`. Fails if main moved → clean retry from step 1. Lease =
   liveness, CAS = safety; a lease bug can't lose an update, only fail-retry.
9. Write evidence (main SHA before/after, verify path, mode), mark `landed` under
   roster lease, release integration lease.

**M9 — State-schema additions (complete).** Per Block: `driver: {id, expires}`,
`slot: <int>`, `integration: pending|landed|skipped-conflict` (worktree already
exists). Roster: `mode`, `wave`, `merge_order`, per-entry `slot`/`driver`.
Campaign: `verify_mode`, `owner_host` (L5). Nothing else — every rule above is a
predicate over these fields + cheap git commands, preserving fresh-driver
operability.

## 3. Target-repo contract (qualification + fail-closed)

A repo qualifies for `parallel-certified` verify only by **declaration +
certification** — never by phil inferring isolation from reading code.

**Declaration** — owner-authored, committed `.phil-parallel.yml`:
- **C1** `verify_cmd:` + assertion it accepts a slot.
- **C2** `slot_env:` (e.g. `PHIL_SLOT=n`) from which verify derives *every* global
  resource (ports `base+100·n`, DB `app_test_n`, scratch under the worktree),
  plus `max_parallel_verify: k`.
- **C3** `shared_files:` the M7 manifest — `{glob, policy: fragment|regen,
  regen_cmd?}`, regen commands required byte-deterministic.
- **C4** owner-attested invariants: verify writes nothing outside worktree +
  slot scratch; no fixed ports; no shared dev-server; hooks write only in the
  invoking worktree; no submodules in verify-covered paths.

**Certification** — a one-time `verify-isolation-cert` Block (new reusable
template): run `max_parallel_verify` concurrent verifies at one SHA, R times, all
green, then diff vs a solo run. Record the certified SHA + a **hash of the
verify-defining files**. Every parallel roster build re-hashes; mismatch → cert
stale → drop to `lease` until re-certified. "Does the repo still qualify" = a
hash compare, not a judgment.

**Fail-closed ladder (at roster build):**
1. No `.phil-parallel.yml` → `lease` (builds parallel, verify serial — universal default).
2. Declaration present, cert absent/stale → `lease` + a claimable `verify-isolation-cert` Block.
3. Declaration + fresh cert → `parallel-certified`.
4. Submodules, or primary can't quiesce off `main`, or not a normal writable git repo → `sequential` (today's system).

The asymmetry is the point: the owner *asserts* isolation (once, committed,
reviewable), phil *verifies* it empirically once, then *checks* it by hash.

## 4. Determinism invariants

- **I1 Partition:** for two wave Blocks, `diff(base..A) ∩ diff(base..B) ⊆ manifest`. Declared via `touches:`, **verified against realized diffs at integration**; violation → M7 serialize, never a merge.
- **I2 Single writer per ref:** `block/X` written only by X's driver-lease holder; `main` only by the integration-lease holder via CAS; all other shared git state read-only to drivers (M2).
- **I3 Single driver per Block:** ≤1 live driver lease per state file (claimed under roster lease). "What's running" = live-lease set → post-crash double-driving is structurally impossible.
- **I4 Merge determinism:** `tree(main_final) = F(branch trees, merge_order, fragment set, regen commands)` — a pure function; timing appears nowhere.
- **I5 Evidence validity:** every verify evidence records its mode; contended-mode evidence is inadmissible and rejected at step-3 re-verify. No race maskable by retry.
- **I6 Fresh-driver operability:** every rule is a predicate over (state file + roster + lease files + ≤4 cheap git commands). A cold agent resumes any Block or the whole wave from files alone.
- **I7 Crash containment:** each Block's mutable surface = {its worktree, branch, state file+ledgers, slot scratch, held leases} — pairwise disjoint; leases expire by time; writes atomic. Block failure can't corrupt another's surface.
- **I8 Idempotent integration:** the ancestor check makes every integration re-run a no-op or clean retry; main advances exactly once per Block (CAS); a crash anywhere in M8 is resumable from files.

## 5. Honest limits + fail-closed

- **L1 Agent output isn't deterministic.** Commit *content* is LLM-produced; "same inputs → same commits" is not claimed. Deterministic: the partition, schedule, merge function, and replayability of every decision from the record. That's the achievable bar and what phil's ethos actually requires.
- **L2 Completion timing is nondeterministic; skips are runtime facts.** Fixed merge_order removes timing from the merge *result* at the cost of head-of-line waiting; a skip is mechanically derived and durably recorded, so the tree is deterministic *given the recorded skip set*.
- **L3 Submodules** → fail-closed `sequential` (shared `.git/modules`, genuinely unsafe).
- **L4 Un-sliceable verify** (one rig, a licensed service, a fixed endpoint, wall-clock-coupled tests) → stays `lease` forever; throughput caps at the verify duty cycle. Named, not hidden.
- **L5 One host per wave.** Leases are files in the target repo; the hosts hold separate clones + registries, so no lease spans them. Campaign gains `owner_host:`; a wave runs entirely on one host; the other doesn't open Blocks on that project while `owner_host` is set. Cross-host parallelism via the remote is a separate design, out of scope.
- **L6 Crons unarmed (inline-only).** N parallel drivers today = N inline contexts (subagent fan-out or N owner-started sessions). Design is driver-source-agnostic (leases don't care who holds them); "scheduler spawns N crons" is dormant until crons are re-armed. Ship inline-first.
- **L7 gc deferral:** store grows during a wave; gc only under integration lease with zero live driver leases. Cost, not correctness.
- **L8 Windows:** `git worktree remove` stays banned (fragile); worktrees pruned manually. Per-worktree installs are the price of C4 isolation — pnpm's content-addressed store makes this cheap and its store locking is concurrency-safe.

## 6. Incremental ship path

- **Phase 0 — genuinely parallel, safe, zero repo cooperation:** 2-Block waves, `verify_mode: lease`. Adds M1 (quiesced primary — the existing bare-primary pattern), M2 denylist (promotes incident lessons to hard rules), M3 driver lease, M4 roster lease + merge_order, M6 verify lease (renames the tree lease's existing verify-mutex half), M8 integration + CAS, atomic state writes. Phase-0 shared-file rule is the brutal version: any shared-file overlap → serialize the pair (no manifest yet). Already true parallelism — the whole edit/commit/build/red-green cycle overlaps; only verify + integration serialize. Every Phase-0 primitive is load-bearing later.
- **Phase 1:** M7 manifest (fragment + regen) — unlocks lockfile-touching Blocks in one wave; CHANGELOG → fragments.
- **Phase 2:** repo contract + `verify-isolation-cert` Block → `parallel-certified` verify + the M5 cap formula. Where wall-clock throughput actually multiplies; opt-in per repo.
- **Phase 3:** Watchdog driver-lease signal, campaign wave accounting, raise N only if evidence shows the 3-cap binding.

Through-line: every fork resolved toward the option whose correctness is a *file
read plus a cheap command* rather than a judgment — fixed order over completion
order, declaration+cert over inference, regeneration over merge, CAS over
trust-the-lease, fail-closed to sequential over degrade-and-hope. The same bet
`blocks.md` already makes everywhere, extended to N.
