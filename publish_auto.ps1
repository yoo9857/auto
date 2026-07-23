param(
    [Parameter(Mandatory=$true)][string]$Url,
    [string]$BaseUrl = '',        # public https folder where the DB assets are hosted
    [switch]$Publish,             # actually post (otherwise dry-run plan)
    [string]$VideoUrl = '',
    [string]$VideoStart = '',
    [string]$VideoEnd = '',
    [switch]$ImageOnly,
    [switch]$Force
)
# End-to-end: article URL -> 5-page carousel + caption (build_auto) -> Instagram
# publish (Meta Graph API). Meta fetches media from public URLs, so -BaseUrl must
# point at the hosted DB assets. Without -BaseUrl it stops after building.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

$articleId = ([uri]$Url).AbsolutePath.TrimEnd('/').Split('/')[-1]
$jobPath = Join-Path $root "output/jobs/$articleId/job.json"

Write-Host "== 1) build carousel ==" -ForegroundColor Cyan
$buildArgs = @{ Url = $Url }
if ($Force) { $buildArgs.Force = $true }
if ($ImageOnly) { $buildArgs.ImageOnly = $true }
if ($VideoUrl) { $buildArgs.VideoUrl = $VideoUrl }
if ($VideoStart) { $buildArgs.VideoStart = $VideoStart }
if ($VideoEnd) { $buildArgs.VideoEnd = $VideoEnd }
& (Join-Path $root 'build_auto.ps1') @buildArgs
if (-not (Test-Path -LiteralPath $jobPath)) { throw "job not found after build: $jobPath" }
$pkg = (Get-Content -Raw -Encoding UTF8 $jobPath | ConvertFrom-Json).delivery_folder
if (-not $pkg -or -not (Test-Path -LiteralPath $pkg)) { throw 'DB package not found after build (delivery_folder missing).' }

Write-Host "`n== 2) publish ==" -ForegroundColor Cyan
if (-not $BaseUrl) {
    Write-Host "assets ready: $pkg" -ForegroundColor Green
    Write-Host "Host these files at a public https URL, then re-run with -BaseUrl <url> (-Publish to post)." -ForegroundColor Yellow
    Write-Host "See META_SETUP_GUIDE.md (section 5-6)."
    return
}
$pubArgs = @($pkg, '--base-url', $BaseUrl)
if ($Publish) { $pubArgs += '--publish' }
& node (Join-Path $root 'automation/meta_instagram_publisher.js') @pubArgs
