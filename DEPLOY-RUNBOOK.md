# Deployment Runbook — one student

Operational checklist for getting a working repository into one student's hands. Copy-pasteable commands, in order.

For *why* any of this works the way it does, see `INSTRUCTOR-GUIDE.md`. This document assumes you have read it, or don't need to.

**Scope:** one student. **For a whole class, use `dwellkit class`** — it wraps this same flow with roster validation, per-student invitations, concurrency, and a results report. See `FANOUT-DESIGN.md`. This runbook remains the right reference for a single build, for the push-protection pre-flight, and for understanding what `dwellkit class` does per student.

---

## Timing — do this ahead of class, not during it

| When | What |
|---|---|
| **A week before** | Pre-flight (§0), once ever. Includes the push-protection check, which can invalidate everything else. |
| **2–3 days before** | Build repos (§1) and send invitations (§3). Students must *accept* before class. |
| **Day before** | Verify acceptance (§4). Chase anyone who hasn't accepted. |
| **In class** | Hand over URL + brief (§5). |

**The invitation step is the one that bites.** An un-accepted invitation means a student sits down to a repository they cannot clone.

---

## §0 — Pre-flight (once, ever)

### 0.1 Tools

```bash
git --version
gh --version
python3 --version
```

Students additionally need `git-filter-repo` for the rewrite step. Worth telling them to install it in advance:

```bash
pip install --user git-filter-repo
```

### 0.2 Credentials

```bash
export GH_TOKEN=<classic PAT with repo + workflow scopes>
export GH_ORG=<your teaching org>
export KIT_PREFIX=hackathon-starter-   # optional; this is also the default
```

Confirm the token works and has the right scopes:

```bash
curl -sI -H "Authorization: token $GH_TOKEN" https://api.github.com/user | grep -i x-oauth-scopes
# expect: repo, workflow
```

Confirm you can reach the org:

```bash
gh api "orgs/$GH_ORG" --jq '.login'
```

> **Note on tokens.** A classic PAT is not org-scoped — it grants access to everything the issuing account can reach. Fine for a pilot; for repeat use, move to a fine-grained PAT restricted to the org, or a GitHub App. See `INSTRUCTOR-GUIDE.md` Part 3.

### 0.3 ⚠️ The push-protection check — do this first

**This can invalidate the whole approach, so do it before anything else.**

```bash
./dwellkit build pushcheck
```

- **Succeeds** → the credential format gets through your org's scanning. Proceed.
- **Fails with a push-protection / GH013 error** → **stop.** The planted credential format is being blocked. Every student repo will fail identically. You will need to change the credential format in `dwellkit build` and re-test before going further.

This single command also validates your token permissions and org policy at the same time.

---

## §1 — Build the repository

```bash
STUDENT=alice          # your label for the repo; not necessarily their username
./dwellkit build "$STUDENT"
```

Expected output ends with:

```
==> [7/7] Confirming branch protection is off
    OK: no branch protection on main
==> Done: https://github.com/<org>/hackathon-starter-alice
    credential value (redact before sharing notes): sk_staging_...
```

⏱ 15–50 seconds.

---

## §2 — Record the credential value

Save the printed value against the student's name. You will want it to confirm they rotated.

**If you lose it**, recover it from the repo:

```bash
gh repo clone "$GH_ORG/hackathon-starter-$STUDENT" /tmp/recover
cd /tmp/recover
git log --all -p -S'sk_staging_' -- config/staging.env | grep STAGING_API_KEY | head -1
```

---

## §3 — Grant the student access

> ⚠️ **Not performed by `dwellkit build`.** This is a manual step; a built repo is private and unreachable until you do it.

You need their **GitHub username** — not an email, not a student ID.

```bash
GH_USER=<their-github-username>

gh api -X PUT "repos/$GH_ORG/hackathon-starter-$STUDENT/collaborators/$GH_USER" \
  -f permission=push
```

**`push` (write) is the correct level.** It is sufficient to rotate the Actions secret and to force-push, and it does not let them delete the repository or change its settings.

### What happens next depends on org membership

| Student is… | Result |
|---|---|
| **Already an org member** | Access is immediate. Nothing to accept. |
| **Not an org member** | An **invitation** is created. They must accept it before they can clone. |

---

## §4 — Verify before handing over

### 4.1 Did the invitation land, and has it been accepted?

```bash
# Outstanding (unaccepted) invitations:
gh api "repos/$GH_ORG/hackathon-starter-$STUDENT/invitations" \
  --jq '.[] | "PENDING: \(.invitee.login)"'

# Actual collaborators (accepted):
gh api "repos/$GH_ORG/hackathon-starter-$STUDENT/collaborators" \
  --jq '.[] | "\(.login)  \(.role_name)"'
```

A student showing under **PENDING** cannot clone yet. Chase them.

### 4.2 Is the repo in the correct starting state?

```bash
# CI should be RED — this is correct, not a fault
gh api "repos/$GH_ORG/hackathon-starter-$STUDENT/actions/runs" \
  --jq '.workflow_runs[0].conclusion'
# expect: failure

# The secret should exist
gh secret list --repo "$GH_ORG/hackathon-starter-$STUDENT"
# expect: STAGING_API_KEY

# Branch protection must be OFF (students need to force-push)
gh api "repos/$GH_ORG/hackathon-starter-$STUDENT/branches/main/protection" 2>&1 | grep -q "Branch not protected" \
  && echo "OK: unprotected" || echo "CHECK THIS"
```

### 4.3 Optional — confirm the exercise itself is intact

```bash
gh repo clone "$GH_ORG/hackathon-starter-$STUDENT" /tmp/verify && cd /tmp/verify

grep -rln "sk_staging_" . --exclude-dir=.git    # expect exactly: config/staging.env
git log --all --oneline -S'sk_staging_' | wc -l # expect: 3
git log --oneline -20 | grep -c "staging config" # expect: 1 (only the live copy)
```

---

## §5 — Hand over

Give the student:

1. **The repository URL** — `https://github.com/<org>/hackathon-starter-<student>`
2. **The brief** — ⚠️ **does not exist yet.** See `TODO.md` §3.1. It must state that marking is on *order of operations*, not on whether the history rewrite succeeded.
3. **A prerequisite note** — they need `git-filter-repo` installed, and a GitHub account with access accepted.

---

## §6 — After the exercise

The student's repository is now rotated and rewritten. **There is no reset path.** To run the exercise again, build a fresh repo with a new suffix:

```bash
./dwellkit build alice-retry
```

### Cleanup

Deleting repositories requires a token with `delete_repo` scope, which the build token does **not** have by default. Either add that scope, or delete via the web UI:

```bash
gh repo delete "$GH_ORG/hackathon-starter-$STUDENT" --yes   # needs delete_repo scope
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `GH_TOKEN is not set` | Env var missing | `export GH_TOKEN=...` — the script refuses to guess |
| `refusing: computed repo name ... does not start with KIT_PREFIX` | Prefix guard tripped | Check `KIT_PREFIX` and the suffix argument |
| `Resource not accessible by integration` | Wrong token type (app token, not a PAT) | Use a classic/fine-grained PAT with `repo` + `workflow` |
| Push rejected, mentions **push protection** / **GH013** | Org scanning recognises the credential format | **Stop.** Change the format in `dwellkit build`, re-test. Affects every student. |
| `Name already exists on this account` | Repo suffix reused | Pick a new suffix. `dwellkit build` is not idempotent; `dwellkit class` is (it skips existing repos) |
| Build fails partway, repo left half-made | No cleanup/resume logic | Delete the partial repo manually, re-run |
| Student: `Repository not found` on clone | Invitation not accepted, or never sent | Check §4.1 |
| Student cannot rotate the secret | Granted `pull` instead of `push` | Re-run §3 with `-f permission=push` |
| CI green at handover | Secret doesn't match the planted value | Rebuild — the starting state is wrong |
| CI never runs | Actions disabled at org level | Enable Actions for the org/repo |

---

## Known gaps in this runbook

Honest limits, so you don't discover them in front of a class:

- **§3 is not verified end to end.** The endpoint, parameters, and token permissions are confirmed working, and GitHub's documentation confirms write-level access is sufficient to manage Actions secrets. What has *not* been tested with a real second account is a write-level collaborator actually rotating the secret and force-pushing. **Test this once with a colleague or throwaway account before a real class** — it is the difference between the exercise working and being impossible.
- **No student brief exists.** §5 has nothing to hand over yet.
- **No prevention artifact exists** for the third phase of the lesson, or for fast finishers.
- **GitHub Education verification** is the outstanding blocker for a real cohort: private-repo collaborators consume paid seats (30 students needs 31). See `FANOUT-DESIGN.md`.
