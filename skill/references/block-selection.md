# Block Selection + Authoring

## Check for an existing Block covering this shape

Read `blocks.md` → `## Blocks` for the doctrine, and `instances.md` (owner-local — see blocks.md → Project Instances) for existing instantiated Blocks; `instances.md` absent means no instances exist yet. Don't trust a Block's last-known status at face value — re-verify against ground truth from the mapping step: a Block can be silently *done* (its loops' Stop conditions already met by work that landed through some other path) and just never marked, same as one project's `core-loop-gate` turned out to be. Found one silently done? Mark it done in `instances.md` with its evidence before moving on.

Also check whether the target repo has its own bespoke loop/pipeline infrastructure (its own docs/tasks dir) — prefer extending/wiring into that over building a parallel system. One Block actively driven at a time; up to 3 path-disjoint open Blocks may form a roster (see `blocks.md` → Roster + Git Convention).

## STALE Blocks — how to handle

A Block marked **STALE** in `instances.md` is one whose premise has been contradicted by ground truth (e.g., one project's `core-loop-gate` Block — drafted assuming the core loop was unvalidated, then contradicted by 1200+ core tests + a closed vertical slice). The STALE note usually points to the new claimable work. Three handling options, in order of preference:

1. **Replace with the new Block.** Author the new Block (per the Loop Authoring Loop in `loops-core.md`) and **delete the STALE Block from `instances.md`** — leaving it "for the shape" is a known anti-pattern. Future agents re-read it, try to claim it, and have to re-discover the contradiction. If the new Block needs the same chain shape (e.g., a Gate-Clear Block for the next gate), reference the working Block by name, not the dead one.
2. **Archive under a renamed heading.** Only if the STALE Block's loop chain has historical/diagnostic value (it captured a real signal about why the project pivoted). Rename to `### ARCHIVED: <old name>` with a one-line "archived <date>: <reason>" — never let an agent re-fire it by accident.
3. **Leave the STALE marker in place only when actively mid-replacement** (a future session is actively authoring the replacement Block). If the replacement hasn't been started, option 1 is still the right call — silent STALE Blocks rot.

Whatever you do, do not leave a STALE Block + a new Block pointing at it from `instances.md` for more than one session. Either replace it or move on.

## Mapping doesn't fit any existing Block?

Run the `Loop Authoring Loop` (in `loops-core.md`) to draft a new Block chaining the right existing Loop types from the mapping step — reach for a new Loop *type* only if nothing in the library fits, not by default:

ground-truth check → draft → independent quality review → fix → independent gap review → fix → re-check ground truth → commit into the appropriate loop category file or `blocks.md`.

## Block scope classes — pick the smallest that fits

When authoring, decide which class of Block you actually need. Different classes have different sizes, different human surfaces, and different chaining rules. Don't write a Gate-Clear Block when the work is really "implement the WO chain that unblocks a gate."

| Class | Shape | Human gate? | Example |
|---|---|---|---|
| **Gate-Clear Block** (template in `blocks.md`) | one named gate's full acceptance chain (Calibration/Tuning + Sim User Pass + User Test + Fix Bugs) | yes — User Test is a `human_gate` | a `gate-GF3`-style instance |
| **Build-Until-Gate-Unblocked** | chain of WOs (e.g., Fix Bugs From a Log × N) that, when done, *unblock* a downstream gate; not the gate itself | no — numbers are spec-defined, not taste | a WO-chain instance gating a downstream release |
| **Single-loop Block** | one Loop (e.g., Doc Sweep, Refactor Loop) called many times until Stop | depends on the loop | rarely needed — usually better as a standalone loop invocation |
| **Mixed-phase Block** | spans Validate + Harden (e.g., Visual Inspection → Fix Bugs → Visual Inspection loop) | sometimes — depends on which Validate-phase loop is in the chain | rare in practice |

A `Build-Until-Gate-Unblocked` Block has three specifics a `Gate-Clear` doesn't:

- **Fixed chain order** at authoring time, not chain-resolved at fire time. The WOs have a spec-defined sequence and a P0 build gate between some of them (e.g., a WO chain's P0 standing build gate from the moment it lands). Encode that as a Block-local chaining rule, not a per-loop Stop.
- **`human_gates: []` is the default**, not the exception. The WOs are spec-defined implementation work; the human surface is the *gate* downstream, not the WO chain. Recording the reasoning in the Block (e.g. "the numbers are spec-defined, not taste calls, so the owner's veto surface is the target repo's own decision ledger, not this Block") prevents a future agent from second-guessing.
- **End-of-Block is "next Block becomes claimable," not "taste cleared."** Stop condition is structural (all WOs done + downstream CI gates armed), not a verdict.

When asked for "post-X work" or "the next thing after Y," the smallest class that fits is almost always `Build-Until-Gate-Unblocked`, not `Gate-Clear`. A Gate-Clear Block is for clearing the gate itself (which involves a human gate, run provisionally per Emulated gates).
