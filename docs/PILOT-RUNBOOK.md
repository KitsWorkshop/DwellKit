# Pilot Runbook — running the kit with a small group

Operational checklist for putting this kit in front of **3–8 colleagues acting as students**, before it ever meets a real cohort.

`DEPLOY-RUNBOOK.md` covers exactly one student. This covers a group, and adds the parts a pilot needs and a single build doesn't: what to watch for, what to capture, and how to tear it all down afterwards.

---

## Why bother — what a pilot actually buys you

Four things are currently unproven, and **three of them a pilot closes in one sitting**:

| Open question | Closed by a pilot? |
|---|---|
| Can a **write-level collaborator** rotate the Actions secret and force-push? | ✅ Yes — this is the big one |
| Does the credential format survive **push protection** in the target org? | ✅ Yes, if the pilot runs in that org |
| Does a **multi-repo build** hold up (timings, rate limits, partial failures)? | ✅ Partially — at 3–8, not at 30 |
| Do students **accept invitations** reliably? | ❌ **No** — see the warning below |

> ### ⚠️ A pilot with colleagues does *not* test the invitation flow
>
> If your participants are already **members of the org**, adding them as collaborators grants access **instantly** — no invitation, nothing to accept. That is the single most common failure mode in a real class, and a pilot staffed by org members walks straight past it.
>
> **To test it properly**, use at least one participant who is *not* an org member. They will get an invitation email and must accept it. That one person tells you more about class-day risk than the other seven combined.

**The write-level rotation test is the one that matters most.** Documentation says write access is sufficient to manage Actions secrets, and that is why `dwellkit class` grants `push`. It has never been confirmed with a real second account. If it turns out to be wrong, the exercise is *impossible* rather than merely awkward — every participant will hit it at the same moment.

---

## ⚠️ Before you start — the seat cost

The org is on GitHub **Team**, where collaborators on **private** repositories consume paid seats. As of the last check it had **1 filled seat of 1**.

A pilot with 5 participants therefore needs **6 seats**, billed monthly, whether they are org members or outside collaborators.

Options, cheapest first:

1. **Apply for GitHub Education verification first** — grants the same Team plan free with unlimited users. It has external lead time, so it is worth starting regardless; see `FANOUT-DESIGN.md`.
2. **Run the pilot, accept one month of billing, tear it down after.** For 5 people this is small and entirely reasonable.
3. **Keep the pilot to 2–3 people.** Enough to close the write-level rotation question, which is the point.

Do not skip this decision. Discovering the bill after inviting eight colleagues is a bad afternoon.

---

## What each participant needs

Send this ahead of time — people arriving unprepared is the main way a pilot loses its first thirty minutes.

- A **GitHub account**, and they must tell you the exact **username** (not an email, not a display name)
- `git` and the `gh` CLI, authenticated
- **`git-filter-repo` installed** — `pip install git-filter-repo` or `brew install git-filter-repo`
- Ninety minutes, and a willingness to be observed while stuck

---

## §1 — Build the roster

```bash
cd /path/to/DwellKit
cp roster.example.csv pilot-roster.csv
```

One row per participant. `participant_id` becomes the repo suffix, so keep it short and lowercase:

```csv
student_id,github_username
pilot-amara,amara-gh
pilot-devin,devin-codes
pilot-sam,samwise-42
```

Prefixing every id with `pilot-` makes teardown unambiguous later.

> Any file matching `*roster*.csv` is gitignored (except `roster.example.csv`), so `pilot-roster.csv` is safe to leave in the working directory.

---

## §2 — Set the environment

```bash
export GH_TOKEN=<PAT with repo + workflow scope>
export GH_ORG=<the org you will actually teach from>
export KIT_SALT=<any secret string — write it down>
```

**Run the pilot in the org you intend to teach from**, not a sandbox. Push protection, Actions policy, and branch-protection defaults are all org-level, and a pilot in the wrong org validates none of them.

Keep `KIT_SALT`. It lets you re-derive any participant's credential later without having recorded them:

```bash
printf 'sk_staging_%s\n' "$(printf '%s' "${PARTICIPANT_ID}${KIT_SALT}" | sha256sum | cut -c1-40)"
```

---

## §3 — Dry run first

```bash
./dwellkit class pilot-roster.csv --dry-run
```

Validates every GitHub username exists and creates **nothing**. A typo caught here costs seconds; caught on the day it costs someone their session.

Expect:

```
==> [2/4] Validating roster
    valid: 3    invalid: 0
==> Dry run complete. Roster is valid. Nothing created.
```

Any `INVALID` line stops the run. Fix and repeat until clean.

---

## §4 — Deploy

```bash
./dwellkit class pilot-roster.csv
```

⏱ Roughly 15–50 seconds per repo, 5 at a time. A group of 5 lands in about a minute.

Writes `dwellkit-results-<timestamp>.csv` containing **live credential values**. It is gitignored. Do not commit it, do not paste it into chat.

Re-runnable: if anything fails, run the identical command again. Existing repos are skipped, invitations are re-sent.

---

## §5 — Facilitator pre-flight

Do this **before** anyone touches anything. Ten minutes here saves the session.

```bash
RESULTS=dwellkit-results-<timestamp>.csv
./dwellkit status "$RESULTS"
```

Everyone should read `✓ accepted`. Anyone `… PENDING` cannot clone yet:

```bash
./dwellkit status "$RESULTS" --remind
```

Then spot-check **one** repo properly:

```bash
REPO=hackathon-starter-pilot-amara

# CI must be RED. This is correct, not a fault.
gh run list --repo "$GH_ORG/$REPO" --limit 1

# The secret must exist
gh secret list --repo "$GH_ORG/$REPO"

# Branch protection must be OFF — participants must be able to force-push
gh api "repos/$GH_ORG/$REPO/branches/main/protection" 2>&1 | grep -q "Branch not protected" \
  && echo "OK: unprotected" || echo "WARNING: protection is ON"

# The credential must be present in exactly ONE tracked file
gh repo clone "$GH_ORG/$REPO" /tmp/pilot-check && cd /tmp/pilot-check
git grep -l 'sk_staging_'     # expect: config/staging.env, and nothing else
git log --oneline -50 | grep -ci 'staging config'   # expect: 1 (only the recent re-add)
cd - && rm -rf /tmp/pilot-check
```

That last check is the important one. It confirms the plant and the scrub are still **buried** — invisible to anyone who merely scrolls the log, which is what forces the pickaxe search.

---

## §6 — What to tell participants

**The brief is already in their repository** — `templates/student-README.md` is installed as the README at build time, so they will read it on arrival. Say this much out loud to frame the session, then let the README do the work. Do not improvise beyond it: the wording is what you are testing.

> You have inherited a repository. It is a working Node.js application with real history and many contributors.
>
> CI is failing. Your job is to find out why and fix it properly.
>
> You are being assessed on **the order in which you do things**, not on whether any particular command succeeded. Narrate what you are doing and why — think aloud. If you get stuck, say so rather than quietly reading documentation for twenty minutes; being stuck is useful data for us.
>
> Time: 45 minutes, then we talk about it.

**Do not say**, at any point before the debrief:

- the word *rotate*
- that there is more than one copy of the credential
- that the history has been tampered with
- anything about `git log -S`, the pickaxe, or searching history

Every one of those is the exercise doing its job. Saying them out loud is you doing the exercise for them.

---

## §7 — What to watch for

Keep a note per participant. These map directly onto the marking criteria in `STUDENT-EXPERIENCE.md` Part 4.

| Observation | Why it matters |
|---|---|
| ⏱ Time to first find the credential | Should be minutes. Much longer means the plant is too well hidden. |
| **Did they rotate before rewriting?** | *The* headline metric. Expect most to rewrite first. |
| Did they say "done" while CI was still red? | The false summit — the exercise's central trap working correctly. |
| Did they find the **older** planted copy, or only the recent one? | The gap between the two is where the lesson lives. |
| **Could they rotate the secret at all?** | ⚠️ If anyone cannot, stop the pilot and record it. This is the untested permission question. |
| **Could they force-push?** | ⚠️ Same. |
| Did push protection block anything? | ⚠️ If yes, stop. This invalidates the credential format for every future class. |
| Where did they get stuck for >10 min? | Candidates for hints in the real brief. |
| Anything they said that revealed a wrong mental model | The most valuable output of the whole pilot. |

Resist helping. A pilot where everyone succeeds smoothly because you rescued them teaches you nothing.

---

## §8 — Debrief

Fifteen minutes, all together. In this order:

1. **"Who rewrote history before rotating the secret?"** — usually most hands. Let that sit.
2. **"At what moment was the credential compromised?"** — the answer is *when it was pushed*, not when it was found.
3. **"So what did the rewrite accomplish?"** — it stops the *next* person cloning it. Nothing more.
4. **Show them the SHA trick** — the orphaned commit is still served by GitHub after a successful force-push, verified live:
   ```bash
   gh api "repos/$GH_ORG/$REPO/commits/<pre-rewrite-sha>" | grep sk_staging_
   ```
   This is usually the moment it properly lands.
5. **"What would have prevented this?"** — leads into the prevention step, which is **not yet built** (`TODO.md` §3.2). Their answers are good raw material for building it.

Then break character and ask them as colleagues: *where was the brief unclear? what felt unfair? what was tedious rather than instructive?*

---

## §9 — Capture the findings

Write these down while they are fresh. They unblock items in `TODO.md`:

- [ ] **Write-level collaborators can rotate + force-push** — confirmed? (`TODO.md` §1.1)
- [ ] **Push protection did not block the credential format** — in the real teaching org (`TODO.md` §2)
- [ ] **Build timings** at this group size, and any failures or rate limiting (`TODO.md` §4)
- [ ] **Invitation acceptance** — only meaningful if you included a non-org-member
- [ ] **How many rotated before rewriting** — the baseline the exercise exists to move
- [ ] **Brief wording that misled or under-specified** (`TODO.md` §3.1)
- [ ] **Whether the pre-red CI read as "broken" rather than "a problem to solve"** (`TODO.md` §5)

---

## §10 — Teardown

**There is no reset path.** A repo that has been rotated and rewritten cannot be returned to its starting state — rebuild instead.

```bash
# List everything the pilot created
gh repo list "$GH_ORG" --limit 100 --json name --jq '.[].name' | grep '^hackathon-starter-pilot-'

# Delete them — requires a token with delete_repo scope, which the build token lacks
gh repo list "$GH_ORG" --limit 100 --json name --jq '.[].name' \
  | grep '^hackathon-starter-pilot-' \
  | xargs -I{} gh repo delete "$GH_ORG/{}" --yes
```

If your token lacks `delete_repo`, delete via the web UI — this is why every pilot id is prefixed `pilot-`.

**Then:**

- [ ] Remove pilot participants from the org / as collaborators — **they consume paid seats until you do**
- [ ] Delete `dwellkit-results-*.csv` and any `*.build.log` — they contain live credential values
- [ ] Revoke the PAT if it was created just for this

To run again with the same people, rebuild with fresh ids (`pilot2-amara`).

---

## Troubleshooting

`DEPLOY-RUNBOOK.md` has the full table. The three that bite hardest in a group setting:

| Symptom | Cause | Fix |
|---|---|---|
| Someone: `Repository not found` | Invitation not accepted | `./dwellkit status "$RESULTS" --remind`, then have them check email **and** github.com/notifications |
| Someone cannot rotate the secret | ⚠️ Possibly the untested permission gap | Record it immediately, grant `admin` to that one person to unblock them, and flag it as a finding |
| Push rejected mentioning **GH013** / push protection | Org scanning recognises the format | **Stop the pilot.** This affects every future class. See `TODO.md` §2 |
