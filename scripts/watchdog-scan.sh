#!/usr/bin/env bash
# Deterministic half of the Watchdog Loop (`cron-mode.md` → ## Watchdog Loop).
# Reads tmp/watchdog-registry.md, prints one line per registered Block or Campaign:
#   <state-file> healthy
#   <state-file> stale updated=<ts> window=<sec>s
#   <state-file> blocked reason=<blocked_reason> updated=<ts>
#   <state-file> thrashing verify_failures=<max>
#   <state-file> campaign-stalled reason=<reason> updated=<ts>
#   <state-file> missing
# Exit code 0 always — trips are findings, not errors. LLM triages non-healthy lines.
#
# Portability: needs GNU coreutils `date` (for `date -d`). Both supported hosts
# satisfy it — the Windows local box (git-bash ships GNU coreutils) and the
# headless Ubuntu VPS. On BSD/macOS `date -d` fails: every timestamp then parses
# empty and the guarded fallback flags everything stale/attention (fail-loud, not
# silent) — swap to `date -j -f` there if that host is ever added.
set -u

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REG="$REPO_DIR/tmp/watchdog-registry.md"
[ -f "$REG" ] || { echo "no-registry $REG"; exit 0; }

now=$(date +%s)

# cadence string ("30m", "2h", bare minutes) -> seconds; default 30m
cadence_secs() {
  case "$1" in
    *m) echo $(( ${1%m} * 60 )) ;;
    *h) echo $(( ${1%h} * 3600 )) ;;
    ''|*[!0-9]*) echo 1800 ;;
    *) echo $(( $1 * 60 )) ;;
  esac
}

while IFS= read -r f; do
  f="${f%%#*}"; f="$(echo "$f" | tr -d '\r' | sed 's/^ *//;s/ *$//')"
  [ -n "$f" ] || continue
  [ -f "$f" ] || { echo "$f missing"; continue; }

  # strip inline "# comment" tails and whitespace from field values
  updated=$(grep -m1 '^updated:' "$f" | sed 's/^updated: *//;s/ *#.*//;s/ *$//' | tr -d '\r')
  cadence=$(grep -m1 '^cadence:' "$f" | sed 's/^cadence: *//;s/ *#.*//;s/ *$//' | tr -d '\r')
  # first non-null reason — done loops carry "blocked_reason: null" placeholders
  reason=$(grep 'blocked_reason:' "$f" | grep -v 'blocked_reason: *null' | head -1 | sed 's/.*blocked_reason: *//' | tr -d '\r')
  max_vf=$(grep -o 'verify_failures: *[0-9]*' "$f" | grep -o '[0-9]*$' | sort -rn | head -1)

  # Campaign files are NOT Blocks (no status: field — they use closed:/age). Route them to
  # the campaign branch below BEFORE the block-only blocked/thrashing checks: a campaign's
  # PLAN PROSE legitimately contains "status: blocked" transition descriptions (2026-07-20
  # false positive on a campaign file's plan prose).
  if [[ ! "$f" =~ campaign-([^/]+)\.md$ ]]; then
  # blocked wins: pausing logic (24h vs cap-reason) is LLM triage, script just reports.
  # Anchor to a real status FIELD (line-leading, optional indent) — a bare 'status: *blocked'
  # also matched prose inside next_hint/comment blocks ("→ status: blocked …"), false-flagging
  # done blocks whose notes mention the word (2026-07-20, minigame-audition).
  if grep -qE '^[[:space:]]*status:[[:space:]]*blocked([[:space:]]|$)' "$f"; then
    echo "$f blocked reason=${reason:-unspecified} updated=${updated:-unknown}"
    continue
  fi

  if [ "${max_vf:-0}" -gt 3 ]; then
    echo "$f thrashing verify_failures=$max_vf"
    continue
  fi
  fi  # end non-campaign block-only checks

  # campaign-stalled check: campaign files registered in registry.
  # Mechanical checks only: updated age >7d + no active Block + not closed.
  # Script does NOT read campaign_stop; campaign_stop-unmet and mapping-claimables
  # are confirmed by LLM triage in blocks.md doctrine when this line trips.
  if [[ "$f" =~ campaign-([^/]+)\.md$ ]]; then
    project="${BASH_REMATCH[1]}"

    # check for closed field (terminal, campaign ended)
    closed=$(grep -m1 '^closed:' "$f" | sed 's/^closed: *//;s/ *#.*//;s/ *$//' | tr -d '\r')
    if [ -n "$closed" ]; then
      echo "$f healthy"
      continue
    fi

    upd_s=$(date -d "${updated:-}" +%s 2>/dev/null || echo "")
    if [ -z "$upd_s" ]; then
      # missing/garbage timestamp on campaign file: fail toward attention
      echo "$f campaign-stalled reason=updated_field_invalid updated=${updated:-none}"
      continue
    fi
    seven_days=$(( 7 * 86400 ))
    age=$(( now - upd_s ))
    if [ "$age" -gt "$seven_days" ]; then
      # Check if any registered block file contains the project name and has status: active.
      # Note: block files without project in name (e.g., block-predictive-ledger.md) are
      # invisible to this check — LLM triage handles association for those.
      has_active=0
      while IFS= read -r block_f; do
        block_f="${block_f%%#*}"; block_f="$(echo "$block_f" | tr -d '\r' | sed 's/^ *//;s/ *$//')"
        [ -n "$block_f" ] || continue
        if [[ "$block_f" == *"$project"* ]] && [ -f "$block_f" ]; then
          if grep -q 'status: *active' "$block_f"; then
            has_active=1
            break
          fi
        fi
      done < "$REG"
      if [ "$has_active" -eq 0 ]; then
        echo "$f campaign-stalled reason=campaign_unmet_no_active_blocks updated=$updated"
        continue
      fi
    fi
    echo "$f healthy"
    continue
  fi

  window=$(( $(cadence_secs "${cadence:-}") * 2 ))
  upd_s=$(date -d "${updated:-}" +%s 2>/dev/null || echo "")
  if [ -z "$upd_s" ]; then
    # missing/garbage timestamp: fail toward attention, not silence
    echo "$f stale updated=${updated:-none} window=${window}s"
    continue
  fi
  if [ $(( now - upd_s )) -gt "$window" ]; then
    echo "$f stale updated=$updated window=${window}s"
    continue
  fi

  echo "$f healthy"
done < "$REG"
