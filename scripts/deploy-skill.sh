#!/usr/bin/env bash
# Regenerate the deployed phil skill shim from the current repo state, so the
# thin pointer at ~/.claude/skills/phil/ never drifts when repo structure
# changes (a deleted/added reference file, a renamed doc). Idempotent.
#
# Run after any structural change to skill/references/ or the repo-root docs,
# and once per host to bootstrap (on the Ubuntu VPS it records the VPS path).
#
#   bash scripts/deploy-skill.sh                 # repo = this script's repo, target = ~/.claude/skills/phil (Claude Code default)
#   For other runtimes (OpenCode, Hermes, OpenClaw, ...): pass their skill dir as <target>.
#   bash scripts/deploy-skill.sh <repo> <target> # explicit
#
# The main shim's frontmatter (name/description) is copied verbatim from the
# repo's skill/SKILL.md, so skill discovery stays in sync automatically.
set -eu

REPO="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
TARGET="${2:-$HOME/.claude/skills/phil}"

# host-native forward-slash absolute path for the shim body:
# git-bash `pwd -W` -> C:/Users/...  ; Linux/macOS fallback -> /home/...
REPO_NATIVE="$(cd "$REPO" && { pwd -W 2>/dev/null || pwd; })"

[ -f "$REPO/skill/SKILL.md" ] || { echo "no skill/SKILL.md under $REPO — wrong repo root?" >&2; exit 1; }
mkdir -p "$TARGET/references"

# frontmatter (line 1 `---` through the closing `---`) copied verbatim
frontmatter="$(awk 'NR==1&&/^---$/{f=1;print;next} f&&/^---$/{print;exit} f{print}' "$REPO/skill/SKILL.md")"

# reference basenames present in the repo, as a {a,b,c} list for the shim
reflist="$(cd "$REPO/skill/references" && ls *.md 2>/dev/null | sed 's/\.md$//' | paste -sd, -)"

{
  printf '%s\n\n' "$frontmatter"
  cat <<EOF
# DEPLOYED SKILL SHIM — READ THE REPO COPY

This is a thin pointer to the real skill implementation, not a standalone copy. The real procedures, reference files, and loop library live in the git repo and must be read fresh on every activation — do not rely on this deployed copy. If this file contains real procedure text instead of a pointer (evidence of a stale fork), stop immediately and report it.

**\`<phil-repo>\` on this host:** \`$REPO_NATIVE\` — this shim is the machine-local anchor that records the repo root. A different host (e.g. the Ubuntu VPS) has its own shim with its own path; see \`<phil-repo>/PORTABILITY.md\`.

**Read now:** \`$REPO_NATIVE/skill/SKILL.md\` — it owns the current procedure and the authoritative reference-file list.

**Reference files:** \`$REPO_NATIVE/skill/references/{$reflist}.md\`
EOF
  [ -f "$REPO/cron-mode.md" ] && printf '\n**Cron mode** (load only when `blocks.md` → Execution-mode status declares cron armed — currently inline-only): `%s/cron-mode.md`\n' "$REPO_NATIVE"
  [ -f "$REPO/loops.md" ] && printf '\n**Loop library:** `%s/loops.md` (and its linked index categories)\n' "$REPO_NATIVE"
  [ -f "$REPO/PORTABILITY.md" ] && printf '\n**Portability (OS + runtime rules):** `%s/PORTABILITY.md`\n' "$REPO_NATIVE"
  printf '\nIf the repo path is inaccessible or missing, stop and report the machine is not bootstrapped.\n'
} > "$TARGET/SKILL.md"

# one pointer per repo reference file
for rf in "$REPO/skill/references"/*.md; do
  b="$(basename "$rf")"
  cat > "$TARGET/references/$b" <<EOF
# POINTER — READ THE REPO COPY

This file is a thin shim pointing to the repo copy. Read \`$REPO_NATIVE/skill/references/$b\` fresh on every activation — do not rely on this deployed copy.
EOF
done

# prune deployed reference shims whose repo file is gone (e.g. cron-pre-flight.md)
pruned=0
for df in "$TARGET/references"/*.md; do
  [ -e "$df" ] || continue
  b="$(basename "$df")"
  [ -f "$REPO/skill/references/$b" ] || { rm -f "$df"; pruned=$((pruned+1)); }
done

echo "deployed shim -> $TARGET (repo: $REPO_NATIVE; references: ${reflist:-none}; pruned: $pruned)"
