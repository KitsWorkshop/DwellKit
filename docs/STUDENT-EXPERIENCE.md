# Student Experience & Model Solution

> ## ⚠️ INSTRUCTOR ONLY — DO NOT DISTRIBUTE TO STUDENTS
> This document contains the complete solution path, the exact recovery commands, and the location of every planted credential. Handing it to a student destroys the exercise. Keep it out of the shared repository, the LMS student view, and any handout pack.

This document has two halves:

1. **Part 1 — The journey.** What a student actually experiences, beat by beat, including what they see on screen. Use this to anticipate where they will get stuck, where they will feel clever, and where they will go wrong.
2. **Part 2 — The optimal path.** What a fully successful student does, in order. Use this as the model answer and marking aid.

Everything below was executed against a real built repository. The outputs are real, not illustrative.

---

# Part 1 — The journey

## Beat 1: Arrival

The student clones their repository and looks around. What they find is an ordinary, busy Node.js project — 3,060 commits, six months of recent activity, dependency bumps, bugfixes, real contributors.

```
$ git log --oneline -5
0523c64 ci: add staging deploy workflow
054d3a1 chore(deps): bump the patch-updates group with 3 updates (#1746)
00435f3 chore(deps): bump the patch-updates group with 4 updates (#1745)
9cb5e93 chore(deps): bump the minor-updates group with 2 updates (#1744)
4aa1521 chore(deps): bump mongoose in the patch-updates group (#1743)
```

Nothing here signals "exercise." That is deliberate.

They will also notice **CI is already failing** before they have done anything. Some students read this as "the repo is broken." Be ready to reframe it: *the build is telling you something is wrong; your job is to work out what.*

## Beat 2: The find

The brief does not tell them what is wrong — only that CI is failing. So the first real move is to read the failing check, which reports a plain deploy rejection:

```
Error: staging deploy failed — upstream returned 401 Unauthorized
The credential in STAGING_API_KEY was rejected by the staging API.
```

That names a thing to chase. Most students go looking for where `STAGING_API_KEY` is set, and reach for a recursive grep almost immediately:

```
$ grep -rn "sk_staging_" . --exclude-dir=.git
config/staging.env:2:STAGING_API_KEY=sk_staging_23066a9c39d6929d2442b066700a3da4e174ed50
```

One file. One credential. It looks exactly like an API key. This takes about ninety seconds.

**This is the trap opening.** The student now believes they understand the problem, and the problem looks small.

## Beat 3: The false summit

The obvious move, and the one the overwhelming majority make:

```
$ git rm config/staging.env
$ git commit -m "chore: remove leaked staging credentials"
$ git push
```

There is a real moment of satisfaction here. The file is gone. `grep` finds nothing. The working tree is clean.

Then CI comes back:

```
failure  <- chore: remove leaked staging credentials
```

**Still red.** Nothing improved. This is the first crack, and it is worth letting the room sit in it for a minute before anyone rescues them. The instinct will be "the test is broken." It is not.

## Beat 4: The reveal

Someone — usually prompted — tries to look at what they just deleted:

```
$ git show HEAD~1:config/staging.env
# Staging environment overrides — do not commit to a public repo.
STAGING_API_KEY=sk_staging_23066a9c39d6929d2442b066700a3da4e174ed50
STAGING_BASE_URL=https://staging.internal.example.com
```

**One command. The credential is back.** Their deletion accomplished nothing.

This is the moment the exercise exists for, and it lands hardest when a student discovers it themselves and says it out loud. If you are running this in a room, stop everything and let that student demonstrate on the projector.

The lesson students verbalise here is usually *"git history is append-only"* — correct, and the intended takeaway.

## Beat 5: The deeper find

Most students now think the problem is bounded: one credential, added once, deleted twice. They are still wrong, and this is where the exercise gets its teeth.

Pushed to search *all* history rather than just the previous commit:

```
$ git log --all --format='%h  %ad  %an  %s' --date=short -S'sk_staging_'
afa31fd  2026-08-13  Owen Fitzgerald   chore: re-add staging config for local testing
e78e88d  2026-06-08  Lena Ostrowski    chore: move staging config out of the repo
d749105  2026-03-23  Lena Ostrowski    chore: add staging config
```

Three commits, not one. The same credential was committed in **March**, "removed" in **June**, and quietly reintroduced in **August**. Nobody noticed for five months.

Note these commits are ~163 and ~82 commits back — they are *not* visible by scrolling `git log`. A student can only find them by actually searching history.

**The reframe this forces:** this is not "a file I need to delete." It is a credential that has been sitting in a shared repository for months, through an unknown number of clones, CI runs, and forks. It is not *at risk* of being compromised. It **is** compromised, and has been since March.

That realisation is what makes rotation obviously the first move rather than a box to tick afterwards.

## Beat 6: The argument

This is the actual content of the exercise, and it should get the most time. The room now knows:

- the credential is recoverable from history
- it has been exposed for five months
- deleting the file changed nothing

The question is **what to do, and in what order.** Most groups instinctively reach for the history rewrite, because it is the impressive technical move. Let them make that argument, then ask who already has a copy.

## Beat 7: Resolution

The student rotates the secret and pushes:

```
$ gh secret set STAGING_API_KEY --body "<new value>" --repo <org>/<repo>
$ git commit --allow-empty -m "chore: verify rotation"
$ git push
```

```
success  <- chore: verify rotation
```

**Green.** The old credential is now worthless, which is the only thing in this entire exercise that actually reduced risk.

Then they clean up:

```
$ git filter-repo --path config/staging.env --invert-paths --force
$ git push --force origin main
```

A fresh clone confirms it is gone:

```
$ grep -rn "sk_staging_" . --exclude-dir=.git
  (nothing)
$ git log --all -S'sk_staging_' --oneline
  (nothing)
```

## Beat 8: The capstone (optional, and very effective)

If you want the lesson to land permanently, spring this after they have declared victory.

The credential is gone from every clone. But GitHub keeps unreferenced commits, and **still serves them by SHA**:

```
$ gh api repos/<org>/<repo>/commits/d7491058a717e8300df78b4e7f6f11473beb609c \
    --jq '.files[] | select(.filename=="config/staging.env") | .patch'
@@ -0,0 +1,3 @@
+# Staging environment overrides — do not commit to a public repo.
+STAGING_API_KEY=sk_staging_23066a9c39d6929d2442b066700a3da4e174ed50
+STAGING_BASE_URL=https://staging.internal.example.com
```

**This was verified live against a real repository after a successful `filter-repo` and force-push.** The rewrite was correct, the clone is clean, and the credential is *still there* if you know the commit SHA — which anyone who cloned the repo before the rewrite does.

Purging it properly requires contacting GitHub Support to run garbage collection. Nothing the student can do from the command line removes it.

The conclusion writes itself: **you cannot un-publish a secret. The only real fix was rotation, and everything after it was housekeeping.**

---

# Part 2 — The optimal path

A fully successful student does the following, in this order. The ordering is the assessment.

### Phase A — Assess before touching anything

The single most important instruction, and the one most students violate within two minutes.

1. **Read the failing check first.** It names `STAGING_API_KEY` and says the credential was rejected. That is the thread to pull — not the file tree.
2. **Locate the live copy** — `grep -rn "STAGING_API_KEY" . --exclude-dir=.git`, then `grep -rn "sk_staging_" . --exclude-dir=.git`
3. **Do not delete it yet.** Deleting is not urgent; understanding the blast radius is.
4. **Enumerate every occurrence across all history:**
   ```bash
   git log --all --oneline -S'sk_staging_'
   ```
5. **Establish the exposure window:**
   ```bash
   git log --all --format='%h %ad %an %s' --date=short -S'sk_staging_'
   ```
   → first committed 2026-03-23, still present today. **Roughly five months.**
5. **Ask who could have obtained it in that window** — every clone, every fork, every CI run with repo access, every developer machine, every backup. The honest answer is *unknowable*.
6. **Conclude explicitly: this credential is compromised, not at risk of compromise.** A student who writes this sentence down has understood the exercise.

### Phase B — Contain (rotate first)

7. **Rotate the credential at the provider.** Here that is the repository secret:
   ```bash
   gh secret set STAGING_API_KEY --body "<new value>" --repo <org>/<repo>
   ```
8. **Verify the old value is dead** — push any commit and confirm CI goes green. Rotation without verification is an assumption, not a fix.
9. **Understand why this came first:** it is the only action that reduces risk. Every copy already in existence becomes worthless the moment the value changes. Nothing else in this exercise achieves that.

### Phase C — Clean up (rewrite history)

10. **Remove the live copy** from the working tree.
11. **Notify collaborators before rewriting.** A force-push to a shared branch breaks everyone else's clone, and anyone who merges a stale branch afterwards *reintroduces the credential*. Coordination is part of the correct answer, not an optional nicety.
12. **Purge from history:**
    ```bash
    git filter-repo --path config/staging.env --invert-paths --force
    git push --force origin main
    ```
13. **Verify with a fresh clone**, not the working copy — the local repo may still hold reflogs and unreachable objects:
    ```bash
    git clone <url> /tmp/verify && cd /tmp/verify
    grep -rn "sk_staging_" . --exclude-dir=.git
    git log --all -S'sk_staging_' --oneline
    ```
14. **Know the limit of what you just did.** The commits remain on GitHub, retrievable by SHA, until GitHub garbage-collects them; removing them requires contacting GitHub Support. Add `.env`-style files to `.gitignore` so the same file cannot return.

### Phase D — Prevent

15. **Install a control that stops recurrence** — a pre-commit hook, a secret scanner in CI (`gitleaks`, `trufflehog`), or enabling push protection on the repository.
16. **State what it does not catch.** This is the more valuable half:
    - hooks are local, optional, and bypassed by `--no-verify`
    - scanners only detect patterns they already know; this credential's invented format would evade most of them
    - nothing prevents a credential from being pasted into an issue, a log, or a screenshot
    - none of it helps for anything already pushed

### Phase E — Document

17. **Write a short incident note**: what leaked, when it was committed, how long it was exposed, who might have seen it, what was done, and in what order. Real incident response is judged on this record; so is this exercise.

---

## The one-line answer

> **Rotate first, because the credential was already compromised. Rewrite second, because it is hygiene rather than remediation. Prevent third. Document throughout.**

---

# Part 3 — Common wrong turns

Anticipate these; most of a cohort will hit at least one.

| Wrong turn | What it looks like | How to redirect |
|---|---|---|
| **Rewrite-first** | Straight to `filter-repo`, no mention of rotation. The most common failure by a wide margin. | *"Who already has a copy? What did your rewrite do about them?"* |
| **Delete and declare victory** | `git rm`, commit, push, done. | Let CI stay red. The exercise self-corrects this one. |
| **Stopping at `HEAD~1`** | Finds the copy they just deleted, misses March. Concludes exposure was minutes. | *"How long had this been in the repository before today?"* |
| **Rotating without verifying** | Changes the secret, never confirms CI. | *"How do you know the old value stopped working?"* |
| **Force-push without warning anyone** | Technically correct, operationally reckless. | *"Three teammates have this cloned. What happens when they push?"* |
| **Treating it as solved** | Believes `filter-repo` fully erased it. | Spring Beat 8 — the commit is still served by SHA. |
| **"It's a private repo, so it's fine"** | Argues exposure was limited. | Partly fair — but who has org access, and what did CI have? Private ≠ contained. |

---

# Part 4 — Marking guidance

Weight the ordering, not the tooling. A flawless `filter-repo` with no rotation is a **failing** answer to the question actually being asked.

| Criterion | Weight | What good looks like |
|---|---|---|
| **Rotated first** | Highest | Rotation precedes the rewrite, and the student can say why |
| **Established true scope** | High | Found all three commits and the five-month window, not just the deletion they made |
| **Articulated the limits of the rewrite** | High | Understands it does nothing about existing copies |
| **Verified rather than assumed** | Medium | Confirmed CI green; verified with a fresh clone |
| **Coordinated the force-push** | Medium | Recognised the impact on collaborators |
| **Prevention + its gaps** | Medium | Installed something, and can say what it misses |
| **Technical execution** | Lowest | The rewrite worked |

**A useful discriminator between grades:** a strong student explains why the credential was compromised *before they ever touched it* — because it lived in a shared repository for five months. A weaker student treats it as compromised only because they personally found it.
