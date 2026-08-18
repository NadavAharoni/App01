# App01 — Claude Code Instructions

## Orientation
At the start of every session, read `prompts/project_log.md` — specifically the **Current Status** section at the top. It contains what's working, what's not, known quirks, and next steps. Update it at the end of the session.

Also read `prompts/wizard_concept.md` when the work touches this repo's role as a **template**. App01 is intended to become the starter application installed by a separate "Build your app with AI" setup wizard. That document records the design decisions, the constraints the template must respect (identity-only OAuth scopes, cost controls, deploy config in the repo), and the open questions.

## Agentic Workflow

- **Run things as you go.** After writing or modifying code, immediately install dependencies, start the server, and verify the change works — without waiting to be asked. Don't use placeholder env vars; where a `.env` exists, let `load_dotenv()` pick it up naturally.
- **`.env` is machine-local and git-ignored**, so a fresh clone has none. `database.py` and `auth.py` read `DATABASE_URL` and `JWT_SECRET` at module level, so the app will not even import without them — copy `.env.example` and fill in the Neon connection string and a generated `JWT_SECRET` before running. Frontend-only work can be smoke-tested with an unreachable `DATABASE_URL`: `init_db()` logs and degrades rather than raising.
- **Fix errors autonomously.** If a command fails, diagnose and fix it before reporting back. Only surface an error to the user if it requires a decision or credential they hold.

## Server

Start the dev server with:
```
python -m uvicorn main:app --reload --port 8080
```
(Use `python -m uvicorn`, not bare `uvicorn` — the PATH has a stale Python 3.13 entry.)

## Commits

- Do not add `Co-Authored-By` trailers to commit messages.
- Update `prompts/project_log.md` at the end of each session with a timestamped entry.
