param(
    [Parameter(Mandatory=$true)][string]$Url,
    # Video (page 2). Empty = auto-search X/YouTube; or pin a source URL (+ optional clip window).
    [string]$VideoUrl = '',
    [string]$VideoStart = '',
    [string]$VideoEnd = '',
    [switch]$ImageOnly,        # skip the video page entirely (4 image pages)
    [ValidateSet('codex','gradient','openai','gemini')][string]$ImageEngine = 'codex',
    [string]$CopyEngine = 'claude',
    [ValidateSet('match','random','fixed')][string]$PaletteMode = 'match',
    [switch]$Force
)
# OneDayTrading single generation session.
# One command: article URL -> snapshot -> AI copy -> text-free recompose background
# (logo kept) -> palette/QA -> video page (auto-found interview or a pinned URL) ->
# 5-page render -> DB delivery package. Copy/background run on subscription CLIs (no API billing).
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$logo = Join-Path $root 'NEWLOGO.png'
function J($p){ Get-Content -Raw -Encoding UTF8 $p | ConvertFrom-Json }

# Tools + provider keys for child processes.
$ff = if (Test-Path (Join-Path $root 'tools/ffmpeg.exe')) { (Resolve-Path (Join-Path $root 'tools/ffmpeg.exe')).Path } else { [Environment]::GetEnvironmentVariable('FFMPEG_PATH','User') }
$yt = if (Test-Path (Join-Path $root 'tools/yt-dlp.exe')) { (Resolve-Path (Join-Path $root 'tools/yt-dlp.exe')).Path } else { [Environment]::GetEnvironmentVariable('YT_DLP_PATH','User') }
if (-not $env:OPENAI_API_KEY) { $env:OPENAI_API_KEY = [Environment]::GetEnvironmentVariable('OPENAI_API_KEY','User') }
# Put the tools dir on PATH so yt-dlp finds deno (its YouTube JS runtime).
if ($yt) { $env:PATH = (Split-Path $yt) + [IO.Path]::PathSeparator + $env:PATH }
$env:COPY_ENGINE = $CopyEngine

$articleId = ([uri]$Url).AbsolutePath.TrimEnd('/').Split('/')[-1]
$jobDir  = Join-Path $root "output/jobs/$articleId"
$jobPath = Join-Path $jobDir 'job.json'
$useSearch = (-not $ImageOnly) -and (-not $VideoUrl)

# Step 1: article snapshot (no search yet; the AI copy derives the video topic first).
Write-Host "[1/6] article snapshot..." -ForegroundColor Cyan
$genArgs = @{ Url = $Url }
if ($Force) { $genArgs.Force = $true }
& (Join-Path $root 'generate_carousel.ps1') @genArgs | Out-Null
if (-not (Test-Path $jobPath)) { throw "job draft not created: $jobPath" }

# Step 2: AI copy (also derives a per-article video_search_profile).
Write-Host "[2/6] AI copy ($CopyEngine)..." -ForegroundColor Cyan
& node (Join-Path $root 'automation/generate_copy.js') $jobPath
if ($LASTEXITCODE -ne 0) { throw 'copy generation failed' }

# Step 2b: video source search using the AI-derived topic (X + YouTube, interview-preferred).
if ($useSearch) {
    Write-Host "[2b] video source search..." -ForegroundColor Cyan
    try { & (Join-Path $root 'find_video_source.ps1') -JobPath $jobPath -YtDlpPath $yt -MaxCandidates 20 | Out-Null }
    catch { Write-Warning "video search failed (continuing): $($_.Exception.Message.Trim())" }
    $vs = (J $jobPath).video_selection
    if ($vs -and $vs.rights_risk -eq 'high') { Write-Warning '저작권 위험 HIGH (엔터/게임 등): 영상 권리 검수 필수 — 자동게시 금지 권장.' }
}

# Step 3: recompose background (text removed, logo kept, 4:5).
Write-Host "[3/6] hook background ($ImageEngine)..." -ForegroundColor Cyan
if ($ImageEngine -eq 'gradient') {
    & (Join-Path $root 'automation/render_gradient_bg.ps1') -JobPath $jobPath | Out-Null
} else {
    & node (Join-Path $root 'automation/generate_background.js') $jobPath --engine $ImageEngine
    if ($LASTEXITCODE -ne 0) { Write-Warning 'generative background failed -> gradient fallback'; & (Join-Path $root 'automation/render_gradient_bg.ps1') -JobPath $jobPath | Out-Null }
}

# Step 4: palette + QA gate.
Write-Host "[4/6] palette + QA..." -ForegroundColor Cyan
& (Join-Path $root 'automation/resolve_palette.ps1') -JobPath $jobPath -Mode $PaletteMode | Out-Null
$qaPath = Join-Path $jobDir 'qa-report.json'
& (Join-Path $root 'automation/validate_job.ps1') -JobPath $jobPath -ReportPath $qaPath | Out-Null
if (-not (J $qaPath).passed) { throw "QA failed: $qaPath" }
$job = J $jobPath

# Step 5: video page (2/5).
Write-Host "[5/6] video page..." -ForegroundColor Cyan
$p2 = Join-Path $jobDir 'page-02-video.mp4'
$clip = Join-Path $jobDir 'source-video-clip.mp4'
$videoAuthor = 'SOURCE'; $videoReady = $false; $motionFallback = $false
$usageRule = 'Context footage only; not proof of the article event.'
$ffDir = Split-Path -Parent $ff
function Get-Author([string]$u){ try { $a = & $yt '--no-warnings' '--print' '%(uploader)s' $u 2>$null | Select-Object -First 1; if ($a) { return [string]$a } } catch {}; return 'SOURCE' }

# A transient video/network failure must not abort the whole session; skip page 2 instead.
try {
if ($VideoUrl) {
    $videoAuthor = Get-Author $VideoUrl
    if ($VideoStart -and $VideoEnd) {
        & (Join-Path $root 'extract_context_clip.ps1') -VideoUrl $VideoUrl -Start $VideoStart -End $VideoEnd -Output $clip -YtDlpPath $yt -FfmpegPath $ff -SourceLabel "CONTEXT VIDEO / $videoAuthor" -UsageRule $usageRule | Out-Null
    } else {
        & $yt '--no-playlist' '--ffmpeg-location' $ffDir '--remux-video' 'mp4' '--output' $clip $VideoUrl | Out-Null
    }
    $videoReady = Test-Path -LiteralPath $clip
}
elseif ($useSearch -and $job.video_selection -and $job.video_selection.candidates_file) {
    $cf = [string]$job.video_selection.candidates_file
    if (-not [IO.Path]::IsPathRooted($cf)) { $cf = Join-Path $root ($cf -replace '^\.\\','') }
    if (Test-Path -LiteralPath $cf) {
        $cand = (J $cf).recommended_candidate
        if ($cand) {
            $selUrl = [string]$cand.post_url
            $videoAuthor = if ($cand.author) { [string]$cand.author } else { 'SOURCE' }
            $isContext = ($job.video_selection.mode -eq 'person_context')
            if ($cand.clip_required) {
                $sd = Join-Path $jobDir '_subtitles'; New-Item -ItemType Directory -Force -Path $sd | Out-Null
                # Single language + retries/sleep keeps YouTube from 429-throttling subtitle fetches.
                & $yt '--skip-download' '--write-auto-subs' '--write-subs' '--sub-langs' 'en' '--sub-format' 'vtt' '--sleep-requests' '1' '--retries' '3' '--ignore-errors' '--output' (Join-Path $sd 'source.%(ext)s') $selUrl 2>$null
                $sub = Get-ChildItem -LiteralPath $sd -Filter '*.vtt' -File | Select-Object -First 1
                if ($sub) {
                    $terms = @($job.video_search_profile.person_name) + @($job.video_search_profile.topic) + @($job.video_search_profile.person_format_terms) | Where-Object { $_ } | Select-Object -Unique
                    $person = [string]$job.video_search_profile.person_name
                    $clipArgs = @{ Subtitle = $sub.FullName; Terms = $terms; ClipSeconds = 12; Output = (Join-Path $jobDir 'context-clip-selection.json') }
                    $interviewTitle = $cand.title -and (@($job.video_search_profile.person_format_terms | Where-Object { $_ -and ([string]$cand.title) -match [regex]::Escape($_) }).Count -gt 0)
                    if ($isContext -and $person -and (-not $cand.official_author_match) -and (-not $interviewTitle)) { $clipArgs.PersonName = $person; $clipArgs.RequirePersonVoice = $true }
                    & (Join-Path $root 'find_context_clip.ps1') @clipArgs | Out-Null
                    $sel = J (Join-Path $jobDir 'context-clip-selection.json')
                    & (Join-Path $root 'extract_context_clip.ps1') -VideoUrl $selUrl -Start $sel.clip_start -End $sel.clip_end -Output $clip -YtDlpPath $yt -FfmpegPath $ff -SourceLabel "CONTEXT VIDEO / $videoAuthor" -UsageRule $usageRule | Out-Null
                }
            } else {
                & $yt '--no-playlist' '--ffmpeg-location' $ffDir '--remux-video' 'mp4' '--output' $clip $selUrl | Out-Null
            }
            $videoReady = Test-Path -LiteralPath $clip
        }
    }
}
} catch { Write-Warning "video source failed: $($_.Exception.Message)"; $videoReady = $false }

# Guaranteed video page: if no source clip was obtained, animate the hero background
# (our own recompose image — always available, no third-party rights). Never skip page 2.
if (-not $videoReady) {
    $bgPath = $job.visual.background_path
    if ($bgPath -and (Test-Path -LiteralPath $bgPath)) {
        try { & (Join-Path $root 'render_motion_clip.ps1') -Image $bgPath -Output $clip -FfmpegPath $ff -Seconds 12 | Out-Null; $videoReady = Test-Path -LiteralPath $clip; $motionFallback = $true; Write-Host '  (video source not found -> hero motion fallback)' -ForegroundColor DarkGray }
        catch { Write-Warning "motion fallback failed: $($_.Exception.Message)" }
    }
}

if ($videoReady) {
    $vEyebrow = if ($motionFallback) { '관련 이미지' } else { '관련 영상' }
    $vSource  = if ($motionFallback) { 'onedaytrading.net' } else { "SOURCE / $videoAuthor" }
    $vCopy    = if ($motionFallback) { '' } else { "(c) $videoAuthor" }
    & (Join-Path $root 'render_page2_video_story.ps1') -Video $clip -Headline $job.pages.page1.headline -Summary $job.pages.page2.quick_answer -SourceLabel $vSource -CopyrightLabel $vCopy -EyebrowText $vEyebrow -Logo $logo -Output $p2 -FfmpegPath $ff -DurationSeconds 12 -PageNumber '02 / 05' | Out-Null
} else {
    Write-Warning 'video page could not be produced (no source clip and no hero background).'
}

# Step 6: image pages (1,3,4,5) + DB package.
Write-Host "[6/6] image pages + DB package..." -ForegroundColor Cyan
$p1 = Join-Path $jobDir 'page-01-hook.png'
$p3 = Join-Path $jobDir 'page-03-analysis.png'
$p4 = Join-Path $jobDir 'page-04-judgment.png'
$p5 = Join-Path $jobDir 'page-05-cta.png'
& (Join-Path $root 'render_card.ps1')  -JobPath $jobPath -Logo $logo -Output $p1 -PageNumber '01 / 05'
& (Join-Path $root 'render_page2.ps1') -JobPath $jobPath -Logo $logo -Output $p3 -PageNumber '03 / 05'
& (Join-Path $root 'render_page3.ps1') -JobPath $jobPath -Logo $logo -Output $p4 -PageNumber '04 / 05'
& (Join-Path $root 'render_page4.ps1') -JobPath $jobPath -Logo $logo -InstagramHandle $job.pages.page4.instagram_handle -Output $p5 -PageNumber '05 / 05'

# 06: Instagram caption + exactly 5 hashtags (algorithm-optimized) as markdown.
$p6 = Join-Path $jobDir '06-caption.md'
$caption = [string]$job.instagram_caption
$tags = @($job.hashtags)
if (-not $caption) {
    try {
        $capNode = "const {createCaption}=require(process.argv[1]);const fs=require('fs');const j=JSON.parse(fs.readFileSync(process.argv[2],'utf8').replace(/^﻿/,''));const r=createCaption(j);process.stdout.write(JSON.stringify({c:r.caption,t:r.hashtags}))"
        $cap = & node -e $capNode (Join-Path $root 'automation/caption_generator.js') $jobPath | ConvertFrom-Json
        $caption = $cap.c; $tags = @($cap.t)
    } catch { $caption = "$($job.pages.page1.headline)`n$($job.pages.page1.subtitle)" }
}
@("# 인스타그램 캡션 — $($job.article.title)", "", $caption, "", ($tags -join ' ')) -join "`n" | Set-Content -Encoding UTF8 $p6

$date = (Get-Date).ToString('yyyy-MM-dd')
# Readable package name from the headline (e.g. 2026-07-22_캣츠아이-신곡-애니멀) for manual upload.
$slug = ($job.pages.page1.headline -replace "`n", ' ') -replace '[^0-9A-Za-z가-힣 ]', ' '
$slug = ($slug -replace '\s+', '-').Trim('-')
if ($slug.Length -gt 28) { $slug = $slug.Substring(0, 28).Trim('-') }
if (-not $slug) { $slug = $articleId.Substring(0, 8) }
$pkg = Join-Path $root "DB/${date}_$slug"
if (Test-Path -LiteralPath $pkg) { Remove-Item -LiteralPath $pkg -Recurse -Force }
New-Item -ItemType Directory -Force -Path $pkg | Out-Null
Copy-Item $p1 (Join-Path $pkg '01-훅.png')
if ($videoReady) { Copy-Item $p2 (Join-Path $pkg '02-영상.mp4') }
Copy-Item $p3 (Join-Path $pkg '03-분석.png')
Copy-Item $p4 (Join-Path $pkg '04-판단.png')
Copy-Item $p5 (Join-Path $pkg '05-마무리.png')
Copy-Item $p6 (Join-Path $pkg '06-캡션.md')
# Record the delivery folder so publish tooling can resolve it by article id.
$jobRec = Get-Content -Raw -Encoding UTF8 $jobPath | ConvertFrom-Json
$jobRec | Add-Member -Force -NotePropertyName delivery_folder -NotePropertyValue ((Resolve-Path -LiteralPath $pkg).Path)
$jobRec | ConvertTo-Json -Depth 30 | Set-Content -Encoding UTF8 $jobPath

$vLabel = if ($videoReady) { '2 video' } else { '(video skipped)' }
Write-Host "DONE: $pkg" -ForegroundColor Green
Write-Host "  1 hook / $vLabel / 3 analysis / 4 judgment / 5 cta / 6 caption.md"
