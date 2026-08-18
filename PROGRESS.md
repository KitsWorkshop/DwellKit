# Progress — The Secret You Can't Delete

Status as of 2026-08-18: **working, demo-ready.** Core mechanic built and verified end-to-end against real GitHub. Full technical write-up in `SPIKE-FINDINGS.md`; this is the short version.

## What's built

- **A real demo repo**: [KitsWorkshop/secretkit-spike-demo7](https://github.com/KitsWorkshop/secretkit-spike-demo7) (private) — clean, unrotated, ready to walk through live.
- **`spike.sh`** — one command builds a complete student repo from scratch: real project history (2,855 commits) + 203 more on top (200 real upstream commits with 3 exercise commits buried among them) + a GitHub Actions workflow that goes red/green on rotation. Re-runnable, ~15–50 seconds per repo.
- **`tail/`** — 203 numbered patch files: 200 genuine upstream commits plus the 3 exercise commits (plant at ~163 back from HEAD, scrub at ~82, live copy at ~6), reusable across every repo `spike.sh` builds.
- **`floor.bundle`** — the real project history, captured once, reused every run (no network needed to rebuild).
- **`SPIKE-FINDINGS.md`** — full phase-by-phase report: what was tested, what broke, timings, open questions.

## Verified working, live, on real GitHub

1. Fresh clone → credential findable in one file, nothing else leaking it.
2. Student deletes the file, commits, pushes → workflow stays **red** (deleting the file doesn't fix anything — that's the point).
3. Recover the deleted copy → one command.
4. Recover the *older* planted-and-scrubbed copy → one command, searches full history.
5. Rotate the secret, push → workflow turns **green**.
6. Rewrite history + force-push → credential no longer recoverable from the remote.

That full loop is the exercise's entire premise, and it works exactly as designed.

## Bug caught and fixed along the way

First version of the workflow file accidentally hardcoded the leaked credential in plaintext, permanently, in a tracked file — which would have quietly broken "invisible in the working tree" forever. Caught by the verification step, fixed to compare a hash instead.

## Known gaps (not oversights — deliberately out of scope or blocked, see below)

- **Push-protection format not empirically validated.** The credential format (`sk_staging_` + 40 hex) is untested against a live GitHub secret scanner — this sandbox org's plan doesn't include that feature. Biggest open risk before running this on a different GitHub environment.
- **No "prevention" step.** The full lesson (rotate → rewrite → prevent) needs a third artifact this spike didn't build — explicitly deferred.
- **No per-student fan-out.** Today's deliverable is one repo + a reusable builder script, not 30 repos for a real roster — explicitly out of scope for this spike.
- **A few throwaway repos in the org need manual deletion** (`secretkit-spike-pushtest`, `-demo1`, `-demo2`, `-demo3`) — the token used doesn't have delete permission.

## Recommended next steps

1. Decide how to validate the credential format against a real push-protection-enabled environment (public-repo test, paid GHAS, or a low-stakes pilot).
2. Design the "prevention" extension artifact for fast finishers.
3. Design the per-student fan-out (the spec's own answer: `sha256(student_id + salt)`, driven by a `foreach:` once this moves into kitscript).
4. Revoke the PAT used for today's build once you're done with it.
