# Instructor Guide — *The Secret You Can't Delete*

This guide assumes you have never seen this kit before and know nothing about how it was built. It explains what the exercise teaches, how the machinery works, why it was built this way, what infrastructure you need, and how to run it in a classroom.

**Read the readiness assessment (final section) before planning a class around this.** The core mechanic is built and proven; several things needed for a real classroom rollout are not.

---

## Part 1 — What the exercise actually teaches

### The surface lesson

A student is given a repository and told a credential was committed to it. They find the credential sitting in a config file, delete the file, commit, and push. Done — or so it feels.

It isn't done. Git history is append-only in practice. The credential is still fully recoverable by anyone with a clone, in one command. The student's own sense of completion is what sets up the reversal, which is why it lands so hard.

### The real lesson

The reversal is the hook, not the point. The point is **order of operations**.

Faced with a leaked credential, there are three correct actions:

1. **Rotate the credential.** It is already compromised. Anyone who cloned the repo, any CI log, any fork, any GitHub cache may hold a copy. The only action that actually reduces risk is making the old value worthless.
2. **Rewrite the history.** Removes it from *your* copy going forward. Does nothing about copies that already exist.
3. **Install prevention.** Stops recurrence.

Most students go straight to step 2, because rewriting git history is the technically impressive part — it feels like real work. Rotation feels administrative and boring. That instinct is exactly backwards, and it is the single most common real-world error in credential-leak incidents.

**This exercise exists to make that mistake happen somewhere cheap.** Mark on the ordering, not on whether the rewrite succeeded. If you don't say so explicitly in the brief, you will receive thirty submissions consisting of a flawless `git filter-repo` invocation and no mention of rotation.

### Why this generalises

The reasoning pattern — *"the damage is already done; containment comes before cleanup"* — transfers directly to breach response, leaked API tokens in logs, exposed database backups, and accidental publication of any kind. Students who internalise the ordering here tend to reach for it later.

---

## Part 2 — How the repository is constructed

Understanding this matters because it determines what students can discover and how.

The student repository is built in four layers.

### Layer 1 — The floor (authentic history)

**What it is:** 2,855 real commits from a genuine open-source project ([`sahat/hackathon-starter`](https://github.com/sahat/hackathon-starter), MIT licensed), captured at a fixed point.

**Why it exists:** the repository has to be *credible*. If it contained twenty obviously-synthetic commits, the student would treat the whole thing as a puzzle box rather than a codebase, and nothing about the exercise would feel like a real incident. Real history means real commit messages, real authors, real merge patterns, real file churn.

> **What the floor does and does not do.** The floor provides authenticity. *Concealment* comes from the tail — see Layer 2. An earlier version of this kit put all the exercise commits in the most recent sixteen, which meant a student could find the plant and the scrub just by scrolling `git log`. That has been fixed.

**Why a real project rather than generated commits:** Synthetic history has a texture that is hard to fake and easy to smell. Contributor names repeat mechanically, timestamps fall in unnatural clusters, diffs are uniform in size. Real history is irregular in ways that are laborious to simulate and instantly convincing.

**How it's stored:** as `floor.bundle`, a single 16 MB git bundle file committed to this repo. A bundle is a git repository serialised into one file — you can `git clone` it exactly as if it were a remote server.

> **Design decision — why a bundle, not a live clone at build time?**
> The alternative is cloning from GitHub each time you build a student repo. That was rejected for three reasons: (1) **reproducibility** — upstream keeps committing, so every build would produce a slightly different floor, and two students would have different repositories; (2) **speed** — unpacking a local bundle takes under a second, versus a network clone each time; (3) **offline capability** — you can rebuild repos with no network access to the upstream project. The cost is 16 MB sitting in git, which is a one-time price worth paying.

### Layer 2 — The tail (scripted recent history)

**What it is:** 203 commits applied on top of the floor, stored as numbered patch files in `tail/`. Of these, **200 are genuine upstream commits** from the source project, and **3 are authored for the exercise**.

**Why it exists:** the floor is fixed and shared. Everything specific to this *exercise* lives in the tail. Keeping them separate means the floor never has to be rewritten, and the exercise commits are readable, reviewable, and editable as plain patch files.

**Why 200 real commits rather than invented ones.** The source project made almost exactly 200 commits in the six months above our floor point, containing zero merge commits — so they convert cleanly to patches. Reusing them rather than writing synthetic filler gives real authors, real dates, real diffs and real cadence for free, and reduces the hand-authored surface from fifteen commits to three.

**This is what buries the credential.** The three exercise commits are spread through the tail rather than clustered at the top:

| Commit | Distance from HEAD | Visible in `git log -20`? |
|---|---|---|
| **PLANT** — `chore: add staging config` | ~164 commits back | No |
| **SCRUB** — `chore: move staging config out of the repo` | ~83 commits back | No |
| **REINTRODUCE** — `chore: re-add staging config for local testing` | ~7 commits back | Yes — intentionally |

Only the reintroduce commit is casually visible, and it is *meant* to be: it is the live copy the student is supposed to find and delete. The plant and the scrub cannot be found by scrolling. They require actually searching history — which is the skill the exercise is teaching.

Crucially, **this does not make the exercise slower for a student who uses the right tool.** `git log -S'sk_staging_'` returns all three commits in well under a tenth of a second regardless of how deep they are buried. Burial closes the scrolling shortcut without adding any time to the correct path.

**Why the messages matter:** no commit message contains the words *secret*, *credential*, *key*, *kit*, or *exercise*. The three that matter are disguised as routine config housekeeping.

> **Design decision — invented author identities for the three exercise commits.**
> The original specification called for authors drawn from the project's real contributor list. That was deliberately not done. Attributing a credential leak to a real, identifiable person by name and email — work they did not do and a mistake they did not make — is not a good thing to manufacture, even in a private teaching repo. The three exercise commits use invented identities instead (two names: one authors the plant and the scrub, another the reintroduction).
>
> **The trade-off:** those three commits now sit among 200 by the project's four real contributors, so a student who cross-references authors could notice two names that appear only around the staging config and nowhere else. That is an acceptable price. If a student does spot it that way, they have done real forensic work and deserve the find.

### Layer 3 — The plant and the scrub

Three of the 203 tail commits carry the exercise:

| Position in tail | Commit message | What it does |
|---|---|---|
| 41 of 203 | `chore: add staging config` | **PLANT** — adds `config/staging.env` containing the credential |
| 122 of 203 | `chore: move staging config out of the repo` | **SCRUB** — deletes that file |
| 198 of 203 | `chore: re-add staging config for local testing` | **REINTRODUCE** — adds it back, same value |

In calendar terms the credential is planted in late March, "removed" in early June — roughly **two and a half months of exposure** — then reintroduced in mid-August. Several further commits sit above the last of these, so nothing exercise-related is the most recent thing in the log.

That exposure window is worth drawing out in the debrief. *"This was live in a public-ish repo for ten weeks. Who had access during that time? What did CI have access to? Can you enumerate everyone who cloned it?"* The answer to the last question is no, and that is precisely why rotation cannot wait for the rewrite.

**Why two copies rather than one.** This is the most important structural decision in the kit, and it creates two distinct discoveries:

- The **live copy at HEAD** is what the student finds, deletes, and feels finished about. Without it there is nothing to delete and no false sense of completion — the reversal has nothing to reverse.
- The **older planted-and-scrubbed pair** is the real teaching. A student who recovers only the file they just deleted (`git show HEAD~1:config/staging.env`) has solved the puzzle in front of them and may believe they're done. Searching *all* history reveals the same credential was committed and "removed" months earlier — meaning it has been exposed far longer than they thought, and any assumption about who has seen it is wrong.

That second discovery is what makes rotation obviously necessary rather than merely advisable.

### Layer 4 — The secret and the workflow

The repository has an Actions secret, `STAGING_API_KEY`, set to the same credential value, and a workflow (`.github/workflows/staging-deploy.yml`) that runs on every push. The workflow **fails while the secret still matches the leaked value, and passes once it has been changed.**

**Why this exists:** without it, "rotate the credential" is a hypothetical instruction with nothing to rotate and no way to verify. The secret makes rotation a real, concrete action with visible consequences: a red CI badge that only turns green when the student does the right thing.

**How it checks:** the workflow compares a **SHA-256 hash** of the secret against a hash of the known-leaked value — it does not contain the credential itself.

> **Worth knowing before you teach this — the rewrite does not fully clean GitHub.**
> After a successful `git filter-repo` and force-push, a fresh clone is genuinely clean. But GitHub retains the orphaned commits and **still serves them by SHA** — verified live against a real repo, the full credential comes back from `gh api repos/<org>/<repo>/commits/<old-sha>`. Purging requires contacting GitHub Support.
>
> This is the single best teaching moment in the kit. Spring it *after* students have declared victory: it proves, concretely, that rotation was the only step that reduced risk. It is written up as the optional capstone in `STUDENT-EXPERIENCE.md`.

> **Design decision — why hashed, and a bug this caught.**
> The first version of the build script embedded the plaintext credential directly in the workflow file for comparison. That file is tracked and permanent, so the credential would have sat in the working tree of every commit forever — visible to `grep` even after the student "successfully" deleted the config file and rewrote history. It would have silently destroyed the exercise's central premise. This was caught by the verification step that greps a fresh clone, and fixed by comparing hashes. The verification step earned its keep.

---

## Part 3 — Infrastructure

### What you need

| Requirement | Notes |
|---|---|
| **A GitHub organisation** | Should be dedicated to teaching. Student repos are created inside it. |
| **A provisioning token** | See below. Used once per build; **students never see or need this.** |
| **`git`** | Any recent version. |
| **`gh` (GitHub CLI)** | Used for repo creation and secret setting. Must be authenticated or given a token. |
| **`curl`**, **`sha256sum`** | Usually preinstalled (coreutils). Checked up front alongside `git` and `gh`. |
| **`python3`** | Only for builds with no `KIT_SALT` set, which generate a random credential value. Not checked up front, because a salted build never invokes it. |
| **`git-filter-repo`** | Only needed by *students* (for the history-rewrite step), not for building. |

Notably **not** required: PyNaCl or any cryptography library. An earlier version hand-rolled libsodium sealed-box encryption to set the Actions secret; this turned out to be unnecessary because `gh secret set` performs that encryption locally itself. That removed a dependency and about nineteen lines of code.

### About the provisioning token

The token is an **instructor/CI-side credential**, used to create repositories and set secrets. Students authenticate as themselves with their own GitHub accounts and never touch it.

During development a **classic Personal Access Token** with `repo` and `workflow` scopes was used. Be aware of what that means: **classic PATs are not scoped to an organisation.** A classic PAT with `repo` grants access to every repository the issuing account can reach, everywhere — not just your teaching org. The restriction to one org and one repo-name prefix is enforced by the *script's* logic, not by the token.

**For anything beyond a one-off test build, use one of these instead:**

- **A fine-grained PAT** restricted to the teaching organisation. Note it cannot be scoped to a name *pattern* (`member-portal-*`) because the repos don't exist when the token is created — you grant "all repositories in the org" plus Administration, Secrets, Contents, and Actions write. The benefit is that it cannot touch anything outside that org.
- **A GitHub App installation** — the best option for a real rollout. Org-scoped, not tied to any individual instructor's account, independently revocable, and auditable.

### The push protection consideration — read this before deploying

GitHub can scan pushes for credential patterns and **block** them ("push protection"). This kit deliberately plants something that looks like a credential, so this is directly relevant.

The kit uses an **invented vendor format**: `sk_staging_` followed by 40 hex characters. It reads convincingly as an API key to a student but is not a real vendor's pattern, so in principle no scanner recognises it.

**This has not been verified against a live scanner.** The organisation used to build the kit is on a plan without secret scanning enabled, so there was no scanner to test against. Testing against a public repository (where GitHub scans for free regardless of plan) was rejected because it would mean making a repo public, breaking the kit's own rule that all repos stay private.

**What this means for you:** if your teaching organisation *has* push protection enabled — and institutional Enterprise/Education organisations often do — this format has not been proven to get through. If it is blocked, **every student repository fails to build at once.**

**Before any real rollout, do one of:**
1. Build a single repo in your actual target org and confirm the push succeeds. *(Cheapest and most direct — strongly recommended.)*
2. Test the format in a throwaway public repo, where scanning runs for free.
3. Run your first fan-out against a small pilot group where a failure is cheap to observe.

---

## Part 3.5 — Deploying into an organisation you have not used before

Everything in this kit is parameterised by `GH_ORG`; nothing is hardcoded to any organisation. Moving to a new org is a configuration change, not a code change. What *does* change is the environment, and five org-level settings can each break the exercise in a different way.

`dwellkit class` probes for them during preflight. Several require the `admin:org` scope to read, which a build token legitimately may not have — so anything unreadable is reported as **"could not verify"**, never as a failure. Only two conditions are hard errors:

| Checked | Behaviour |
|---|---|
| **SAML SSO not authorised** | **Hard fail.** The token is valid and the org is visible, but every write returns 403 until the token is authorised for the org. Detected from the `x-github-sso` response header, because otherwise the first symptom is a build dying mid-fan-out. |
| **Actions disabled org-wide** | **Hard fail.** No CI means no red build and no exercise. |
| Org membership and role | Warning — a non-member cannot create repositories. |
| Outside-collaborator policy | Warning. `class` distributes *entirely* through the collaborators endpoint; an org that forbids outside collaborators will build every repo successfully and deliver none of them. |
| Private-repo creation permission | Warning. |

**Push protection is deliberately not probed.** There is no API that answers "would this specific string be blocked", so the only honest check is an actual push. Run `./dwellkit build pilot1` once in the new org before any fan-out — it exercises repo creation, token permissions, push protection, secret setting, Actions, and branch protection in about a minute. Then delete it.

### Default branch

`build` pins the default branch to `main` with an explicit API call after the first push, rather than relying on GitHub adopting the first branch pushed. Organisations can configure a different default branch name; if that happened, `HEAD` would point at a branch that was never created and students would clone with nothing checked out. The call is idempotent and harmless when `main` is already the default.

---

## Part 4 — How a repository gets built

**`dwellkit class` is the deployment workflow** — roster validation, per-student builds, invitations, and a results report. The commands are in the README; the surrounding work is in its "Deploying to a class" section.

This part explains what `class` does per student, because `dwellkit build` is the thing it calls once per row:

```bash
./dwellkit build amara-gh     # → $GH_ORG/member-portal-amara-gh
```

Roughly 15–50 seconds per repository. The variance is GitHub API latency, not local work — applying all 203 patches locally accounts for only about 5 seconds of it. It prints the credential value at the end.

The script is deliberately plain, linear shell with a commented step for each phase. It is meant to be read.

> **You will rarely run `build` directly.** Two cases where you do:
> - **The push-protection check in a new organisation** — one throwaway repo, deleted afterwards. This is the only way to find out whether your org's scanning blocks the credential format, and it fails every student identically if it does.
> - **Rebuilding for one student mid-session.** There is no reset path: once a student has rotated and rewritten, the repo cannot be returned to its starting state. Re-running `class` will *not* help, because it skips repositories that already exist. Build a fresh one under a new id (`./dwellkit build alice-retry`) and invite them to it.

**What it does, in order:**

1. Unpacks the floor bundle into a working directory
2. Applies the 203 tail patches (200 real upstream commits + 3 exercise commits), substituting the real credential for the `__KIT_SECRET__` placeholder
3. Creates the private repository
4. Pushes floor + tail
5. Sets the `STAGING_API_KEY` Actions secret
6. Adds the staging-deploy workflow
7. Replaces the upstream README with the student brief (`templates/student-README.md`), then pushes both
8. Pins the default branch to `main` and confirms branch protection is off (students must be able to force-push)
9. Confirms GitHub Actions is enabled for the new repository and that a `staging-deploy` run was actually queued — without a failing check the exercise has no entry point

**Safety properties worth knowing:**

- It refuses to run unless `GH_TOKEN` and `GH_ORG` are set — no silent fallback to your personal namespace.
- It refuses to build a repo whose name doesn't start with `KIT_PREFIX`.
- Every repository it creates is private.
- It never writes the credential to any file in this repo — the patches contain only the `__KIT_SECRET__` placeholder.

**Failure behaviour to be aware of:** the script has no cleanup or resume logic. If it fails partway (a transient API error, say), it leaves a partially-built repository behind — the repo exists, but may have no history, no secret, or no workflow.

> ⚠️ **This matters more at class scale than it looks.** `dwellkit class` decides a student is already handled by asking *does the repo exist*, and the repo is created at step 3 of 9. A build that dies at step 4 or later leaves a repo that a re-run will **skip and report as `ok`** — so a student receives a broken repository and nobody finds out until class. Delete any partially-built repo manually before re-running. Tracked in `TODO.md` §4.

Note that deleting requires a `delete_repo` scope that the standard build token does not have.

---

### How students are told they have a repository

Two mechanisms, because neither covers everyone on its own:

| Student is… | Collaborator call does | Assigned issue does |
|---|---|---|
| **Not an org member** | Creates an invitation — GitHub emails them (`201`) | Created, but **unassigned** — GitHub requires push access to be assignable and drops the assignee silently. They cannot be notified about a private repo they cannot yet see. |
| **Already an org member** | Adds them silently — **no notification at all** (`204`) | Notifies them immediately |

The issue exists mainly to close that second row. An org member who is quietly granted access has no way of knowing unless somebody tells them, and that is easy to discover on the morning of the session rather than the week before.

It also does a second job. The ticket is written in-fiction — *"Priya's last day was Friday, and `staging-deploy` has been red ever since"* — so the work arrives the way it actually arrives in a job: as something you inherited, not an exercise you were handed. Edit `templates/student-issue.md` to change the wording; `__STUDENT__` is replaced with their GitHub username.

`class` prints anyone who was added silently, and records the outcome per student in the `notified` column of the results CSV.

> **Re-run `class` once everyone has accepted.** Nothing back-fills an assignment — GitHub sends no retroactive notification for events that predate your access, and the dropped assignee is not reapplied. A re-run finds the existing issue, sees it has no assignee, and assigns it. The `note` column will say `issue assigned on re-run`, or `issue unassigned (student has not accepted yet)` for anyone still pending. Re-running is safe: repos are skipped and no duplicate issue is opened.

> **Send the URLs yourself as well.** GitHub notification email lands in Promotions, gets filtered, and is muted outright by plenty of students. Neither channel is reliable enough to be the only one for something a session depends on — use your LMS.

---

### What students need installed

Tell them in advance — neither is a default install, and discovering it at the start of a session costs you twenty minutes:

- **`git-filter-repo`** — `pip install --user git-filter-repo`, or `brew install git-filter-repo`
- **A GitHub account**, with the repository invitation already accepted

> Do **not** explain *why* they need `git-filter-repo`. Listing it as course tooling is fine; saying "you will need this to rewrite history" gives away the second half of the exercise.

---

## Part 5 — Running it in class

### Format

**Deliver it live, in class.** This exercise is unusually sensitive to delivery format. The collective reaction when the first student recovers the "deleted" credential does more teaching than any written brief. Set as homework, it becomes a mechanical `filter-repo` exercise and the ordering lesson evaporates.

**Time box:** 45–60 minutes. **Class size:** any.

### Suggested shape

| Phase | Time | What happens |
|---|---|---|
| Setup | 5 min | Students clone their repo. Confirm everyone has access and CI is visibly red. |
| Discovery | 10 min | "A credential was committed to this repo. Find it." They find `config/staging.env`. |
| The false summit | 10 min | They delete it, commit, push. CI stays red. Let them sit with this. |
| **The reveal** | 5 min | Someone recovers it from history. Let that student demonstrate to the room. |
| The deeper find | 10 min | Push them to search *all* history, not just the last commit. The older plant surfaces. |
| The argument | 15 min | **The actual content.** What do we do, and in what order? Let them argue. |
| Resolution | 10 min | Rotate → verify green → rewrite → prevention discussion. |

### The moment that matters

Do not rush from the reveal to the fix. **The argument about ordering is the exercise**, and it needs room. Useful prompts:

- *"You've rewritten history. Who already has a copy?"*
- *"How long has this credential been exposed? How would you find out?"*
- *"If you rotate first, does the history rewrite still matter? Why?"*
- *"What can't you know about who has seen this?"*

The intended landing point: **rotation is the only step that reduces risk; the rewrite is hygiene; you cannot un-publish a secret.**

### Commands students will need

Recovering the file they just deleted:
```bash
git show HEAD~1:config/staging.env
```

Finding *every* occurrence across all history — the important one:
```bash
git log -p --all -S'sk_staging_' -- config/staging.env
```

Rotating the credential (needs write access to repo settings, or done via the web UI):
```bash
gh secret set STAGING_API_KEY --body "<new value>" --repo <org>/<repo>
```
Then push any commit to trigger a run — changing a secret alone does not trigger a workflow.

Rewriting history:
```bash
git filter-repo --path config/staging.env --invert-paths --force
git push --force origin main
```

### A pacing warning

Students who already know this tooling will finish in ten minutes. Have the extension ready: **install prevention so this cannot recur, and articulate what your prevention does *not* catch.** That second half is the valuable part — every prevention mechanism has gaps (a pre-commit hook doesn't run on `--no-verify`, a scanner only knows patterns it has seen, none of it helps for a credential already pushed).

### A tuning note

When the workflow fails, its log reads as an ordinary deploy rejection:

```
Error: staging deploy failed — upstream returned 401 Unauthorized
The credential in STAGING_API_KEY was rejected by the staging API.
```

**This is deliberately uninformative**, and it is worth understanding why before you soften it.

GitHub Actions echoes the entire `run:` block into the log, and job and step names show in the checks UI — so *everything* in that workflow is student-visible. An earlier version said *"STAGING_API_KEY still matches the value that leaked into git history"*, which gave away the reveal (that the credential predates the file they are looking at) before the student had opened anything.

The current version never mentions git history. A student who reads the workflow carefully learns only that the key must differ from a known-bad fingerprint — not that the old value is still recoverable. Reading CI config to diagnose a failure is a skill worth rewarding; being handed the diagnosis is not.

The fiction is also true to life: secret-scanning partners really do auto-revoke leaked keys, so "this credential was rejected" is exactly what a leaked-then-revoked key looks like in production.

> **If your cohort flounders**, add hints verbally rather than in CI — you can always become more helpful mid-session, but you cannot un-spoil a group that was already told the answer.

### Marking

Mark on **order of operations**, explicitly and stated up front in the brief:

- Did they rotate the credential, and did they do it **first**?
- Did they recognise the credential was compromised regardless of the rewrite?
- Did they find the *earlier* exposure, not just the one they created?
- Can they articulate what the rewrite does and does not accomplish?
- Prevention: what did they install, and what does it miss?

A submission with a perfect history rewrite and no rotation should not score well. Say this in the brief, or you will not get what you're looking for.

---

## Part 6 — Readiness assessment

**This kit is demo-ready. It is not yet classroom-ready.** The distinction matters.

### What is built and proven

The full loop has been executed end to end against real GitHub, not simulated:

1. Fresh clone → credential present in exactly one file, nothing else leaking it ✓
2. Student deletes it, commits, pushes → workflow stays **red** ✓
3. Deleted copy recovered in one command ✓
4. Older planted-and-scrubbed copy recovered by searching all history ✓
5. Secret rotated → workflow turns **green** ✓
6. History rewritten + force-pushed → **fresh clones are clean**, but GitHub still serves the orphaned commit by SHA ✓ (see the box in Part 2)

A working demo repository exists and is in the correct pre-exercise state: **[`KitsWorkshop/secretkit-spike-demo7`](https://github.com/KitsWorkshop/secretkit-spike-demo7)** — cloned fresh it has one credential in the tree, the plant and scrub invisible to `git log -50`, and CI red.

### What is missing before students can use it

| Gap | Severity | Notes |
|---|---|---|
| ~~Students cannot access the repos~~ | ✅ **Done** | `dwellkit class` invites each student as a collaborator at `permission=push`. |
| ~~No per-student fan-out~~ | ✅ **Done** | `dwellkit class` builds a repo per student from a roster, concurrently, with deterministic credentials and idempotent re-runs. |
| **GitHub Education verification** | **Blocking for a real cohort** | Private-repo collaborators consume paid seats — 30 students needs 31, versus the 1 a bare Team org has. Note the org is *already* on Team — that is the cause, not the cure. Education grants the same Team plan free with unlimited users. External lead time; start it early. See `FANOUT-DESIGN.md`. |
| **Push protection format unvalidated** | **High risk** | See Part 3. Could cause every repo to fail to build in an org that enforces scanning. Cheapest mitigation: build one repo in your real target org and see if it pushes. |
| **Brief never read by a student** | Needs a pilot | The brief itself is built (`templates/student-README.md`, installed as the repo README at build time) and states that marking is on ordering. What is missing is evidence it reads clearly to someone seeing it cold. |
| **No marking rubric or debrief** | Required to mark | Suggested criteria are in Part 5, but neither has been written up. `TODO.md` §3.1. |
| **No prevention artifact** | Needed for the full lesson | Step 3 of the three-step lesson (rotate → rewrite → prevent) has no built component — no pre-commit hook, scanner config, or equivalent. Also the designated extension for fast finishers. |
| **No partial-failure handling** | Operational | A failed build leaves a half-made repo needing manual cleanup. Tolerable for a handful of repos; annoying at thirty. |
| **Untested at class scale** | Operational | Built and verified for a handful of repos. Rate limits look comfortable on paper (~180 API calls for 30 students against a 5,000/hour limit) but a 30-repo burst has not actually been run. |

### Recommended next steps, in order

1. **Build one repo in your real target organisation.** This single action validates the push protection question, the token permissions, and the org configuration all at once. Highest information per unit effort by a wide margin.
2. **Apply for GitHub Education verification.** External lead time, and it removes the per-seat cost of a class. Now the main non-content blocker.
3. **Write the marking rubric and the debrief.** The brief itself is done; these are not, and they are the largest remaining piece of work.
4. **Design the prevention extension** for fast finishers.
5. **Test a write-level collaborator end to end** with a second account — confirm they can rotate the secret and force-push.

### Housekeeping

- Several throwaway repositories from development remain in the build org (`secretkit-spike-pushtest`, `-demo1`, `-demo2`, `-demo3`, `-demo5`, `-demo6`). They need manual deletion; the build token lacks the `delete_repo` scope. `-demo4` should also go — it was built with the earlier shallow tail and is superseded. **`secretkit-spike-demo7`** is the intentionally-preserved demo repo. *(These repos keep their literal `secretkit-spike-*` names because that is what they are actually called on GitHub — they predate the current `member-portal-` prefix.)*
- The classic PAT used during development was entered in plaintext into a chat transcript. It was never written to any file in this repository, but it should be revoked and reissued.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `GH_TOKEN is not set` | Env var missing | `export GH_TOKEN=...` — the script refuses to guess |
| `refusing: computed repo name ... does not start with KIT_PREFIX` | Prefix guard tripped | Check `KIT_PREFIX` and the suffix argument |
| `Resource not accessible by integration` | Wrong token type (app token, not a PAT) | Use a classic/fine-grained PAT with `repo` + `workflow` |
| Push rejected, mentions **push protection** / **GH013** | Org scanning recognises the credential format | The script detects this and explains it. **Stop.** Change the format in `credential_for()`, delete the empty repo, re-test. Affects every student. |
| `Name already exists on this account` | Repo suffix reused | Pick a new suffix. `dwellkit build` is not idempotent; `dwellkit class` is (it skips existing repos) |
| Build fails partway, repo left half-made | ⚠️ `class` treats an existing repo as done and will **skip** it — see `TODO.md` §4 | Delete the partial repo manually, then re-run |
| Student: `Repository not found` on clone | Invitation not accepted, or never sent | `./dwellkit status <results.csv> --remind` |
| Student cannot rotate the secret | Granted `pull` instead of `push` | Re-run `./dwellkit class` — it invites at `push` |
| CI green at handover | Secret doesn't match the planted value | Rebuild — the starting state is wrong |
| CI never runs | Actions disabled at org level | Enable Actions for the org/repo |

---

---

## Appendix — Files in this repository

| File | Purpose |
|---|---|
| `dwellkit` | The only script, with three subcommands:<br>`build <id>` — one complete student repo. Plain, linear, commented — meant to be read.<br>`class <roster>` — roster validation → build → invite → report. Concurrent, idempotent.<br>`status <results>` — who hasn't accepted their invitation; `--remind` re-sends. |
| `roster.example.csv` | Roster format (`student_id,github_username`). |
| `floor.bundle` | The 2,855-commit authentic history, serialised (16 MB). |
| `tail/*.patch` | 203 numbered patches applied on top of the floor: 200 genuine upstream commits, plus the 3 exercise commits (plant at 41, scrub at 122, reintroduce at 198). The three exercise patches contain only the `__KIT_SECRET__` placeholder, never a real value. |
| `INSTRUCTOR-GUIDE.md` | This document. |
| `STUDENT-EXPERIENCE.md` | **Instructor-only.** Beat-by-beat walkthrough of what students experience, the model solution path, common wrong turns, and marking guidance. Contains all the answers — do not distribute. |
| `SLIDES.md` | Marp-format deck, ~10 slides, covering the whole kit — pedagogy, student journey, delivery, architecture, findings, readiness. **Spoils the exercise**; for instructor briefings and stakeholder demos, not for a cohort. |
| `PILOT-RUNBOOK.md` | Running the kit with 3–8 colleagues acting as students, before it meets a real cohort. Closes three of the four open unknowns in one sitting. |
| `FANOUT-DESIGN.md` | Scaling to a class: access models, the GitHub Education/billing constraint, why Classroom's template flow can't deliver this kit, and what to build. |
| `TODO.md` | Remaining work before classroom-ready, ordered by what blocks what. |
| `TECHNICAL-NOTES.md` | Full technical report — what was tested, what broke, timings, open questions. |
| `PROGRESS.md` | Short status summary suitable for reporting. |
| `agent-spec.md` | The original build specification. Useful for understanding intent; note that several of its assumptions were revised during the build, and where they conflict, `TECHNICAL-NOTES.md` is authoritative. |

A built student repository contains **3,060 commits**: 2,855 floor + 203 tail + 2 commits added at build time (the staging-deploy workflow, then the student README).
