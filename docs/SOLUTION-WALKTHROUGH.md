# Solution Walkthrough — being the student

> ## ⚠️ INSTRUCTOR ONLY — DO NOT DISTRIBUTE TO STUDENTS
> This is the complete answer key in executable form. Handing it to a student destroys the exercise.

`STUDENT-EXPERIENCE.md` describes the journey and grades it. **This document is for walking it yourself**, with a terminal open, against a real built repository — so you can time it, feel where it sticks, and decide what to say in the room.

It is deliberately linear and includes the wrong turn. Do not skip §4; most of a cohort will spend real time there, and you cannot facilitate a trap you have not personally fallen into.

**Expect 35–50 minutes at instructor pace.** A student takes 60–90.

---

## §0 — Set up a repository to walk

Build a throwaway. Do **not** walk a student's repo — there is no reset path once you rotate and rewrite.

```bash
export GH_TOKEN=...        # repo + workflow scope
export GH_ORG=your-org
unset KIT_SALT             # random credential; correct for a scratch build

./dwellkit build walkthrough1
```

Record two things from the build output:

| Value | Where it comes from |
|---|---|
| Repo URL | last line of the build |
| Credential value | second-to-last line — **you are about to pretend you don't know this** |

Then clone it the way a student would, and **close the build terminal** so the credential is not on screen:

```bash
git clone https://github.com/$GH_ORG/member-portal-walkthrough1.git
cd member-portal-walkthrough1
```

> **Observation checkpoint.** Before reading further: does this look like an exercise? It should look like an ordinary inherited Node service. If anything on first inspection says "teaching kit," that is a defect worth fixing.

---

## §1 — Arrival

```bash
git log --oneline -5
git log --oneline | wc -l      # ~3,060
```

Six months of dependency bumps, real contributor names, no signal that anything is planted.

Now look at the repository on GitHub. **CI is already red** and you have not touched anything.

> **Observation checkpoint.** Some students read a pre-existing red check as "my repo is broken" and stop. Decide now what you will say. The reframe that works: *the build is not broken, it is reporting. Read what it reports.*

---

## §2 — Read the failing check properly

Open the failed `staging-deploy` run and **expand the step**, do not just read the red annotation.

The annotation:

```
Error: staging deploy failed — upstream returned 401 Unauthorized
The credential in STAGING_API_KEY was rejected by the staging API.
```

The expanded `Run` block — this is the part that matters:

```bash
# Pre-flight check. The provider revokes keys that have been reported
# as exposed; deploying with one just fails further down the pipeline.
KEY_FINGERPRINT=$(printf '%s' "$STAGING_API_KEY" | sha256sum | cut -d' ' -f1)
REVOKED_FINGERPRINT=<64 hex chars>

if [ "$KEY_FINGERPRINT" = "$REVOKED_FINGERPRINT" ]; then
  echo "::error::staging deploy failed — upstream returned 401 Unauthorized"
  ...
```

Three things are now knowable, and they are not equally easy to see:

| Knowable | Difficulty | Why it matters |
|---|---|---|
| The checked value lives in **repo settings**, not the tree (`secrets.`) | Easy | Points at rotation |
| Green requires **a different value** — it is a hash comparison | Easy | There is exactly one solution |
| The key was **"reported as exposed"** | **Hard — it is a code comment** | The only bridge from *stale* to *leaked* |

> **⚠️ This is the first of two junctions where the exercise derails.**
>
> The natural reading is *"the secret in settings went stale; replace it."* That is professionally correct, reaches green in three minutes, and teaches nothing. Only the word **exposed** suggests looking in the repository at all — and it is a `#` comment inside a `run:` block.
>
> **Time yourself here.** If you personally skimmed past that comment, so will a cohort. See "Known weaknesses" at the end.

---

## §3 — Find the copy

The move a student makes is a reflex, not a deduction: unknown identifier in a failing build, grep for it.

```bash
grep -rn "STAGING_API_KEY" . --exclude-dir=.git
```

```
.github/workflows/staging-deploy.yml:12:  STAGING_API_KEY: ${{ secrets.STAGING_API_KEY }}
config/staging.env:2:STAGING_API_KEY=sk_staging_23066a9c39d6929d...
```

Now grep the value's format, which you could not have done thirty seconds ago:

```bash
grep -rn "sk_staging_" . --exclude-dir=.git
```

One tracked file. Plaintext. About ninety seconds in.

> **Observation checkpoint — the honest snag.** Check what loads this file:
>
> ```bash
> grep -rn "staging.env" . --exclude-dir=.git
> ```
>
> **Nothing does.** No config loader, no `dotenv` call, no import. A rigorous student notices the file is orphaned and can correctly conclude it is *not the mechanical cause of the red check* — it merely shares a name with the CI secret. Rigor is currently punished here. Watch for it; it is a real gap, not a student error.

---

## §4 — Take the wrong turn on purpose

Do this. Do not skip it.

```bash
git rm config/staging.env
git commit -m "chore: remove leaked staging credentials"
git push
```

The file is gone. `grep` finds nothing. The tree is clean. There is a genuine feeling of completion here — notice it.

Watch the check:

```bash
gh run list --limit 1
```

```
failure  <- chore: remove leaked staging credentials
```

**Still red.**

> **Observation checkpoint — the most valuable minute in the exercise.** The instinct is *"the test is broken."* It is not. Let a room sit in this for a full minute before rescuing anyone. Time how long *you* tolerate it; that is your budget for how long they will.

Then recover what you just deleted:

```bash
git show HEAD~1:config/staging.env
```

```
# Staging environment overrides — do not commit to a public repo.
STAGING_API_KEY=sk_staging_23066a9c39d6929d...
STAGING_BASE_URL=https://staging.internal.example.com
```

One command. The deletion accomplished nothing. The takeaway students verbalise — *git history is append-only* — is correct and is the intended one.

> **⚠️ Second junction, and the more dangerous one.** A student can stop right here with a complete-feeling story: *"leaked today, I deleted it, it's still in the last commit, I'll rotate."* Exposure lasted minutes, in that story. It is wrong, and nothing in the exercise contradicts it.

---

## §5 — Establish the real scope

This is the step that separates a pass from a good mark, and **nothing prompts it.**

```bash
git log --all --format='%h %ad %an %s' --date=short -S'sk_staging_'
```

```
afa31fd  2026-08-13  Owen Fitzgerald   chore: re-add staging config for local testing
e78e88d  2026-06-08  Lena Ostrowski    chore: move staging config out of the repo
d749105  2026-03-23  Lena Ostrowski    chore: add staging config
```

> **These SHAs are from the reference build, not yours.** §0 had you `unset KIT_SALT`, so your
> credential is random and every commit below the plant hashes differently. Take the third SHA
> from *your* output and keep it — §8 needs it:
>
> ```bash
> PLANT=<the oldest SHA from your own output above>
> ```

Three commits, not one:

- **23 Mar** — committed.
- **8 Jun** — "moved out of the repo." Removed the file. Left the commit. Somebody believed this fixed it.
- **13 Aug** — re-added by a second person, who presumably believed June had dealt with it.

Confirm the March copy is still live:

```bash
git show $PLANT:config/staging.env
```

Now check how far back that is:

```bash
git log --oneline | grep -n $PLANT      # ~164 commits back
```

> **Observation checkpoint.** These commits are **not reachable by scrolling**. `git log -50` shows nothing. The only route is `-S` (or `log -p --follow`, or a full-history grep).
>
> **The brief now signposts this.** The Tooling reference lists `git log --all -S'<string>'` with the gloss *"every commit that added or removed a string"*, followed by *"Searching the files and searching the history are not the same operation."* So the tool is no longer invisible — but **nothing tells them to use it here**, or that the answer spans five months. Judgement about when to reach for it is still theirs.
>
> If a cohort clears this too easily, that gloss line is the first thing to cut: the command stays listed, the insight goes back to being theirs to find.

**The sentence to listen for:**

> *"This credential has been retrievable by anyone with read access since 23 March. It is compromised, not at risk of compromise."*

A strong student says this *before* touching anything, because the repository was shared for five months. A weaker one treats it as compromised only because they personally found it. That distinction is your cleanest grade discriminator.

---

## §6 — Rotate first

> *"One action makes every existing copy worthless. Nothing else does. Do it first."*

```bash
gh secret set STAGING_API_KEY \
  --body "sk_staging_$(openssl rand -hex 20)" \
  --repo $GH_ORG/member-portal-walkthrough1
```

> **Two routes, both available at `push`.** GitHub's docs are explicit: *"To create secrets or variables on GitHub for an organization repository, you must have `write` access"*, and the repository-roles table lists "create, update, and delete" Actions secrets at Write and above. So students invited at `permission=push` (the collaborator call in `cmd_deploy_one`) can rotate either way:
>
> - **CLI** — the command above. Requires `gh` installed and authenticated. The brief's Tooling reference lists `gh` as **optional**, and says so explicitly, precisely because the UI route below exists.
> - **UI** — Settings → Secrets and variables → Actions → `STAGING_API_KEY` → Update. A Write-level collaborator sees a **reduced** Settings page, not the full admin one: the roles table grants settings capabilities section by section rather than wholesale, and secrets is one of the sections Write gets. If the tab does not render for them, the page is still reachable directly at `https://github.com/<org>/<repo>/settings/secrets/actions`.
>
> The roles table lists these as **two separate rows** — "...on GitHub.com" and "...using the REST API" — both granted at Write/Maintain/Admin. The existence of a distinct GitHub.com row is what establishes there is a web route at Write at all.
>
> **Still unverified live** (`TODO.md` §1.1). Walking it yourself as an org admin **does not test it** — you need a second account at `push`. Three outcomes to look for: tab visible (done); tab hidden but the direct URL loads (put the URL in the brief); direct URL 404s (docs wrong for your org — `gh` becomes a hard prerequisite).
>
> **The secret cannot be read back by anyone, at any role.** Rotation is write-only, so no permission level lets a student peek at the planted value.

Rotation you have not verified is an assumption, not a fix:

```bash
git commit --allow-empty -m "chore: verify rotation"
git push
gh run list --limit 1
```

```
success  <- chore: verify rotation
```

**Green.**

> **Observation checkpoint.** This is the only action in the entire exercise that reduced risk, and it is also the moment CI stops applying pressure. From here the exercise runs on the brief alone — a student who treats green as "done" submits with no rewrite, no prevention, and no incident note, and CI will not argue.

---

## §7 — Clean up, knowing what cleanup is worth

Before force-pushing, the coordination point — this is marked, not optional:

> *"Who has this cloned? A force-push breaks their clones, and anyone who merges a stale branch afterwards reintroduces the credential."*

```bash
git filter-repo --path config/staging.env --invert-paths --force

# filter-repo DELETES the origin remote as a safety measure. Without this,
# the push below fails with "'origin' does not appear to be a git repository".
# The brief now warns about this, so it should cost them seconds, not minutes —
# check whether it actually does.
git remote add origin https://github.com/$GH_ORG/member-portal-walkthrough1.git
git push --force origin main
```

> **Tooling note.** `git filter-repo` is not bundled with git — it needs `pip install git-filter-repo` (or `brew`/`apt`). The brief lists it as *"only if you decide you need it"* with the install line, so students are not blocked — but decide whether you are pre-installing it, teaching the install, or accepting `git filter-branch` as an answer.

Verify on a **fresh clone**, never the working copy — yours still holds reflogs and unreachable objects and will tell you a comfortable lie:

```bash
git clone https://github.com/$GH_ORG/member-portal-walkthrough1.git /tmp/verify
cd /tmp/verify
grep -rn "sk_staging_" . --exclude-dir=.git    # nothing
git log --all -S'sk_staging_' --oneline        # nothing
```

Clean.

---

## §8 — The capstone

Spring this only *after* victory is declared. Use the `PLANT` SHA you captured in §5 — the
rewrite deleted the commit from your branch, but GitHub still serves it:

```bash
gh api repos/$GH_ORG/member-portal-walkthrough1/commits/$PLANT \
  --jq '.files[] | select(.filename=="config/staging.env") | .patch'
```

```
@@ -0,0 +1,3 @@
+# Staging environment overrides — do not commit to a public repo.
+STAGING_API_KEY=sk_staging_23066a9c39d6929d...
+STAGING_BASE_URL=https://staging.internal.example.com
```

The rewrite was correct. The clone is clean. **The credential is still served by SHA** — to anyone who cloned before the rewrite, which is everyone the exercise has been worrying about. Purging it needs GitHub Support; nothing at the command line does it.

> **The conclusion writes itself:** you cannot un-publish a secret. Rotation was the only remediation. Everything after it was housekeeping.

---

## §9 — Prevent, and name the gaps

```bash
echo "*.env" >> .gitignore
# plus a pre-commit hook, or gitleaks / trufflehog as a CI step
```

The more valuable half is what it does **not** catch:

- hooks are local, optional, and bypassed by `--no-verify`
- scanners match known formats; this invented `sk_staging_` format evades most
- nothing stops a key pasted into an issue, a log, or a screenshot
- none of it touches anything already pushed

> **Note.** There is no built prevention artifact in the kit. This step is currently the student inventing something unaided, and it is also the designated extension for fast finishers.

---

## §10 — The write-up

The primary artifact. What leaked; committed 23 Mar; exposed ~5 months across three commits and two authors; found via the CI revocation notice; **rotated first at `<time>`**; history rewritten afterwards; residual risk = orphaned commits still served by SHA, plus every pre-rotation copy, now inert; prevention added, with its gaps named.

---

## Teardown

```bash
gh repo delete "$GH_ORG/member-portal-walkthrough1" --yes   # needs delete_repo scope
```

---

## Known weaknesses this walkthrough should have shown you

Walk it before you judge these — they are much more visible from inside the exercise than from the design docs.

| Weakness | Where you felt it | Severity |
|---|---|---|
| The bridge from *stale key* → *leaked key* is a **`#` comment** in the run block | §2 | **High** — gates the whole exercise |
| `config/staging.env` has **no consumer**; careful students correctly rule it out | §3 | Medium — punishes rigor |
| **Nothing forces the all-history search**; §4 offers a complete-feeling stopping point | §4→§5 | **Medium** — the tool is now listed in the brief, the prompt to use it is not |
| **CI stops pressuring at green**, before rewrite/prevent/write-up | §6 | Medium — brief must carry it |
| ~~**`gh` unmentioned** in the student README~~ | §6 | ✅ **Closed** — the brief now carries a Tooling reference covering `gh`, `git-filter-repo`, and the secrets UI path |

Cheapest fixes, in order of value: promote "reported as exposed" from a comment to an emitted `echo` line (keeps spoiler discipline — still no mention of git history); give `config/staging.env` a real consumer in the app's config loader; add a fourth completion condition to the brief requiring the student to state *how long* the credential was exposed and how they established it.
