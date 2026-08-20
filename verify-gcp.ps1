# Read-only drift check: does the live GCP state still match what the repo declares?
#
#   .\verify-gcp.ps1
#
# Makes ONLY describe/list calls. It never creates, updates or deletes anything, so it is safe to
# run at any time, by anyone with read access, on any machine. Exits 0 when everything matches,
# 1 when something has drifted, 2 when it could not check (no gcloud, no auth, no access).
#
# WHY A CHECKER AND NOT JUST A PROVISIONER
# A provisioning script asserts that things EXIST. That is not the same as asserting that nothing
# EXTRA has appeared, and the failure that motivated this script was of the second kind: if the
# Cloud Build trigger regains a `substitutions:` block, it silently overrides the defaults declared
# in cloudbuild.yaml. Nothing breaks -- every build stays green -- but from that moment editing
# cloudbuild.yaml has no effect, and the repo describes a deployment that is not happening. Only a
# check that says "this must be ABSENT" catches that.
#
# The other checks here exist for the same reason: each one is a thing that can drift silently,
# where the symptom is either invisible or actively misleading.

[CmdletBinding()]
param(
    # Print every check, including the ones that pass.
    [switch]$Detailed
)

# Deliberately NOT 'Stop'. gcloud is chatty on stderr for perfectly successful calls ("Listing
# items under project...", "Repository Size: ..."), and Windows PowerShell wraps native stderr in
# ErrorRecords -- so under 'Stop' a successful command aborts the script the moment anything
# redirects its output, which is exactly what happens when this script is run from a test harness
# or piped to a file. Every call below therefore checks $LASTEXITCODE or its own output explicitly.
$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\gcp-config.ps1"

$script:Failures = @()
$script:Warnings = @()

function Pass($label, $detail) {
    if ($Detailed) { Write-Output "  ok    $label" }
}
function Fail($label, $detail) {
    Write-Output "  DRIFT $label"
    if ($detail) { Write-Output "          $detail" }
    $script:Failures += $label
}
function Warn($label, $detail) {
    Write-Output "  warn  $label"
    if ($detail) { Write-Output "          $detail" }
    $script:Warnings += $label
}
function Section($name) { Write-Output "`n$name" }

# --- gcloud and identity ------------------------------------------------------
# Checked first and loudly, because every confusing failure in this project's history traced back
# to one of these two: gcloud missing on this particular machine, or authenticated as an account
# that cannot see this project. A "not found" from either looks exactly like a real absence.
Section "Environment"
try { $gcloud = Get-Gcloud } catch { Write-Output "  BLOCKED $($_.Exception.Message)"; exit 2 }
Pass "gcloud found at $gcloud"

$account = & $gcloud config get-value account --quiet
if ([string]::IsNullOrWhiteSpace($account) -or $account -eq '(unset)') {
    Write-Output "  BLOCKED no active gcloud account. Run: gcloud auth login"
    exit 2
}
Write-Output "  account: $account"

# The active config project is a real trap rather than a cosmetic one: some APIs (billing budgets
# especially) bill the call against the ACTIVE project rather than the one named by --project, so a
# config pointing at an unrelated project produces a permission error naming that other project.
$activeProject = & $gcloud config get-value project --quiet
if ($activeProject -ne $ProjectId) {
    Write-Output "  note: active gcloud project is '$activeProject', not '$ProjectId'."
    Write-Output "        Every call below passes --project explicitly, so this is fine, but a"
    Write-Output "        permission error naming another project means this, not a real denial."
}

# --- Cloud Build trigger ------------------------------------------------------
Section "Cloud Build trigger ($TriggerId)"
$trigJson = & $gcloud beta builds triggers describe $TriggerId --project $ProjectId `
    --region $TriggerRegion --format json --quiet
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($trigJson)) {
    Fail "trigger not readable in region '$TriggerRegion'" `
         "If this says NOT_FOUND, check the region before anything else -- the trigger is global."
} else {
    $trig = $trigJson | ConvertFrom-Json

    # THE check this script exists for. Substitutions on the trigger beat the ones in
    # cloudbuild.yaml, so their presence makes that file decorative.
    $subs = $trig.PSObject.Properties['substitutions']
    if ($null -ne $subs -and $null -ne $subs.Value) {
        $names = ($subs.Value.PSObject.Properties | ForEach-Object { $_.Name }) -join ', '
        Fail "trigger has a substitutions block" `
             "Found: $names. These SHADOW the defaults in cloudbuild.yaml, so editing that file no longer changes the deploy. Remove them via: gcloud beta builds triggers export/import."
    } else {
        Pass "trigger has no substitutions (cloudbuild.yaml owns them)"
    }

    # An inline build means the repo file is being ignored entirely.
    if ($null -ne $trig.PSObject.Properties['build'] -and $null -ne $trig.build) {
        Fail "trigger carries an inline build config" `
             "The repo's cloudbuild.yaml is not being used at all. Expected 'filename: $TriggerFilename'."
    } else {
        Pass "trigger has no inline build"
    }

    if ($trig.filename -ne $TriggerFilename) {
        Fail "trigger filename is '$($trig.filename)'" "Expected '$TriggerFilename'."
    } else {
        Pass "trigger delegates to $TriggerFilename"
    }

    $branch = $trig.github.push.branch
    if ($branch -ne $TriggerBranch) {
        Fail "trigger branch filter is '$branch'" `
             "Expected '$TriggerBranch'. A wider filter means feature branches deploy to production."
    } else {
        Pass "trigger fires only on $TriggerBranch"
    }

    $live = @()
    if ($null -ne $trig.ignoredFiles) { $live = @($trig.ignoredFiles) }
    $missing = @($TriggerIgnoredFiles | Where-Object { $live -notcontains $_ })
    $extra   = @($live | Where-Object { $TriggerIgnoredFiles -notcontains $_ })
    if ($missing.Count -gt 0 -or $extra.Count -gt 0) {
        $d = @()
        if ($missing.Count -gt 0) { $d += "missing: $($missing -join ', ')" }
        if ($extra.Count   -gt 0) { $d += "unexpected: $($extra -join ', ')" }
        # Not a hard failure: an over-broad list risks skipping a real deploy, an under-broad one
        # only wastes quota. Both are worth seeing; neither breaks the app.
        $detail = $d -join ' | '
        Warn "ignoredFiles differs from the declared list" $detail
    } else {
        Pass "ignoredFiles matches ($($live.Count) patterns)"
    }
}

# --- Cloud Run service --------------------------------------------------------
Section "Cloud Run service ($ServiceName in $Region)"
$svcJson = & $gcloud run services describe $ServiceName --project $ProjectId --region $Region `
    --format json --quiet
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($svcJson)) {
    Fail "service not readable" "Checked project '$ProjectId', region '$Region'."
} else {
    $svc = $svcJson | ConvertFrom-Json

    $revAnn = $svc.spec.template.metadata.annotations
    $revMax = $revAnn.'autoscaling.knative.dev/maxScale'
    if ("$revMax" -ne "$MaxInstances") {
        Fail "revision maxScale is '$revMax'" `
             "Expected '$MaxInstances', which is what cloudbuild.yaml passes as --max-instances. This is the ceiling that actually governs spend."
    } else {
        Pass "revision maxScale = $MaxInstances (the effective ceiling)"
    }

    # The lying-header check. This annotation is written once by the Cloud Run console wizard at
    # creation and never touched by `gcloud run deploy`, so it can sit stale forever while the
    # real ceiling is something else. RiddleSite advertised Max: 3 while running at 1.
    $svcMax = $svc.metadata.annotations.'run.googleapis.com/maxScale'
    if ($null -eq $svcMax) {
        Pass "no stale service-level maxScale annotation"
    } elseif ("$svcMax" -ne "$MaxInstances") {
        Fail "service-level maxScale is '$svcMax' but the revision runs at '$revMax'" `
             "Cosmetic but misleading: the console header will advertise $svcMax while the real ceiling is $revMax. 'gcloud run deploy' never updates this key -- fix it in the console YAML editor."
    } else {
        Pass "service-level maxScale = $svcMax (console header agrees with reality)"
    }

    $revMin = $revAnn.'autoscaling.knative.dev/minScale'
    if ($null -eq $revMin) {
        Pass "no minScale annotation (means 0 -- scales to zero)"
    } elseif ("$revMin" -ne "$MinInstances") {
        Fail "minScale is '$revMin'" "Expected '$MinInstances'. Anything above 0 means paying for an idle instance."
    } else {
        Pass "minScale = $MinInstances"
    }

    $ready = $svc.status.latestReadyRevisionName
    Write-Output "  serving: $ready"
}

# --- Artifact Registry --------------------------------------------------------
# Nothing prunes App01's images. This is a slow leak with a hard edge: the free tier is 0.5 GB,
# and once crossed the repository starts billing quietly and forever.
Section "Artifact Registry ($ArtifactRepo)"
# The repository size is NOT a field: `describe --format=json` has no size key at all, and gcloud
# only ever emits it as a human-readable informational line on stderr ("Repository Size: 424MB").
# So it has to be scraped. Summing imageSizeBytes over the images is NOT a substitute -- layers are
# deduplicated, so 42 images of ~67MB each occupy 424MB, not 2.8GB, and summing overstates it ~7x.
#
# 2>&1 merges the informational stderr line into the pipeline; ToString() flattens the
# ErrorRecords PowerShell wraps it in back to plain text. Safe now that the preference is
# 'Continue' -- under 'Stop' this line alone would abort the script.
$raw = & $gcloud artifacts repositories describe $ArtifactRepo --project $ProjectId `
    --location $Region --format json 2>&1 | ForEach-Object { $_.ToString() }
$sizeText = ($raw | Select-String -Pattern 'Repository Size:\s*([0-9.]+)\s*([KMGT]?B)' |
    Select-Object -First 1)

# Tagged images are the real deploys; untagged manifests are attestation/metadata artifacts of a
# few KB that share the namespace. They are reported separately because conflating the two is what
# made the first prune step delete 18 revisions worth of images.
$imgJson = & $gcloud artifacts docker images list "$ArtifactHost/$ProjectId/$ArtifactRepo/$ArtifactImage" `
    --project $ProjectId --include-tags --format json --quiet 2>&1 | ForEach-Object { $_.ToString() }
# 2>&1 merged gcloud's informational stderr preamble into the same stream, so the JSON has to be
# isolated first -- the document begins at the first line that is exactly "[".
$imgs = @()
$jsonStart = ($imgJson | Select-String -Pattern '^\s*\[\s*$' | Select-Object -First 1)
if ($null -ne $jsonStart) {
    $body = ($imgJson[($jsonStart.LineNumber - 1)..($imgJson.Count - 1)]) -join "`n"
    try {
        # Explicit foreach, not @(... | ConvertFrom-Json): in Windows PowerShell the pipeline form
        # can hand back the whole JSON array as ONE element, which then silently reports 1 image
        # and makes every per-item property an array.
        $parsed = ConvertFrom-Json -InputObject $body
        foreach ($x in $parsed) { $imgs += $x }
    } catch { $imgs = @() }
}
$tagged   = @($imgs | Where-Object { $_.tags })
$untagged = @($imgs | Where-Object { -not $_.tags })
$liveMb = 0
foreach ($i in $tagged) {
    $bytes = 0
    if ($null -ne $i.metadata -and $null -ne $i.metadata.imageSizeBytes) {
        [void][double]::TryParse([string]$i.metadata.imageSizeBytes, [ref]$bytes)
    }
    $liveMb += $bytes / 1048576
}
$liveMb = [math]::Round($liveMb, 1)
Write-Output "  tagged images: $($tagged.Count) (keeping $KeepImages), totalling $liveMb MB"
if ($untagged.Count -gt 0) {
    Write-Output "  untagged manifests: $($untagged.Count) (KB-scale metadata; never pruned)"
}

if ($null -eq $sizeText) {
    Warn "could not read repository size" "gcloud did not print a 'Repository Size:' line."
} else {
    $n    = [double]$sizeText.Matches[0].Groups[1].Value
    $unit = $sizeText.Matches[0].Groups[2].Value
    switch ($unit) {
        'TB' { $mb = $n * 1024 * 1024 }
        'GB' { $mb = $n * 1024 }
        'MB' { $mb = $n }
        'KB' { $mb = $n / 1024 }
        default { $mb = $n / 1048576 }
    }
    $pct  = [math]::Round($mb / $ArtifactFreeTierMB * 100, 1)
    $line = "reported $([math]::Round($mb,1)) MB of the $ArtifactFreeTierMB MB free tier ($pct%); live tagged content is $liveMb MB"
    # The reported figure lags deletion badly -- Artifact Registry reclaims asynchronously, so it
    # can sit hundreds of MB above the actual content for hours after a prune. When the two
    # disagree by a wide margin the gap is storage pending reclamation, not a real leak, so say so
    # rather than raising an alarm that resolves itself.
    $gap = [math]::Round($mb - $liveMb, 1)
    if ($mb -ge $ArtifactFreeTierMB -and $liveMb -ge $ArtifactFreeTierMB) {
        Fail "Artifact Registry is genuinely over the free tier" "$line. Both figures are over, so this is real content, not reclamation lag."
    } elseif ($mb -ge $ArtifactFreeTierMB -or $pct -ge $ArtifactWarnPct) {
        if ($gap -gt 50) {
            Pass "Artifact Registry: $line -- the $gap MB gap is deletion pending reclamation"
            Write-Output "          Reported size lags a prune by hours. Live content is what matters; re-check later."
        } else {
            Warn "Artifact Registry is approaching the free tier" "$line."
        }
    } else {
        Pass "Artifact Registry within free tier -- $line"
    }
}

# --- Cost controls that should exist and do not -------------------------------
# prompts/wizard_concept.md lists a budget alert and a notification channel as constraints the
# template must respect. Reported rather than created: making them touches billing.
Section "Cost controls"
$channels = & $gcloud beta monitoring channels list --project $ProjectId `
    --format "value(name)" --quiet
if ($LASTEXITCODE -ne 0) {
    Warn "could not list notification channels"
} elseif ([string]::IsNullOrWhiteSpace($channels)) {
    Warn "no monitoring notification channel" `
         "wizard_concept.md requires one. Without it a budget alert reaches only the billing-account admins."
} else {
    Pass "notification channel exists"
}

# Gated on the API being enabled rather than just calling and catching: if billingbudgets has
# never been enabled there is definitively no budget, and calling anyway prints a 20-line
# SERVICE_DISABLED error that buries every other finding. Enabling an API is a write, so this
# reports and stops.
$budgetApi = & $gcloud services list --enabled --project $ProjectId `
    --filter "config.name:billingbudgets.googleapis.com" --format "value(config.name)" --quiet
if ([string]::IsNullOrWhiteSpace($budgetApi)) {
    Warn "no billing budget -- the Budget API is not enabled on this project" `
         "So there is definitively no budget, not merely an unreadable one. wizard_concept.md requires a budget alert; creating one touches billing and is a separate authorised step."
} else {
    $budgets = & $gcloud billing budgets list --billing-account $BillingAccount `
        --billing-project $ProjectId --format "value(displayName)" --quiet
    if ($LASTEXITCODE -ne 0) {
        Warn "could not list billing budgets" "The API is enabled but the call failed."
    } elseif ([string]::IsNullOrWhiteSpace($budgets)) {
        Warn "no billing budget configured" "wizard_concept.md requires one."
    } else {
        Pass "billing budget exists: $budgets"
    }
}

# --- Summary ------------------------------------------------------------------
Write-Output ""
Write-Output ("-" * 70)
if ($script:Failures.Count -gt 0) {
    Write-Output "DRIFT: $($script:Failures.Count) item(s) no longer match what the repo declares"
    foreach ($f in $script:Failures) { Write-Output "  - $f" }
}
if ($script:Warnings.Count -gt 0) {
    Write-Output "WARNINGS: $($script:Warnings.Count)"
    foreach ($w in $script:Warnings) { Write-Output "  - $w" }
}
if ($script:Failures.Count -eq 0 -and $script:Warnings.Count -eq 0) {
    Write-Output "All checks pass: live GCP state matches the repo."
}
if ($script:Failures.Count -gt 0) { exit 1 }
exit 0
