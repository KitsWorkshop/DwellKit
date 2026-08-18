# TODO — Remaining work before classroom-ready

Current status: **deployment machinery complete; not yet classroom-ready.** The exercise and the tooling to hand it to a class are both built and verified against real GitHub. What remains is org setup (GitHub Education), one validation step, and the teaching materials — which are the larger half.

Ordered by what blocks what. Effort estimates assume familiarity with the codebase.

---

## 0. Do this first — highest information per unit effort

- [ ] **Build one repo in the real target organisation** (~10 min)
  Run `./dwellkit build pilot1` against the organisation you will actually teach from, not the development sandbox.
  **This single action validates three separate unknowns at once:** whether push protection blocks the credential format, whether your token has sufficient permissions, and whether org policy (default branch protection, Actions restrictions, required workflows) interferes.
  *Acceptance: repo builds, push succeeds, workflow runs and reports red.*

- [ ] **Then run a group pilot** (~2 hours including debrief) — see `PILOT-RUNBOOK.md`
  3–8 colleagues acting as students. Closes item 1.1 (write-level rotate + force-push), item 2 (push-protection format), and part of item 4 (multi-repo build behaviour) in one sitting, and produces the observations the brief in §3.1 needs.
  **Include at least one participant who is not an org member** — otherwise the invitation-acceptance path, the most common class-day failure, is never exercised.

Everything below is easier to scope once this is done — in particular, item 2 may turn out to be a non-issue or may become the top priority.

---

## 1. Blockers — students cannot use this without these

### 1.1 Student access to repositories — ✅ DONE (Option A)
Implemented in `dwellkit class`: per-repo outside-collaborator invitations at `permission=push`. See `FANOUT-DESIGN.md`.
- [x] ~~**Decide the access mechanism**~~ → **Option A: outside-collaborator invitations** at `permission=push`.
  **GitHub Classroom was ruled out on a hard technical constraint**, not preference: its assignment flow provisions repos from a *template*, and templates start with a single commit. That would erase the 3,060-commit history the exercise depends on. Classroom remains usable for roster/identity only.
- [x] ~~**Build the roster mechanism**~~ → `roster.csv` + `dwellkit class`, with pre-flight validation that every username actually exists before anything is created.
- [ ] **Confirm invited students can perform every required action** (~15 min, needs a second GitHub account to test properly — or run `PILOT-RUNBOOK.md`, which closes this plus two other unknowns in one sitting)
  Verified from documentation already: **write access is sufficient** to manage Actions secrets, so students can rotate. Still worth confirming live that a write-level collaborator can also force-push (branch protection is off, so this should hold).

> **Note:** it is worth testing this end-to-end with a real second account rather than assuming. A student who cannot rotate the secret cannot complete the exercise's central action.

### 1.2 Per-student fan-out — ✅ DONE

> **See `FANOUT-DESIGN.md` for the full analysis.** Two constraints found since this list was written: (a) GitHub Classroom's template flow **starts repos with a single commit**, so it cannot provision this kit's 3,060-commit history; (b) private-repo collaborators **consume paid seats** on Team — 30 students needs 31 seats — which is removed entirely by GitHub Education verification. **Start the Education application first; it has an external lead time.**
- [x] ~~**Deterministic credentials**~~ → `sha256(student_id + KIT_SALT)` when `KIT_SALT` is set; random otherwise.
- [x] ~~**Roster loop**~~ → `dwellkit class`, idempotent (re-run skips existing repos).
- [x] ~~**Concurrency**~~ → `xargs -P`, default 5, `CONCURRENCY` overridable.
- [x] ~~**Acceptance monitoring**~~ → `dwellkit status`, with `--remind` to re-send.
- [x] ~~**Notify students that a repo exists**~~ → an issue assigned to each student, from `templates/student-issue.md`, filed in their repo. Closes the org-member gap, where `PUT .../collaborators` returns `204` and notifies nobody. The `notified` column of the results CSV records `invited` / `added-silently` / `none` per student, and the run prints the silent list.

**Still open in this area:**
- [ ] **Teardown subcommand** (~15 min) — bulk delete after the exercise. Working commands exist in `PILOT-RUNBOOK.md` §10 (list by prefix, pipe to `gh repo delete`); this item is now only about folding them into `dwellkit` as a subcommand. Needs `delete_repo` scope, which the build token lacks.
- [ ] **Retry with backoff** (~30 min) — failures are reported and retryable by re-running, but there is no automatic backoff on secondary rate limits.
- [ ] **⚠️ GitHub Education verification** (external, days) — private-repo collaborators consume paid seats; 30 students needs 31. The org is already on Team — that is what creates the cost. Education grants the same Team plan free with unlimited users. **Now the main blocker for a real cohort.** See `FANOUT-DESIGN.md`.

---

## 2. High risk — validate before any rollout

- [ ] **Validate the credential format against a live push-protection scanner** (~15 min)
  The format (`sk_staging_` + 40 hex) is **unvalidated**. No scanner was available in the development org. If your teaching org enforces push protection and this format is recognised, **every student repo fails to build simultaneously.**
  Cheapest check is item 0 above. If that org has no scanning either, test in a throwaway *public* repo, where GitHub scans free of charge regardless of plan.
  *Acceptance: a push containing the credential completes without being blocked, in an org with push protection demonstrably enabled.*

---

## 3. Required for the full lesson

### 3.1 Student-facing brief
- [x] ~~**Write the brief**~~ → `templates/student-README.md`, installed as the student repo's README at build time (step 7 of 8).
  States the scenario, the three completion conditions, and explicitly that **marking is on order of operations, not on whether the history rewrite succeeded.** Deliberately avoids the words *rotate*, *credential*, and any mention of history search — working those out is the exercise.
  It also requires an **ordered log** (`Time | What I did | Why I did it then`), written before each action. That log is what makes order-of-operations actually markable; without it, ordering has to be reconstructed from GitHub's event feed, which was rejected as unreliable (see §7).
- [ ] **Review the brief wording against a real cohort** (~30 min after the first run)
  It has never been read by an actual student. The pilot (`PILOT-RUNBOOK.md`) is the cheapest way to find out where it misleads.
- [ ] **Write the marking rubric** (~30 min)
  Suggested criteria are in `INSTRUCTOR-GUIDE.md` Part 5.
- [ ] **Write the debrief** (~30 min)
  Should push students to search *all* history, not just `HEAD~1`. The gap between "recovered the file I just deleted" and "found the exposure from months earlier" is where the lesson lives, and it is easy for a student to stop at the first one and believe they are finished.

### 3.2 Prevention artifact
- [ ] **Build the prevention component** (~1–2 hours)
  Step three of the three-step lesson (rotate → rewrite → prevent) has no built component. Also serves as the extension for fast finishers, who will otherwise be done in ten minutes.
  Candidates: a pre-commit hook, a `gitleaks`/`trufflehog` config, or enabling push protection on the student repo.
- [ ] **Write the "what this does *not* catch" discussion prompts** (~20 min)
  Arguably more valuable than the prevention itself. Every mechanism has gaps: hooks are bypassed with `--no-verify`, scanners only know patterns they have seen, and none of it helps for a credential that has already been pushed.

---

## 4. Operational hardening

- [ ] **⚠️ Fix the idempotency check — a half-built repo is silently reported as done** (~30 min)
  `dwellkit class` decides a student is already handled by asking *does the repo exist* (`cmd_deploy_one`). But `gh repo create` happens at step 3 of 7. If a build fails at step 4, 5, or 6 — network blip, rate limit, token hiccup — the repo exists but has no history, no secret, or no workflow. **Re-running skips it and reports `ok`.** The student gets a broken repository and nobody finds out until class.
  Fix: check for a completion marker rather than mere existence — e.g. that `main` has the expected commit count, or that the `STAGING_API_KEY` secret is set. Alternatively add a `--cleanup` path (needs `delete_repo` scope, which the build token lacks by default).
  This is the most likely way a real 30-student fan-out goes wrong.
- [ ] **Dry-run the full fan-out at real class size** (~30 min) — `dwellkit class` is verified at 2 students; 30 concurrent has not been run
  Rate limits look comfortable on paper (~180 API calls for 30 students against 5,000/hour) but a 30-repo burst has never actually been run. Watch for secondary rate limits, which are triggered by burst *concurrency* rather than total volume and are not visible in the standard rate-limit headers.
- [x] ~~**Decide how instructors receive the credential values**~~ → written to a gitignored `dwellkit-results-<org>-<timestamp>.csv`, and re-derivable from `student_id` + `KIT_SALT` at any time.
- [x] ~~**Make the tooling safe to run against more than one org**~~ → results files are named and stamped with the org (`# org=` provenance line); `dwellkit status` refuses a results file built for a different org than `GH_ORG`; preflight probes SAML authorisation, org role, outside-collaborator policy and Actions availability; `build` pins the default branch to `main` explicitly. See `INSTRUCTOR-GUIDE.md` Part 3.5.

---

## 5. Tuning and polish

- [x] ~~**Soften the workflow failure message**~~ → done; it now fails as a plain 401 from the staging API.
  The original message named git history and told the student to rotate, collapsing Beats 3 and 4 before they had opened a file. **The fix was not the one-line edit this item originally assumed:** Actions echoes the whole `run:` block into the log and shows job/step names in the checks UI, so the comparison logic, the job name (`check-secret-rotated`) and the step name were all student-visible too. All four were rewritten to read as an ordinary deploy rejecting a revoked credential. Nothing in the workflow now mentions git history.
- [ ] **Check the new message lands** (~during the pilot)
  It is now deliberately uninformative. Watch whether students diagnose it or stall — this is exactly what `PILOT-RUNBOOK.md` §7 is for. Becoming more helpful mid-session is easy; un-spoiling is not.
- [ ] **Consider the pre-red CI state** (~15 min of thought)
  Students clone a repository whose CI is *already* failing, before they have done anything. This may read as "the exercise is broken" rather than "there is a problem to solve." Worth either addressing in the brief or reconsidering whether the workflow should only start failing after the student's first push.
- [ ] **Review tail commit dates** (~10 min)
  The 203 tail commits are dated Feb–Aug 2026 (real upstream dates), but the workflow commit is stamped at build time. Once real build dates drift well past August 2026, there will be a visible gap in the log. Cosmetic, but exactly the sort of thing an observant student notices.

---

## 6. Housekeeping

- [x] ~~**Fix the temp-directory leak on failed builds**~~ → the `EXIT` trap referenced a `local` variable that was out of scope by the time the trap ran, so under `set -u` every failed build printed `WORKDIR: unbound variable` and left a ~40 MB checkout in `/tmp`. Same bug in `class`.
- [x] ~~**Fix failure-log paths in the results CSV**~~ → rows pointed at `$OUTDIR/<id>.build.log`, a path inside the temp directory that is deleted on exit. Logs are copied into the working directory on failure, so the CSV now records the basename that actually survives.
- [x] ~~**Translate a push-protection rejection**~~ → a blocked push (`GH013` / "push cannot contain secrets") now explains what happened, warns that it affects every student identically, and names the fix. Previously it surfaced as raw git output mid-build.
- [x] ~~**Check for required tools up front**~~ → `git`, `gh`, `curl`, `sha256sum` are checked before any work, instead of failing as "command not found" partway through.
- [x] ~~**Validate the student id**~~ → the prefix guard passed anything that merely *started* with the prefix, so `build ../evil` did 30 seconds of local work before GitHub rejected the name. Ids are now checked against `[A-Za-z0-9._-]` before any work begins.

- [ ] **Revoke the development PATs — both of them**
  **Two** classic PATs were entered in plaintext into a chat transcript: the original build token, and a second one used to rename the repository. Neither was written to any file in this repository, but both must be considered exposed. Revoke both and reissue.
- [ ] **Delete leftover development repositories** — *list unverified, check before acting*
  `secretkit-spike-pushtest`, `-demo1`, `-demo2`, `-demo3`, `-demo5`, `-demo6`, and the fan-out test repos `secretkit-ft1`/`-ft2` in the build org. Requires manual deletion — the build token lacks `delete_repo` scope.
  **Confirm what actually still exists first:** `gh repo list <org> --limit 100`. This list is from the build session and has not been re-checked since; the Codespaces token cannot see other repos in the org.
  Also delete **`-demo4`** — it was built with the earlier shallow tail and is superseded.
  **Keep `secretkit-spike-demo7`** — it is the preserved, correctly-staged demo repo, built with the current buried tail. *(These repos keep their literal `secretkit-spike-*` names because that is what they are actually called on GitHub — they predate the rename to the `hackathon-starter-` prefix.)*
- [ ] **Move to an org-scoped credential for real rollout**
  Classic PATs are not org-scoped; they grant access to everything the issuing account can reach. Replace with a fine-grained PAT restricted to the teaching org, or preferably a GitHub App installation (not tied to any individual instructor, independently revocable, auditable). See `INSTRUCTOR-GUIDE.md` Part 3.

---

## 7. Deferred / out of scope for now

Recorded so the reasoning is not lost, not because they need doing:

- **Grading harness** — automated detection of whether the student rotated *before* rewriting. The GitHub Events API does expose `PushEvent` with a `forced` field and a timestamp, but the events feed was observed to lag by several minutes and showed sparse results on private repos. Not reliable enough to build on without further investigation.
- **Shrinking the floor history** — would *add* engineering rather than remove it (the floor is not truncated at the root, so genuinely cutting it requires grafting), and it is not costing anything at current push timings.
- **Replacing `floor.bundle` with a live clone** — would trade 16 MB of storage for a network dependency and a floor that drifts as upstream commits, meaning two students could receive different repositories.

---

## Rough total

| Category | Estimated effort |
|---|---|
| ~~Access + fan-out~~ | ✅ **done** |
| GitHub Education verification | external, days — **start this first** |
| Format validation (one repo in the real org) | ~15 min |
| Group pilot + debrief (`PILOT-RUNBOOK.md`) | ~2 hours — closes 3 open unknowns |
| Teaching materials (brief, rubric, debrief, prevention) | ~3–4 hours |
| Operational hardening (teardown, retry, scale dry-run) | ~1.5 hours |
| Polish + housekeeping | ~1 hour |
| **Total remaining** | **~8 hours + Education lead time** |

**The engineering is essentially done.** What remains is teaching materials and org setup — and the brief is the piece the exercise most depends on.

The engineering is the small half. The teaching materials are the larger and more important half, and they cannot be shortcut — the exercise's value depends entirely on the brief making the marking basis explicit.
