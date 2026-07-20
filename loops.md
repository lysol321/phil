# Agent Loops Index

Phil's loop library is split by responsibility so the index stays small and the individual loop definitions remain easy to read and review. This file is the entry point, not a second copy of the library.

## Read first

- **Loop contract and general-purpose loops:** [`loops-core.md`](loops-core.md)
- **Product pipeline and build/validate loops:** [`loops-pipeline.md`](loops-pipeline.md)
- **UX and validation loops:** [`loops-ux.md`](loops-ux.md)
- **Hardening, compatibility, observability, and release loops:** [`loops-hardening.md`](loops-hardening.md)
- **Block system, Driver Protocol, Watchdog, templates, and instantiated Blocks:** [`blocks.md`](blocks.md)
- **Model roster:** [`models.md`](models.md)

Read the relevant linked file fresh each time. Do not quote a prior copy from memory; the files are actively edited and the system exists to prevent staleness.

## Loop contract

Every loop uses the same fields:

- **Goal** — task and boundaries.
- **Checkpoint** — what is recorded or verified after each significant step.
- **Stop** — an exact, testable completion condition.
- **Track** — a repo-relative `tmp/...` ledger path.
- **Extras** — caveats, tools, phase placement, and hand-off rules.

Before starting a loop, read its existing Track ledger and resume from the last checkpoint. Every ledger pass appends a one-line cost record — canonical format `cost: ~<wall-clock> / ~<tokens if known> / <N findings or units>` — so discovery and ground-truth loops can be demoted or retired when their cost per finding/unit degrades. A green regression suite is not a demotion candidate. **This section is the contract owner** — `loops-core.md`'s field list points here; don't let the two drift.

The glossary is shared across the library: `autoreview` means the repository's own review skill or command; `oracle review` means an independent fresh-context judgment pass. Blocks add state-file fields, evidence verification, chaining, leases, roster rotation, and execution-mode rules in [`blocks.md`](blocks.md).

## Catalog

| Category | File | Contents |
|---|---|---|
| Core | [`loops-core.md`](loops-core.md) | Full Production, Triage, Fix Bugs, Test Coverage, Refactor, Planning, Spec Decomposition, Design Alignment, Doc Sweep, Threat Model, Test-Speed, Loop Authoring, Campaign |
| Product pipeline | [`loops-pipeline.md`](loops-pipeline.md) | Pipeline phases, Vertical Slice, Feature Audition, Content, Calibration/Tuning |
| UX / validation | [`loops-ux.md`](loops-ux.md) | UI Design, Visual Inspection, Mechanical Sweep, Simulated User Pass, User Test, Onboarding, Polish/Feel |
| Hardening and release | [`loops-hardening.md`](loops-hardening.md) | Performance, Regression Soak, Save/Load, Network Sync, Accessibility, Localization, Release Certification, Determinism, Progression, Failure-Recovery, Asset/Data, Controls, Observability, Compatibility, Clean-Build, Abuse/Boundary, Triage (scoped ref) |
| Blocks | [`blocks.md`](blocks.md) | Block schema, Git Convention, leases, roster, Driver Protocol, Gate-Clear, Watchdog, reusable templates (live project instances: instances.md, owner-local) |

## Product Pipeline quick map

The full phase membership and chaining rules live in [`loops-pipeline.md`](loops-pipeline.md). This index keeps only the short map and file links below.

`Pre-Validate → Plan → Build → Validate → Harden → Certify`

Continuous loops run alongside the pipeline: Design Doc Alignment, Doc Sweep, Test-Suite Speed, and Threat Model refinement.

## Block entry point

When a task needs an ordered, resumable chain, use [`blocks.md`](blocks.md). It owns the State File Schema, Git Convention, Tree Lease, Roster, Driver Protocol, Emulated Gates, and Watchdog. Instantiated Block records live in instances.md (owner-local live state, absent from delivered artifacts). A Block references loop names from the category files; it does not duplicate their definitions.

## File ownership rules

- Put reusable loop definitions in exactly one category file.
- Put Block mechanics and Block chains in `blocks.md`.
- Keep this file as navigation, shared vocabulary, and the catalog.
- When moving or renaming a loop, update the catalog, every Block chain that names it, and the phil skill references in the same change.
- If a linked file is missing or unreadable, stop and report it. Do not reconstruct the missing procedure from memory.
