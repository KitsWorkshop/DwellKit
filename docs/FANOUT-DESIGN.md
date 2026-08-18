# Fan-out design — delivering to a class

How to get one repository per student to ~30 people who may or may not be members of your organisation.

**Short version:** the loop is the easy part (~30 minutes). Three other problems are harder, and one of them rules out the option most people reach for first.

---

## Two findings that shape everything below

### 1. ⚠️ GitHub Classroom's template flow cannot deliver this kit

Classroom's standard assignment flow provisions student repositories from a **template repository**. Per GitHub's documentation:

> *"A new fork includes the entire commit history of the parent repository, while a repository created from a template **starts with a single commit**."*

This kit is 3,060 commits, with the credential planted **164 commits back**. Template instantiation would collapse all of that into one commit — the student would open a repo with the credential sitting in plain view, no history to search, and no exercise.

**Classroom can still be used for roster and identity. It cannot be used to provision the repository content.**

### 2. 💰 Private-repo collaborators consume paid seats

Per GitHub's billing documentation, an organisation on the **Team** plan is billed for:

> *"Outside collaborators on private repositories owned by your organisation, excluding forks."*

Each collaborator counts **once**, regardless of how many repos they touch. Org members are billed the same way.

**A class of 30 therefore needs 31 seats.** The `KitsWorkshop` org currently has `filled_seats: 1, seats: 1`.

**The fix is not to pay for it, and not to change tier.** `KitsWorkshop` is *already* on Team — that is precisely what creates the per-seat cost, not something to upgrade away from. GitHub Education grants verified educators **the same Team plan, free, with unlimited users and unlimited private repositories**. What you need is the Education grant applied to this org, not a different plan.

> **Do this first.** Verification is an external process with a lead time measured in days, so start it before writing any code.

---

## The three real problems

Building the loop is trivial. These are not.

| Problem | Why it's hard |
|---|---|
| **Identity** | You need each student's *GitHub username* — not their email, not their student ID. They may not have an account, may use an unguessable handle, and will typo it. |
| **Access** | Private repos require invitations. Invitations are asynchronous and must be **accepted**. Some students won't, and they can't clone until they do. |
| **Billing** | Solved by GitHub Education (above). Unsolved, it's ~$120/month for a class of 30. |

---

## Access models

### Option A — Outside collaborators (per-repo invitations)

Build each repo, then invite the student directly:

```bash
gh api -X PUT "repos/$ORG/hackathon-starter-$STUDENT/collaborators/$GH_USER" -f permission=push
```

| | |
|---|---|
| ✅ | Works today — one API call added to the existing builder |
| ✅ | No org membership required |
| ✅ | Students can't see each other's repos |
| ⚠️ | One invitation per student, each must be accepted |
| ⚠️ | Some orgs restrict or forbid outside collaborators — check policy |
| ⚠️ | Consumes a seat per student unless on Education |

**Best for:** pilots, small cohorts, and any situation where students shouldn't be org members.

### Option B — Org members + teams

Invite students to the organisation once, then grant repo access by team or directly.

| | |
|---|---|
| ✅ | One org invitation covers this and every future assignment |
| ✅ | Team-based access management scales better across a course |
| ⚠️ | Org membership is a larger commitment and more visibility |
| ⚠️ | Still an invitation to accept; still consumes a seat |

**Best for:** a course that will run several kits, where the org invitation is a one-time cost amortised across the term.

### Option C — Classroom for roster, direct push for content (hybrid)

Use GitHub Classroom purely to establish the student → username mapping (students authenticate and self-identify, which solves the identity problem properly), then ignore its template provisioning and push the real history into each repo yourself.

| | |
|---|---|
| ✅ | Solves the identity problem better than any manual method |
| ✅ | Familiar to students who've used Classroom before |
| ⚠️ | More moving parts; you're using Classroom against its grain |
| ⚠️ | Requires GitHub Education verification anyway |

**Best for:** larger cohorts where manual roster collection is the dominant cost.

---

## Recommendation

For a first real class of ~30:

1. **Apply for GitHub Education verification now** — removes billing, unlimited seats and private repos. External lead time, so start it first. **This is now the main blocker for a real cohort.**
2. ~~Use Option A~~ → **Option A is implemented.** See below.
3. **Solve identity with a warm-up task**, not a spreadsheet. Have students do something trivial that proves their username — accept an org invitation, or comment on a tracking issue — a week ahead. This gives you a *verified* roster instead of a transcribed one, and surfaces the students who don't have accounts while there's still time.
4. **Revisit Classroom** only if you run this repeatedly and roster collection proves to be the bottleneck.

---

## Implementation status — Option A is built ✅

Implemented and verified live, as two subcommands of the `dwellkit` script:

| Command | Purpose |
|---|---|
| `dwellkit class <roster.csv>` | Validate roster → build repos → invite students → report. Concurrent, re-runnable. |
| `dwellkit status <results.csv>` | Who hasn't accepted yet. `--remind` re-sends invitations. |

Plus `roster.example.csv`, which documents the roster format.

### Usage

```bash
export GH_TOKEN=<classic PAT: repo + workflow>
export GH_ORG=<your teaching org>
export KIT_SALT=<per-cohort secret string — keep it>

./dwellkit class roster.csv --dry-run     # validate roster, create nothing
./dwellkit class roster.csv               # build + invite
./dwellkit status dwellkit-results-$ORG-*.csv           # who hasn't accepted
./dwellkit status dwellkit-results-$ORG-*.csv --remind  # re-send pending
```

### What it does

**Phase 1 — Preflight.** Verifies the org is reachable and reports token scopes, warning if `repo` is absent.

**Phase 2 — Roster validation, before creating anything.** Every username is checked to exist via the API; blank usernames and duplicate student IDs are rejected. **If any row is invalid, nothing is created.** A typo caught here costs seconds; caught on the day it costs a student their session.

**Phase 3 — Build and invite,** at a default concurrency of 5. Capped deliberately: GitHub's *secondary* rate limits trigger on burst concurrency rather than total volume and are invisible in the standard headers.

**Phase 4 — Report,** written to `dwellkit-results-<org>-<timestamp>.csv` with each student's repo, credential, and status. The file carries `# org=` / `# prefix=` / `# generated=` provenance lines above the CSV header; `dwellkit status` reads the org back out and refuses to run against a file built for a different org.

### Design decisions

**Deterministic credentials.** `dwellkit build` now derives the credential from `sha256(student_id + KIT_SALT)` when `KIT_SALT` is set, and stays random when it isn't (correct for one-off builds). This means a repo can be rebuilt identically after a failure, and any student's value can be re-derived for marking without having recorded thirty of them.

> **Keep `KIT_SALT` safe and unchanged for the cohort.** Losing it means losing the ability to re-derive credentials. Changing it mid-cohort means new repos get different values from existing ones.

**Idempotent re-runs.** A student whose repo already exists is skipped; the invitation is re-sent regardless, because `PUT` on the collaborators endpoint is idempotent. After a partial failure, re-run the identical command. Verified: a re-run of a completed 2-student fan-out took **1.5s** versus 20.5s for the original.

**Results are gitignored.** `roster.csv` holds student data and `dwellkit-results-*.csv` holds credential values. Both are in `.gitignore`. Do not commit or share them.

### Verified live

| Check | Result |
|---|---|
| Roster validation rejects bad rows | ✅ caught missing username, nonexistent user, duplicate ID |
| Dry run creates nothing | ✅ |
| Build + invite, 2 students, concurrency 2 | ✅ 20.5s total |
| Credentials match independent derivation | ✅ exact match |
| Built repo contains the derived credential | ✅ |
| `dwellkit status` reports status correctly | ✅ |
| Re-run skips existing repos | ✅ 1.5s |
| Results CSV well-formed | ✅ every row exactly 6 fields |

### Not yet built

- **Teardown.** Bulk deletion after the exercise needs a token with `delete_repo` scope, which the build token does not have.
- **Retry with backoff.** A failed student is reported and can be retried by re-running, but there is no automatic backoff on secondary rate limits.

## Operational realities

- **Expect 10–20% non-acceptance** by the day before, in any cohort. Build in a chase cycle; don't discover it at the start of class.
- **Rate limits** look comfortable on paper (~200 API calls for 30 students against 5,000/hour), but bursts can trip *secondary* rate limits, which are triggered by concurrency rather than volume and aren't visible in the standard headers. Cap concurrency around 5 and add backoff.
- **Build repos 2–3 days ahead**, not on the day. 30 repos at 15–50s each is 8–25 minutes serially — fine, but not something to run with a room waiting.
- **Have 2–3 spare repos pre-built.** Someone will turn up with no account, a broken account, or an unaccepted invitation, and a spare they can be dropped into is worth more than a fix.
- **Students need `git-filter-repo` installed.** Tell them in advance; it is not a default install.

---

## Still unverified

- **A write-level collaborator rotating the secret and force-pushing.** The endpoint, parameters, and token permissions are confirmed, and GitHub's documentation confirms write access suffices for Actions secrets — but this has not been executed with a real second account. **Test it once before a real class.**
- **Whether your target org permits outside collaborators.** Institutional orgs frequently restrict this. Check before committing to Option A.
- **Push protection against the credential format** — build one throwaway repo in the target org (`./dwellkit build pilot1`) before any fan-out. Still the single highest-risk unknown, and it affects all 30 repos identically.
