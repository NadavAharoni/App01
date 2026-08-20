# Project Log

---

## Current Status
*Last updated: 2026-08-20 — update this section at the start/end of every session.*

### What's Working
- ✅ Google OAuth 2.0 login — tested locally and on Cloud Run with two separate Google accounts.
  Re-verified end to end in production 2026-08-19 against the restyled frontend: sign-in creates
  the Neon `users` row, the dashboard renders the profile, and Google's generated letter-avatar
  loads via `avatar_url`. `username` is correctly `—` for Google accounts.
- ⚠️ Local register / login / logout (email + password) — **implemented but never exercised
  end to end.** Listed here previously as working, which contradicted the "not done yet" entry
  below. The routes and the form exist; nobody has created an account this way.
- ✅ JWT session via HTTP-only cookie (`access_token`, 24h TTL)
- ✅ Protected `/auth/me` endpoint and `get_current_user` dependency
- ✅ Public marketing home page (hero, features, stack, CTA) reachable without logging in
- ✅ Sticky menu bar with Sign in / Sign up buttons and a hamburger menu on narrow screens
- ✅ Dashboard as a second view behind auth; signing out returns to the public home page
- ✅ Neon Postgres connected; `users` table auto-created on startup
- ✅ App runs locally on Python 3.14 via `python -m uvicorn main:app --reload --port 8080`
- ✅ Deployed to Google Cloud Run
- ✅ **Deploy config lives in the repo and is live.** The trigger holds only
  `filename: cloudbuild.yaml` and runs the committed file — verified 2026-08-20 by an explicit
  trigger run (steps `Build;Push;Deploy`, same Artifact Registry path as before).
- ✅ **Docs- and test-only commits no longer redeploy.** `ignoredFiles` on the trigger covers
  `**/*.md`, `tests/**`, `package*.json`, `.gitignore`, `.env.example`.
- ✅ **Artifact Registry is capped** — `cloudbuild.yaml` prunes to the newest 3 tagged images on
  every deploy, so storage no longer grows without bound
- ✅ **Budget alert** — 10 ILS/month, scoped to this project, alerting the billing admin by default
- ✅ **Cloud drift check** — `verify-gcp.ps1` + `gcp-config.ps1`. Read-only; exits 1 on drift.
  Reports 0 drift and 0 warnings as of 2026-08-20. Verifies the trigger has no substitutions and no
  inline build, both `maxScale` keys agree, the registry is within the free tier, and the budget
  exists with a recipient.
- ✅ **Test suite for the bilingual UI** — `tests/check_i18n.py` (static, dependency-free) and
  `tests/dom_i18n.test.js` (jsdom, 42 assertions, runs against local or production).
- ✅ **Bilingual UI (English + Hebrew, RTL)** — language auto-detected from the browser on first
  visit, remembered in `localStorage`, switchable from the menu bar. All copy in `static/i18n.js`.
  **Merged to `main` and live in production 2026-08-20.** The 42-case jsdom suite passes against
  the production URL, and the page was checked by eye on Android Chrome: RTL layout, mirrored
  spacing and the `dir="ltr"` values all render correctly. Tag `before-hebrew` marks the last
  English-only commit if a rollback is ever needed.

### What's Not Done Yet
- ⬜ Local credentials login (form exists in UI, untested end-to-end)
- ⬜ Cloudflare CDN / R2 integration (future phase)
- ⬜ AI API integration (future phase)

### Known Quirks
- `uvicorn` in PATH is Python 3.13 — always use `python -m uvicorn`, never bare `uvicorn`
- Neon connection string contains libpq params (`sslmode`, `channel_binding`) that asyncpg rejects — `database.py` strips them automatically; don't add them manually to `connect_args`
- `load_dotenv()` is called in `main.py` — `.env` is picked up automatically, no need to set env vars manually when running locally
- Cloud Run terminates HTTPS at the ingress — `ProxyHeadersMiddleware` in `main.py` ensures `request.base_url` reflects the correct `https://` scheme
- **Tailwind CDN has two traps, both hit in `static/index.html`:** (1) `@apply` in a `<style>` block does nothing — it is a build-time directive, so write plain CSS; (2) the CDN only compiles class names it can find in the document, so a class that exists *only* inside a JS string (e.g. `lg:inline` in an `innerHTML` template) is never generated. Keep both auth states in the static HTML and toggle them instead of injecting markup.
- **RTL: the bidi algorithm is the thing that bites.** An LTR run (email, UUID, hostname, shell
  command) placed inside RTL text gets reordered on screen and renders as nonsense — a UUID's
  hyphens shuffle and the id becomes unreadable. Every such value carries `dir="ltr"`. If a value
  ever looks scrambled in Hebrew, this is why, and the fix is always `dir="ltr"`, never rewriting
  the string.
- **RTL: use logical Tailwind utilities only** (`ms-`/`me-`/`ps-`/`pe-`/`text-start`), never
  `ml-`/`mr-`/`pl-`/`pr-`/`text-left`. The CDN is Tailwind **3.4.17**, verified by fetching it,
  which supports all of them. A physical utility is a bug visible only in Hebrew.
- `i18n.js` is loaded **blocking and first** in `<head>` on purpose: it sets `<html lang/dir>`
  before first paint. Making it `defer`, moving it after the stylesheets, or converting the
  dictionary to fetched JSON all reintroduce a visible flash of English LTR.
- No `.env` exists on this machine — `DATABASE_URL` and `JWT_SECRET` must be supplied before the app will import (`database.py` and `auth.py` read them at module level)

### Environment
- Local: Windows, Python 3.14.3, WSL2 available as fallback
- DB: Neon Postgres 17 (credentials in `.env`)
- Docker image: `python:3.11-slim` (production target)
- Cloud Run: service `app01`, region **us-east1** (free-tier eligible), scaling Min 0 / Max 1,
  URL `https://app01-295433370725.us-east1.run.app`
- GCP project: ID `project-159346f9-b041-4382-b4f`, number `295433370725`
- **Deploys happen by pushing to the GitHub repo**, not by `gcloud run deploy --source`. A Cloud
  Build trigger created through the Cloud Run console watches the repo and builds from the
  `Dockerfile`. Trigger `app01-deploy-on-push` (renamed 2026-08-20 from the wizard-generated
  `rmgpgab-...--maoch`), ID `68da5a2f-0efc-48f1-8214-c3dbd54b039f`. The ID is the handle: key
  scripts on it, never on the name.
- **The trigger lives in region `global`**, not `us-east1` — the deploy *target* is us-east1, the
  trigger resource is not. Passing `--region us-east1` to `gcloud builds triggers describe`
  returns `NOT_FOUND` even with full access, which reads exactly like a permissions problem and
  is not one. Always `--region global` for this trigger.
- **Only `main` deploys.** Verified 2026-08-20 by `gcloud builds triggers describe`:
  `github.push.branch: ^main$`. Feature branches can be pushed freely — they build nothing and
  create no revision. Work in progress is safe on a branch; merging to `main` is the deploy.
- **The build config is inline in the trigger**, not a `cloudbuild.yaml` — the trigger holds a
  `build:` block (docker build `--no-cache` → push to `us-east1-docker.pkg.dev` →
  `gcloud run services update`) and has no `filename:`. This is the concrete reason the RiddleSite
  warning applies: `gcloud builds triggers create/update github` cannot express an inline build,
  so use `gcloud beta builds triggers export` → edit → `import`. It also means the deploy steps
  are recoverable, so the "no deploy config in the repo" gap can be closed by committing them.
- The trigger has **no `ignoredFiles`/`includedFiles` filter at all**, which confirms that
  docs-only commits rebuild and deploy an identical revision.
- **Two machines.** This repo is worked on from more than one Windows machine, so nothing about
  the local toolchain is a project-wide fact — always re-verify rather than trusting a past note.
- gcloud CLI: **present on the machine used 2026-08-20** (SDK 578.0.0). That retires the old
  "once gcloud is installed" phrasing, but it does not mean gcloud is available in the current
  session — run `gcloud --version` and check.
- The **active gcloud account is whatever the last `gcloud auth login` set**, and several Google
  identities are used across unrelated projects, so it may not be App01's owner and can differ
  between sessions. When it is not, App01's project reads as `PERMISSION_DENIED` rather than
  missing, and `gcloud projects list` simply omits it — neither is a fault. Confirm with
  `gcloud auth list`, then pass `--project` and `--account` explicitly.
- The repo is **public**, and Cloud Build's GitHub check runs expose both project identifiers to
  anyone: the check *name* carries the project ID and its Details link carries the project number.
  Readable unauthenticated via `/repos/NadavAharoni/App01/commits/main/check-runs`, or in the web
  UI under a commit's Checks tab. Not a vulnerability — a project ID is not a credential — but do
  not assume these IDs are private.

### Next Steps

*Resolved items are not kept here. Session 5 (2026-08-20) closed the deploy-config, docs-only
rebuild, Artifact Registry, budget, trigger-rename and Hebrew-verification items; the reasoning for
each is in that session entry rather than duplicated as struck-through text.*

**Verification owed**
- `sql/users_table.sql` is **syntax-checked but never executed** — there is no reachable database
  from this machine. Run it once in the Neon SQL editor; both verification queries should report
  `OK` on every row.
- Test local credentials register/login end-to-end, then smoke test the same against Cloud Run.
  The form exists and has never been exercised.
- Re-run `.\verify-gcp.ps1` and confirm the Artifact Registry *reported* size has fallen toward the
  ~134 MB of real content. It read 472 MB immediately after the prune because reclamation is
  asynchronous. No action unless it stays high.

**Content**
- Replace the placeholder landing-page copy once a demo feature (e.g. per-user notes) exists — the
  hero should show off that feature rather than describe the template. Note this is now ~30 keys
  across two dictionaries in `static/i18n.js`, not one block of English in the markup.
- **Have a native Hebrew reader review the copy in `static/i18n.js`.** It was written to read as
  Hebrew rather than as a translation, and leans on impersonal forms ("אפשר לפתוח",
  "פותחים, קוראים") because Hebrew has no gender-neutral second person. That is a style choice
  worth a second opinion.
- Cosmetic: the Hebrew headline breaks between `כמעט` and `בחינם.`, splitting the phrase. A
  non-breaking space in `hero.title_accent` would hold it together.

**Testing**
- **pytest suite** — unit tests (JWT, password hashing) plus integration tests via
  `httpx.AsyncClient` against the FastAPI routes; run in CI on every push. Note `tests/` already
  holds the i18n checks, so this slots in beside them rather than starting from nothing.
- **Browser smoke tests** — automated end-to-end verification against Cloud Run after deploy
  (local credentials test account; Google OAuth verified manually). This is the gap the jsdom suite
  cannot cover, since it computes no layout.

**Carried forward for the template, not for this project**
- The **GCP free trial cliff** was resolved here in 2026-08-19, but every student hits it 90 days
  after signing up. Tracked in `prompts/wizard_concept.md` under "Constraints the template must
  respect".

---

## 2026-08-20 — Session 5

### Deploy pipeline recorded, and the trigger's actual behaviour established

`gcloud` turned out to be installed on this machine, which unblocked questions that had been open
since the trigger was created in the Cloud Run console. Answers, all now in **Current Status**:
the trigger lives in region **`global`** (asking for `us-east1` returns `NOT_FOUND` even with full
access, which reads exactly like a permissions error), it fires only on **`^main$`** so feature
branches never deploy, it has **no `ignoredFiles`** filter, and its build config is **inline** —
which is why `gcloud builds triggers update github` rejects it and export/import is required.

Committed `cloudbuild.yaml` reproducing that build. The templated image path was checked against
Artifact Registry and resolves to the same `cloud-run-source-deploy/app01/app01` in use today.
It is **not live** — repointing the trigger at it is a separate change.

An incidental finding: the repo is public, and Cloud Build's GitHub check runs publish both the
project ID (in the check name) and the project number (in its Details link) to anyone. Not a
credential, but not private either, and every student following the wizard will inherit it.

### Bilingual UI: English + Hebrew with RTL — shipped to production

Second language added on `feature/i18n-hebrew`, then merged and deployed. The frontend turned out to be unusually
well-suited to it: one file, no build step, and only **five** direction-sensitive utilities in 636
lines, because the layout was already flex/grid with `gap` and `mx-auto`. Setting `dir="rtl"` flips
it correctly on its own.

- `static/i18n.js` — new. 75 keys × 2 languages, plus the detection/switching runtime. Loaded
  blocking from `<head>` so `lang`/`dir` are set before first paint.
- `static/index.html` — 34 edits: `data-i18n` hooks throughout, the five physical utilities
  swapped for logical ones, `dir="ltr"` on every LTR-by-nature value, and a language switcher in
  both the desktop bar and the mobile menu.
- `routers/auth.py` — six English `detail` sentences became stable codes (`email_taken`, …),
  translated client-side against `err.*` keys. Unknown codes fall back to a generic message.
- Heebo added alongside Inter: Inter has no Hebrew glyphs, so without it Hebrew fell back to a
  system face and looked like a different site.

Judgement calls worth knowing about: the hero headline is **three** keys rather than one, because
its `<br class="hidden sm:block">` is a deliberate desktop break that each language wants
elsewhere — and keeping the tag in the markup also keeps `sm:block` visible to the Tailwind CDN,
which only compiles classes it can find in the document. The `users` table name is split out of
its sentence so translation cannot touch it. Shell commands are left untranslated inside a
`dir="ltr"` block while their comments are translated. The switcher labels ("EN", "עברית") are each
written in their own language and deliberately not translated.

Verified with jsdom against the running server: 42 assertions over both languages, both auth
states, runtime switching, persistence, the legacy `iw` language code, blocked `localStorage`, and
error-code translation including the unknown-code fallback. Plus static checks for key parity in
both directions, orphaned keys, leftover untranslated text, and physical direction utilities.
**Not** verified: actual rendered layout, since jsdom computes no CSS.

### Shipping it, and what that taught us about the pipeline

Sequence: pushed the `cloudbuild.yaml` commit to `main` on its own, waited for that build to go
green, tagged that commit **`before-hebrew`** as the rollback point, then merged and pushed. Both
builds succeeded in 70–80s. The multilingual app is live and the jsdom suite passes against the
production URL as well as locally.

Facts worth keeping:

- **`gcloud builds list` also needs `--region global`.** Builds from a global trigger are global.
  Querying `us-east1` returns an empty list with no error, which looks exactly like "no builds ran"
  rather than "you asked the wrong region". Same trap as `triggers describe`.
- **Pushing a tag does not trigger a build.** The trigger filters on `github.push.branch`, so
  `before-hebrew` reached the remote without producing a revision. Tags are free.
- Deploying the tag is a valid rollback: `gcloud run services update app01 --image <the image
  tagged with 47fcc50>`, or revert the i18n commit and push.
- `COPY . .` in the Dockerfile with no `.dockerignore` means a newly added static file needs
  nothing extra to ship — checked before pushing, because a Dockerfile that copied files
  individually would have silently omitted `static/i18n.js` and broken the page in production only.

### Trigger repointed at the repo, and a test suite for the i18n rules

Two follow-ups closed.

**The trigger now runs `cloudbuild.yaml`.** Worth being precise about what was previously done and
what was not: committing the file recorded the pipeline in git, but the trigger still carried its
own inline copy of the build steps and never read the file. Those are separate things — a file in
the repo and a resource in GCP — and they only connect via `filename:`. Done by export → edit →
import (the only way, since `triggers update github` rejects a console-created trigger), removing
the inline `build:` block and the trigger's substitutions. Dropping the substitutions matters: had
they stayed, they would shadow the file's defaults and editing `cloudbuild.yaml` would have changed
nothing, which is the worst possible outcome — a config file that looks authoritative and is inert.

Verified by an explicit `gcloud builds triggers run`: steps `Build;Push;Deploy`, `ALLOW_LOOSE` from
the file's own options, and the image resolved to the same
`cloud-run-source-deploy/app01/app01:<sha>` as before, which confirms `$PROJECT_ID` and
`_REPO_NAME` behave in a real build and not just on paper. Service came back on revision
`app01-00017-nc6` with `maxScale: 1` intact.

**`ignoredFiles` is set**, so docs- and test-only commits no longer ship identical revisions.

**Tests committed.** `tests/check_i18n.py` is dependency-free and mechanically enforces every rule
in CLAUDE.md's Multilingual section; each of its ten checks was confirmed to actually fail by
temporarily breaking the thing it guards (dropping a Hebrew key, reintroducing `-mr-2`, adding an
API error code with no message, un-wrapping a translated span, and making `i18n.js` `defer`). A
check that cannot fail is worse than no check, because it reads as coverage.
`tests/dom_i18n.test.js` is the jsdom suite, now runnable from the repo and pointable at
production via `APP_BASE`.

The suite is **42** assertions, not the 46 stated in the two commit messages before this one —
counted properly from its own output (10+3+5+6+10+4+3+1) rather than estimated. Nothing functional
turns on it; the docs are corrected and the commit messages stand as written.

Neither suite computes CSS, so rendered layout remains unverified by machine — a real-browser look
after RTL changes is still a manual step, and is still outstanding.

### Renaming the trigger

`rmgpgab-app01-us-east1-NadavAharoni-App01--maoch` is now **`app01-deploy-on-push`**, matching
RiddleSite's convention. Cosmetic, but this repo is destined to be a template and a student opening
the Cloud Build console should be able to recognise their own trigger.

Two things were verified rather than assumed. Renaming by export/import had not been done before —
RiddleSite did it through the console — so the trigger list was counted before and after in case
import created a duplicate instead of updating in place. It updated in place: one trigger, same id,
`gcp-cloud-build-deploy-cloud-run-managed` tags intact. And because a rename touches live deploy
config, a build was run afterwards to prove the path still works end to end; it deployed
`app01-00021-jrq` and production still serves the Hebrew page.

That build also gave the fixed prune step its first run at steady state: 3 tagged images, keeping 3,
0 candidates, nothing deleted. The over-deletion is fixed and the rollback depth has healed.

### Budget: 10 ILS, and one resource that turned out to be unnecessary

Created `app01-monthly`: 10 ILS per calendar month, scoped to this project alone so spend on other
projects cannot trip it and so an alert names the right culprit. Thresholds at 50%, 90% and 100% of
actual spend, plus 100% of *forecast* — the forecast rule is the one that warns before the money is
gone rather than after.

The billing account is in ILS, which matters: a budget whose currency differs from the account is
rejected outright, so that was checked first rather than discovered from an error.

**The notification channel was dropped, not deferred.** The question "isn't that email already
there?" was the right one. A Cloud Monitoring channel exists to reach somebody who is *not* a
billing administrator, without granting them billing permissions. Here the intended recipient is
the sole `roles/billing.admin` on the account, and a budget with an empty `notificationsRule` emails
the billing admins by default — so a channel would have been a duplicate destination, and its
address would have had to be committed to a public repo to be verifiable. `verify-gcp.ps1` now
checks that a billing admin exists, which is the property that actually determines whether anyone
receives an alert.

Worth being clear about what a budget is for: it would not have caught the Artifact Registry leak,
because cents never cross a threshold. It catches the expensive mistakes — an instance ceiling
raised by accident, a runaway loop, a service left with min-instances above zero.

`verify-gcp.ps1` now reports zero drift and zero warnings.

### Capping Artifact Registry, and breaking rollback while doing it

The registry had reached 424 MB of the 500 MB free tier across 42 images with nothing reaping them.
Added a `Prune` step to `cloudbuild.yaml` and granted the Cloud Build service account
`roles/artifactregistry.repoAdmin`, scoped to the one repository — `artifactregistry.writer` can
push but not delete, so without it the step reaps nothing and, under `allowFailure`, says nothing.

**The first version of the step was wrong and did real damage.** It kept "the newest 3 entries" in
the repository and deleted 40. The repository namespace also holds untagged OCI manifests —
attestation and metadata artifacts a few KB in size — and keep-slots went to those instead of to
real images. Result: every revision except the one then serving lost its image, so instant rollback
via `update-traffic` is gone for all 19 older revisions. Recovery is `git revert` plus a push, which
works because all ten dependencies are pinned exactly, but it is a ~90s rebuild rather than a
traffic switch. The `before-hebrew` tag is still a valid rollback target by that route.

Fixed by counting and deleting **tagged images only** — every genuine deploy carries its commit sha
as a tag, so tags are the reliable discriminator — sorting newest-first without relying on
`--sort-by`, and refusing to delete anything tagged with the sha the build just deployed. Untagged
manifests are never touched: they are kilobytes and some are referrers attached to an image being
kept. The shell logic was tested against simulated `gcloud` output containing the exact untagged
manifests that caused the failure, asserting in particular that the *previous* image survives.

**On severity, honestly:** this was reported as urgent, and unbounded growth did need capping, but
the financial exposure was never dramatic — Artifact Registry charges roughly \$0.10 per GB per
month beyond the free 0.5 GB, so overshooting would have cost cents. The damage done by rushing the
fix was larger than the problem being fixed.

`verify-gcp.ps1` now reports tagged and untagged counts separately with the live content size, and
explains a large reported-vs-live gap as reclamation lag instead of raising an alarm that resolves
itself.

### Pulling RiddleSite, and a drift checker instead of a provisioner

Pulled RiddleSite (12 commits behind) before writing anything, on the theory that it had already
met these problems. It had, and three findings transferred directly.

**Two `maxScale` keys.** The Cloud Run console wizard writes `run.googleapis.com/maxScale` on the
*service* metadata, and `gcloud run deploy` never touches it. The key that actually governs
autoscaling is `autoscaling.knative.dev/maxScale` on the *revision*. RiddleSite ran for weeks with
1 on the revision and a stale 3 on the service, so its console header advertised triple the real
ceiling, on the single number that exists to reassure you about spend. App01 checked: both are 1,
clean by luck rather than by design. Now an explicit check.

**Trigger names are mutable.** RiddleSite's config used to claim the wizard-generated name could
not be changed because "the name is the handle". Its Step 20 disproved that: the immutable handle
is the id, the name is a label, and a rename preserved the Cloud Run association. Worth knowing
here, because a note to that effect had already been carried into this repo.

**Artifact Registry needs pruning.** RiddleSite prunes to the 3 newest images because the free
tier is 0.5 GB. App01 has no prune step and sits at 424 MB across 42 images, 85% of the tier and
growing with every deploy. This was the most valuable thing the pull turned up, and writing the
script from first principles would not have found it.

Also corroborated independently: gcloud absent on one machine and present on another, matching the
two-machine correction recorded above; and `gcloud builds triggers update github` being unable to
express Cloud Run-managed fields.

**Built verify-only, not a provisioner.** RiddleSite's `setup-gcp.ps1` provisions and doubles as
machine recovery. Useful, but it would not have caught the substitutions problem, because
provisioning asserts things *exist* and that failure was something *extra* appearing. So App01 gets
`gcp-config.ps1` (declared state) plus `verify-gcp.ps1` (read-only comparison, exit 1 on drift).
Provisioning can be layered on the same config later.

All five drift checks were confirmed to actually fire, by mutating the *declared* config rather
than live cloud state: same comparison code path, no production risk. The first attempt at that
crashed mid-run and left `gcp-config.ps1` mutated; the second run then backed up the corrupted file
as its own baseline, so every case inherited a phantom drift and the numbers looked wrong in a
confusing way. Rewritten with a `finally` restore and a baseline assertion that refuses to run
unless drift is 0.

Two Windows/PowerShell details that cost real time, now in `CLAUDE.md`, because both present as
unrelated bugs:

- **Save `.ps1` as UTF-8 with BOM.** PS 5.1 decodes a BOM-less `.ps1` as ANSI, which turned every
  em dash into mojibake and fed a cascade of parse errors.
- **`$ErrorActionPreference` must be `Continue`, not `Stop`.** gcloud writes informational lines to
  stderr on *success* ("Listing items under project...", "Repository Size: ..."), and Windows
  PowerShell wraps native stderr in ErrorRecords. Under `Stop`, a perfectly successful gcloud call
  kills the script the moment anything redirects its output, which is precisely what a test harness
  does. Exit codes are checked explicitly instead.

One more quirk: the repository size is not a field. `describe --format=json` has no size key at
all, and gcloud only emits it as a human-readable stderr line, so it has to be scraped. Summing
`imageSizeBytes` across images is not a substitute, because layers are deduplicated: 42 images of
~67 MB each occupy 424 MB, and summing overstates it roughly sevenfold.

## 2026-08-19 — Session 4

### Frontend restyle: public home page + menu bar

App01 previously opened straight onto a login card, so there was nothing to see without an
account. Rebuilt `static/index.html` as a public marketing page with the app behind it, in
preparation for using this repo as the template for the setup-wizard project.

#### Changes

| File | Change |
|---|---|
| `static/index.html` | Rewritten. Sticky translucent menu bar (brand, nav links, Sign in / Sign up, hamburger under `md`); public hero with gradient headline and a drawn product mock; features, stack and CTA sections; footer. Login/register moved into a single modal dialog shared by the header buttons and both CTAs. Dashboard is now a second view (`#view-dashboard`) rather than a replacement for the page. |

Backend untouched — no changes to `main.py`, `routers/auth.py`, `models.py`, `database.py`
or `auth.py`. The frontend still talks to the same four endpoints.

#### Landing-page copy: describe the app, don't advertise the template

First draft of the hero sold the *idea* of the template ("Your app, on the cloud, for almost
nothing"). Wrong on two counts: this page is also what a student's own users will eventually see,
so until it is rewritten their app advertises someone else's product; and the pitch belongs on the
wizard site, not in the thing the wizard installs. Recast as an example app describing itself
("An example app, running in the cloud for almost nothing"), with a `Replace this copy` comment
marking the section as the first thing to rewrite. When a demo feature lands, the hero should
show that feature instead.

The stack panel also claimed `gcloud run deploy --source .`, which is not how this repo ships.
Corrected to `git push origin main`.

#### Follow-up after the first deploy: the home page ignored the auth state

Signing in with Google landed on the public home page still showing "Create an account", "Sign up"
and "Try the sign-in flow" — to a user who had just signed in. Two separate faults:

1. **The public page never adapted to being signed in.** It is reachable while authenticated (via
   the logo, the Home link, or the post-login redirect), so its calls to action have to follow the
   auth state like the header already did. The hero CTA now swaps to "Open your dashboard", the
   closing invitation section is removed entirely, and the hero's final sentence swaps. All are
   static markup toggled by class in `renderAuth()` — the same pattern used for the header, and
   for the same Tailwind CDN reason.
2. **The two auth paths ended in different places.** `routers/auth.py` redirected the Google
   callback to `/`, while the email/password path calls `showView("dashboard")`. The callback now
   redirects to `/#/dashboard`, which the frontend already reads on load.

Verified locally in both states: signed in, the home page contains no "Create an account" or
"Sign up" text anywhere; signed out, everything is restored.

Confirmed on the live service after deploy: Google sign-in now lands on the dashboard, and a
second sign-in reuses the existing `users` row (same UUID) rather than inserting a duplicate,
so the callback's update branch works as well as its insert branch.

#### Bugs found and fixed along the way

- `.tab-btn.active` was styled with `@apply` inside a plain `<style>` block, which the Tailwind
  CDN does not process. The active-tab underline had never rendered. Now plain CSS.
- The signed-in username span was injected via `innerHTML` carrying `lg:inline`, a class present
  nowhere else in the document, so the CDN never generated it and the name was invisible at every
  width. Both auth states are now static markup toggled by class, and the display name is set with
  `textContent` — which also removes the `innerHTML` injection path entirely.

#### Verified locally

Server run on port 8080 with a deliberately unreachable `DATABASE_URL` (`init_db` degrades
without raising, by design). Driven through the browser: logged-out header, modal open/close via
button, backdrop and Escape, tab switching, hamburger toggle with correct `aria-expanded`, menu
auto-close on navigation, dashboard render for both avatar and initials fallback, Google vs local
provider badges, sign-out returning to the public page, HTML-escaping of a hostile display name,
and no horizontal overflow at 375 / 768 / 1280 px.

**Not verified:** real register / login / Google OAuth against Neon — this machine has no `.env`,
so no database credentials. The forms are wired to the same endpoints as before and the request
shapes are unchanged, but the round trip is still untested end to end.

---

## 2026-05-28 12:00–12:06 — Session 3

### Cloud Run OAuth Fix

Google OAuth redirect URI was hardcoded to `localhost`, causing login to fail on Cloud Run.

#### Changes

| File | Change |
|---|---|
| `routers/auth.py` | `GOOGLE_REDIRECT_URI` env var removed; redirect URI now built dynamically via `_callback_uri(request)` using `str(request.base_url) + "auth/google/callback"` |
| `main.py` | Added `ProxyHeadersMiddleware` so `request.base_url` returns `https://` on Cloud Run (which terminates TLS at the ingress before uvicorn) |

#### Git Commit

`407cd38` — *Fix Google OAuth redirect URI to be dynamic; add ProxyHeadersMiddleware for Cloud Run HTTPS*

#### Milestone

✅ Google OAuth confirmed working on Cloud Run.

---

## 2026-05-27 18:40–19:19 — Session 2

### Dependency Cleanup & Local Dev Fixes

All issues resolved; Google OAuth confirmed working end-to-end with two separate Google accounts.

#### Dependency Changes (`requirements.txt`)

| Change | Reason |
|---|---|
| Removed `alembic` | Was never used — `Base.metadata.create_all` in the lifespan already handles table creation |
| `passlib[bcrypt]` → `bcrypt==4.1.3` | passlib unmaintained since 2020; `bcrypt` is the library passlib called anyway |
| `python-jose[cryptography]` → `PyJWT==2.8.0` (later bumped to `2.13.0`) | python-jose pulls the heavy `cryptography` binary; HS256 only needs stdlib — `PyJWT` with no extras suffices |
| All packages bumped to current stable | Original pins pre-dated Python 3.14 — `asyncpg 0.29.0` and `pydantic-core 2.18.2` failed to compile on the local Python 3.14 install |

#### Bug Fixes

| File | Fix |
|---|---|
| `database.py` | Strip all libpq-style query params (`sslmode`, `channel_binding`, etc.) from the Neon URL — asyncpg doesn't accept them; pass `ssl="require"` via `connect_args` instead |
| `database.py` | `init_db()` now catches connection failures and logs a warning instead of crashing the app on startup |
| `main.py` | Added `load_dotenv()` so a local `.env` file is picked up automatically; no-op in Cloud Run where vars are injected |

#### Local Dev Notes

- `uvicorn` in PATH resolves to a Python 3.13 install; always run via `python -m uvicorn main:app --reload --port 8080` to use the active Python (3.14)
- WSL2 available as fallback if Python version conflicts arise

#### Git Commits

| Hash | Message |
|---|---|
| `fad3628` | Dependency improvements: remove Alembic, swap passlib->bcrypt, swap python-jose->PyJWT |
| `86441a4` | Bump all deps to current stable; fixes build on Python 3.14 |
| `aab1c4d` | Graceful DB startup: warn instead of crash if DB unreachable |
| `42082f1` | Fix asyncpg SSL: strip all libpq query params, load .env on startup |

#### Milestone

✅ Google OAuth login confirmed working with two separate Google accounts against live Neon Postgres database.

---

## 2026-05-27 17:50–18:08 — Session 1

### Initial Application Build

Implemented the full baseline FastAPI authentication application as specified in `version_01.md`.

#### Files Created

| File | Description |
|---|---|
| `main.py` | FastAPI app entry point; registers routers, mounts static files, runs `init_db()` on startup via lifespan context |
| `database.py` | Async SQLAlchemy engine using `asyncpg`; auto-translates `postgres://` → `postgresql+asyncpg://` for Neon compatibility; `init_db()` creates tables on first run |
| `models.py` | `User` ORM model supporting both local and Google auth: `id` (UUID), `email`, `username`, `hashed_password` (nullable), `auth_provider`, `full_name`, `avatar_url`, `is_active`, `created_at`, `updated_at` |
| `auth.py` | bcrypt password hashing via `bcrypt`; JWT creation and decoding via `PyJWT`; `get_current_user` FastAPI dependency (reads `access_token` HTTP-only cookie) |
| `routers/auth.py` | All authentication endpoints (see API surface below) |
| `routers/__init__.py` | Package marker |
| `requirements.txt` | Pinned dependencies: FastAPI, Uvicorn, SQLAlchemy, asyncpg, bcrypt, PyJWT, httpx, python-multipart, python-dotenv, pydantic[email] |
| `static/index.html` | Single-page frontend (Tailwind CSS via CDN) |
| `.env.example` | Documents all required environment variables |
| `.gitignore` | Excludes `.env`, `__pycache__`, virtual environments |

#### Dockerfile Update

Updated `CMD` to use `${PORT:-8080}` so Google Cloud Run's injected `PORT` environment variable is respected at runtime.

#### API Surface

| Method | Route | Description |
|---|---|---|
| `POST` | `/auth/register` | Register a local account; returns user JSON + sets `access_token` cookie |
| `POST` | `/auth/login` | Authenticate with email + password; sets cookie |
| `POST` | `/auth/logout` | Clears the `access_token` cookie |
| `GET` | `/auth/google` | Redirects to Google OAuth 2.0 consent screen |
| `GET` | `/auth/google/callback` | Exchanges auth code for tokens; upserts user; redirects to `/` |
| `GET` | `/auth/me` | Returns current user profile (protected — requires valid cookie) |
| `GET` | `/` | Serves the SPA (`static/index.html`) |

#### Frontend Features

- "Sign in with Google" button (redirects to `/auth/google`)
- Login / Register tab switcher with inline error display
- Protected Dashboard view: avatar, full name, email, username, user ID, auth provider badge
- Auto-detects existing session on page load via `/auth/me`

#### Environment Variables Required

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | Neon Postgres connection string |
| `GOOGLE_CLIENT_ID` | Google OAuth app client ID |
| `GOOGLE_CLIENT_SECRET` | Google OAuth app client secret |
| `JWT_SECRET` | Secret key for signing JWTs |
| `GOOGLE_REDIRECT_URI` | OAuth callback URL registered in Google Console |
| `PORT` | Injected automatically by Cloud Run (defaults to `8080`) |

#### Git Commit

`08d4a30` — *Implement FastAPI auth app (Google OAuth + local credentials)*
