# "Build your app with AI" — setup wizard concept

*Design discussion, 2026-08-19. Not built yet. Recorded here because App01 is intended to become
the template application the wizard installs, so decisions here constrain this repo.*

---

## What it is

A guided path that takes a semi-technical user from a bare Windows machine to a working web
application deployed on Google Cloud Run, with a Neon Postgres database and Google sign-in.

Once the app is running, the user continues with Claude Code to build the actual functionality.
The wizard's job ends at "you have a live URL and a repo you own".

**Two artifacts, one seam:**

| Piece | Owns |
|---|---|
| **Wizard web page** (guided tutorial) | Everything a coding agent physically cannot do: signing up for GitHub / Neon / GCP, entering a payment method, the OAuth consent screen, authorizing the Cloud Build GitHub App |
| **Claude Code skill** (`/setup`, shipped in the template repo) | Everything on the machine: gcloud provisioning, clone, `.env`, first deploy, and diagnosing failures |

The page's final step is "run `claude`, type `/setup`" — which is also the moment the user first
sees what Claude Code is for.

## Who it is for

- Students in "Build your app with AI" classes (CS and industrial engineering)
- Semi-professional builders who want to own their app rather than rent it

Deliberately **not** aimed at pure vibe-coding users. This sits below Lovable / Base44 and above
"build it from scratch".

## Positioning

> You are already paying for Claude Code. Instead of also paying Lovable or Base44, put your app
> on the cloud for almost nothing and keep full control.

The differentiator is ownership, and it is durable **because the competitors structurally cannot
match it** — hosting *is* their business model:

- Stop paying for Claude Code and the app keeps running.
- Switch to Codex or Gemini later; the app does not care.
- Hand the whole thing to a customer. For industrial engineering students demonstrating to
  industry partners, the deliverable is an asset, not a seat on someone's SaaS.

**Monetization:** paid "Build your app with AI" classes where students use the wizard to get a
running app within the first session; and lead generation for consulting. The wizard page is
therefore also a portfolio piece and should carry the author's name.

## Decisions settled

- **Cloud hosting is mandatory, not optional.** Students must be able to demo to external users.
  Instance caps, region, and budget alerts are in from day one — the cost controls are part of the
  pitch, not a caveat.
- **Windows first.** A bash script for macOS comes in phase 2. Keep OS-specific content in one
  clearly marked place so adding macOS is adding a column, not a rewrite.
- **Use `winget` with unattended installs**, ideally a [WinGet Configuration](https://learn.microsoft.com/en-us/windows/package-manager/configuration/)
  DSC YAML — idempotent and Microsoft-maintained. A tiny bootstrap PowerShell script pulls the
  YAML from the repo. Reuse the `Get-Gcloud` fallback from RiddleSite's `gcp-config.ps1`: the
  Cloud SDK installer does not update PATH for already-open processes.
- **Walk the user through a real Neon signup.** Rejected Neon Launchpad / `npx neondb`
  (instant no-signup Postgres): its 72-hour expiry creates an "it stopped working" cliff and
  teaches nothing about the service they will actually operate. Neon's signup is GitHub OAuth
  with no card, so it is not where users are lost.
- **Region is not a free choice.** us-east1 is free-tier eligible; Tel Aviv (me-west1) is Tier 1
  priced but appears *not* free-tier eligible. Present it as a deliberate one-time fork with the
  cost stated, since region is effectively irreversible for a service. App01 itself is deployed in
  us-east1; RiddleSite is in me-west1.
- **Ship one opinionated path.** Multi-provider (AWS, other DBs) is a later problem — the
  abstraction is the expensive part and doubles the testing surface forever. Keep the *seam*
  clean (provider logic in one skill file and one config file) and let demand decide.
- **Cold starts: do not add Cloudflare.** Serving a static shell from a CDN does not fix it — the
  first API call still waits on the cold container, so it moves the spinner rather than removing
  it, while adding an account, a nameserver migration and a failure mode. In order: (1) honest
  loading state, (2) trim container startup and do not block serving on the database, (3)
  `min-instances=1` when it is worth paying for. Option 3 is the upsell, and makes the cold start
  a live lesson in the cost/performance dial. Cloudflare is right later, for a custom domain.
- **Single source of truth for agent instructions.** Put the setup runbook in one plain
  `SETUP.md`; make `CLAUDE.md` / `AGENTS.md` / the skill file thin pointers to it. Codex and
  Gemini support then costs two lines each rather than a fork.

## Wizard page design

Four properties that decide whether a guided page actually works:

1. **Pre-fill everything.** A form at the top takes project name, GitHub username, region; every
   subsequent command block renders with those values substituted. Pure client-side JS, no
   backend. Kills the largest error class — a mistyped project ID propagating silently through
   eight steps.
2. **Every step ends in a verification.** *Do this → run this → you should see exactly this.* The
   failure mode of a static guide is a user who does not know step 4 half-worked and carries
   broken state to step 9.
3. **Deep links, not screenshots.** Screenshots go stale within a semester. A link like
   `console.cloud.google.com/apis/credentials?project=<id>` does not, and it skips the navigation
   where people actually get lost. Where UI must be described, describe searchable label text.
4. **Progress that survives closing the tab.** Setup spans hours and multiple sittings.
   `localStorage` checkboxes are ~15 lines. A backend with real login would additionally give a
   class roster and drop-off analytics — attractive, but it turns a static page into an app with
   its own auth, and machine-local steps still cannot be verified server-side. **Postponed.**

Host the wizard page on the same stack it teaches. It dogfoods the claim, and "this page is
running on the thing I am about to show you, for about ₪2/month" is a good opening line.

## Classroom design

- **Split the wizard into "before class" and "in class".** Account signups, billing approval and
  `winget` installs are homework with a deadline. Class time starts at a machine that already has
  tooling and accounts, and is spent on clone → deploy → build a feature. Otherwise the first two
  hours go to twenty people downloading the Cloud SDK over one wifi access point.
- **A known-good checkpoint** the student runs *before* class, so failures surface while there is
  still time to answer email.
- **A Plan B** for the student whose card is declined — pair them up, or a pre-made project.
- Success metric: *what fraction of students reach a working URL in 90 minutes, unaided.* Every
  step should fail loudly with the fix printed.

## Constraints the template must respect

- **Identity scopes only.** An unverified Google OAuth consent screen in Testing mode does *not*
  cap sign-ins at 100 test users when the app requests only `openid`, `email`, `profile` — those
  are non-sensitive scopes needing no verification review. This was confirmed in RiddleSite
  (`architecture.md`, `devlog.md`). **The moment any sensitive scope is added (Drive, Calendar,
  Gmail), verification and the 100-user cap both switch on** and a student's demo breaks in a way
  they will not diagnose. This belongs as an explicit rule in the template's `CLAUDE.md`.
- **Cost controls from commit one:** `--max-instances=1`, `min-instances=0`, a budget alert and a
  notification channel. RiddleSite's `setup-gcp.ps1` is the working reference.
- **The free trial cliff.** GCP trial credit expires 90 days after signup; without upgrading to a
  paid account the service stops and is eventually deleted. For a semester course this lands
  around midterms or demo week, and it fails silently from the student's perspective — the app was
  working, nobody changed anything, the URL is dead. The wizard needs a page for it, and the
  upgrade is best done in the same sitting as billing setup, while the card is already out.
  Distinguish clearly between *trial credit* (expires on a clock) and *steady-state cost*
  (genuinely cents per month).
- **Deploy config must live in the repo.** A console-created Cloud Build trigger cannot be cloned,
  reviewed, or recreated by a script — and RiddleSite documents that `gcloud builds triggers`
  subcommands reject console-managed triggers outright. App01 currently has no `cloudbuild.yaml`
  and no `.github/workflows`, which must be fixed before it becomes a template.

## Prior art

Nothing found that covers the bare-Windows-machine → deployed-URL path for non-developers on an
opinionated Python + Neon + Cloud Run stack. The gap is real, but it is unfilled for a reason:
platform-specific, maintenance-heavy, no business model. It is best treated as **teaching
infrastructure**, not a product.

Adjacent layers:

- **Above** — vibe-coding platforms: Lovable, Base44 (Wix), Bolt.new, v0, Replit Agent,
  Firebase Studio. Deliberately not competing here.
- **Same layer** — boilerplates: [Open SaaS / Wasp](https://github.com/wasp-lang/open-saas) is the
  closest (free, auth, landing page, one-command deploy, and now an `AGENTS.md` plus a Claude Code
  plugin), also Apptension SaaS Boilerplate, Makerkit, SaaS Pegasus, ixartz, `create-t3-app`.
  **Every one of them starts at "clone the repo"** and assumes a developer with a working machine
  and existing accounts. That assumption is the gap.

## Open questions

- Backend login for wizard progress state, or `localStorage` only?
- Two repos (`app-template` + wizard/plugin) or one? Current leaning: two, so the template is
  forkable on its own.
- Which demo feature ships in the template — per-user notes is the leading candidate. Exactly one
  vertical slice: one table, list/create/delete, owner-scoped, one passing test. It is the pattern
  students will copy.
- Distribute the skill as a Claude Code plugin via a marketplace, or just in the template repo?
