# TODO — Remaining work before classroom-ready

Current status: **demo-ready, not classroom-ready.** The core mechanic is built and proven end to end against real GitHub. What remains is access, scale, and the surrounding teaching materials.

Ordered by what blocks what. Effort estimates assume familiarity with the codebase.

---

## 0. Do this first — highest information per unit effort

- [ ] **Build one repo in the real target organisation** (~10 min)
  Run `./spike.sh pilot1` against the organisation you will actually teach from, not the development sandbox.
  **This single action validates three separate unknowns at once:** whether push protection blocks the credential format, whether your token has sufficient permissions, and whether org policy (default branch protection, Actions restrictions, required workflows) interferes.
  *Acceptance: repo builds, push succeeds, workflow runs and reports red.*

Everything below is easier to scope once this is done — in particular, item 2 may turn out to be a non-issue or may become the top priority.

---

## 1. Blockers — students cannot use this without these

### 1.1 Student access to repositories
- [ ] **Decide the access mechanism** (design decision, ~30 min of thinking)
  Repositories are private and currently nobody is invited to them. Options:
  - **Collaborator invites** — cheapest. `PUT /repos/{org}/{repo}/collaborators/{username}` with `permission: push`. Requires a roster mapping each student to their GitHub username.
  - **GitHub Classroom** — heavier lift, but handles roster linking, accepts assignments, and integrates with an LMS. Worth it if you will run this repeatedly or alongside other assignments.
- [ ] **Build the roster mechanism** (~30 min for the collaborator path)
  A CSV of `student_id,github_username` and a loop that invites each student to their own repo.
- [ ] **Confirm invited students can perform every required action** (~15 min, needs a second GitHub account to test properly)
  Verified from documentation already: **write access is sufficient** to manage Actions secrets, so students can rotate. Still worth confirming live that a write-level collaborator can also force-push (branch protection is off, so this should hold).

> **Note:** it is worth testing this end-to-end with a real second account rather than assuming. A student who cannot rotate the secret cannot complete the exercise's central action.

### 1.2 Per-student fan-out
- [ ] **Switch the credential from random to deterministic** (~10 min)
  Currently `spike.sh` generates a random value each run. Change to `sha256(student_id + salt)`, truncated to 40 hex characters, so a repo can be rebuilt identically if something goes wrong and so the instructor can derive any student's value without having recorded it.
- [ ] **Add the roster loop** (~30 min)
  Iterate the roster, call the existing build path per student. The builder is already fully self-contained per invocation, so this is genuinely just a loop.
- [ ] **Add modest concurrency** (~15 min)
  `xargs -P 5` or equivalent. At the slower observed timing (48s/repo) thirty students is ~24 minutes serially, under 5 minutes at 5-wide.

---

## 2. High risk — validate before any rollout

- [ ] **Validate the credential format against a live push-protection scanner** (~15 min)
  The format (`sk_staging_` + 40 hex) is **unvalidated**. No scanner was available in the development org. If your teaching org enforces push protection and this format is recognised, **every student repo fails to build simultaneously.**
  Cheapest check is item 0 above. If that org has no scanning either, test in a throwaway *public* repo, where GitHub scans free of charge regardless of plan.
  *Acceptance: a push containing the credential completes without being blocked, in an org with push protection demonstrably enabled.*

---

## 3. Required for the full lesson

### 3.1 Student-facing brief
- [ ] **Write the brief** (~1 hour)
  Must state the scenario, what is expected, and critically: **that marking is on order of operations, not on whether the history rewrite succeeded.** Without this stated explicitly you will receive thirty flawless `filter-repo` invocations and no mention of rotation.
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

- [ ] **Add partial-failure handling to the builder** (~30 min)
  Currently a mid-run failure leaves a half-built repo with no cleanup or resume. Tolerable for one repo, genuinely annoying at thirty. Either make it idempotent (detect and resume) or add a `--cleanup` path.
  Note the build token needs `delete_repo` scope for cleanup to work — it does not have it by default.
- [ ] **Dry-run the full fan-out at real class size** (~30 min)
  Rate limits look comfortable on paper (~180 API calls for 30 students against 5,000/hour) but a 30-repo burst has never actually been run. Watch for secondary rate limits, which are triggered by burst *concurrency* rather than total volume and are not visible in the standard rate-limit headers.
- [ ] **Decide how instructors receive the credential values** (~15 min)
  The builder currently prints the value to stdout. At thirty students that is thirty values in terminal scrollback. Write them to a file, or (better) make them derivable from the student ID via item 1.2's deterministic hash, so they never need to be recorded at all.

---

## 5. Tuning and polish

- [ ] **Consider softening the workflow failure message** (~2 min)
  It currently reads *"STAGING_API_KEY still matches the value that leaked into git history"* — a strong hint delivered by CI at the exact moment the student should be working it out unaided. Something like *"deployment credential validation failed"* preserves the red/green signal without spoiling the reveal. One-line edit in `spike.sh`.
- [ ] **Consider the pre-red CI state** (~15 min of thought)
  Students clone a repository whose CI is *already* failing, before they have done anything. This may read as "the exercise is broken" rather than "there is a problem to solve." Worth either addressing in the brief or reconsidering whether the workflow should only start failing after the student's first push.
- [ ] **Review tail commit dates** (~10 min)
  The 203 tail commits are dated Feb–Aug 2026 (real upstream dates), but the workflow commit is stamped at build time. Once real build dates drift well past August 2026, there will be a visible gap in the log. Cosmetic, but exactly the sort of thing an observant student notices.

---

## 6. Housekeeping

- [ ] **Revoke the development PAT**
  The classic PAT used during the build was entered in plaintext into a chat transcript. It was never written to any file in this repository, but it should be considered exposed. Revoke and reissue.
- [ ] **Delete leftover development repositories**
  `secretkit-spike-pushtest`, `-demo1`, `-demo2`, `-demo3`, `-demo5`, `-demo6` in the build org. Requires manual deletion — the build token lacks `delete_repo` scope.
  Also delete **`-demo4`** — it was built with the earlier shallow tail and is superseded.
  **Keep `secretkit-spike-demo7`** — it is the preserved, correctly-staged demo repo, built with the current buried tail.
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
| Blockers (access + fan-out) | ~2 hours |
| Format validation | ~15 min |
| Teaching materials (brief, rubric, debrief, prevention) | ~3–4 hours |
| Operational hardening | ~1.5 hours |
| Polish + housekeeping | ~1 hour |
| **Total to classroom-ready** | **~8–9 hours** |

The engineering is the small half. The teaching materials are the larger and more important half, and they cannot be shortcut — the exercise's value depends entirely on the brief making the marking basis explicit.
