# Model Tiers and Roster

Doctrine never requires a concrete model — it names a **capability tier** (this file's contract) and, where the runtime exposes one, an **effort level**. Any runtime/vendor maps its own models into the tiers below; the concrete mapping lives in the owner-local roster table underneath, verified by interview.

## Capability tiers — the doctrine vocabulary

| tier | role in doctrine | definition | fits comparatively |
|---|---|---|---|
| **frontier** | emulated gates, independent/oracle reviews, simulated-user personas, design passes, hard reasoning | the strongest judgment/reasoning model reachable from this runtime | Claude Fable/Opus-class; GPT pro/o-series-class; Gemini Ultra-class; DeepSeek-R-class |
| **mid** | default working model, long-run drivers, ordinary build/fix work | capable workhorse balancing cost and competence | Claude Sonnet-class; GPT mainline-class; Gemini Pro-class; MiniMax-M-class |
| **small** | trivial mechanical delegation: scans, renames, probes | the cheapest model that reliably follows instructions | Claude Haiku-class; mini/flash/nano-class |

**Effort axis (orthogonal to tier):** where the runtime exposes a thinking/effort knob, doctrine may name a level — low / medium / high / max (map your runtime's equivalent). No knob on this runtime → tier alone is the contract; don't emulate effort with prompt tricks.

Routing rules the doctrine relies on: judgment work (emulated gates, oracle reviews, simulated-user passes) runs **frontier** — a small/mid model roleplays and judges badly, and the pass is worthless; drivers and ordinary work run **mid**; mechanical delegation runs **small**. A reviewer is never a lower tier than the author it reviews. Escalate one tier when genuinely stuck; log the escalation in the ledger.

## Current roster (owner-local — rewrite via the interview; on a fresh install treat this table as a seed example)

updated: 2026-07-15
status: CONFIRMED — owner interview run 2026-07-15. No changes vs. seeded table: fable/opus/sonnet/haiku confirmed available this session; MiniMax-M2.7 confirmed Hermes-only/inert here, unchanged. No budget ceiling. Routing defaults confirmed as-is.

| provider | model | access path | tier | cost | use for |
|---|---|---|---|---|---|
| anthropic (Claude Code) | fable | main session / delegate `model: fable` | frontier | subscription | simulated-user personas, workshop/authoring, judgment-heavy calls |
| anthropic (Claude Code) | opus | delegate `model: opus` | frontier | subscription | independent review passes (workshop-build-review pattern), hard reasoning |
| anthropic (Claude Code) | sonnet | delegate `model: sonnet` | mid | subscription | default working model |
| anthropic (Claude Code) | haiku | delegate `model: haiku` | small | subscription | trivial mechanical delegation |
| minimax (Hermes runtime) | MiniMax-M2.7 | Hermes driver `provider=minimax`; `delegate_task` for escalation | mid — elite tool adherence | free / unlimited | long-running autonomous drivers — Hermes runtime ONLY, inert elsewhere (see PORTABILITY.md → Runtime adapters) |

Routing defaults (owner's standing preference, 2026-06): default mid (sonnet); escalate to frontier manually; delegate trivial tasks to small (haiku) subagents.

## phil interview questions (ask, then rewrite this file)

1. Which providers/models are available right now, and from which runtime?
2. Any paid or metered ones — budget ceiling per Block or per day?
3. Preferred defaults per tier: driver model (mid), judgment-loop model (frontier — simulated-user passes / reviews), mechanical-delegation model (small)?
4. Anything on this table that's gone, renamed, or newly added?
