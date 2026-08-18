# Agent Spec — Secret Kit, Day-One Spike

> **Historical note:** this is the original specification, kept unedited. Names have since changed: `spike.sh` is now `build-repo.sh`, `SPIKE-FINDINGS.md` is now `TECHNICAL-NOTES.md`, and the default `KIT_PREFIX` is now `hackathon-starter-`. Several assumptions here were also revised during the build; where they conflict, `TECHNICAL-NOTES.md` is authoritative.

Hand this to Claude Code as the task. It assumes no prior context beyond what it can read on disk.

---

## Mission

Build **one** working student repository for a teaching exercise called *The Secret You Can't Delete*, and package the steps that made it into a repeatable script. Prove the exercise's central reveal actually works against real GitHub.

This is a spike, not a product. The goal is information: which parts of this are easy, which are fiddly, and what GitHub does when you try to push a credential on purpose.

**You are done when** a single command produces a private GitHub repo in which a credential is invisible in the working tree, recoverable from history in one command, and rotatable through a repo secret — and you have written down what broke on the way.

---

## Background — the exercise

A student is handed a repository and told a credential was committed to it. They find one in the working tree, delete it, commit, and feel finished. They are not: the credential is still fully recoverable from history, and it was also committed and "removed" months earlier, further back.

The real assessment is **order of operations**. The correct first move is to *rotate* the credential — it is already compromised, and rewriting history does nothing about copies that already exist. Most people go straight for the history rewrite because it is the technically impressive part. The exercise exists to make that mistake happen somewhere cheap.

You are building the artifact that makes that possible. You are not writing the student-facing materials.

---

## Phase 0 — Reconnaissance. Stop and report before building.

Read before deciding anything. Under `~/Documents/KitsWorkshop` (or wherever this repo tree sits) there are four projects:

- `kitscript/` — the YAML script runner. Read `examples/annotated-example.yaml`, `docs/scripts.md`, and `src/kitscript/commands/` to learn what constructs exist (`foreach:`, `with: services:`, `run_container`).
- `kit-dev/` — the `kit` CLI. Read `src/main.sh` and `src/lib/*.sh` for the phase structure (`capture` / `prepare` / `build-deploy` / `deploy` / `release`).
- `kitscript-examples-design/` — read `docs/mini-kits/catalog.md` and all four mini-kit designs. These define the expected kit repo shape.
- `GitKit/` — a real, working kit. Read `kit_deploy_config.yaml`, `deploy.sh`, `FarmData2/deploy.sh`, and `docs/deploy.md`. Note that `GitKit/FarmData2/` contains a captured copy of the FarmData2 project.

**Then answer these four questions in a written report and stop:**

1. **Do `git-mirror-to-bundle`, `git-bundle-checkout`, and `git-bundle-commit` exist yet?** The mini-kit catalog says all four kits are blocked on them. Check whether that is still true. If they exist, use them. If not, do the bundle round-trip in plain shell and note precisely what you had to implement — that becomes the specification for those tasks.
2. **Is `kit-starter` reachable?** The catalog says kits are bootstrapped from `gitlab.com/hfossedu/kits/kit-starter`. If you can reach and read it, recommend building inside a repo bootstrapped from it. If you cannot, recommend a standalone scratch repo and say so plainly.
3. **Is FarmData2 usable as the source?** It is already captured under `GitKit/FarmData2/` and is the intended source for this spike. Confirm it has enough history, a plausible place a credential would live (a config directory, a `.env`-ish file, a deploy script), and a licence permitting redistribution. If any of that fails, say which and stop — do not substitute another project on your own initiative.
4. **Which repo are you working in, and why?** Your call, based on 1–3.

Do not write code before this report. If the answers contradict anything in this spec, the answers win — say so and propose the amendment.

---

## Environment

The operator supplies:

- `GH_TOKEN` — classic PAT with `repo` (all) and `workflow` scopes
- `GH_ORG` — a **throwaway** GitHub organisation created for this work
- `KIT_PREFIX` — repo name prefix, default `secretkit-spike-`

If any is unset, stop and ask. Do not fall back to a personal namespace.

---

## Hard guardrails

- **Only create or modify repositories whose name starts with `$KIT_PREFIX`, inside `$GH_ORG`.** Never touch anything else. Never delete a repository you did not create in this session.
- **All created repositories must be private.**
- **Never disable org-level or repo-level secret scanning or push protection.** If push protection blocks you, that is a finding to work around by changing the credential format, not a setting to switch off. This is not negotiable — the workaround is the point (see Phase 3).
- **Never commit a real credential of any kind**, including the operator's `GH_TOKEN`, to any repository, including the working one.
- Do not install anything globally without asking. `git-filter-repo` may be needed; ask first.
- Force-pushing is fine, but only to repos you created under the prefix.

---

## Phase 1 — Floor: authentic history

From the captured FarmData2 history, produce a truncated bare repository ending at a chosen commit. This is the noise the plant will be buried in.

- Choose a truncation point leaving at least a few hundred commits of real history.
- Record the chosen SHA and the resulting commit count and pack size in your notes.
- Verify: `git log --oneline | wc -l` on a checkout, and that the tree at HEAD is coherent (the project's own files are all present).

**Do not rewrite this history.** It is the floor and it stays untouched. Everything you add goes on top.

---

## Phase 2 — Tail: a scripted patch series

Author roughly fifteen commits that sit on top of the floor and read as ordinary project work. Store them as patch files (`git format-patch` style) in a `tail/` directory, numbered.

Requirements:

- **Plausible messages.** `refactor: extract config loading`, `fix: handle missing locale`. Nothing that hints at an exercise. No commit message may contain the words secret, credential, key, kit, or exercise — except where the exercise intends it (Phase 3).
- **Plausible author identities and dates**, drawn from the project's real contributor list, continuing its existing cadence. A tail where every commit is authored by the same person on the same afternoon defeats the purpose.
- **Real diffs.** Small but genuine changes to real files. Do not commit placeholder files.
- Two positions are reserved as slots, filled in Phase 3.

Verify: apply the series to a checkout of the floor and confirm `git log --oneline -20` is indistinguishable, to a reader, from the real history below it.

---

## Phase 3 — The plant, the scrub, and the credential format

**The credential format is the most important empirical question in this spike. Resolve it first.**

GitHub push protection blocks pushes containing recognised credential patterns — AWS keys, GitHub tokens, Stripe keys and similar. A realistic-looking plant is exactly what it is designed to stop, and it will fail the push for every student at once.

The intended answer is an invented vendor format that reads as an API key to a student but matches no scanner — for example `sk_staging_` followed by forty hex characters. **Test this empirically:**

1. Push a candidate format to a throwaway repo under the prefix.
2. Record whether push protection blocked it.
3. If blocked, adjust and retry. Record every format you tried and the outcome.

This table of what was and was not blocked is a primary deliverable. Do not skip recording the failures.

Once the format is settled, fill the two reserved slots:

- **PLANT** — a commit adding a config file containing the credential, with a message like `chore: add staging config`.
- **SCRUB** — a later commit removing that file, message like `chore: move staging config out of the repo`. At least four further tail commits must sit above SCRUB so the removal is not the most recent thing in the log.

Store both patches with the credential replaced by the literal placeholder `__KIT_SECRET__`, substituted at build time. The spike uses one hardcoded value; per-student seeding is explicitly out of scope (see Non-goals).

**Second credential, same value.** A live copy must sit in the working tree at HEAD — `config/staging.env` or similar — so the student deletes it, commits, and feels finished before discovering it was never gone. Same value as the planted one: it reads as one key that has been in and out of this repo for months.

---

## Phase 4 — Push, secret, workflow

1. Create the private repo in `$GH_ORG` under the prefix.
2. Push the floor plus the applied tail.
3. Set an Actions repo secret `STAGING_API_KEY` to the credential value. This requires libsodium sealed-box encryption against the repo's public key — implement it inline, do not build a polished reusable task.
4. Add `.github/workflows/staging-deploy.yml`, running on push, which reads `secrets.STAGING_API_KEY` and **fails if it matches the known-leaked value, passes otherwise**. Keep it under thirty seconds.
5. Confirm branch protection is off and the workflow can be triggered.

---

## Phase 5 — Prove the reveal

This is the phase that decides whether the exercise works. Do it as a student would, and record the output of each step verbatim.

1. Clone the repo fresh. Confirm nothing in the working tree contains the credential: `grep -r` finds nothing.
2. Delete the visible config file, commit, push. Confirm the workflow run is **red**.
3. Recover the credential from history in one command. Record the exact command and its output (redact the value in your notes).
4. Recover the *earlier* planted copy, which requires searching history rather than the current file — `git log -p --all -S'<prefix>'` or equivalent. Record the command.
5. Rotate: change the repo secret to a new value, push. Confirm the workflow run is now **green**.
6. Confirm that after a history rewrite (`git filter-repo` or equivalent) plus force-push, the credential is no longer recoverable from the remote.

If any of steps 1–6 does not behave as described, **stop and report**. A failure here is the most valuable output this spike can produce and it must not be papered over.

---

## Phase 6 — Package

Collapse everything into `spike.sh`, which takes a repo suffix and produces a complete student repo from scratch. It must be re-runnable: running it twice with different suffixes yields two independent repos.

Keep it plain shell and readable. This script is a specification for the eventual `script-deploy.yaml`, so favour clarity over cleverness, and comment each step with what it will eventually become.

---

## Phase 7 — Report

Write `SPIKE-FINDINGS.md` covering:

- **Push protection results** — every credential format tried, and what happened. Table.
- **The bundle round-trip** — whether the three microtasks existed, and if not, exactly what you implemented in their place, framed as a specification for them.
- **Timings** — how long the truncate, the tail application, and the push each took. This determines whether thirty students is feasible and how the fan-out must be structured.
- **What was fiddly** — ranked. Be specific and be honest; a spike that reports everything went smoothly has not been useful.
- **Whether the reveal actually lands** — your assessment, having done it as a student would. Say so if it feels flat.
- **Open questions** you hit and did not resolve.

---

## Non-goals — do not build these

- **Per-student variation.** No seeding, no roster, no `foreach:`. One repo. The eventual design derives everything from `sha256(student_id + salt)`; note where that hook belongs and move on.
- **Polished kitscript tasks.** No `github-repo-secret-set`, no `git-tail-apply` as reusable images. Inline shell is correct here.
- **Student-facing materials.** No brief, no debrief, no rubric.
- **The grading harness.** In particular, do not build the timestamp comparison that determines whether the student rotated before rewriting. Note in your findings whether the GitHub Events API exposes `PushEvent` with `forced: true` and a usable timestamp — a yes/no with a link, not an implementation.
- **A different source project.** If FarmData2 fails Phase 0's check, stop and report rather than substituting.

---

## Working style

- Report after Phase 0 and after Phase 5. Those are the two points where a wrong answer is cheap to correct and expensive to carry.
- Prefer stopping and asking over guessing, on anything touching the operator's GitHub org.
- Keep a running log of commands that failed and why. That log is worth more than the code.
