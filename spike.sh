#!/usr/bin/env bash
#
# spike.sh — build one student repo for "The Secret You Can't Delete".
#
# This is a day-one spike script: plain, linear shell. Every numbered step
# below is a stand-in for a future kitscript task/microtask; the comment on
# each step says what that eventual task would be called.
#
# Usage:
#   GH_TOKEN=... GH_ORG=... [KIT_PREFIX=secretkit-spike-] ./spike.sh <suffix>
#
# Re-runnable: a different <suffix> produces a fully independent repo.

set -euo pipefail

# ---------------------------------------------------------------------------
# Config / environment
# ---------------------------------------------------------------------------

: "${GH_TOKEN:?GH_TOKEN is not set. Stop — do not fall back to a personal namespace.}"
: "${GH_ORG:?GH_ORG is not set. Stop — do not fall back to a personal namespace.}"
KIT_PREFIX="${KIT_PREFIX:-secretkit-spike-}"

SUFFIX="${1:?Usage: spike.sh <repo-suffix>}"
REPO_NAME="${KIT_PREFIX}${SUFFIX}"

case "$REPO_NAME" in
  "${KIT_PREFIX}"*) ;;
  *) echo "refusing: computed repo name '$REPO_NAME' does not start with KIT_PREFIX '$KIT_PREFIX'" >&2; exit 1 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# The one hardcoded credential value for this spike. Per-student seeding via
# sha256(student_id + salt) is explicitly out of scope — see agent-spec.md
# Non-goals.
#
# WARNING: this format is UNVALIDATED against GitHub push protection. No
# format testing was possible (the build org has no secret scanning — see
# SPIKE-FINDINGS.md Phase 3). If you deploy to an org that HAS push
# protection enabled, verify this format is not blocked before running a
# fan-out, or every student repo will fail to push at once.
# If KIT_SALT is set, the credential is derived deterministically from
# sha256(suffix + salt). This means a repo can be rebuilt identically after a
# failure, and an instructor can re-derive any student's value for marking
# without having recorded thirty of them. Used by fanout.sh.
# If KIT_SALT is unset, the value is random — correct for one-off builds.
if [ -n "${KIT_SALT:-}" ]; then
  CREDENTIAL_VALUE="sk_staging_$(printf '%s' "${SUFFIX}${KIT_SALT}" | sha256sum | cut -c1-40)"
else
  CREDENTIAL_VALUE="sk_staging_$(python3 -c 'import secrets; print(secrets.token_hex(20))')"
fi

echo "==> Building $REPO_NAME in org $GH_ORG"

export GH_TOKEN

# ---------------------------------------------------------------------------
# Step 1 — floor: unpack the authentic history bundle.
# Eventual kitscript task: git-bundle-checkout
# (does not exist yet as of this spike; this is plain `git clone` against a
# bundle file, which is exactly what that task needs to wrap.)
# ---------------------------------------------------------------------------
echo "==> [1/7] Unpacking floor bundle"
git clone --quiet "$SCRIPT_DIR/floor.bundle" "$WORKDIR/repo"
cd "$WORKDIR/repo"
git checkout --quiet -b main origin/floor
git remote remove origin

# ---------------------------------------------------------------------------
# Step 2 — tail: apply the scripted patch series on top of the floor.
# Eventual kitscript task: git-tail-apply (explicitly a non-goal to build as
# a reusable image for this spike — inline is correct here).
# Substitutes the __KIT_SECRET__ placeholder for the real credential value
# as each patch is applied.
# ---------------------------------------------------------------------------
echo "==> [2/7] Applying tail patch series"
for patch in "$SCRIPT_DIR"/tail/*.patch; do
  sed "s/__KIT_SECRET__/${CREDENTIAL_VALUE}/g" "$patch" > "$WORKDIR/patch.tmp"
  # --whitespace=nowarn: most of these patches are real upstream commits and
  # carry the upstream project's own whitespace quirks. The warnings are
  # cosmetic and would otherwise bury the build output in noise.
  git am --quiet --committer-date-is-author-date --whitespace=nowarn "$WORKDIR/patch.tmp"
done
rm -f "$WORKDIR/patch.tmp"

echo "    tail applied: $(ls "$SCRIPT_DIR"/tail/*.patch | wc -l | tr -d ' ') commits on top of floor"

# ---------------------------------------------------------------------------
# Step 3 — create the private repo under the prefix.
# Eventual kitscript task: github-repo-create (with: services: github)
# ---------------------------------------------------------------------------
echo "==> [3/7] Creating private repo $GH_ORG/$REPO_NAME"
gh repo create "$GH_ORG/$REPO_NAME" --private --description "Secret Kit spike repo" >/dev/null

# ---------------------------------------------------------------------------
# Step 4 — push floor + tail.
# Eventual kitscript task: git-push (generic, likely already exists)
# ---------------------------------------------------------------------------
echo "==> [4/7] Pushing floor + tail"
# Auth via a per-invocation header rather than embedding the token in the
# remote URL — an embedded-token URL gets echoed back by things like
# `git remote -v`, .git/config, and tool notices (e.g. git-filter-repo's
# "removing origin remote" message), which is a needless leak surface.
AUTH_HEADER="AUTHORIZATION: basic $(printf 'x-access-token:%s' "$GH_TOKEN" | base64 -w0)"
git remote add origin "https://github.com/${GH_ORG}/${REPO_NAME}.git"
git -c http.extraheader="$AUTH_HEADER" push --quiet origin main

# ---------------------------------------------------------------------------
# Step 5 — set the Actions repo secret.
# Eventual kitscript task: github-repo-secret-set.
#
# The agent-spec assumed this needed hand-rolled libsodium sealed-box
# encryption against the repo's public key. It does not: `gh secret set`
# performs that encryption locally before transmitting. This replaced ~19
# lines of PyNaCl and one dependency with the line below.
# ---------------------------------------------------------------------------
echo "==> [5/7] Setting STAGING_API_KEY repo secret"
gh secret set STAGING_API_KEY --body "$CREDENTIAL_VALUE" --repo "${GH_ORG}/${REPO_NAME}"

# ---------------------------------------------------------------------------
# Step 6 — add the workflow that turns red/green on the credential.
# Eventual kitscript task: probably folds into the same repo-bootstrap task
# as step 3/4 — a file written into the tree before the first push, rather
# than a separate task. Written here as a second commit + push for clarity
# of what changed and when.
# ---------------------------------------------------------------------------
echo "==> [6/7] Adding staging-deploy workflow"
mkdir -p .github/workflows
# Compare a hash of the known-leaked value, not the raw value itself — the
# workflow file is a tracked, permanent part of the repo, so embedding the
# plaintext credential here would defeat "invisible in the working tree"
# forever, even after the student deletes config/staging.env.
LEAKED_VALUE_HASH="$(printf '%s' "$CREDENTIAL_VALUE" | sha256sum | cut -d' ' -f1)"
cat > .github/workflows/staging-deploy.yml <<EOF
name: staging-deploy
on: [push]
jobs:
  check-secret-rotated:
    runs-on: ubuntu-latest
    steps:
      - name: Fail if the secret still matches the known-leaked value
        env:
          STAGING_API_KEY: \${{ secrets.STAGING_API_KEY }}
        run: |
          ACTUAL_HASH=\$(printf '%s' "\$STAGING_API_KEY" | sha256sum | cut -d' ' -f1)
          if [ "\$ACTUAL_HASH" = "${LEAKED_VALUE_HASH}" ]; then
            echo "STAGING_API_KEY still matches the value that leaked into git history."
            echo "Rotate the secret before this will pass."
            exit 1
          fi
          echo "STAGING_API_KEY has been rotated. OK."
EOF
git add .github/workflows/staging-deploy.yml
GIT_AUTHOR_NAME="Priya Natarajan" GIT_AUTHOR_EMAIL="pnatarajan@users.noreply.github.com" \
GIT_COMMITTER_NAME="Priya Natarajan" GIT_COMMITTER_EMAIL="pnatarajan@users.noreply.github.com" \
  git commit --quiet -m "ci: add staging deploy workflow"
git -c http.extraheader="$AUTH_HEADER" push --quiet origin main

# ---------------------------------------------------------------------------
# Step 7 — confirm branch protection is off, report the result.
# Eventual kitscript task: none — verification-only step, likely folds into
# a `verify:` block on the repo-create task rather than its own task.
# ---------------------------------------------------------------------------
echo "==> [7/7] Confirming branch protection is off"
if gh api "repos/${GH_ORG}/${REPO_NAME}/branches/main/protection" >/dev/null 2>&1; then
  echo "    WARNING: branch protection is ON for main (expected off)"
else
  echo "    OK: no branch protection on main"
fi

echo "==> Done: https://github.com/${GH_ORG}/${REPO_NAME}"
echo "    credential value (redact before sharing notes): ${CREDENTIAL_VALUE}"
