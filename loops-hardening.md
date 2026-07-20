# Hardening, Compatibility, and Release Loops

These loops live after Validate in the Product Pipeline. They turn a working build into a recoverable, observable, compatible, and releasable one.

## Performance / Profiling Loop
Goal: Optimize until frame-time/FPS budget is hit on target hardware. No behavior change.
Checkpoint: After each optimization: profile on target hardware, run regression suite, commit.
Stop: Frame-time/FPS budget met on all target hardware tiers.
Track: tmp/perf-{project}.md
Extras: Ground-truth, terminal — lives in Harden, not Continuous (a loop with no completion event can't gate Certify). Gates Release Certification directly.

## Triage Loop
See **Triage Loop** in [`loops-core.md`](loops-core.md) — same loop, scoped here to a fixed ledger set: User Test, Calibration, Visual Inspection, Polish/Feel.
Track: tmp/triage-{project}.md
Extras: Feeds Fix Bugs From a Log.

## Regression Soak Loop
Goal: Run long automated replay/bot sessions to catch crash/desync bugs.
Checkpoint: After each soak run: log any crash/desync with repro, file to Triage, commit.
Stop: Zero crash/desync over N consecutive hours of soak.
Track: tmp/soak-{project}.md
Extras: Ground-truth. Feeds Triage Loop (not Fix Bugs directly).

## Save/Load Integrity Loop
Goal: Fuzz save/load across N save-format generations until no corruption.
Checkpoint: After each fuzz batch: log any corruption with repro, fix, commit.
Stop: Zero corruption across N format generations.
Track: tmp/saveload-{project}.md
Extras: Ground-truth.

## Network Sync Loop
Goal: Simulate latency/packet-loss profiles until desync rate is under threshold.
Checkpoint: After each profile run: log desync events, fix root cause, commit.
Stop: Desync rate under threshold across all simulated profiles.
Track: tmp/netsync-{project}.md
Extras: Ground-truth. Multiuser-only.

## Accessibility Pass Loop
Goal: Iterate until accessibility checklist (colorblind modes, remappable controls, captions, contrast) passes.
Checkpoint: After each fix: re-check against checklist item, commit.
Stop: Full checklist passes.
Track: tmp/a11y-{project}.md
Extras: Gate — start only after UI Design Loop's own Stop has fired (3 straight passes changed nothing defensible), to avoid rework churn.

## Localization Loop
Goal: Translate every string; verify no UI overflow in any target locale.
Checkpoint: After each locale batch: verify translation + UI fit, commit.
Stop: All locales translated, no overflow in any.
Track: tmp/loc-{project}.md
Extras: Same UI-stabilization gate as Accessibility Pass Loop.

## Release Certification Loop
Goal: Iterate until the LOCAL cert checklist (store/platform certification checklist requirements) fully passes.
Checkpoint: After each cert item addressed: re-check against checklist, commit.
Stop: Full local checklist passes — flag for human submission. (Actual platform submission/approval is an external human action, not agent-runnable; this loop covers everything on the agent's side of that line.)
Track: tmp/cert-{project}.md
Extras: Terminal fan-in gate — depends on Regression Soak clean, Performance/Profiling passed, Accessibility + Localization complete, Save/Load integrity clean.

---

## Determinism / Replay Fidelity Loop
Goal: Run the same seed, input sequence, and starting state across repeated runs and supported environments. Compare state hashes and important outputs.
Checkpoint: After each mismatch, capture the earliest divergent tick, minimize the input sequence, fix the root cause, and add a permanent replay fixture.
Stop: All required replay fixtures produce identical hashes and outputs across N consecutive runs on every target environment.
Track: tmp/determinism-{project}.md
Extras: Distinct from Regression Soak, which catches long-run crashes and desyncs, and Network Sync, which targets multi-client divergence. This loop catches nondeterminism in single-user and simulation paths too.

## Progression Integrity Loop
Goal: Verify that every user progression path works from a clean profile through unlocks, upgrades, milestones, and completion states.
Checkpoint: After each path tested, record reachable states, unlock prerequisites, save point, and whether the user can continue after reload.
Stop: Every progression path is reachable, every intended unlock is obtainable when specified, and no path produces a dead-end state, impossible prerequisite, duplicate reward, or unreachable end state.
Track: tmp/progression-{project}.md
Extras: Calibration/Tuning changes values; Save/Load checks persistence. This loop checks the graph of user progression and its reachable states.

## Failure-Recovery Loop
Goal: Interrupt the application at meaningful points — during save, loading, transition, asset streaming, network reconnect, or background work — and verify safe recovery.
Checkpoint: After each interruption case, record the interruption point, recovery result, data loss, duplicate side effects, and user-visible state.
Stop: Every defined interruption case either resumes correctly or fails into an explicitly safe and recoverable state, with zero corruption and zero unrecoverable dead-end states.
Track: tmp/recovery-{project}.md
Extras: Save/Load Integrity fuzzes data formats. This loop tests process and environment failure at the worst possible moment.

## Asset and Data Integrity Loop
Goal: Validate every shipped asset, data row, reference, schema, identifier, localization key, and generated artifact before it reaches a working build.
Checkpoint: After each asset/data batch, run reference validation, duplicate detection, schema validation, missing-resource checks, and size/type checks.
Stop: Zero missing references, invalid schemas, orphaned required assets, duplicate identifiers, broken generated artifacts, or unreviewed placeholder data remain.
Track: tmp/assets-{project}.md
Extras: Content Pipeline creates or imports content. This is the deterministic quality gate that prevents bad content from entering the build.

## Input and Control Compatibility Loop
Goal: Verify every user action using all supported control schemes: keyboard/mouse, controller, rebinding, alternate layouts, and navigation-only input where applicable.
Checkpoint: After each action tested, record reachability, conflict status, focus behavior, feedback, and whether the action remains usable after rebinding.
Stop: Every required action is reachable through every supported scheme, all bindings are conflict-resolved or explicitly documented, and no control path creates a dead end.
Track: tmp/controls-{project}.md
Extras: Accessibility Pass checks broader accessibility requirements; Mechanical Sweep checks interaction invariants. This loop checks action coverage across devices and mappings.

## Observability Contract Loop
Goal: Ensure critical user actions, state transitions, failures, performance markers, and gate metrics emit the telemetry or logs needed to diagnose them.
Checkpoint: For each critical event, trigger it in a real run and verify the event name, required fields, timestamp/order, correlation ID, and redaction behavior.
Stop: Every critical event has a verified producer, consumer or sink, schema, and diagnostic query; no required event is missing or ambiguous.
Track: tmp/observability-{project}.md
Extras: Threat Model defines risks and Watchdog checks Block health. This loop verifies that the running product produces useful evidence when something goes wrong.

## Compatibility Matrix Loop
Goal: Exercise the build across the declared OS, browser, hardware, resolution, graphics, input, and runtime matrix.
Checkpoint: After each environment, record install, launch, core action, rendering, save/load, performance, and exit results.
Stop: Every required matrix cell passes its smoke checklist, or every excluded cell has an explicit documented reason.
Track: tmp/compat-{project}.md
Extras: Performance tests budgets and Accessibility/Localization test specific qualities. This loop tests whether the product works at all in each supported environment.

## Dependency and Clean-Build Reproducibility Loop
Goal: Prove that a clean checkout can install, build, test, package, and launch without hidden local state.
Checkpoint: After each clean environment or dependency change, record lockfile state, install command, build artifact hash, test result, and runtime launch result.
Stop: Two clean builds from the same revision produce equivalent artifacts and both pass the declared verification suite.
Track: tmp/repro-{project}.md
Extras: Release Certification checks requirements. This loop catches "works on the agent's machine" failures and undeclared dependency drift.

## Abuse and Boundary-Case Loop
Goal: Exercise malformed input, impossible values, repeated actions, extreme quantities, invalid state transitions, and unauthorized or out-of-order operations.
Checkpoint: After each boundary case, record expected behavior, actual behavior, exploitability, and whether a regression test was added.
Stop: Every defined abuse class is rejected, normalized, or safely handled, with no crash, corruption, bypass, or silent invalid state.
Track: tmp/abuse-{project}.md
Extras: Refine the Threat Model documents the attack surface. This loop performs the actual adversarial checks and converts findings into regression coverage.
