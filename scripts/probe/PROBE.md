# Fresh-Driver Probe

Semantic regression test for the Driver Protocol. The linter (`scripts/lint-phil.sh`)
catches mechanical defects (broken pointers, missing fields, jargon); this catches
what only a literal execution reveals — a step that *reads* fine but *runs* wrong.
It exists because the 2026-07 review found a shipped BLOCKER (step 2's blocked-halt
was dead code) that two prose reviews missed and a single fresh execution caught.

## How it works

Give a **cheap, fresh-context** agent only: `loops.md`, `blocks.md`, and one
fixture state file. Ask it to execute one Driver Protocol pass as the driver and
report the action it would take. Diff that action against the fixture's expected
answer. A mismatch = a protocol regression.

Fresh context is the whole point — no memory of this conversation, no knowledge of
the expected answer. A cheap model (small tier per models.md) is deliberate: if the protocol is
only operable by a strong model, it's under-specified.

## Run it

Dispatch an agent (the runtime's delegate capability at small tier — e.g. `model: haiku`) with this prompt,
substituting the fixture path:

> You are a fresh phil driver with no prior context. Read `loops.md`, `blocks.md`
> (Driver Protocol section), and the block state file at
> `scripts/probe/<fixture>.md`. Execute exactly ONE Driver Protocol pass from
> step 2. Report in ≤5 lines: (a) which loop you act on, (b) what you do to it
> (activate / halt / re-verify / drain), (c) the resulting `status` of every loop.
> Do not do any real work — just state the protocol action.

Then assert the answer against the fixture's expected block below.

## Fixtures + expected answers

### `fixture-blocked-halt.md` — the step-2 blocker regression
Loops: `Fix Bugs`=done, `Test Coverage`=**blocked**, `Doc Sweep`=pending.

**PASS** = the driver **halts on `Test Coverage`** and surfaces its `blocked_reason`;
takes **no** action on `Doc Sweep`; all statuses unchanged.

**FAIL (regression)** = the driver activates `Doc Sweep` (or any pending loop) —
this means step 2 scanned the `active` slot, missed the `blocked` loop (which is
`blocked`, not `active`), fell through to "first pending", and drove the chain
**past** an unmet precondition. That is exactly the dead-code halt the fix closed.

Assertion (grep the agent's answer): contains "halt"/"blocked"/"Test Coverage" AND
does NOT contain "activate Doc Sweep" / "set Doc Sweep active".

## Adding fixtures

One fixture per protocol invariant a bug could regress. Candidates the reviews
surfaced, not yet covered — add when a regression in them would be expensive:
- `feedback_pending` drain: a queued re-run loop is picked up before new pending
  loops, exactly once, and the Block can't close while the queue is non-empty.
- roster blocked-entry reset: a re-tested-passing entry resets the loop's
  state-file `status: blocked -> pending`, so the next drive resumes it.
- spec-conformance gate: a `needs-human` clause does not deadlock the gate.

Keep each fixture a valid state file per `blocks.md` → State File Schema so a fresh
driver operates it with no special-casing — that fidelity is the test.
