---
marp: true
theme: default
paginate: true
header: "The Secret You Can't Delete"
---

<!-- 
SPOILER WARNING: this deck reveals the entire exercise, including the reveal
and the solution. Do not present it to a cohort before they have done the
activity. Safe for: instructor briefings, curriculum review, stakeholder demos.
-->

# The Secret You Can't Delete

### A teaching kit for credential-leak response

**Status:** working prototype, verified end to end
**Build effort:** very low · **Time box:** 45–60 min, in class

---

## ⚠️ Before presenting

This deck **spoils the exercise completely.**

Safe for:
- Instructor briefings
- Curriculum review
- Stakeholder demos

**Not** for a cohort that hasn't done the activity yet.

---

# Part 1 — What it teaches

---

## The pitch

> A student is handed a repository and told a credential was committed to it.
>
> They find it, delete it, commit, and feel finished.
>
> **They are not finished.**

---

## The trap

The credential is still fully recoverable — in **one command**.

```bash
git show HEAD~1:config/staging.env
```

```
STAGING_API_KEY=sk_staging_23066a9c39d6929d...
```

The student's own confidence is what sets up the reversal.

<!--
This is why the exercise works. Nobody who experiences this forgets that git
history is append-only in practice. The satisfaction of "task completed" is
load-bearing — it has to be there for the reversal to land.
-->

---

## But the reveal is the hook, not the point

**The point is order of operations.**

1. **Rotate** the credential — it's already compromised
2. **Rewrite** the history — hygiene, not remediation
3. **Prevent** recurrence

Most students go straight to **2**, because it's the technically impressive part.

That instinct is exactly backwards.

---

## Why students get it wrong

| | Feels like | Actually is |
|---|---|---|
| **Rotation** | Administrative, boring | The only step that reduces risk |
| **History rewrite** | Real technical work | Does nothing about existing copies |

**This exercise exists to make that mistake happen somewhere cheap.**

---

## Why it generalises

> *"The damage is already done — containment comes before cleanup."*

Transfers directly to:

- Breach response
- Leaked tokens in logs
- Exposed database backups
- Any accidental publication

---

# Part 2 — The student experience

---

## Beat 1–2: Arrival and the find

Student clones an ordinary, busy Node.js project — **3,059 commits**, six months of recent activity, real contributors.

CI is **already red**.

```bash
$ grep -rn "sk_staging_" . --exclude-dir=.git
config/staging.env:2:STAGING_API_KEY=sk_staging_2306...
```

⏱ Takes about **90 seconds**. The problem looks small.

---

## Beat 3: The false summit

```bash
$ git rm config/staging.env
$ git commit -m "chore: remove leaked staging credentials"
$ git push
```

Real satisfaction. File gone. `grep` finds nothing.

Then CI returns:

```
failure  <- chore: remove leaked staging credentials
```

**Still red.** Let the room sit in this.

---

## Beat 4: The reveal 💥

```bash
$ git show HEAD~1:config/staging.env
STAGING_API_KEY=sk_staging_23066a9c39d6929d...
```

**One command. It's back.**

Let the student who finds it demonstrate to the room.

<!--
Stop everything here. The collective reaction does more teaching than the brief
does. This is the single highest-value moment in the session.
-->

---

## Beat 5: The deeper find

Searching *all* history, not just the last commit:

```bash
$ git log --all --format='%h %ad %an %s' --date=short -S'sk_staging_'
afa31fd  2026-08-13  chore: re-add staging config for local testing
e78e88d  2026-06-08  chore: move staging config out of the repo
d749105  2026-03-23  chore: add staging config
```

Committed **March**. "Removed" **June**. Quietly reintroduced **August**.

**Five months. Nobody noticed.**

---

## Why that changes everything

Not *"a file I need to delete."*

A credential that sat in a shared repo for five months, through an unknown number of clones, CI runs, and forks.

It is not **at risk** of compromise.

### It **is** compromised — and has been since March.

---

## Beat 6: The argument

**This is the actual content.** Give it the most time.

Prompts that work:

- *"You've rewritten history. Who already has a copy?"*
- *"How long was this exposed? How would you find out?"*
- *"What can't you know about who has seen this?"*

---

## Beat 7: Resolution

```bash
$ gh secret set STAGING_API_KEY --body "<new>" --repo <org>/<repo>
$ git push
```
```
success  <- chore: verify rotation
```

✅ **Green.** The old credential is now worthless.

Then cleanup: `git filter-repo` + force-push. Fresh clone is clean.

---

## Beat 8: The capstone 🔥

Spring this **after** they've declared victory.

```bash
$ gh api repos/<org>/<repo>/commits/d7491058a717e83... \
    --jq '.files[] | select(.filename=="config/staging.env") | .patch'

+STAGING_API_KEY=sk_staging_23066a9c39d6929d...
```

GitHub **still serves the orphaned commit by SHA** after a successful rewrite.

<!--
Verified live against a real repo. The rewrite was correct, the fresh clone was
genuinely clean, and the credential still comes back if you know the SHA —
which anyone who cloned before the rewrite does. Purging requires contacting
GitHub Support. This is the best teaching moment in the kit.
-->

---

## The conclusion writes itself

# You cannot un-publish a secret.

The only real fix was **rotation**.

Everything after it was housekeeping.

---

# Part 3 — The instructor experience

---

## Deliver it live, in class

**Not** as homework.

- The collective reaction when the first student recovers the credential does more teaching than the brief
- Set as homework, it becomes a mechanical `filter-repo` exercise
- The ordering lesson evaporates

**Time box:** 45–60 min · **Class size:** any

---

## Session shape

| Phase | Time | What happens |
|---|---|---|
| Setup | 5 min | Clone, confirm access, CI visibly red |
| Discovery | 10 min | They find `config/staging.env` |
| False summit | 10 min | Delete, commit, push. CI stays red |
| **The reveal** | 5 min | Someone recovers it. Demo to the room |
| Deeper find | 10 min | Push them to search *all* history |
| **The argument** | 15 min | What do we do, in what order? |
| Resolution | 10 min | Rotate → green → rewrite → prevent |

---

## Mark on ordering, not tooling

A flawless `filter-repo` with no rotation is a **failing** answer.

| Criterion | Weight |
|---|---|
| Rotated **first** | Highest |
| Established true scope (5 months, 3 commits) | High |
| Articulated limits of the rewrite | High |
| Verified rather than assumed | Medium |
| Prevention **+ its gaps** | Medium |
| Technical execution | Lowest |

**Say this in the brief** — or you'll get thirty history rewrites and no rotation.

---

## Common wrong turns

| Wrong turn | Redirect with |
|---|---|
| **Rewrite-first** (most common) | *"Who already has a copy?"* |
| Delete and declare victory | Let CI stay red — self-correcting |
| Stopping at `HEAD~1` | *"How long had this been here?"* |
| Rotating without verifying | *"How do you know the old value is dead?"* |
| Force-push, no warning | *"Three teammates have this cloned."* |
| *"It's private, so it's fine"* | Private ≠ contained |

---

## Watch out for

**Students who already know the tooling will finish in ten minutes.**

Have the extension ready:

- Install prevention so this can't recur
- **Explain what your prevention does *not* catch**

That second half is the valuable part — every mechanism has gaps.

---

# Part 4 — How it's built

---

## Four layers

| Layer | What | Why |
|---|---|---|
| **1. Floor** | 2,855 real commits | Credibility |
| **2. Tail** | 203 commits on top | **Burial** |
| **3. Plant/scrub** | 3 of those commits | The exercise |
| **4. Secret + workflow** | Actions secret + CI | Makes rotation *real* |

**Total: 3,059 commits per student repo.**

---

## Layer 1 — The floor

**2,855 real commits** from `sahat/hackathon-starter` (MIT).

Why a real project?

- Synthetic history is easy to smell — mechanical names, uniform diffs, unnatural timestamp clusters
- Real history is irregular in ways that are laborious to fake

Stored as `floor.bundle` (16 MB) — reproducible, fast, works offline.

---

## Layer 2 — The tail, and the burial

**203 commits: 200 genuine upstream + 3 authored.**

The source project made ~200 real commits in the six months above our floor point — with **zero merges**, so they convert cleanly to patches.

| Commit | Distance from HEAD | In `git log -20`? |
|---|---|---|
| **PLANT** | ~163 back | No |
| **SCRUB** | ~82 back | No |
| **REINTRODUCE** | ~6 back | Yes — intentionally |

---

## Burial costs the student nothing

`git log -S'sk_staging_'` returns all three commits in **0.04 seconds** — regardless of depth.

**Burial closes the scrolling shortcut without adding time to the correct path.**

<!--
This was a fix made during review. The first version put all exercise commits
in the most recent 16, so a student could find the plant by scrolling and never
needed to search history at all — undercutting the exact skill being taught.
-->

---

## Layer 4 — Making rotation real

Actions secret `STAGING_API_KEY` + a workflow that **fails while the secret matches the leaked value**.

Without it, "rotate the credential" is a hypothetical with nothing to rotate.

With it: a **red badge that only turns green when the student does the right thing.**

The workflow compares a **SHA-256 hash** — it never contains the credential.

---

# Part 5 — Infrastructure

---

## What you need

| Requirement | Note |
|---|---|
| A GitHub org | Dedicated to teaching |
| A provisioning token | **Students never see this** |
| `git`, `gh`, `python3` | Standard |
| `git-filter-repo` | Needed by *students*, not the builder |

**Not** required: any crypto library — `gh secret set` handles the sealed-box encryption itself.

---

## Building a repo

```bash
export GH_TOKEN=<token>
export GH_ORG=<your teaching org>
./spike.sh alice
```

⏱ **15–50 seconds** per repo — dominated by GitHub API latency, not local work.

Applying all 203 patches locally: **~5 seconds**.

Safety: refuses without `GH_TOKEN`/`GH_ORG`, refuses names outside the prefix, always private.

---

## ⚠️ The push protection risk

The credential format (`sk_staging_` + 40 hex) is **unvalidated against a live scanner.**

The build org had no secret scanning available to test against.

**If your teaching org enforces push protection and this format is recognised — every student repo fails to build at once.**

### Mitigation: build one repo in your real target org. 10 minutes.

---

# Part 6 — What the spike proved

---

## Verified end to end, against real GitHub

1. ✅ Fresh clone → credential in exactly one file
2. ✅ Delete + push → workflow stays **red**
3. ✅ Deleted copy recovered in one command
4. ✅ Older plant found by searching all history
5. ✅ Rotate → workflow turns **green**
6. ✅ Rewrite + force-push → clean in any fresh clone

**Not simulated.** Every step run against live repositories.

---

## Bugs caught during the build

**1. Plaintext credential in the workflow file**
Would have sat in the tree forever — visible to `grep` even after a "successful" cleanup. Silently destroys the premise. → Fixed with hashing.

**2. Exercise commits all in the most recent 16**
Findable by scrolling; the search skill was skippable. → Fixed by burial.

**3. Hand-rolled libsodium encryption**
The spec insisted it was required. `gh secret set` already does it. → **−19 lines, −1 dependency.**

---

## Timings — is 30 students feasible?

| Step | Time |
|---|---|
| Floor unpack + 203 patches (local) | ~5 s |
| GitHub API calls (create, push, secret) | 10–45 s |
| **Per repo** | **15–50 s** |

30 students: **~25 min serially**, under **5 min** at 5-wide concurrency.

Rate limits comfortable on paper (~180 calls vs 5,000/hr) — **but a 30-repo burst hasn't been run.**

---

# Part 7 — Readiness

---

## Demo-ready ≠ classroom-ready

# ✅ Demo-ready today

A working repo exists and the full loop is proven.

# ⚠️ Not yet classroom-ready

Several things are missing — none of them the core mechanic.

---

## What's missing

| Gap | Severity |
|---|---|
| **Students can't access the repos** | 🔴 Blocking |
| **No per-student fan-out** | 🔴 Blocking |
| Push protection format unvalidated | 🟠 High risk |
| No student-facing brief | 🟠 Required |
| No prevention artifact | 🟡 Needed for full lesson |
| No partial-failure handling | 🟡 Operational |

---

## The real blocker

Repos are **private** and **nobody is invited to them.**

Needs either:
- **Collaborator invites** — cheap, needs a roster of GitHub usernames
- **GitHub Classroom** — heavier, handles rosters and LMS linking

**This is a design decision, not an engineering problem.**

*(Verified: write access is sufficient for students to rotate secrets.)*

---

## Next steps, in order

1. **Build one repo in your real target org** ← highest value, 10 min
2. **Decide the access mechanism** — invites vs Classroom
3. **Write the student brief** — state the marking basis explicitly
4. Add the fan-out loop (~1 hour)
5. Design the prevention extension

**Estimated to classroom-ready: ~8–9 hours** — and the *teaching materials* are the larger half, not the engineering.

---

## Standout property

> **Best ratio of build effort to memorability in the collection.**

- Setup is genuinely trivial
- The payoff is large and it lands
- The lesson generalises well beyond version control

**Nobody who experiences the reveal forgets it.**

---

# Questions?

**Repo:** `KitsWorkshop/ScrubKit`
**Demo:** `secretkit-spike-demo7` (private)

| Document | Purpose |
|---|---|
| `INSTRUCTOR-GUIDE.md` | Full guide, zero knowledge assumed |
| `STUDENT-EXPERIENCE.md` | Walkthrough + model solution ⚠️ instructor-only |
| `SPIKE-FINDINGS.md` | Technical report |
| `TODO.md` | Remaining work |
