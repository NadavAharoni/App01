# App01 — Claude Code Instructions

## Orientation
At the start of every session, read `prompts/project_log.md` — specifically the **Current Status** section at the top. It contains what's working, what's not, known quirks, and next steps. Update it at the end of the session.

Also read `prompts/wizard_concept.md` when the work touches this repo's role as a **template**. App01 is intended to become the starter application installed by a separate "Build your app with AI" setup wizard. That document records the design decisions, the constraints the template must respect (identity-only OAuth scopes, cost controls, deploy config in the repo), and the open questions.

## Agentic Workflow

- **Run things as you go.** After writing or modifying code, immediately install dependencies, start the server, and verify the change works — without waiting to be asked. Don't use placeholder env vars; where a `.env` exists, let `load_dotenv()` pick it up naturally.
- **`.env` is machine-local and git-ignored**, so a fresh clone has none. `database.py` and `auth.py` read `DATABASE_URL` and `JWT_SECRET` at module level, so the app will not even import without them — copy `.env.example` and fill in the Neon connection string and a generated `JWT_SECRET` before running. Frontend-only work can be smoke-tested with an unreachable `DATABASE_URL`: `init_db()` logs and degrades rather than raising.
- **Write and commit tests as part of the work, without being asked.** If a change has a rule that
  can be checked mechanically, the check is part of the change — not a follow-up to offer. Put it
  under `tests/`, verify it actually fails when the thing it guards is broken (a check that cannot
  fail is worse than none, because it reads as coverage), and commit it alongside the code. Do not
  ask permission for this.
- **Fix errors autonomously.** If a command fails, diagnose and fix it before reporting back. Only surface an error to the user if it requires a decision or credential they hold.
- **Asking for help is not a failure mode.** When the blocker *is* a credential or an access decision, ask immediately instead of routing around it. `PERMISSION_DENIED` from a cloud CLI, a missing login, or a resource that simply is not visible to the active account are all things the user can clear in seconds and no amount of cleverness can. Say what is blocked, what you need, and the exact command you will run once you have it. Exhausting workarounds first burns a turn for nothing.
- **Never assume which `gcloud` account is active.** It is whatever the last `gcloud auth login` left behind, on whichever machine this session is running, and more than one Google identity is used across projects — so it may or may not be the one that owns App01, and it can change between sessions. A `gcloud projects list` that comes back without App01 in it therefore means nothing is wrong. Check `gcloud auth list` and `gcloud config list` first, and pass `--project` / `--account` explicitly instead of trusting the active config. IDs are in `prompts/project_log.md` under **Environment**.
- **Do not assume anything about the local toolchain across sessions.** Work on this repo happens from two different machines, so "X is installed" is never a durable fact — a tool present last session may be absent this one. Verify with a version check before relying on it, and when recording a finding in `project_log.md`, write it as an observation with its date and machine, not as a property of the project.

## Multilingual (Hebrew / RTL)

The UI ships in English and Hebrew. Hebrew is RTL, which makes a few rules non-negotiable:

- **All user-visible text lives in `static/i18n.js`.** Adding UI copy means adding a key there and
  referencing it from the markup as `data-i18n="key"` (or `data-i18n-placeholder` /
  `data-i18n-aria-label` for attributes). Never hardcode a sentence in `index.html`, and never
  assemble one in JS. Both dictionaries must carry the same key set — a key present in one and
  missing from the other falls back silently to English and nobody notices.
- **Use logical Tailwind utilities, never physical ones.** `ms-*` / `me-*` / `ps-*` / `pe-*` /
  `text-start` / `text-end` / `start-*` / `end-*`, never `ml-*`, `mr-*`, `pl-*`, `pr-*`,
  `text-left`, `text-right`. The CDN serves Tailwind 3.4.17, which supports all of them. A
  physical utility is a layout bug that only shows up in Hebrew, so it survives review easily.
- **Anything inherently LTR needs `dir="ltr"`.** Email addresses, UUIDs, hostnames, shell commands
  and the credential inputs. Without it the Unicode bidi algorithm reorders the run inside RTL
  text and it renders scrambled — a UUID is the worst case, since its hyphens get shuffled and the
  id becomes unreadable. This is the single most common way an RTL port looks broken.
- **API errors return codes, not sentences.** `routers/auth.py` raises `detail="email_taken"`;
  the wording is `err.email_taken` in `i18n.js`. Change a code without adding the key and the
  message quietly degrades to the generic one. Change both together.
- **`i18n.js` must stay first and stay blocking in `<head>`.** It sets `<html lang>` and
  `<html dir>` during head parsing, before anything is painted. Defer it, move it, or turn the
  dictionary into a fetched `.json`, and Hebrew visitors get a visible flash of English LTR.
- **Adding a language** means one entry in `I18N_LANGS` plus one dictionary. Nothing else should
  need to change; if it does, something has been hardcoded that should not be.

## Server

Start the dev server with:
```
python -m uvicorn main:app --reload --port 8080
```
(Use `python -m uvicorn`, not bare `uvicorn` — the PATH has a stale Python 3.13 entry.)

## Tests

```
python tests/check_i18n.py     # static, no deps, no server — run this after ANY frontend edit
npm install && npm test        # behavioural, needs a server running (see below)
```

- `tests/check_i18n.py` enforces the Multilingual rules below: key parity between dictionaries,
  no orphaned or undefined keys, every API error code has a message, no physical direction
  utilities, `dir="ltr"` where bidi needs it, no hardcoded copy, and that `i18n.js` stays blocking
  and ahead of the stylesheet. Pure Python, no dependencies, runs in under a second.
- `tests/dom_i18n.test.js` loads the page as served and drives its real scripts under jsdom — 46
  assertions over both languages, both auth states, runtime switching, persistence, the legacy
  `iw` language code, blocked `localStorage`, and error-code translation. Needs a running server:
  `python -m uvicorn main:app --port 8080` in one shell, `npm test` in another. Point it at
  production with `APP_BASE=https://app01-295433370725.us-east1.run.app npm test`.
- **jsdom computes no CSS**, so neither suite proves anything about rendered layout. A visual check
  in a real browser is still a manual step, and it is the one worth doing after RTL changes.
- `package.json` exists only to pull in jsdom. The app is Python; nothing at runtime needs Node.

## Deploying

Pushing to `main` builds and deploys — there is no separate deploy command. `cloudbuild.yaml` in
the repo is the live build config; read its header comment before changing anything about the
pipeline, because the branch filter and `ignoredFiles` live on the trigger and cannot be expressed
in the file. Feature branches never deploy (`^main$`), and docs/test-only commits do not rebuild.

## Commits

- Do not add `Co-Authored-By` trailers to commit messages.
- Update `prompts/project_log.md` at the end of each session with a timestamped entry.
