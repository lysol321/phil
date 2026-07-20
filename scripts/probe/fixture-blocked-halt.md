block: probe-blocked-halt
phase: null
branch: block/probe-blocked-halt
touches: [src/probe/**]
cron_job_id: null
cadence: 30m
next: ask
loops:
  - name: Fix Bugs From a Log
    status: done
    ledger: tmp/bugfix-probe.md
    pre_check: "bug log exists at tmp/bugs-probe.md"
    evidence: {path: abc1234, verify: "git cat-file -e abc1234 && pnpm test passes"}
    iterations: 0
    verify_failures: 0
    blocked_reason: null
    next_hint: done
  - name: Test Coverage Loop
    status: blocked
    ledger: tmp/coverage-probe.md
    pre_check: "the module under test exists at src/probe/target.ts"
    evidence: {path: null, verify: "diff coverage == 100%"}
    iterations: 0
    verify_failures: 0
    blocked_reason: "src/probe/target.ts does not exist yet — pre_check failed, blocked on landing the module first"
    next_hint: "stuck: target module absent"
  - name: Doc Sweep
    status: pending
    ledger: tmp/docs-probe.md
    pre_check: "docs dir exists"
    evidence: {path: null, verify: "no stale section"}
    iterations: 0
    verify_failures: 0
    blocked_reason: null
    next_hint: null
feedback_pending: []
human_gates: []
authority: code
updated: 2026-07-17T00:00:00Z
