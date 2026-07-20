#!/usr/bin/env bash
# Prose linter for the phil loop library — the deterministic half of quality
# review (the LLM oracle pass catches the rest). Mechanical checks only:
#   A. every phil-repo cross-file pointer resolves to a file that exists
#   B. every loop carries the load-bearing contract fields (Stop, Track)
#   C. no Stop is an unenforceable "until happy" without a give-up bound
#   D. no project jargon (owner-configured tokens below, uncaveated delegate_task) leaks
#      into the loaded surface (archive/ + models.md interview keep history)
# One line per finding: "<ERROR|WARN> <file>:<line> <check> — <detail>".
# Exit 1 if any ERROR (CI gate); WARN alone exits 0.
# Run: bash scripts/lint-phil.sh
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO" || exit 2
errors=0
warns=0

# The loaded surface — files an agent actually reads at runtime. archive/ and
# tmp/ are excluded on purpose (history / live state, not doctrine).
SURFACE=(loops.md loops-core.md loops-ux.md loops-pipeline.md loops-hardening.md blocks.md \
         cron-mode.md models.md README.md \
         skill/SKILL.md skill/references/execution.md \
         skill/references/ground-truth-and-mapping.md \
         skill/references/block-selection.md)

emit_err() { echo "ERROR $1"; errors=$((errors+1)); }
emit_warn() { echo "WARN $1"; warns=$((warns+1)); }

# ── Check A: cross-file pointer resolution ───────────────────────────────
# A .md/.sh token is resolved if its basename exists anywhere in the repo, or
# is a known external (a target-repo file phil references as an example). A
# token that's neither is a broken pointer — including a deleted/renamed phil
# file. Skips templates ({..}/<..>) and tmp/ runtime-state paths (live, absent
# by design). Basename-resolution instead of an exact-path list so a moved
# file (cron-pre-flight.md -> cron-mode.md) is still caught.
# blocks-2026-07.md + instances.md: legitimately absent from delivered artifacts (archive/ and
# instances.md are export-ignored), so pointers to them must resolve without the file present.
# instances.md is also intentionally NOT in SURFACE — owner-local live state, jargon allowed.
# watchdog-registry.md/watchdog.md: runtime state under tmp/ (export-ignored) — bare-basename
# references in doctrine must resolve even when tmp/ is absent (delivered artifact).
EXTERNAL='NEXT.md CHANGELOG.md blocks-2026-07.md instances.md watchdog-registry.md watchdog.md'
for f in "${SURFACE[@]}"; do
  [ -f "$f" ] || { emit_err "$f:0 pointer — surface file itself is missing"; continue; }
  grep -noE '`[^`]+`|\]\([^)]+\)' "$f" 2>/dev/null | while IFS=: read -r ln tok; do
    p="${tok#\`}"; p="${p%\`}"; p="${p#](}"; p="${p%)}"
    p="${p%% *}"; p="${p%%#*}"                              # drop arrows/anchors
    case "$p" in
      *.md|*.sh) ;; *) continue ;;                          # only file refs
    esac
    case "$p" in
      *'{'*|*'<'*|*'*'*|tmp/*|*/tmp/*) continue ;;          # template / runtime state
    esac
    b="$(basename "$p")"
    printf ' %s ' "$EXTERNAL" | grep -q " $b " && continue  # known external
    find . -name "$b" -not -path './.git/*' 2>/dev/null | grep -q . && continue
    echo "ERR $f:$ln pointer — unresolved \`$p\` (basename $b found nowhere in repo)"
  done
done > /tmp/lint_a.$$ 2>/dev/null
while IFS= read -r l; do emit_err "${l#ERR }"; done < /tmp/lint_a.$$; rm -f /tmp/lint_a.$$

# ── Check B: loop contract fields ────────────────────────────────────────
# A "loop" = a heading whose next few lines contain a "Goal:" line. Every one
# must carry Stop: and Track:. Watchdog Loop is the sanctioned exception
# (standing daemon, idle/wake condition instead of a completion Stop).
for f in loops-core.md loops-ux.md loops-pipeline.md loops-hardening.md; do
  [ -f "$f" ] || continue
  awk -v F="$f" '
    /^#{2,4} / {
      if (inloop) checkloop()
      hdr=$0; hln=NR; inloop=0; goal=stop=track=0; next
    }
    /^(#{2,4} )/ {}
    { if ($0 ~ /^Goal:/) { inloop=1 }
      if ($0 ~ /^Stop:/) stop=1
      if ($0 ~ /^Track:/) track=1 }
    END { if (inloop) checkloop() }
    function checkloop() {
      name=hdr; sub(/^#+ /,"",name)
      if (name ~ /Watchdog/) return
      if (!stop)  printf "ERR %s:%d field — loop \"%s\" missing Stop:\n",  F, hln, name
      if (!track) printf "ERR %s:%d field — loop \"%s\" missing Track:\n", F, hln, name
    }
  ' "$f"
done > /tmp/lint_b.$$ 2>/dev/null
while IFS= read -r l; do emit_err "${l#ERR }"; done < /tmp/lint_b.$$; rm -f /tmp/lint_b.$$

# ── Check C: unenforceable Stops (heuristic → WARN) ──────────────────────
# A Stop line naming a vague bar must also carry a give-up bound token.
bound='give.?up|give up|straight pass|consecutive|no new|surfaces no|adds nothing|no further|until 23|budget|nothing you.?d|\bcap\b|N consecutive|\[N\]'
for f in loops-core.md loops-ux.md loops-pipeline.md loops-hardening.md blocks.md; do
  [ -f "$f" ] || continue
  grep -nE '^Stop:' "$f" | grep -iE 'until happy|until satisfied|as fast as possible|explicitly defined' \
    | while IFS=: read -r ln rest; do
        if ! printf '%s' "$rest" | grep -qiE "$bound"; then
          echo "WRN $f:$ln stop — vague bar without a give-up bound: ${rest:0:60}"
        fi
      done
done > /tmp/lint_c.$$ 2>/dev/null
while IFS= read -r l; do emit_warn "${l#WRN }"; done < /tmp/lint_c.$$; rm -f /tmp/lint_c.$$

# ── Check D: project jargon leaking into generic doctrine ────────────────
# JARGON: owner-configured target-project tokens — edit this list per project.
JARGON='⟐|\bF4-D\b|\bSTEER\b'
for f in "${SURFACE[@]}"; do
  [ -f "$f" ] || continue
  # bare use is a finding; an attributed example ("e.g. ...") is the correct
  # way to reference project jargon, so allow those lines.
  grep -nE "$JARGON" "$f" | grep -viE 'e\.g\.|example|target repo|its own' \
    | while IFS=: read -r ln rest; do
        echo "WRN $f:$ln jargon — project-specific token in loaded doctrine: ${rest:0:50}"
      done
  # delegate_task without a nearby inert/Hermes qualifier on the same line
  grep -nE 'delegate_task' "$f" | grep -viE 'inert|hermes' | while IFS=: read -r ln rest; do
    echo "WRN $f:$ln jargon — delegate_task without its Hermes-only/inert caveat: ${rest:0:40}"
  done
done > /tmp/lint_d.$$ 2>/dev/null
while IFS= read -r l; do emit_warn "${l#WRN }"; done < /tmp/lint_d.$$; rm -f /tmp/lint_d.$$

# ── Check E: hardcoded absolute paths (breaks the non-Windows host) ──────
# phil-repo paths must be repo-relative or written `<phil-repo>/...` (resolved
# per SKILL.md step 0). A hardcoded C:\ / C:/Users / /home/<user> absolute is a
# cross-platform breaker (Windows local box vs headless Ubuntu VPS).
# A line that also references <phil-repo> is teaching the resolution mapping
# (e.g. SKILL.md step 0: "the Windows box has it at C:/Users/...") — allowed;
# a bare absolute used as the operative path is the finding.
for f in "${SURFACE[@]}"; do
  [ -f "$f" ] || continue
  grep -nF 'C:\Users' "$f" 2>/dev/null | grep -vF '<phil-repo>' | while IFS=: read -r ln rest; do
    echo "ERR $f:$ln abspath — hardcoded Windows path; use <phil-repo>/... : ${rest:0:50}"
  done
  grep -nE 'C:/Users/[a-z]|/home/[a-z]+/' "$f" 2>/dev/null | grep -vF '<phil-repo>' | while IFS=: read -r ln rest; do
    echo "ERR $f:$ln abspath — hardcoded absolute path; use <phil-repo>/... : ${rest:0:50}"
  done
done > /tmp/lint_e.$$ 2>/dev/null
while IFS= read -r l; do emit_err "${l#ERR }"; done < /tmp/lint_e.$$; rm -f /tmp/lint_e.$$

echo "── lint-phil: $errors error(s), $warns warning(s) ──"
[ "$errors" -eq 0 ]
