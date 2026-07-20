# Product Pipeline and Build/Validate Loops

## Product Pipeline

Phase pipeline for product projects: Plan -> Build -> Validate -> Harden -> Certify, plus a Continuous lane. Same Goal/Checkpoint/Stop/Track/Extras fields. The category-specific loops below are supplemented by generic loops in [`loops-core.md`](loops-core.md) and UX/validation loops in [`loops-ux.md`](loops-ux.md).

**Pre-Validate gate**: for a greenfield or core-loop-unproven project, skip straight to the Vertical Slice Build Loop (below) before touching Plan/Build. Don't generate content at quota or design further until it passes. (A prior project's `core-loop-gate` Block was the original instance of this shape - now archived STALE in `archive/blocks-2026-07.md`; the gate is the Vertical Slice Build Loop itself, not that dead Block.)

### Phase Membership
- **Pre-Validate** (unproven core loop only): Vertical Slice Build Loop
- **Plan**: Planning Loop, Feature Audition Loop
- **Build**: Content Pipeline Loop, UI Design Loop ([`loops-ux.md`](loops-ux.md))
- **Validate**: Calibration / Tuning Loop, Mechanical Sweep Loop, Simulated User Pass, User Test, Polish / Feel Loop, Visual Inspection Loop, Onboarding / First-Session Loop (the interaction loops are defined in [`loops-ux.md`](loops-ux.md))
- **Harden**: Triage Loop, Fix Bugs From a Log, Regression Soak Loop, Save/Load Integrity Loop, Network Sync Loop, Performance / Profiling Loop, Accessibility Pass Loop, Localization Loop, Determinism / Replay Fidelity Loop, Progression Integrity Loop, Failure-Recovery Loop, Asset and Data Integrity Loop, Input and Control Compatibility Loop, Observability Contract Loop, Compatibility Matrix Loop, Dependency and Clean-Build Reproducibility Loop, Abuse and Boundary-Case Loop
- **Certify**: Release Certification Loop
- **Continuous** (parallel, ungated, no completion event): Design Doc Alignment, Doc Sweep, The Test-Suite Speed Loop, Refine the Threat Model (defined in [`loops-core.md`](loops-core.md))

### Chaining Rules
- A loop's Track ledger is the hand-off artifact: downstream Goal references it directly.
- Phase gates, sequential fan-out/fan-in: Pre-Validate → Plan → Build → Validate → Harden → Certify.
- A Build-phase block for a new user-facing feature gates on that feature's Feature Audition Loop verdict existing (provisional PASS or human override) — see Feature Audition Loop below (2026-07-16). Extending an existing feature needs no audition unless it changes the core user verb.
- Forward feedback: Validate → Build ("tune & re-iterate") when Calibration/User Test surface content gaps.
- Backward feedback: Harden → Validate — any Harden-phase code change (soak fix, perf fix, network fix) triggers a re-run of Calibration Loop and User Test before Certify, since Harden fixes can shift balance/feel. Cap at 3 bounces — beyond that, set `status: blocked` with `blocked_reason: "feedback-edge iteration cap reached"` and stop, rather than looping forever (Driver Protocol step 7 makes this state write mandatory). That reason string is what lets the Watchdog, in cron mode, tell a capped-out loop apart from an ordinary block awaiting human input (Watchdog Loop is defined in `cron-mode.md`).
- Validate-phase ledgers route through Triage Loop before Fix Bugs From a Log — taste ledgers (like/dislike notes, coverage gaps) aren't bug-log format, Triage converts them.
- Mechanical Sweep Loop runs before Simulated User Pass as a cheaper filter, not a substitute — catches the DOM/event-state bug class (focus traps, toggle-state mismatches, swallowed input, dialog tab-order) deterministically before spending an LLM roleplay pass's budget on it. Simulated User Pass runs before User Test as a cheap filter, not a substitute — User Test's human_gate still runs (emulated per Emulated gates, never silently skipped) regardless of how clean the roleplay pass comes back.
- Rung attribution (2026-07-16): expensive loops never re-discover what a cheaper rung could catch — rung attribution turns each such finding into permanent cheap-rung coverage (see Mechanical Sweep Loop Extras for the origin observation and rationale).
- Accessibility Pass Loop + Localization Loop gated behind UI Design Loop's own Stop firing, not a vague "stabilizes."

### Vertical Slice Build Loop
Goal: Build the smallest usable slice that proves the core loop — a caller-supplied checklist of concrete, demoable actions (e.g. "move, pick up item, operate machine, produce output, resource decay"). No content pipeline, no polish, no abstraction beyond what each checklist item needs.
Checkpoint: After each checklist item becomes demoable: capture evidence (video/screenshot/log), commit.
Stop: Every checklist item is demoable with captured evidence.
Track: tmp/slice-{project}.md
Extras: Supersedes Content Pipeline Loop and Planning Loop at pre-validation stage — don't generate content at quota or design further until the slice proves the loop is worth building on.

### Feature Audition Loop (2026-07-16)
Goal: Before any Build-phase work starts on a new user-facing feature, produce (a) a 1-page user-experience note — what the user does, moment-to-moment, and why it's fun, written in the voice of an end user, not as canon-elegance — and (b) a throwaway runnable stub of the feature, hard-capped at one session's build effort, explicitly disposable (no production code paths, no tests, no polish).
Checkpoint: After the stub is runnable: run an emulated end-user verdict per `blocks.md` → Emulated gates (fresh-context frontier-tier persona plays the stub and answers "would I keep using this feature?"), record `verdict: provisional: ...` in the ledger, one-line heads-up to the human, proceed.
Stop: Verdict recorded (pass or fail). A provisional PASS lets the feature proceed to Build. A provisional FAIL queues the audition as a backward feedback edge: driver iterates autonomously (redesign → re-stub → re-emulate, same loop, same driver, no pause). Build-phase block for the feature does not open until a PASS is recorded or human override reaches the field. Human ratifies/overrides async per Emulated gates. Cap: after 3 failed audition iterations, set `status: blocked` with `blocked_reason: "feature fails audition"` and surface to human (matches the file's existing cap-3 convention).
Track: tmp/audition-{feature}-{project}.md
Extras: Exists because a fully-built feature was owner-rejected after the fact (COHERE count/loop, 2026-07-12 — "grade as an end user, not on canon-elegance"; the full rebuild cost 2–3 days, an audition costs hours). Distinct from Vertical Slice Build Loop: that proves a greenfield core loop once; this auditions each new feature thereafter. Boundary: extending an existing feature (UI polish, parameter tuning, a new upgrade tier) needs no audition unless the change adds or renames the core user verb.

### Content Pipeline Loop
Goal: Generate/import content units (records, entities, templates, assets) per design doc until content quota met.
Checkpoint: After each batch: validate against design doc, run autoreview, commit.
Stop: Content quota per design doc fully met.
Track: tmp/content-{project}.md
Extras: Chains from Planning Loop (design doc). Feeds User Test, Visual Inspection Loop.

### Calibration / Tuning Loop
Goal: Adjust numeric knobs (rates, thresholds, weights, pricing/difficulty curves, model or heuristic parameters) until target metric band is hit.
Checkpoint: After each adjustment: run bot-sim or telemetry replay, record metric, commit.
Stop: Metrics land in target band for [N] consecutive runs.
Track: tmp/calibration-{project}.md
Extras: Ground-truth loop. Covers automated-behavior tuning as an example knob — no separate loop needed. Chains from Content Pipeline. Feeds User Test; re-seeds Content Pipeline next iteration. Level-scoped user testing is just User Test run per-level.

