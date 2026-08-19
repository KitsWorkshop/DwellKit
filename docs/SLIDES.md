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

This is the short deck (~10 slides). The long-form 30-slide version is in git
history; the standing documents are INSTRUCTOR-GUIDE.md, SOLUTION-WALKTHROUGH.md,
FANOUT-DESIGN.md and TECHNICAL-NOTES.md.
-->

# The Secret You Can't Delete

### DwellKit — a teaching kit for credential-leak response

**Status:** working prototype, verified end to end against real GitHub
**Time box:** ~65 min, delivered live in class

⚠️ **This deck spoils the exercise.** Instructor briefings only.

---

## The trap

A student is handed a repo and told a credential was committed to it. They find it in about 90 seconds, delete it, commit, push — and feel finished.

CI stays **red**. Then someone types:

```bash
$ git show HEAD~1:config/staging.env
STAGING_API_KEY=sk_staging_23066a9c39d6929d...
```

**One command. It's back.**

The student's own confidence is what sets up the reversal — the satisfaction of "task completed" is load-bearing.

---

## The reveal is the hook. The point is order of operations.

1. **Rotate** the credential — it's already compromised
2. **Rewrite** the history — hygiene, not remediation
3. **Prevent** recurrence

Most students go straight to **2**, because it's the technically impressive part.

| | Feels like | Actually is |
|---|---|---|
| **Rotation** | Administrative, boring | The only step that reduces risk |
| **History rewrite** | Real technical work | Does nothing about existing copies |

> *"The damage is already done — containment comes before cleanup."*
> Transfers straight to breach response, leaked tokens in logs, exposed backups.

---

## Why it's called DwellKit

**Dwell time** — the interval between a compromise happening and anyone noticing.

Searching *all* history, not just the last commit:

```bash
$ git log --all --format='%h %ad %s' --date=short -S'sk_staging_'
afa31fd  2026-08-13  chore: re-add staging config for local testing
e78e88d  2026-06-08  chore: move staging config out of the repo
d749105  2026-03-23  chore: add staging config
```

Committed **March**. "Removed" **June**. Quietly reintroduced **August**. **Five months, nobody noticed.**

It is not *at risk* of compromise. It **is** compromised, and has been since March.

---

## The student arc — about 65 minutes

| Phase | Time | What happens |
|---|---|---|
| Setup | 5 min | Clone 3,060 commits. CI already red |
| Discovery | 10 min | They find `config/staging.env` |
| False summit | 10 min | Delete, commit, push. **CI stays red** |
| **The reveal** | 5 min | Someone recovers it. Demo to the room |
| Deeper find | 10 min | Push them to search *all* history |
| **The argument** | 15 min | What do we do, in what order? |
| Resolution | 10 min | Rotate → **green** → rewrite → prevent |

**Deliver it live.** Set as homework it becomes a mechanical `filter-repo` exercise and the ordering lesson evaporates.

**Mark on ordering, not tooling** — a flawless rewrite with no rotation is a *failing* answer. Say so in the brief.

---

## The capstone — spring it after they declare victory

They rotated, rewrote history, force-pushed. A fresh clone is genuinely clean. Then:

```bash
$ gh api repos/<org>/<repo>/commits/d7491058a717e83... \
    --jq '.files[] | select(.filename=="config/staging.env") | .patch'

+STAGING_API_KEY=sk_staging_23066a9c39d6929d...
```

GitHub **still serves the orphaned commit by SHA** — which anyone who cloned before the rewrite has. Purging requires contacting GitHub Support.

# You cannot un-publish a secret.

The only real fix was rotation. Everything after it was housekeeping.

---

## How it's built — four layers, 3,060 commits

| Layer | What | Why |
|---|---|---|
| **1. Floor** | 2,855 real commits from `sahat/hackathon-starter` (MIT) | Credibility — synthetic history is easy to smell |
| **2. Tail** | 203 commits: 200 genuine upstream + 3 authored | **Burial** |
| **3. Plant / scrub / re-add** | 3 of those commits, at ~164, ~83 and ~7 back | The exercise |
| **4. Secret + workflow** | Actions secret + CI that fails while it matches | Makes rotation **real** |

**Burial** keeps the plant out of `git log -20`, closing the scrolling shortcut — while `git log -S` still finds all three in 0.04 s, so the *correct* path costs nothing.

The workflow compares a **SHA-256 hash**; it never contains the credential. Without layer 4, "rotate the credential" is a hypothetical with nothing to rotate.

---

## Deploying a cohort

```bash
export GH_TOKEN=… GH_ORG=… KIT_SALT=…
./dwellkit class roster.csv --dry-run   # validate, create nothing
./dwellkit class roster.csv             # build + invite everyone
./dwellkit status results.csv           # who hasn't accepted
```

Roster validated before anything is created · deterministic credentials `sha256(id + salt)` · concurrent · **idempotent** — re-run to retry failures.

**15–50 s per repo**, dominated by API latency. 30 students: ~25 min serially, **under 5 min** at 5-wide.

Two hard constraints:
- **GitHub Classroom can't deliver this** — its template flow starts repos at a *single commit*
- **Private-repo collaborators consume seats** — 30 students = 31 → **GitHub Education** removes this

---

## What was proved — and what broke

**Verified live, not simulated:** clean clone → one leaking file · delete + push → still red · deleted copy recovered in one command · older plant found via history search · rotate → **green** · rewrite + force-push → clean clone, orphaned commit still served by SHA.

**Three bugs caught during the build:**

1. **Plaintext credential in the workflow file** — visible to `grep` even after a "successful" cleanup. Silently destroys the premise. → hashed instead.
2. **All three exercise commits in the most recent 16** — findable by scrolling; the search skill was skippable. → fixed by burial.
3. **Hand-rolled libsodium encryption** — `gh secret set` already does it. → −19 lines, −1 dependency.

---

## Readiness

# ✅ Demo-ready today — ⚠️ not yet classroom-ready

**Built and verified:** exercise, `dwellkit build` / `class` / `status`, student brief (`templates/student-README.md`), student issue, instructor guide, solution walkthrough, pilot runbook.

| Gap | Severity |
|---|---|
| **GitHub Education verification** (external lead time) | 🔴 Blocking — billing |
| Credential format unvalidated against live push protection | 🟠 High risk |
| Brief never read by an actual student | 🟠 Needs a pilot |
| No prevention artifact (step 3 of 3) | 🟡 Needed for the full lesson |
| Marking rubric + debrief not written | 🟡 Required to mark |

---

## Next steps, in order

1. **Build one repo in your real target org** ← ~10 min, highest value: validates push protection, token scope and org policy at once
2. **Run the group pilot** — `PILOT-RUNBOOK.md`, 3–8 colleagues, one sitting
3. **Apply for GitHub Education** — external lead time, removes per-seat cost
4. Write the rubric and debrief; design the prevention extension

> **Best ratio of build effort to memorability in the collection.** The engineering is essentially done; what's left is teaching materials and org setup.

**Docs:** `INSTRUCTOR-GUIDE.md` · `SOLUTION-WALKTHROUGH.md` ⚠️ · `STUDENT-EXPERIENCE.md` ⚠️ · `FANOUT-DESIGN.md` · `PILOT-RUNBOOK.md` · `TECHNICAL-NOTES.md` · `TODO.md`
**One script:** `./dwellkit` — `build` · `class` · `status`
