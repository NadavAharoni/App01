# Declared GCP state for App01. Dot-source it:  . "$PSScriptRoot\gcp-config.ps1"
#
# This is the single source of truth for the IDENTITY of the cloud resources: which project,
# which service, which trigger, and how that trigger is expected to be configured.
#
# It is deliberately NOT the source of truth for how the service is deployed. The runtime flags
# (--max-instances, --min-instances, the image path, the build steps) live in cloudbuild.yaml and
# are not restated here. A second copy of a value that nothing reads is a copy that goes stale and
# then misleads -- the same failure as putting substitutions on the trigger, where they would
# silently shadow the ones declared in cloudbuild.yaml and make editing that file a no-op.
#
# $MaxInstances below is the one apparent exception, and it is not really one: it is here so
# verify-gcp.ps1 can assert that what is *running* matches what cloudbuild.yaml asked for. It is
# an expectation to check, not a value to apply.

# --- Project ------------------------------------------------------------------
# Both identifiers are needed: gcloud commands want the ID, while the Cloud Run URL and some
# console links carry the NUMBER. Neither is a secret -- the repo is public and Cloud Build's
# GitHub check runs publish both anyway (the check name carries the id, its Details link the
# number). A project id is not a credential.
$ProjectId     = "project-159346f9-b041-4382-b4f"
$ProjectNumber = "295433370725"

$Region      = "us-east1"                  # free-tier eligible; the deploy target
$ServiceName = "app01"
$ServiceUrl  = "https://app01-295433370725.us-east1.run.app"

# --- Artifact Registry --------------------------------------------------------
# Image path is <repo>/<repo-name>/<service>; both segments are "app01" here.
$ArtifactRepo    = "cloud-run-source-deploy"   # the name `run deploy --source` expects
$ArtifactHost    = "us-east1-docker.pkg.dev"
$ArtifactImage   = "app01/app01"
# Artifact Registry bills above 0.5 GB. Nothing prunes App01's images today, so this is a ceiling
# being approached rather than one being respected -- verify-gcp.ps1 warns as it gets close.
# Must match _KEEP_IMAGES in cloudbuild.yaml, which is where the prune step reads it.
$KeepImages = 3
$ArtifactFreeTierMB = 500
$ArtifactWarnPct    = 80

# --- Cloud Build trigger ------------------------------------------------------
# The ID is the immutable handle; the NAME is a mutable label. (RiddleSite's devlog Step 20
# corrected the opposite belief -- the console's edit form shows the id is what everything hangs
# off, and renaming preserved the Cloud Run association and its managed tags.) So the id is what
# this script keys on, and a rename will not break it.
$TriggerId     = "68da5a2f-0efc-48f1-8214-c3dbd54b039f"
$TriggerName   = "rmgpgab-app01-us-east1-NadavAharoni-App01--maoch"  # wizard-generated; renamable
$TriggerRegion = "global"     # NOT us-east1. us-east1 answers NOT_FOUND even with full access,
                              # which reads exactly like a permissions error and is not one.
                              # `gcloud builds list` needs --region global for the same reason.
$TriggerBranch   = "^main$"          # so feature branches never deploy
$TriggerFilename = "cloudbuild.yaml" # the trigger must delegate to the repo, not inline its build

# A build is skipped only when ALL changed files match one of these. Docs and tests do not affect
# the container, so shipping a byte-identical revision for them wastes build quota.
# `sql/**` is deliberately NOT here: nothing reads those files at runtime today, but if anything
# ever does, an ignored schema change would be a silent bug, and the occasional extra build costs
# nothing. This list can only ever live on the trigger -- cloudbuild.yaml cannot express it.
$TriggerIgnoredFiles = @(
    '**/*.md'
    'tests/**'
    'package.json'
    'package-lock.json'
    '.gitignore'
    '.env.example'
    '**/*.ps1'
)

# --- Expectations to verify, not to apply ------------------------------------
# Set by cloudbuild.yaml on every deploy. Checked here against the running service because the
# Cloud Run console wizard writes a SECOND, service-level maxScale annotation that
# `gcloud run deploy` never touches: `run.googleapis.com/maxScale` on the service metadata versus
# `autoscaling.knative.dev/maxScale` on the revision. RiddleSite ran for weeks with 1 on the
# revision and a stale 3 on the service, so its console header advertised a ceiling three times
# the real one -- on the single number that exists to reassure you about spend.
$MaxInstances = 1
$MinInstances = 0

# --- Billing ------------------------------------------------------------------
# No budget and no notification channel exist yet, which violates the cost-control constraint in
# prompts/wizard_concept.md. verify-gcp.ps1 reports that; creating them is a separate, explicitly
# authorised step because it touches billing.
$BillingAccount = "0144E8-569D37-8FE02B"
# The alert email is intentionally absent: this repo is public, and committing an address here
# would publish it to crawlers. Supply it via $env:APP01_ALERT_EMAIL when provisioning is added.

# --- gcloud resolution --------------------------------------------------------
# The Cloud SDK installer does not update PATH for already-open processes, so fall back to the
# default install locations when gcloud isn't on PATH. Borrowed from RiddleSite's gcp-config.ps1.
function Get-Gcloud {
    $cmd = Get-Command gcloud -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @(
        "$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd",
        "$env:ProgramFiles\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd",
        "${env:ProgramFiles(x86)}\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }

    throw "gcloud not found. Install the Google Cloud CLI, or restart the shell if you just did."
}
