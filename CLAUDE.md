# App01 — Claude Code Instructions

## Orientation
At the start of every session, read `prompts/project_log.md` — specifically the **Current Status** section at the top. It contains what's working, what's not, known quirks, and next steps. Update it at the end of the session.

Also read `prompts/wizard_concept.md` when the work touches this repo's role as a **template**. App01 is intended to become the starter application installed by a separate "Build your app with AI" setup wizard. That document records the design decisions, the constraints the template must respect (identity-only OAuth scopes, cost controls, deploy config in the repo), and the open questions.

## Agentic Workflow

- **Run things as you go.** After writing or modifying code, immediately install dependencies, start the server, and verify the change works — without waiting to be asked. Don't use placeholder env vars; where a `.env` exists, let `load_dotenv()` pick it up naturally.
- **`.env` is machine-local and git-ignored**, so a fresh clone has none. `database.py` and `auth.py` read `DATABASE_URL` and `JWT_SECRET` at module level, so the app will not even import without them — copy `.env.example` and fill in the Neon connection string and a generated `JWT_SECRET` before running. Frontend-only work can be smoke-tested with an unreachable `DATABASE_URL`: `init_db()` logs and degrades rather than raising.
- **Fix errors autonomously.** If a command fails, diagnose and fix it before reporting back. Only surface an error to the user if it requires a decision or credential they hold.
- **Asking for help is not a failure mode.** When the blocker *is* a credential or an access decision, ask immediately instead of routing around it. `PERMISSION_DENIED` from a cloud CLI, a missing login, or a resource that simply is not visible to the active account are all things the user can clear in seconds and no amount of cleverness can. Say what is blocked, what you need, and the exact command you will run once you have it. Exhausting workarounds first burns a turn for nothing.
- **Never assume which `gcloud` account is active.** It is whatever the last `gcloud auth login` left behind, on whichever machine this session is running, and more than one Google identity is used across projects — so it may or may not be the one that owns App01, and it can change between sessions. A `gcloud projects list` that comes back without App01 in it therefore means nothing is wrong. Check `gcloud auth list` and `gcloud config list` first, and pass `--project` / `--account` explicitly instead of trusting the active config. IDs are in `prompts/project_log.md` under **Environment**.
- **Do not assume anything about the local toolchain across sessions.** Work on this repo happens from two different machines, so "X is installed" is never a durable fact — a tool present last session may be absent this one. Verify with a version check before relying on it, and when recording a finding in `project_log.md`, write it as an observation with its date and machine, not as a property of the project.

## Server

Start the dev server with:
```
python -m uvicorn main:app --reload --port 8080
```
(Use `python -m uvicorn`, not bare `uvicorn` — the PATH has a stale Python 3.13 entry.)

## Commits

- Do not add `Co-Authored-By` trailers to commit messages.
- Update `prompts/project_log.md` at the end of each session with a timestamped entry.
