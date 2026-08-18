# Progress — The Secret You Can't Delete

Status as of 2026-08-18: **working; deployment machinery complete.** The exercise and the tooling to deploy it to a whole class are both built and verified end-to-end against real GitHub. Not yet classroom-ready — see the gaps below. Full technical write-up in `TECHNICAL-NOTES.md`; this is the short version.

## What's built

- **A real demo repo**: [KitsWorkshop/secretkit-spike-demo7](https://github.com/KitsWorkshop/secretkit-spike-demo7) (private) — clean, unrotated, ready to walk through live.
- **`dwellkit build`** — one command builds a complete student repo from scratch: real project history (2,855 commits) + 203 more on top (200 real upstream commits with 3 exercise commits buried among them) + a GitHub Actions workflow that goes red/green on rotation. Re-runnable, ~15–50 seconds per repo.
- **`tail/`** — 203 numbered patch files: 200 genuine upstream commits plus the 3 exercise commits (plant at ~164 back from HEAD, scrub at ~83, live copy at ~7), reusable across every repo `dwellkit build` builds.
- **`floor.bundle`** — the real project history, captured once, reused every run (no network needed to rebuild).
- **`dwellkit class`** — class-scale deployment: validates a roster, builds a repo per student, invites each as a collaborator, reports results. Concurrent and re-runnable.
- **`dwellkit status`** — reports who hasn't accepted their invitation yet; `--remind` re-sends.
- **`templates/student-issue.md`** — a ticket filed in each student's repo and assigned to them: notification plus in-fiction framing. It is the *only* notification an existing org member gets, since GitHub adds members to a repo silently.
- **`templates/student-README.md`** — the student brief, installed as each repo's README at build time. Replaces the 1,568-line upstream README, states the three completion conditions, and requires an ordered log (which is what makes order-of-operations markable).
- **A CI failure that doesn't spoil itself** — the workflow fails as a plain `401 Unauthorized` from the staging API. Nothing student-visible mentions git history or rotation, including the job name, step name, and the `run:` block Actions echoes into the log.
- **Multi-org safety** — results files are named and stamped with the org and `dwellkit status` refuses a mismatched pair; preflight probes SAML authorisation, org role, outside-collaborator policy and Actions availability; `build` pins the default branch explicitly.
- **`TECHNICAL-NOTES.md`** — full phase-by-phase report: what was tested, what broke, timings, open questions.

## Verified working, live, on real GitHub

1. Fresh clone → credential findable in one file, nothing else leaking it.
2. Student deletes the file, commits, pushes → workflow stays **red** (deleting the file doesn't fix anything — that's the point).
3. Recover the deleted copy → one command.
4. Recover the *older* planted-and-scrubbed copy → one command, searches full history.
5. Rotate the secret, push → workflow turns **green**.
6. Rewrite history + force-push → fresh clones are clean, but GitHub **still serves the orphaned commit by SHA**. Purging it requires GitHub Support.

That full loop is the exercise's entire premise, and it works exactly as designed.

## Bug caught and fixed along the way

First version of the workflow file accidentally hardcoded the leaked credential in plaintext, permanently, in a tracked file — which would have quietly broken "invisible in the working tree" forever. Caught by the verification step, fixed to compare a hash instead.

## Known gaps (not oversights — deliberately out of scope or blocked, see below)

- **Push-protection format not empirically validated.** The credential format (`sk_staging_` + 40 hex) is untested against a live GitHub secret scanner — this sandbox org's plan doesn't include that feature. Biggest open risk before running this on a different GitHub environment.
- **No "prevention" step.** The full lesson (rotate → rewrite → prevent) needs a third artifact that hasn't been built — explicitly deferred.
- **GitHub Education verification not yet applied for.** Private-repo collaborators consume paid seats — a class of 30 needs 31, versus the 1 a bare Team org has. Education verification gives free Team with unlimited users. External lead time, so start it early.
- **A few throwaway repos in the org need manual deletion** (`secretkit-spike-pushtest`, `-demo1` through `-demo6`; keep `-demo7`) — the build token lacks `delete_repo` scope.

## Recommended next steps

1. Decide how to validate the credential format against a real push-protection-enabled environment (public-repo test, paid GHAS, or a low-stakes pilot).
2. Design the "prevention" extension artifact for fast finishers.
3. Apply for GitHub Education verification (external lead time; removes the per-seat cost of a class).
4. Revoke both development PATs (the build token and the one used to rename the repo) — see `TODO.md` §6.
