param(
    [Parameter(Mandatory=$true)][string]$ArticleId,
    [string]$Date = '',            # DB package date prefix (default: today)
    [switch]$Preview,              # compose in Chrome and screenshot before sharing (semi-auto review)
    [switch]$Confirm,              # actually post (requires approved job)
    [string]$Reviewer = 'onedaytrading.io owner'
)
# Semi-automatic Instagram publish via the persistent Chrome session (no Meta API).
# One-time login first:  npm run instagram:setup
# Flow:  build_auto -> (this) approve -> -Preview -> -Confirm
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Date) { $Date = (Get-Date).ToString('yyyy-MM-dd') }

$jobPath = Join-Path $root "output/jobs/$ArticleId/job.json"
if (-not (Test-Path $jobPath)) { throw "job.json not found: $jobPath" }
$jobObj = Get-Content -Raw -Encoding UTF8 $jobPath | ConvertFrom-Json
$pkg = if ($jobObj.delivery_folder -and (Test-Path -LiteralPath $jobObj.delivery_folder)) { $jobObj.delivery_folder } elseif ($Date) { Join-Path $root "DB/$Date-$ArticleId" } else { '' }
if (-not $pkg -or -not (Test-Path -LiteralPath $pkg)) { throw 'DB package not found. Run build_auto first (job.delivery_folder missing).' }

$pub = Join-Path $root 'automation/chrome_instagram_publisher.js'

if ($Confirm) {
    # Ensure the job is human-approved before any external post.
    $job = Get-Content -Raw -Encoding UTF8 $jobPath | ConvertFrom-Json
    if ($job.status -ne 'approved' -or -not $job.qa.approved) {
        Write-Host "[approve] marking job approved (reviewer: $Reviewer)" -ForegroundColor Cyan
        & (Join-Path $root 'automation/approve_carousel.ps1') -JobPath $jobPath -Decision approved -Reviewer $Reviewer -Notes 'chrome semi-auto publish' | Out-Null
    }
    Write-Host "[publish] posting to Instagram..." -ForegroundColor Cyan
    & node $pub publish --job $jobPath --assets-dir $pkg --confirm
}
elseif ($Preview) {
    Write-Host "[preview] composing in Chrome (not sharing)..." -ForegroundColor Cyan
    & node $pub preview --job $jobPath --assets-dir $pkg
    Write-Host "Preview screenshot: $(Join-Path (Split-Path $jobPath) 'chrome-publish-preview.png')" -ForegroundColor Green
}
else {
    Write-Host "[plan] building publish plan (assets + caption)..." -ForegroundColor Cyan
    & node $pub plan --job $jobPath --assets-dir $pkg
}
