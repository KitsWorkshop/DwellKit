# DwellKit — "The Secret You Can't Delete"

A teaching kit for a git exercise about leaked credentials.

Students receive a private repository with a real, plausible commit history. Somewhere in that history a staging credential was committed, and later "removed" in a tidy cleanup commit. The credential is still live, still in CI, and still recoverable — and the removal commit is what makes people believe otherwise.

**The exercise assesses order of operations: rotate → rewrite → prevent.** Most students go straight for the impressive history rewrite. Rewriting first accomplishes nothing, because the credential is already compromised the moment it is pushed. That gap is the entire lesson.

*Dwell time* is how long a compromise sits undetected. Students reliably find the credential they deleted a minute ago; the one that has been exposed since March is the one they walk past. The name points at the dimension the exercise is really testing.

> ⚠️ **This repository is instructor-only.** It contains the answers, the model solution, and the mechanism. Do not hand it to a cohort.

---

## Start here

| If you want to… | Read |
|---|---|
| Understand the kit from zero — concepts, design decisions, infrastructure | [INSTRUCTOR-GUIDE.md](docs/INSTRUCTOR-GUIDE.md) |
| Deploy to a whole class | [Deploying to a class](#deploying-to-a-class), below |
| Understand the class-scale constraints (billing, GitHub Classroom) | [FANOUT-DESIGN.md](docs/FANOUT-DESIGN.md) |
| Trial it with colleagues before a real cohort | [PILOT-RUNBOOK.md](docs/PILOT-RUNBOOK.md) |
| Know what students actually experience, and how to mark it | [STUDENT-EXPERIENCE.md](docs/STUDENT-EXPERIENCE.md) |
| Brief colleagues or stakeholders | [SLIDES.md](docs/SLIDES.md) (Marp) |
| Know what still needs building | [TODO.md](docs/TODO.md) |
| Know what was tested, what broke, and what is still unproven | [TECHNICAL-NOTES.md](docs/TECHNICAL-NOTES.md) |
| Report status upward | [PROGRESS.md](docs/PROGRESS.md) |

---

## Quick start

Requires `git`, `gh` (authenticated), `python3`, and a token with `repo` + `workflow` scope on the target org.

Deploying to a class.

```bash
# 1. Environment. Keep KIT_SALT — it re-derives any student's credential later.
export GH_TOKEN=...        # repo + workflow scope on the target org
export GH_ORG=your-org
export KIT_SALT=...        # any secret string, one per class/cohort

# 2. First time in this org? Build one throwaway repo and delete it.
#    This is the only way to test push protection, which fails ALL students at once.
#    (delete needs delete_repo scope; otherwise remove it in the web UI)
./dwellkit build pilot1
gh repo delete "$GH_ORG/hackathon-starter-pilot1" --yes

# 3. Roster: one row per student, "student_id,github_username", header required.
cp roster.example.csv roster.csv && $EDITOR roster.csv

# 4. Validate the roster. Creates nothing. Refuses the whole run on one bad username.
./dwellkit class roster.csv --dry-run

# 5. Deploy. ~3 minutes for 20 students. Re-run freely — existing repos are skipped.
./dwellkit class roster.csv

# 6. Chase invitations daily until everyone shows "accepted".
#    An unaccepted invitation means a student cannot clone. This is the step that bites.
./dwellkit status dwellkit-results-$GH_ORG-*.csv
./dwellkit status dwellkit-results-$GH_ORG-*.csv --remind
```

Two things this sequence assumes you have already dealt with — both covered in
[Deploying to a class](#deploying-to-a-class):

- **Paid seats.** 20 students needs 21 on Team. Sort GitHub Education verification first; it has
  external lead time.
- **The student brief.** It ships in `templates/student-README.md` and is installed into every
  student repo automatically — but read it once before a cohort does.

<details>
<summary><strong>Building a single repository</strong> — rarely needed, two cases</summary>

```bash
./dwellkit build alice     # → $GH_ORG/hackathon-starter-alice
```

`class` calls this once per roster row, so it is not a separate workflow. You would run it
directly only to:

- **test push protection in a new org** (step 2 of the quickstart), or
- **rebuild for one student mid-session.** There is no reset path once a student has rotated and
  rewritten, and re-running `class` will *not* help — it skips repositories that already exist.
  Build a fresh one under a new id (`./dwellkit build alice-retry`) and invite them to it.

</details>

---

## Deploying to a class

The commands are in [Quick start](#quick-start) above. This section is the surrounding
work — what to do weeks ahead, what to check before handover, and what to clean up after.

Roughly 20 minutes of hands-on work for 20 students, spread across two weeks. The commands are
fast; the waiting is not.

### Before you commit to a date

- [ ] **Apply for [GitHub Education](https://education.github.com/) verification.** Collaborators on
      **private** repos consume paid seats — 20 students needs 21. Education grants the same Team
      plan free with unlimited users. It has external lead time, so start it first.
      *(Being on Team is what creates the cost; it is not something to upgrade away from.)*
- [ ] **Get a token scoped to the teaching org** — a fine-grained PAT or a GitHub App install,
      with `repo` + `workflow`. Not a personal classic PAT: those reach every repo the issuing
      account can see.
- [ ] **Run one build in the real teaching org** — `./dwellkit build pilot1`. This single action
      checks push protection, token permissions, and org policy at once. Delete it afterwards.
- [ ] **Run a group pilot** — [PILOT-RUNBOOK.md](docs/PILOT-RUNBOOK.md). Optional, but it closes
      the one genuinely untested question: whether a write-level collaborator can rotate the
      Actions secret and force-push.
- [ ] **Review the student brief.** It ships in `templates/student-README.md` and is installed as
      the repository's README at build time, so every student reads it on arrival. It already
      states that marking is on *order of operations* and asks for an ordered log. Read it once
      and adjust the wording to your cohort. The **rubric and debrief** are still unwritten
      ([TODO.md](docs/TODO.md) §3.1).

### Two to three days before

**1. Build the roster.** One row per student. `student_id` becomes the repo suffix, so keep it
short and lowercase.

```bash
cp roster.example.csv roster.csv
```

```csv
student_id,github_username
amara,amara-gh
devin,devin-codes
```

Usernames must be exact. `dwellkit class` validates every one against GitHub and **refuses to
create anything if any row is bad**, so one typo blocks the whole run — which is the behaviour
you want, but it means getting them right matters.

**2. Set the environment.**

```bash
export GH_TOKEN=<org-scoped token: repo + workflow>
export GH_ORG=<teaching org>
export KIT_SALT=<any secret string — write it down and keep it>
```

`KIT_SALT` makes each student's credential reproducible. Keep it and you can re-derive any
value later without having recorded twenty of them:

```bash
printf 'sk_staging_%s\n' "$(printf '%s' "${STUDENT_ID}${KIT_SALT}" | sha256sum | cut -c1-40)"
```

**3. Validate, then deploy.**

```bash
./dwellkit class roster.csv --dry-run   # checks every username, creates nothing
./dwellkit class roster.csv             # builds, invites, writes dwellkit-results-<org>-<ts>.csv
```

⏱ About 15–50 seconds per repo, 5 at a time — roughly 3 minutes for 20 students.

Re-runnable: if anything fails, run the identical command again. Existing repos are skipped and
invitations are re-sent.

> The results CSV contains **live credential values**. It is gitignored. Don't commit or paste it.

### The week before — chase acceptance

This is the step that actually bites. An unaccepted invitation means a student sits down to a
repository they cannot clone.

```bash
./dwellkit status dwellkit-results-$GH_ORG-*.csv            # who's accepted, who hasn't
./dwellkit status dwellkit-results-$GH_ORG-*.csv --remind   # re-send the pending ones
```

Run it daily. **Do not start class with anyone still `PENDING`.**

Students who are already members of the org get access instantly with nothing to accept — so if
you tested with colleagues who are org members, you have not actually exercised this path.

### On the day

Hand each student their repository URL and the brief. Expect CI to be **red on arrival** — that
is correct, not a fault, but decide in advance how you frame it, because it can read as
"the exercise is broken."

Keep [STUDENT-EXPERIENCE.md](docs/STUDENT-EXPERIENCE.md) open for yourself: model solution,
common wrong turns, and marking guidance. Fast finishers have no built extension yet
([TODO.md](docs/TODO.md) §3.2), so have something ready.

### Afterwards

There is **no reset path** — a rotated and rewritten repo cannot be returned to its starting
state. To re-run, rebuild with fresh ids.

```bash
gh repo list "$GH_ORG" --limit 100 --json name --jq '.[].name' | grep '^hackathon-starter-'
```

Delete them (needs `delete_repo` scope — the build token lacks it), remove students as
collaborators so they stop consuming seats, and delete the results CSV and any build logs.

---

## How a student repo is built

Two phases. **Upstream is never contacted at build time**, so builds are offline and reproducible: every student gets a byte-identical history apart from their own credential.

1. **Floor** — `floor.bundle` (16 MB) holds 2,855 genuine commits of [`sahat/hackathon-starter`](https://github.com/sahat/hackathon-starter). Cloned as-is.
2. **Tail** — 203 patches applied on top: 200 real upstream commits, with 3 hand-authored exercise commits interleaved at positions **41** (plant), **122** (scrub), and **198** (reintroduce).

The credential exists only as the literal `__KIT_SECRET__` in the patch files; the real value is substituted as each patch is applied, so no working credential is ever stored in this repository. It is written to the student's repo *and* set as an Actions secret, and CI fails while the two still match — comparing SHA-256 hashes, never the raw value.

Total: 3,060 commits. The plant and scrub sit far enough back that `git log` will not surface them, which is what forces students to learn pickaxe search (`git log -S`).

## Layout

```
dwellkit              The only script — build / class / status
floor.bundle          The authentic 2,855-commit history, serialised
tail/*.patch          The 203-patch series applied on top
roster.example.csv    Roster format
templates/            student-README.md — the brief students see. Edit this, not the script.
docs/                 Everything written; see the table above
```

`dwellkit` is meant to be read: `build` is eight numbered, commented steps.
Run it from the repository root — it locates `floor.bundle` and `tail/` relative to itself.

`roster.csv`, `dwellkit-results-*.csv`, and build logs are gitignored — they contain student identities and live credential values.

---

## Status

The deployment machinery is **built and verified against real GitHub**. The kit is **not yet classroom-ready**. Three things gate a real cohort:

- **GitHub Education verification** — external lead time, start it first. Private-repo collaborators consume paid seats on Team; 20 students needs 21. Education grants the same Team plan free with unlimited users.
- **The student brief** — not yet written, and the exercise depends on it. It must state that marking is on order of operations, not on whether the rewrite succeeded. Without that, expect flawless `filter-repo` runs and no rotations.
- **Credential format validation** — `sk_staging_` + 40 hex has never been tested against a live push-protection scanner. If your teaching org enforces one and recognises the format, every student repo fails to build at once.

See [TODO.md](docs/TODO.md) for the full list, ordered by what blocks what.
