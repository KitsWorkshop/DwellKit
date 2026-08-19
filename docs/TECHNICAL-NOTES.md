# Technical Notes — The Secret You Can't Delete

> **This is a point-in-time report of the original build-out.** Work has continued since: the tail was rebuilt for proper burial, and class-scale fan-out (`dwellkit class`, `dwellkit status`) has been built and verified. For current status see `TODO.md`; for deployment see the README and `FANOUT-DESIGN.md`.

Status: **build-out complete**. All phases run against real GitHub (`KitsWorkshop` org). One phase (3, push-protection format testing) is unresolved on paper rather than empirically — see below, that's a real gap, not a formality.

---

## Phase 0 — Reconnaissance

The spec assumes a `~/Documents/KitsWorkshop` tree containing `kitscript/`, `kit-dev/`, `kitscript-examples-design/`, and `GitKit/` (with a captured FarmData2 copy). **None of these exist** on this machine, and the `KitsWorkshop` GitHub org (which does exist, created 2026-08-17) contains only this one repo, `DwellKit` (named `ScrubKit` at the time).

Answers to the four required questions:

1. **Do `git-mirror-to-bundle` / `git-bundle-checkout` / `git-bundle-commit` exist?** Unknown — `kitscript/` isn't reachable, so the catalog can't be checked. Per the spec's fallback, the bundle round-trip was implemented directly in plain shell instead (see "The bundle round-trip" below) — that implementation is offered as the specification for those three tasks.
2. **Is `kit-starter` reachable?** Yes — `gitlab.com/hfossedu/kits/kit-starter` is live (6 commits, GPLv3, established 2026-08-15). Under normal circumstances this would argue for bootstrapping inside it. It wasn't used here because of the operator's decision in point 3.
3. **Is FarmData2 usable as the source?** No — `GitKit/FarmData2/` doesn't exist anywhere accessible. Per the spec ("do not substitute another project on your own initiative"), I stopped and asked rather than guessing. **Operator decision: substitute a different real source project rather than fabricate history.** See below.
4. **Which repo are you working in, and why?** `KitsWorkshop/DwellKit` (this repo) — it's the one pre-provisioned scaffold in the relevant org, matches the naming convention, and the operator confirmed it as the target.

### Deviation: substitute source project

FarmData2 isn't available, so — with the operator's explicit sign-off — the floor is built from **[sahat/hackathon-starter](https://github.com/sahat/hackathon-starter)** instead:

- MIT licensed (redistribution permitted)
- 3,055 commits, 229 contributors — far more history than needed (not to be confused with the 3,060 commits of a *built student repo*: 2,855 floor + 203 tail + 2 build-time commits, workflow and README)
- Real `config/` directory and `.env.example` — a natural, unforced place for a credential to live
- An actively deployed Node.js starter app, not a library — the "config/deploy script" shape the spec asked for

### Deviation: invented author identity for the exercise commits

The spec asks for tail-commit authors "drawn from the project's real contributor list." I did not do this for the three exercise commits — attributing a credential leak to a real, identifiable person, by name and email, for a mistake they did not make, is not the kind of realism worth manufacturing even in a private teaching repo. Those three use an invented identity.

Note this became a much smaller deviation after the burial rework: the other 200 tail commits are genuine upstream commits carrying their real authors and dates, so the multi-author realism signal is now *actually real* rather than simulated. The residual tell is that one invented name appears exactly three times, always around the staging config — an acceptable price, and a legitimate find for any student who does that cross-referencing.

---

## Phase 1 — Floor

- Source: `sahat/hackathon-starter`
- Truncation point: commit `bb265d154d5a90f199a6c3df498ddfd15340cb84` (2026-02-12, "chore(deps): bump the patch-updates group with 4 updates (#1550)")
- Resulting floor: **2,855 commits**, pack size **16 MB**
- Verified: checkout at that SHA is coherent (all project files present, `npm`-project shape intact), `git log --oneline | wc -l` = 2855.
- Stored as `floor.bundle` (git bundle, single ref `floor`) in this repo rather than a live re-clone at build time — this is the plain-shell bundle round-trip (see below).

## Phase 2 — Tail

**Revised after review — see "Burial" below.** 203 commits in `tail/`, numbered patch files (`git format-patch` style): **200 genuine upstream commits** from the source project (Feb–Aug 2026, zero merge commits, real authors and dates) with **3 authored exercise commits** interleaved among them. All 203 verified applying cleanly onto the floor. No commit message contains secret/credential/key/kit/exercise outside the three intended plant/scrub/reintroduce messages, which use only "config" language.

Commit roles:

| Position in tail | Distance from HEAD | Role | Message |
|---|---|------|---------|
| 41 of 203 | ~164 back | **PLANT** | `chore: add staging config` |
| 122 of 203 | ~83 back | **SCRUB** | `chore: move staging config out of the repo` |
| 198 of 203 | ~7 back | **REINTRODUCE** (live copy at HEAD) | `chore: re-add staging config for local testing` |

All other 200 tail commits are genuine upstream project commits, unmodified.

### Burial — a design flaw found on review and fixed

The first version of the tail was 15 hand-authored commits, which put **every** exercise commit inside `git log --oneline -20`. The 2,855-commit floor sat entirely *underneath* them, so it supplied authenticity but no concealment — a student could find the plant and the scrub by scrolling, never needing to search history at all. That undercut the specific skill the exercise claims to teach.

Fixed by rebuilding the tail from the 200 real upstream commits that sit above the floor point (Feb–Aug 2026, conveniently containing zero merge commits, so `git format-patch` handles them cleanly) with the 3 exercise commits interleaved at positions 41, 122, and 198.

Results:

- Plant and scrub are no longer visible in `git log --oneline -50`; only the intended live copy is.
- `git log -S'sk_staging_'` still returns all three in **0.04s** — burial costs a student nothing *if they use the right tool*, which is precisely the desired incentive.
- Hand-authored commits dropped from 15 to 3, so the invented-author surface shrank by 80%.
- Plant-to-scrub gap became a realistic ~2.5 months (late March → early June) instead of ~5 weeks. Note this is the *believed-fixed* gap, not total exposure: the reintroduce commit puts the credential back at HEAD, so real exposure runs from late March to the present — about five months. Use that figure when debriefing.
- Build time rose only ~3s (11s → 14s) despite 13× the patches.
- `dwellkit build` required **no changes** — it already globbed `tail/*.patch` in order. Only a `--whitespace=nowarn` flag was added, to suppress cosmetic warnings from the upstream project's own whitespace quirks.

The "REINTRODUCE" commit isn't named as a separate slot in the spec, but re-reading Phase 3 closely: it describes *two* credential copies — one that's planted-then-scrubbed in older history, and a separate live copy sitting in the working tree at HEAD "so the student deletes it, commits, and feels finished." Those can't be the same commit (SCRUB removes the file), so a third commit was needed to put a live copy back before HEAD. Both credential-bearing patches store the literal placeholder `__KIT_SECRET__`, substituted by `dwellkit build` at build time.

## The bundle round-trip (spec for the missing kitscript tasks)

Since `git-mirror-to-bundle` / `git-bundle-checkout` / `git-bundle-commit` weren't reachable to check, here's exactly what was implemented in plain shell, offered as the spec for those three:

- **`git-mirror-to-bundle`**: `git branch -f <name> <sha>` then `git bundle create <file> <name>` on a full clone of the source. Gotcha: `git bundle create <file> <sha>` directly (without a named ref) fails with "Refusing to create empty bundle" — bundles need a ref, not a bare commit.
- **`git-bundle-checkout`**: `git clone <bundle-file> <dir>`. Gotcha: the clone leaves the branch as `origin/<name>`, not a local branch, and prints `warning: remote HEAD refers to nonexistent ref` because the bundle has no HEAD symref — you must `git checkout -b <local-name> origin/<name>` explicitly, and `git remote remove origin` afterward if you intend to push somewhere else via a freshly-added `origin`.
- **`git-bundle-commit`**: not yet exercised — this would be the equivalent of `git am --committer-date-is-author-date <patch>` against a bundle-sourced checkout, which `dwellkit build` already does for the tail series.

## Phase 6 — Package (partial)

`dwellkit build` exists and is re-runnable (verified: running it twice with different suffixes attempted two independent repo names; only blocked at the GitHub-write step, not by any local state collision). Steps 1–2 (bundle checkout + tail apply with `__KIT_SECRET__` substitution) verified working end-to-end locally.

**Timing (steps 1–2 only):** unpacking the floor bundle + applying all 203 tail patches: **~5 seconds combined** when this was written, on this machine, from a local bundle file (no network). The Burial section under Phase 2 records ~14s for the same steps after the tail grew to 203 patches; treat that as the current figure. This suggests the floor/tail portion of the pipeline is not the bottleneck for a 30-student fan-out; the GitHub API calls (repo create, push, secret set) will dominate wall-clock and are not yet timed.

---

## Phase 3 — Credential format vs. push protection

**Empirical result: push protection could not be tested live, and that inability is itself the finding.**

Sanity-checked first with a known, universally-recognized pattern (fake AWS access key, `AKIA` + 16 alnum) pushed to a private throwaway repo (`secretkit-spike-pushtest`) under the prefix. It was **allowed through** — not because the format evaded detection, but because secret scanning / push protection is disabled, both on the repo (`security_and_analysis.secret_scanning_push_protection: "disabled"`) and as the org-wide default (`secret_scanning_push_protection_enabled_for_new_repositories: false`). The `KitsWorkshop` org is on GitHub's Team plan; private-repo secret scanning requires GitHub Advanced Security, a separate paid add-on not purchased here, and turning it on isn't an API call — it needs a billing admin in the web UI.

A free path existed — GitHub runs secret scanning + push protection on all **public** repos regardless of plan — but taking it would have meant breaking the spec's own hard guardrail ("all created repositories must be private") for a test repo. Operator's call: don't do that; skip live testing.

**Consequence:** no format table was produced. `dwellkit build` uses the format the spec itself proposes on paper — `sk_staging_` + 40 hex characters — untested against a real scanner. **This is a real gap, not a formality**: if the actual rollout org (e.g. an institutional GitHub Enterprise/Education org, which often bundles secret scanning differently than a bare Team-plan sandbox) has push protection on, this format has not been verified to get past it. Before running this against real students, either (a) test against a public throwaway repo with explicit sign-off to bypass the private-only guardrail for that one test, or (b) get GHAS enabled (paid) on a private repo, or (c) run the first real fan-out against a low-stakes pilot org where a blocked push is a cheap failure to observe.

## Phase 4 — Push, secret, workflow

Ran for real against `KitsWorkshop/secretkit-spike-demo4` (superseded; the current demo repo is `-demo7`, rebuilt after the burial rework) using a classic PAT (`repo` + `workflow` scopes) the operator supplied. Full `dwellkit build` run: **48s** wall clock (steps 3–6, all GitHub API calls; steps 1–2 are local and near-instant — see Phase 6 timings). An earlier run of the same repo-creation step against a different suffix completed in **9–13s**; the variance looks like GitHub API/network jitter, not a systemic issue — worth budgeting for on a 30-repo fan-out.

Secret encryption was initially implemented with PyNaCl's `SealedBox` against the repo's Actions public key, per GitHub's documented flow (`GET .../actions/secrets/public-key` → `crypto_box_seal` → `PUT .../actions/secrets/STAGING_API_KEY`), as the agent-spec instructed ("this requires libsodium sealed-box encryption... implement it inline").

**That instruction was wrong, and the spec's premise with it.** `gh secret set STAGING_API_KEY --body "$VALUE" --repo "$ORG/$REPO"` performs the sealed-box encryption locally before transmitting — it is a documented feature of the CLI, not a shortcut around the crypto. Verified equivalent end-to-end: a secret written via `gh secret set` produces a red workflow when it matches the leaked value and a green one after rotation. **Replaced ~19 lines and the entire PyNaCl dependency with one line.** The spec's "do not build a polished reusable task" instruction was sound; it just didn't know the tool already existed.

**Bug found and fixed while building this**: the first version of `dwellkit build` hardcoded the raw leaked credential value into `.github/workflows/staging-deploy.yml` (to compare against `secrets.STAGING_API_KEY`). That file is tracked and permanent — so the plaintext secret would sit in the working tree at every commit going forward, forever, even after a student "successfully" deletes `config/staging.env` and rotates. Fixed by comparing a SHA-256 hash of the leaked value instead of the raw value; confirmed via `grep -r` that after the fix only the one intended live copy (`config/staging.env`) is found anywhere in the tree.

## Phase 5 — Proving the reveal

Ran as a student would, against `secretkit-spike-demo2` (used for this destructive phase so the demo repo stays intact for a live demo). All six steps behaved correctly:

1. **Fresh clone, grep the tree.** Found exactly one match (`config/staging.env`) — see the Phase 4 bug note above; this step is what caught that bug on the first pass, when it found *two* matches instead of one. **Note on spec wording**: step 1 says "confirm nothing in the working tree contains the credential: grep -r finds nothing" — read completely literally, that's impossible to satisfy simultaneously with Phase 3's own requirement that a live copy sit in the tree at HEAD (and with Background's framing that the student "finds one in the working tree"). Read as "confirm the *only* thing grep finds is the one intended live copy, not some other accidental leak," it works, has real teeth, and is exactly what caught the workflow-file bug. Went with that reading; flagging the wording tension rather than silently resolving it.
2. **Delete the visible file, commit, push.** Workflow ran **red** immediately (`failure`) — correct: deleting the tracked file doesn't touch the actual secret, so the mismatch against the leaked-value hash persists. This is the moment the exercise is testing: the student's fix didn't fix anything.
3. **Recover the just-deleted copy.** One command: `git show HEAD~1:config/staging.env`. Instant.
4. **Recover the older planted-then-scrubbed copy.** `git log -p --all -S'sk_staging_' -- config/staging.env`. Surfaces the full timeline — add (PLANT), remove (SCRUB), add (REINTRODUCE), remove (student's step 2) — in one command. This is the actual "aha": a student who only checked `git show HEAD~1` (step 3) would still miss that the same value was committed and removed months earlier, further back, exactly as the Background section describes.
5. **Rotate.** New secret value sealed-box-encrypted and set via the API; pushed a trivial commit to trigger a new workflow run (secret changes alone don't trigger `on: push`). Workflow went **green** (`success`).
6. **History rewrite + force-push.** `git filter-repo --path config/staging.env --invert-paths --force`, force-pushed. Fresh clone from the remote afterward: `grep -r` found nothing, `git log --all -S'sk_staging_'` found nothing.

**Correction to an earlier claim in this document.** This was originally recorded as "the credential is no longer recoverable from the remote." That is **only true for clones.** Re-tested explicitly afterwards: GitHub retains the orphaned commits and still serves them by SHA. Against a repo where the rewrite had succeeded and a fresh clone was verifiably clean:

```
$ gh api repos/<org>/<repo>/commits/d7491058a717e8300df78b4e7f6f11473beb609c \
    --jq '.files[] | select(.filename=="config/staging.env") | .patch'
+STAGING_API_KEY=sk_staging_23066a9c39d6929d...
```

The full credential comes back. Anyone who cloned before the rewrite knows that SHA. Purging it requires contacting GitHub Support to force garbage collection — nothing the student (or instructor) can do from the CLI removes it.

**This is a gift to the exercise, not a defect.** It is the most concrete possible demonstration of the actual lesson: rotation was the only step that reduced risk, and even a technically perfect history rewrite does not un-publish a secret. It is written up as the optional "capstone" beat in `STUDENT-EXPERIENCE.md`.

**Assessment of whether the reveal lands:** yes, and it lands *because* of step 4, not step 3. Deleting the visible file and recovering it from `HEAD~1` (step 3) is the "trap" — undo the delete, remove the credential, done. It's step 4 (searching *all* history, not just the immediate parent) that reveals the credential was compromised months earlier too, which is what should push a thoughtful student toward "rotate first" instead of "clean up history first." If anything felt flat: the gap between steps 3 and 4 might be too easy to miss for a student who stops as soon as `HEAD~1` "solves" the puzzle — the debrief materials (out of scope here) will need to make sure students are pushed to search *all* history, not just the last commit, before they're allowed to feel done.

## Phase 6 — Package (complete)

> **Superseded timing.** The "under 2 seconds" figure below was measured against the *original* 15-commit tail. After the burial rework (203 patches, 13× more) the same steps take **~14s** — see the Burial section under Phase 2, which is the current number. The conclusion is unchanged: the local portion is not the bottleneck.

`dwellkit build` is re-runnable end to end: `demo1`, `demo2`, and `demo4` are three independently built repos from three suffixes (`demo1` was the pre-bugfix build, kept as-is rather than cleaned up — see below; `demo3` is a partial/broken build from mid-bugfix, also not cleaned up). Steps 1–2 (bundle checkout + tail apply): **under 2 seconds combined**, local, no network. Steps 3–6 (repo create, push, secret, workflow): **9–48 seconds**, dominated entirely by GitHub API calls and network variance, not by anything in this repo's control.

**Fan-out feasibility for ~30 students**: at the *slower* end observed (48s/repo) that's ~24 minutes if run serially, or well under 5 minutes with even modest parallelism (5-wide). The local floor/tail portion is not a bottleneck at any scale tested. GitHub API rate limits weren't hit during development (a handful of repos), but haven't been checked against a real 30-repo burst — worth a dry run before relying on this for a live class.

## Phase 7 — What was fiddly (ranked)

1. **Bundle-from-a-bare-SHA gotchas** (see "the bundle round-trip" above) — `git bundle create` refusing a bare commit, and the `origin/<branch>` vs local-branch naming after cloning a bundle. Small, but cost real debugging time and is exactly the kind of thing worth baking into the eventual `git-bundle-checkout`/`git-mirror-to-bundle` tasks so nobody re-discovers it.
2. **The GitHub-write-access token story** — three different failure modes stacked: the ambient Codespaces token couldn't create org repos or touch secrets (app-installation token, wrong permission model); classic PATs turned out not to be org-scoped at all (broader than needed); and the org itself didn't have GHAS, which wasn't obvious until actually probing `security_and_analysis` on a live repo. None of this is hard, but all of it needed to be discovered empirically rather than assumed.
3. **The plaintext-secret-in-workflow-file bug** (Phase 4) — an easy mistake to make (the spec's own wording, "fails if it matches the known-leaked value," reads naturally as "hardcode the value") and one that would have quietly undermined the entire "invisible in the working tree" premise if Phase 5 step 1's grep check hadn't caught it. Good argument for keeping that check even though its literal wording is imprecise.
4. **libsodium sealed-box encryption** — the step that sounded scariest on paper turned out not to be a step at all. Implemented by hand with PyNaCl first (which worked fine), then deleted entirely on discovering `gh secret set` already does it. The fiddliness here was self-inflicted: the spec asserted the hand-rolled approach was required, and that assertion went unchecked. Worth a general note for the eventual kitscript tasks — **check whether `gh` already covers a GitHub operation before hand-rolling it against the REST API.**
5. **Push protection being off** — not fiddly exactly, but a genuine dead end: the empirical test the spec cares most about simply isn't runnable in this sandbox without either a paid upgrade or breaking a hard guardrail. Surprising, in that "GitHub push protection will block a fake credential" turned out to be an assumption that doesn't hold universally even on paid org plans.

## Open questions (not resolved)

- **Push protection credential-format table** — not produced. `dwellkit build` ships with the spec's own suggested format (`sk_staging_` + 40 hex) untested against a live scanner. This is the single biggest open risk before running this against real students on a different GitHub environment. See Phase 3 above for the three ways to close this gap.
- **GitHub Events API `PushEvent.forced`** — checked empirically (not implemented, per Non-goals): `GET /repos/{owner}/{repo}/events` does return `PushEvent` payloads with a `forced` field and a `created_at` timestamp on the event ([docs](https://docs.github.com/en/rest/using-the-rest-api/github-event-types#pushevent)) — so yes, the field exists. Caveat worth flagging: on a private repo in this org, the events feed showed only one event total and appears to lag real time by more than a few minutes (a force-push made ~5+ minutes earlier hadn't appeared yet). Whatever grading harness eventually reads this should not assume near-real-time delivery.
- **Who holds the provisioning credential at rollout time?** Not students — it's an operator/CI-side credential used once per fan-out run; students only ever receive a repo URL. For real rollout, recommend a GitHub App installation (narrower, org-scoped, revocable independent of any one person) over a personal classic PAT — see the note left in-line above. Same `gh api` calls in `dwellkit build`, different auth source.
- **Leftover repos in `KitsWorkshop` needing manual cleanup** — *this is the list as it stood at the end of the build session; `TODO.md` §6 is the one to act from.* The token used has `repo`+`workflow` scopes but not `delete_repo`, so none of these could be cleaned up programmatically: `secretkit-spike-pushtest` (empty, harmless), `secretkit-spike-demo1` (pre-bugfix build, has the plaintext-secret-in-workflow issue in its history), `secretkit-spike-demo3` (partial build, missing its workflow commit), `secretkit-spike-demo2` (post-`filter-repo` rewrite, used up for Phase 5 destructive testing). `secretkit-spike-demo4` and `-demo6` are superseded builds from before/during the burial rework. **`secretkit-spike-demo7`** is the one intentionally kept clean for a demo.
- **Two classic PATs were pasted directly into chat** — the build token, and a second one used to rename the repository. Per the hard guardrail against committing credentials, neither was written into any file inside this repo, but both are sitting in the conversation transcript in plaintext. Revoke both and cut fresh ones for any future session.
