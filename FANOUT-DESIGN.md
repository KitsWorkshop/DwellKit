# Fan-out design — delivering to a class

How to get one repository per student to ~30 people who may or may not be members of your organisation.

**Short version:** the loop is the easy part (~30 minutes). Three other problems are harder, and one of them rules out the option most people reach for first.

---

## Two findings that shape everything below

### 1. ⚠️ GitHub Classroom's template flow cannot deliver this kit

Classroom's standard assignment flow provisions student repositories from a **template repository**. Per GitHub's documentation:

> *"A new fork includes the entire commit history of the parent repository, while a repository created from a template **starts with a single commit**."*

This kit is 3,059 commits, with the credential planted **163 commits back**. Template instantiation would collapse all of that into one commit — the student would open a repo with the credential sitting in plain view, no history to search, and no exercise.

**Classroom can still be used for roster and identity. It cannot be used to provision the repository content.**

### 2. 💰 Private-repo collaborators consume paid seats

Per GitHub's billing documentation, an organisation on the **Team** plan is billed for:

> *"Outside collaborators on private repositories owned by your organisation, excluding forks."*

Each collaborator counts **once**, regardless of how many repos they touch. Org members are billed the same way.

**A class of 30 therefore needs 31 seats.** The `KitsWorkshop` org currently has `filled_seats: 1, seats: 1`.

**The fix is not to pay for it.** Verified educators can apply for **free GitHub Team with unlimited users and unlimited private repositories** through GitHub Education. This single action removes the billing problem entirely, and it is the highest-leverage thing on this page.

> **Do this first.** Verification is an external process with a lead time measured in days, so start it before writing any code.

---

## The three real problems

Building the loop is trivial. These are not.

| Problem | Why it's hard |
|---|---|
| **Identity** | You need each student's *GitHub username* — not their email, not their student ID. They may not have an account, may use an unguessable handle, and will typo it. |
| **Access** | Private repos require invitations. Invitations are asynchronous and must be **accepted**. Some students won't, and they can't clone until they do. |
| **Billing** | Solved by GitHub Education (above). Unsolved, it's ~$120/month for a class of 30. |

---

## Access models

### Option A — Outside collaborators (per-repo invitations)

Build each repo, then invite the student directly:

```bash
gh api -X PUT "repos/$ORG/secretkit-$STUDENT/collaborators/$GH_USER" -f permission=push
```

| | |
|---|---|
| ✅ | Works today — one API call added to the existing builder |
| ✅ | No org membership required |
| ✅ | Students can't see each other's repos |
| ⚠️ | One invitation per student, each must be accepted |
| ⚠️ | Some orgs restrict or forbid outside collaborators — check policy |
| ⚠️ | Consumes a seat per student unless on Education |

**Best for:** pilots, small cohorts, and any situation where students shouldn't be org members.

### Option B — Org members + teams

Invite students to the organisation once, then grant repo access by team or directly.

| | |
|---|---|
| ✅ | One org invitation covers this and every future assignment |
| ✅ | Team-based access management scales better across a course |
| ⚠️ | Org membership is a larger commitment and more visibility |
| ⚠️ | Still an invitation to accept; still consumes a seat |

**Best for:** a course that will run several kits, where the org invitation is a one-time cost amortised across the term.

### Option C — Classroom for roster, direct push for content (hybrid)

Use GitHub Classroom purely to establish the student → username mapping (students authenticate and self-identify, which solves the identity problem properly), then ignore its template provisioning and push the real history into each repo yourself.

| | |
|---|---|
| ✅ | Solves the identity problem better than any manual method |
| ✅ | Familiar to students who've used Classroom before |
| ⚠️ | More moving parts; you're using Classroom against its grain |
| ⚠️ | Requires GitHub Education verification anyway |

**Best for:** larger cohorts where manual roster collection is the dominant cost.

---

## Recommendation

For a first real class of ~30:

1. **Apply for GitHub Education verification now** — removes billing, unlimited seats and private repos. External lead time.
2. **Use Option A** (outside collaborators + direct API fan-out). It is the smallest change to what already works, and it sidesteps Classroom's template limitation entirely.
3. **Solve identity with a warm-up task**, not a spreadsheet. Have students do something trivial that proves their username — accept an org invitation, or comment on a tracking issue — a week ahead. This gives you a *verified* roster instead of a transcribed one, and surfaces the students who don't have accounts while there's still time.
4. **Revisit Classroom** only if you run this repeatedly and roster collection proves to be the bottleneck.

---

## What to build

Roughly **2–3 hours** of engineering, assuming the Education verification is in flight.

### 1. Roster file (~15 min)
```csv
student_id,github_username
alice,alice-gh
bob,bobcodes
```
Validate every username exists **before** building anything:
```bash
gh api "users/$GH_USER" --jq '.login' || echo "INVALID: $GH_USER"
```
A typo caught here costs seconds; caught on the day it costs a student their session.

### 2. Deterministic credentials (~10 min)
Replace the random per-run value in `spike.sh` with `sha256(student_id + salt)`, truncated to 40 hex characters. Lets you rebuild a repo identically, and derive any student's value for marking without having recorded 30 of them.

### 3. The loop + invite (~45 min)
Per student: build, invite, record. The builder is already fully self-contained per invocation, so this genuinely is a loop.

### 4. Concurrency and retry (~45 min)
`xargs -P 5` or equivalent. Must handle partial failure — with 30 repos, something will fail. Currently a failed build leaves a half-made repo with no cleanup or resume.

### 5. Acceptance monitoring (~20 min)
A script that reports who still hasn't accepted:
```bash
gh api "repos/$ORG/secretkit-$STUDENT/invitations" --jq '.[] | .invitee.login'
```
Run it daily in the week before class. **This is the step that saves the session**, because unaccepted invitations are the most likely cause of a student being unable to start.

### 6. Teardown (~15 min)
Bulk delete after the exercise. Needs a token with `delete_repo` scope, which the build token does not have.

---

## Operational realities

- **Expect 10–20% non-acceptance** by the day before, in any cohort. Build in a chase cycle; don't discover it at the start of class.
- **Rate limits** look comfortable on paper (~200 API calls for 30 students against 5,000/hour), but bursts can trip *secondary* rate limits, which are triggered by concurrency rather than volume and aren't visible in the standard headers. Cap concurrency around 5 and add backoff.
- **Build repos 2–3 days ahead**, not on the day. 30 repos at 15–50s each is 8–25 minutes serially — fine, but not something to run with a room waiting.
- **Have 2–3 spare repos pre-built.** Someone will turn up with no account, a broken account, or an unaccepted invitation, and a spare they can be dropped into is worth more than a fix.
- **Students need `git-filter-repo` installed.** Tell them in advance; it is not a default install.

---

## Still unverified

- **A write-level collaborator rotating the secret and force-pushing.** The endpoint, parameters, and token permissions are confirmed, and GitHub's documentation confirms write access suffices for Actions secrets — but this has not been executed with a real second account. **Test it once before a real class.**
- **Whether your target org permits outside collaborators.** Institutional orgs frequently restrict this. Check before committing to Option A.
- **Push protection against the credential format** — see `DEPLOY-RUNBOOK.md` §0.3. Still the single highest-risk unknown, and it affects all 30 repos identically.
