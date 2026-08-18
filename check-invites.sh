#!/usr/bin/env bash
#
# check-invites.sh — who still hasn't accepted their repository invitation?
#
# An unaccepted invitation is the single most likely reason a student cannot
# start the exercise. Run this daily in the week before class.
#
# Usage:
#   GH_TOKEN=... GH_ORG=... ./check-invites.sh fanout-results-YYYYMMDD-HHMMSS.csv
#   ./check-invites.sh <results.csv> --remind    # re-send pending invitations

set -euo pipefail

: "${GH_TOKEN:?GH_TOKEN is not set}"
: "${GH_ORG:?GH_ORG is not set}"
export GH_TOKEN

RESULTS="${1:?Usage: check-invites.sh <fanout-results.csv> [--remind]}"
REMIND=false
[ "${2:-}" = "--remind" ] && REMIND=true

[ -f "$RESULTS" ] || { echo "results file not found: $RESULTS" >&2; exit 1; }

ACCEPTED=0; PENDING=0; MISSING=0
PENDING_LIST=()

echo "==> Checking invitations against $RESULTS"
echo

while IFS=, read -r student_id github_username repo credential status note; do
  [ "$student_id" = "student_id" ] && continue     # header
  [ -z "${repo:-}" ] && continue

  if ! gh api "repos/${GH_ORG}/${repo}" >/dev/null 2>&1; then
    printf '  %-14s %-18s  ✗ REPO MISSING\n' "$student_id" "$github_username"
    MISSING=$((MISSING+1)); continue
  fi

  # Accepted → appears as a collaborator. Not yet → appears under invitations.
  if gh api "repos/${GH_ORG}/${repo}/collaborators" --jq '.[].login' 2>/dev/null \
       | grep -qix "$github_username"; then
    printf '  %-14s %-18s  ✓ accepted\n' "$student_id" "$github_username"
    ACCEPTED=$((ACCEPTED+1))
  else
    INV_ID="$(gh api "repos/${GH_ORG}/${repo}/invitations" \
              --jq ".[] | select(.invitee.login | ascii_downcase == \"$(echo "$github_username" | tr '[:upper:]' '[:lower:]')\") | .id" 2>/dev/null | head -1)"
    if [ -n "$INV_ID" ]; then
      printf '  %-14s %-18s  … PENDING\n' "$student_id" "$github_username"
      PENDING_LIST+=("${student_id},${github_username},${repo},${INV_ID}")
      PENDING=$((PENDING+1))
    else
      printf '  %-14s %-18s  ✗ NO INVITATION — re-run fanout.sh\n' "$student_id" "$github_username"
      MISSING=$((MISSING+1))
    fi
  fi
done < "$RESULTS"

echo
echo "==> accepted: $ACCEPTED    pending: $PENDING    problems: $MISSING"

if [ "$PENDING" -gt 0 ] && [ "$REMIND" = true ]; then
  echo
  echo "==> Re-sending pending invitations"
  for row in "${PENDING_LIST[@]}"; do
    IFS=, read -r sid ghu repo inv_id <<< "$row"
    # Delete + recreate: GitHub re-sends the notification email.
    gh api -X DELETE "repos/${GH_ORG}/${repo}/invitations/${inv_id}" >/dev/null 2>&1 || true
    if gh api -X PUT "repos/${GH_ORG}/${repo}/collaborators/${ghu}" -f permission=push >/dev/null 2>&1; then
      echo "    re-sent: $sid ($ghu)"
    else
      echo "    FAILED to re-send: $sid ($ghu)" >&2
    fi
  done
fi

if [ "$PENDING" -gt 0 ]; then
  echo
  echo "    Students listed PENDING cannot clone their repository yet."
  echo "    Chase them, or re-send with:  ./check-invites.sh $RESULTS --remind"
fi

[ "$MISSING" -gt 0 ] && exit 1 || exit 0
