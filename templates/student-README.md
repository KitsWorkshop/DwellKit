# Member Portal — Node.js service

Internal web application built on the [hackathon-starter](https://github.com/sahat/hackathon-starter)
boilerplate. Express, MongoDB, Passport-based auth, and a set of third-party API integrations.

---

## 📋 Your task

**You have inherited this repository. CI is failing. Find out why, and fix it properly.**

That is the whole brief. The rest of this section tells you how you will be judged, not what to do.

### What "properly" means

You are finished when all three of these are true:

1. **CI passes.**
2. You can state, in a sentence or two, **what the actual risk was and at what moment it began.**
3. You can say **what you would change** so this does not happen again.

Getting CI green without being able to answer 2 and 3 is not a pass. There is more than one way
to make a red check go green, and most of them fix nothing.

### What to pay attention to

- **Read the failing check.** Don't just look at whether it's red — read what it asserts.
- **Distinguish removing a symptom from resolving a cause.** Ask yourself, each time you're about
  to do something: does this make the problem *gone*, or merely *invisible*?
- **This repository has a long history, and history is evidence.** The current state of the files
  is not the whole picture.
- **Notice when you believe you're finished.** If you feel done and something is still red, that
  gap is the most interesting thing in this exercise. Sit with it rather than reaching for a
  bigger hammer.

### How you are assessed

> **You are marked on the order in which you do things, and on your reasoning — not on whether
> any particular command succeeded.**

A technically impressive fix performed in the wrong order scores **lower** than a modest one
performed in the right order. If you are choosing between doing something clever and doing
something first, do it first.

### What to hand in

Keep a running log as you work. For each step, note:

| Time | What I did | Why I did it then |
|---|---|---|

Write the entry *before* you run the command, not afterwards. The log is the primary artifact —
it is how ordering gets marked, and reconstructing it from memory at the end defeats the point.

### Ground rules

- Work on your own repository only.
- If you get stuck for more than ten minutes, say so. Being stuck is expected and useful; quietly
  reading documentation for half an hour is not.
- Don't ask another group what the answer is. Do compare notes afterwards.

---

## 🧰 Tooling reference

These are the tools this task is likely to involve. The list tells you what exists — **not which to
use, when to use it, or in what order.** That is the part you are marked on.

If you want to do something that isn't listed here, look it up. Nothing below is exhaustive.

### What you need installed

| Tool | Needed? |
|---|---|
| `git` | Yes |
| A GitHub account with access to this repository | Yes — the web interface is enough for most things |
| [`gh`](https://cli.github.com) (GitHub CLI) | Optional. Everything it does here can also be done in the browser |
| [`git-filter-repo`](https://github.com/newren/git-filter-repo) | Only if you decide you need it. **Not bundled with git** — `pip install git-filter-repo` |
| Node.js / MongoDB | **No.** You do not need the application running |

> ⚠️ If you use `git-filter-repo`, note that it **deletes your `origin` remote** when it runs, as a
> safety measure. Your next push will fail with *"'origin' does not appear to be a git repository"*.
> That is expected, not a broken repo — restore it with `git remote add origin <url>`.

### Reading CI

The **Actions** tab shows every workflow run. Click into a failed run and **expand the step** — the
collapsed view shows you considerably less than the expanded one.

```
gh run list                gh run view --log-failed
```

### Searching the files as they are now

```
grep -rn "<string>" . --exclude-dir=.git
```

### Looking at the repository's past

```
git log                    git log --oneline
git show <commit>:<path>          # a file as it was at that commit
git log --all -S'<string>'        # every commit that added or removed a string
```

Searching the files and searching the history are not the same operation. They can return very
different answers.

### Repository settings you have access to

You have **write access**, which is more than read-only. Among other things you can reach
**Settings → Secrets and variables → Actions**, directly at:

```
https://github.com/<org>/<this-repo>/settings/secrets/actions
```

Secret *values* can be updated but never read back — not by you, not by anyone. That is by design.

### Changing what is already committed (destructive)

```
git rm             git filter-repo             git push --force
```

> ⚠️ A force-push rewrites the branch for **everyone**, not just you. Anyone else with a clone will
> have a broken one, and if they push a stale branch afterwards they can undo your work. Whether and
> when to use these is a judgement call, and that judgement is being assessed.

### Stopping things getting into a repository

```
.gitignore         .git/hooks/pre-commit         gitleaks         trufflehog
```

---

## Running the application

Only needed if you want to run it. **You do not have to get the app running to complete the task.**

### Prerequisites

- [Node.js](https://nodejs.org) 24.18 or newer (check `engines` in `package.json`)
- [MongoDB](https://www.mongodb.com/docs/manual/installation/) running locally, or a connection string
- A command line with `git`

### Getting started

```bash
npm install
npm start
```

The app serves on `http://localhost:8080` by default.

### Project structure

| Path | Contents |
|---|---|
| `config/` | Configuration and environment settings |
| `controllers/` | Route handlers |
| `models/` | Mongoose schemas |
| `views/` | Pug templates |
| `test/` | Test suite |
| `.github/workflows/` | CI |

Full upstream documentation — API key setup, deployment, the complete package list — is in the
[hackathon-starter README](https://github.com/sahat/hackathon-starter#readme). This copy has been
shortened; nothing about the application itself has been changed.

---

## License

MIT, inherited from the upstream project. See `LICENSE`.
