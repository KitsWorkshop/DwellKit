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
| Understand the kit from zero — concepts, design decisions, infrastructure | [INSTRUCTOR-GUIDE.md](INSTRUCTOR-GUIDE.md) |
| Deploy to one student | [DEPLOY-RUNBOOK.md](DEPLOY-RUNBOOK.md) |
| Deploy to a whole class | [FANOUT-DESIGN.md](FANOUT-DESIGN.md) |
| Know what students actually experience, and how to mark it | [STUDENT-EXPERIENCE.md](STUDENT-EXPERIENCE.md) |
| Brief colleagues or stakeholders | [SLIDES.md](SLIDES.md) (Marp) |
| Know what still needs building | [TODO.md](TODO.md) |
| Know what was tested, what broke, and what is still unproven | [TECHNICAL-NOTES.md](TECHNICAL-NOTES.md) |
| Report status upward | [PROGRESS.md](PROGRESS.md) |

---

## Quick start

Requires `git`, `gh` (authenticated), `python3`, and a token with `repo` + `workflow` scope on the target org.

**One repository:**

```bash
export GH_TOKEN=...        # repo + workflow scope
export GH_ORG=your-org
./dwellkit build alice      # → your-org/hackathon-starter-alice
```

**A whole class:**

```bash
cp roster.example.csv roster.csv     # student_id,github_username
export KIT_SALT=...                  # per-cohort secret; makes credentials reproducible
./dwellkit class roster.csv --dry-run     # validate the roster, create nothing
./dwellkit class roster.csv               # build, invite, report to dwellkit-results-<ts>.csv
./dwellkit status dwellkit-results-*.csv --remind
```

Both are re-runnable — an existing repo is skipped, and invitations are idempotent.

---

## How a student repo is built

Two phases. **Upstream is never contacted at build time**, so builds are offline and reproducible: every student gets a byte-identical history apart from their own credential.

1. **Floor** — `floor.bundle` (16 MB) holds 2,855 genuine commits of [`sahat/hackathon-starter`](https://github.com/sahat/hackathon-starter). Cloned as-is.
2. **Tail** — 203 patches applied on top: 200 real upstream commits, with 3 hand-authored exercise commits interleaved at positions **41** (plant), **122** (scrub), and **198** (reintroduce).

The credential exists only as the literal `__KIT_SECRET__` in the patch files; the real value is substituted as each patch is applied, so no working credential is ever stored in this repository. It is written to the student's repo *and* set as an Actions secret, and CI fails while the two still match — comparing SHA-256 hashes, never the raw value.

Total: 3,059 commits. The plant and scrub sit far enough back that `git log` will not surface them, which is what forces students to learn pickaxe search (`git log -S`).

## Files

| File | Purpose |
|---|---|
| `dwellkit` | The only script. `build` makes one repo (plain, linear, commented — meant to be read), `class` deploys a cohort, `status` reports invitation state. |
| `roster.example.csv` | Roster format. |
| `floor.bundle` | The authentic 2,855-commit history, serialised. |
| `tail/*.patch` | The 203-patch series applied on top. |
| `agent-spec.md` | The original build spec, kept unedited for intent. Superseded in places by `TECHNICAL-NOTES.md`. |

`roster.csv`, `dwellkit-results-*.csv`, and build logs are gitignored — they contain student identities and live credential values.

---

## Status

The deployment machinery is **built and verified against real GitHub**. The kit is **not yet classroom-ready**. Three things gate a real cohort:

- **GitHub Education verification** — external lead time, start it first. Private-repo collaborators consume paid seats on Team; 20 students needs 21. Education grants the same Team plan free with unlimited users.
- **The student brief** — not yet written, and the exercise depends on it. It must state that marking is on order of operations, not on whether the rewrite succeeded. Without that, expect flawless `filter-repo` runs and no rotations.
- **Credential format validation** — `sk_staging_` + 40 hex has never been tested against a live push-protection scanner. If your teaching org enforces one and recognises the format, every student repo fails to build at once.

See [TODO.md](TODO.md) for the full list, ordered by what blocks what.
