# App01 — Claude Code Instructions

## Orientation
At the start of every session, read `prompts/project_log.md` — specifically the **Current Status** section at the top. It contains what's working, what's not, known quirks, and next steps. Update it at the end of the session.

## Agentic Workflow

- **Run things as you go.** After writing or modifying code, immediately install dependencies, start the server, and verify the change works — without waiting to be asked. Don't use placeholder env vars; the project has a `.env` file, let `load_dotenv()` pick it up naturally.
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
