#!/usr/bin/env bash
#
# fanout.sh — build and hand out one repository per student.
#
# Implements "Option A" from FANOUT-DESIGN.md: direct API fan-out with
# outside-collaborator invitations. Deliberately does NOT use GitHub Classroom
# template assignments — those provision repos with a single commit, which
# would destroy this kit's 3,059-commit history. See FANOUT-DESIGN.md.
#
# Usage:
#   GH_TOKEN=... GH_ORG=... KIT_SALT=... ./fanout.sh roster.csv
#   ./fanout.sh roster.csv --dry-run      # validate only, create nothing
#
# Roster format (header required):
#   student_id,github_username
#   alice,alice-gh
#
# Re-runnable: students whose repo already exists are skipped (the invite is
# re-sent regardless, since PUT on collaborators is idempotent). Safe to run
# again after a partial failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Internal single-student mode (invoked by the concurrency layer below).
# Kept in this file rather than a second script so the logic lives in one place.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--deploy-one" ]; then
  STUDENT_ID="$2"; GH_USER="$3"; OUTDIR="$4"
  REPO_NAME="${KIT_PREFIX}${STUDENT_ID}"
  STATUS="ok"; NOTE=""

  CREDENTIAL="sk_staging_$(printf '%s' "${STUDENT_ID}${KIT_SALT}" | sha256sum | cut -c1-40)"

  if gh api "repos/${GH_ORG}/${REPO_NAME}" >/dev/null 2>&1; then
    NOTE="repo already existed; build skipped"
  else
    if ! KIT_SALT="$KIT_SALT" "$SCRIPT_DIR/spike.sh" "$STUDENT_ID" >"$OUTDIR/$STUDENT_ID.build.log" 2>&1; then
      printf '%s,%s,%s,,build-failed,see %s\n' \
        "$STUDENT_ID" "$GH_USER" "$REPO_NAME" "$OUTDIR/$STUDENT_ID.build.log" > "$OUTDIR/$STUDENT_ID.row"
      exit 0
    fi
  fi

  # Invite. PUT is idempotent: re-running does not create duplicate invitations.
  if ! gh api -X PUT "repos/${GH_ORG}/${REPO_NAME}/collaborators/${GH_USER}" \
        -f permission=push >"$OUTDIR/$STUDENT_ID.invite.log" 2>&1; then
    STATUS="invite-failed"
    NOTE="see $OUTDIR/$STUDENT_ID.invite.log"
  fi

  printf '%s,%s,%s,%s,%s,%s\n' \
    "$STUDENT_ID" "$GH_USER" "$REPO_NAME" "$CREDENTIAL" "$STATUS" "$NOTE" > "$OUTDIR/$STUDENT_ID.row"
  exit 0
fi

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
: "${GH_TOKEN:?GH_TOKEN is not set. Stop — do not fall back to a personal namespace.}"
: "${GH_ORG:?GH_ORG is not set. Stop — do not fall back to a personal namespace.}"
: "${KIT_SALT:?KIT_SALT is not set. Pick a per-cohort secret string and keep it: it is what makes credentials reproducible.}"
KIT_PREFIX="${KIT_PREFIX:-secretkit-}"
CONCURRENCY="${CONCURRENCY:-5}"

export GH_TOKEN GH_ORG KIT_PREFIX KIT_SALT SCRIPT_DIR

ROSTER="${1:?Usage: fanout.sh <roster.csv> [--dry-run]}"
DRY_RUN=false
[ "${2:-}" = "--dry-run" ] && DRY_RUN=true

[ -f "$ROSTER" ] || { echo "roster not found: $ROSTER" >&2; exit 1; }

echo "==> Fan-out: org=$GH_ORG prefix=$KIT_PREFIX concurrency=$CONCURRENCY"

# ---------------------------------------------------------------------------
# Phase 1 — Preflight
# ---------------------------------------------------------------------------
echo "==> [1/4] Preflight"

gh api "orgs/${GH_ORG}" --jq '.login' >/dev/null 2>&1 \
  || { echo "    FAIL: cannot reach org '$GH_ORG' with this token" >&2; exit 1; }
echo "    org reachable: $GH_ORG"

SCOPES="$(curl -sI -H "Authorization: token $GH_TOKEN" https://api.github.com/user \
          | tr -d '\r' | awk -F': ' 'tolower($1)=="x-oauth-scopes"{print $2}')"
echo "    token scopes: ${SCOPES:-<none reported>}"
case "$SCOPES" in
  *repo*) ;;
  *) echo "    WARNING: token does not report the 'repo' scope; repo creation will likely fail" >&2 ;;
esac

# ---------------------------------------------------------------------------
# Phase 2 — Validate the roster before creating anything.
# A typo caught here costs seconds; caught on the day it costs a student their
# session. This is why validation is a separate phase.
# ---------------------------------------------------------------------------
echo "==> [2/4] Validating roster"

ROWS=(); INVALID=0; SEEN_IDS=""
LINENO_=0
while IFS=, read -r student_id github_username _rest; do
  LINENO_=$((LINENO_+1))
  student_id="$(echo "${student_id:-}" | tr -d ' \r')"
  github_username="$(echo "${github_username:-}" | tr -d ' \r')"

  [ "$LINENO_" -eq 1 ] && [ "$student_id" = "student_id" ] && continue   # header
  [ -z "$student_id" ] && continue                                        # blank line

  if [ -z "$github_username" ]; then
    echo "    INVALID line $LINENO_: '$student_id' has no github_username"; INVALID=$((INVALID+1)); continue
  fi
  case " $SEEN_IDS " in *" $student_id "*)
    echo "    INVALID line $LINENO_: duplicate student_id '$student_id'"; INVALID=$((INVALID+1)); continue ;;
  esac
  SEEN_IDS="$SEEN_IDS $student_id"

  if gh api "users/${github_username}" --jq '.login' >/dev/null 2>&1; then
    ROWS+=("${student_id},${github_username}")
  else
    echo "    INVALID line $LINENO_: GitHub user '$github_username' does not exist (student '$student_id')"
    INVALID=$((INVALID+1))
  fi
done < "$ROSTER"

echo "    valid: ${#ROWS[@]}    invalid: $INVALID"

if [ "$INVALID" -gt 0 ]; then
  echo "    FAIL: fix the roster before running. Nothing has been created." >&2
  exit 1
fi
[ "${#ROWS[@]}" -eq 0 ] && { echo "    FAIL: roster is empty" >&2; exit 1; }

if [ "$DRY_RUN" = true ]; then
  echo "==> Dry run complete. Roster is valid. Nothing created."
  exit 0
fi

# ---------------------------------------------------------------------------
# Phase 3 — Build + invite, with bounded concurrency.
# Concurrency is capped because GitHub's *secondary* rate limits trigger on
# burst concurrency rather than total volume, and are not visible in the
# standard rate-limit headers.
# ---------------------------------------------------------------------------
echo "==> [3/4] Building and inviting (${#ROWS[@]} students)"

OUTDIR="$(mktemp -d)"
trap 'rm -rf "$OUTDIR"' EXIT

printf '%s\n' "${ROWS[@]}" \
  | xargs -P "$CONCURRENCY" -I{} bash -c \
      'IFS=, read -r sid ghu <<< "{}"; "$SCRIPT_DIR/fanout.sh" --deploy-one "$sid" "$ghu" "'"$OUTDIR"'"'

# ---------------------------------------------------------------------------
# Phase 4 — Report
# ---------------------------------------------------------------------------
echo "==> [4/4] Results"

RESULTS="fanout-results-$(date +%Y%m%d-%H%M%S).csv"
echo "student_id,github_username,repo,credential,status,note" > "$RESULTS"
cat "$OUTDIR"/*.row 2>/dev/null | sort >> "$RESULTS" || true

OK=$(grep -c ',ok,' "$RESULTS" || true)
FAILED=$(grep -cE ',(build-failed|invite-failed),' "$RESULTS" || true)

column -s, -t "$RESULTS" | sed 's/^/    /' | cut -c1-140

echo
echo "==> Wrote $RESULTS  (ok: $OK, failed: $FAILED)"
echo "    This file contains credential values — it is gitignored. Do not commit or share it."
if [ "$FAILED" -gt 0 ]; then
  cp "$OUTDIR"/*.log . 2>/dev/null || true
  echo "    Failure logs copied to the current directory."
  echo "    Re-run the same command to retry — existing repos are skipped."
fi
echo
echo "    NEXT: students must ACCEPT their invitations before they can clone."
echo "          Run ./check-invites.sh $RESULTS daily until everyone has."
