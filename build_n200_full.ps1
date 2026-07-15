param(
    [Parameter(Mandatory=$true)][string]$Url,
    [string]$OutputRoot = 'output/jobs',
    [string]$DatabaseRoot = 'DB',
    [string]$YtDlpPath = '',
    [string]$FfmpegPath = '',
    [switch]$Force,
    [ValidateRange(1,50)][int]$MaxVideoCandidates = 20
)

$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
function Save-Utf8Json($value,[string]$path){ $value | ConvertTo-Json -Depth 30 | Set-Content -Encoding UTF8 $path }
function Get-SafeName([string]$value){
    $safe=$value -replace '[\\/:*?"<>|]',' ' -replace '\s+',' '
    $safe=$safe.Trim(); if($safe.Length -gt 42){$safe=$safe.Substring(0,42).Trim()}; return $safe
}
function Get-ToolPath([string]$provided,[string]$command,[string]$envName){
    if($provided -and (Test-Path -LiteralPath $provided)){return (Resolve-Path $provided).Path}
    $fromEnv=[Environment]::GetEnvironmentVariable($envName);if($fromEnv -and (Test-Path -LiteralPath $fromEnv)){return $fromEnv}
    $found=Get-Command $command -ErrorAction SilentlyContinue;if($found){return $found.Source}
    $winget=Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if(Test-Path -LiteralPath $winget){
        $packagePattern=if($command -eq 'ffmpeg'){'*FFmpeg*'}else{'yt-dlp*'}
        $binary=Get-ChildItem -LiteralPath $winget -Directory -Filter $packagePattern -ErrorAction SilentlyContinue | ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Filter "$command.exe" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 } | Select-Object -First 1
        if($binary){return $binary.FullName}
    }
    throw "$command is required. Pass -$($envName -replace '_PATH$','Path') or set $envName."
}

$OutputRoot=if([IO.Path]::IsPathRooted($OutputRoot)){$OutputRoot}else{Join-Path $root $OutputRoot}
$DatabaseRoot=if([IO.Path]::IsPathRooted($DatabaseRoot)){$DatabaseRoot}else{Join-Path $root $DatabaseRoot}
$yt=Get-ToolPath $YtDlpPath 'yt-dlp' 'YT_DLP_PATH'
$ffmpeg=Get-ToolPath $FfmpegPath 'ffmpeg' 'FFMPEG_PATH'

# Phase 1: article snapshot, copy contract, and SSS video selection.
$generateArgs=@{Url=$Url;OutputRoot=$OutputRoot;SelectXVideo=$true;YtDlpPath=$yt;XMaxCandidates=$MaxVideoCandidates}
if($Force){$generateArgs.Force=$true}
& (Join-Path $root 'generate_carousel.ps1') @generateArgs

$articleId=(([uri]$Url).AbsolutePath.TrimEnd('/') -split '/')[-1]
$jobDir=Join-Path $OutputRoot $articleId
$jobPath=Join-Path $jobDir 'job.json'
if(-not(Test-Path -LiteralPath $jobPath)){throw "Job was not created: $jobPath"}
$job=Get-Content -Raw -Encoding UTF8 $jobPath | ConvertFrom-Json

# Phase 2: a link-only job gets a review-required article visual automatically.
if(-not $job.visual.background_path){
    if(-not $job.article.og_image){throw 'The article has no OG image. Supply an approved background before rendering.'}
    $backgroundPath=Join-Path $jobDir 'article-background.jpg'
    Invoke-WebRequest -Uri $job.article.og_image -OutFile $backgroundPath -UseBasicParsing
    if(-not(Test-Path -LiteralPath $backgroundPath)){throw 'Article background download failed.'}
    $job.visual.background_path=(Resolve-Path $backgroundPath).Path
    $job.visual.strategy='article_og_image'
    $job.visual.license='review_required'
    Save-Utf8Json $job $jobPath
}

# Phase 3: download only an editorially matched excerpt. Never turn context footage into event proof.
$job=Get-Content -Raw -Encoding UTF8 $jobPath | ConvertFrom-Json
$candidateFile=[string]$job.video_selection.candidates_file
if(-not [IO.Path]::IsPathRooted($candidateFile)){$candidateFile=Join-Path $root ($candidateFile -replace '^\.\\','')}
$ranked=Get-Content -Raw -Encoding UTF8 $candidateFile | ConvertFrom-Json
$candidate=$ranked.recommended_candidate
if(-not $candidate){throw 'No eligible video candidate. The job is intentionally stopped before rendering a misleading video card.'}
$sourceUrl=[string]$candidate.post_url
$author=if($candidate.author){[string]$candidate.author}else{'SOURCE'}
$isContext=($job.video_selection.mode -eq 'person_context')
$clipPath=Join-Path $jobDir 'source-video-clip.mp4'
$clipSelectionPath=Join-Path $jobDir 'context-clip-selection.json'

if($candidate.clip_required){
    $subtitleDir=Join-Path $jobDir '_subtitles'; New-Item -ItemType Directory -Force -Path $subtitleDir | Out-Null
    & $yt '--skip-download' '--write-auto-subs' '--write-subs' '--sub-langs' 'en.*,ko.*' '--sub-format' 'vtt' '--output' (Join-Path $subtitleDir 'source.%(ext)s') $sourceUrl
    $subtitle=Get-ChildItem -LiteralPath $subtitleDir -Filter '*.vtt' -File | Select-Object -First 1
    if(-not $subtitle){throw 'No VTT subtitle was available for the chosen long-form video.'}
    $terms=@($job.video_search_profile.person_name)+@($job.video_search_profile.topic)+@($job.video_search_profile.format_terms)+@($job.video_search_profile.person_format_terms) | Where-Object {$_} | Select-Object -Unique
    $personName=[string]$job.video_search_profile.person_name
    $clipArgs=@{Subtitle=$subtitle.FullName;Terms=$terms;ClipSeconds=12;Output=$clipSelectionPath}
    if($isContext -and $personName){$clipArgs.PersonName=$personName;$clipArgs.RequirePersonVoice=$true}
    & (Join-Path $root 'find_context_clip.ps1') @clipArgs
    $selection=Get-Content -Raw -Encoding UTF8 $clipSelectionPath | ConvertFrom-Json
    & (Join-Path $root 'extract_context_clip.ps1') -VideoUrl $sourceUrl -Start $selection.clip_start -End $selection.clip_end -Output $clipPath -YtDlpPath $yt -FfmpegPath $ffmpeg -SourceLabel "CONTEXT VIDEO / $author" -UsageRule 'Context footage only; not proof of the article event.'
} else {
    & $yt '--no-playlist' '--ffmpeg-location' $ffmpeg '--remux-video' 'mp4' '--output' $clipPath $sourceUrl
    if(-not(Test-Path -LiteralPath $clipPath)){throw 'Selected video download failed.'}
    Save-Utf8Json ([ordered]@{strategy='direct_evidence_video';clip_start='00:00:00';clip_end='editorial_review_required';review_status='needs_fact_check'}) $clipSelectionPath
}

$person=if($job.video_search_profile.person_name){[string]$job.video_search_profile.person_name}else{[string]$job.video_search_profile.topic}
$videoHeadline=if($isContext){"$person,`n시장 신호는 무엇인가"}else{"$($job.article.title)"}
$videoSummary=if($isContext){"HOT ISSUE · $($job.article.title)"}else{"HOT ISSUE · $($job.article.title)"}
$videoSourceLabel="SOURCE / $author"
$videoEyebrow=if($isContext){'N200 / CONTEXT VIDEO'}else{'N200 / EVIDENCE VIDEO'}
$videoOutput=Join-Path $jobDir 'page-02-video.mp4'
& (Join-Path $root 'render_page2_video_story.ps1') -Video $clipPath -Headline $videoHeadline -Summary $videoSummary -SourceLabel $videoSourceLabel -CopyrightLabel "(c) $author" -EyebrowText $videoEyebrow -Logo (Join-Path $root 'NEWLOGO.png') -Output $videoOutput -FfmpegPath $ffmpeg -DurationSeconds 12 -PageNumber '02 / 05'

# Phase 4: four data cards plus the video, all in one 5-page sequence.
$p1=Join-Path $jobDir 'page-01-hook.png';$p3=Join-Path $jobDir 'page-03-analysis.png';$p4=Join-Path $jobDir 'page-04-judgment.png';$p5=Join-Path $jobDir 'page-05-cta.png'
& (Join-Path $root 'render_card.ps1') -JobPath $jobPath -Logo (Join-Path $root 'NEWLOGO.png') -Output $p1 -PageNumber '01 / 05'
& (Join-Path $root 'render_page2.ps1') -JobPath $jobPath -Logo (Join-Path $root 'NEWLOGO.png') -Output $p3 -PageNumber '03 / 05'
& (Join-Path $root 'render_page3.ps1') -JobPath $jobPath -Logo (Join-Path $root 'NEWLOGO.png') -Output $p4 -PageNumber '04 / 05'
& (Join-Path $root 'render_page4.ps1') -JobPath $jobPath -Logo (Join-Path $root 'NEWLOGO.png') -InstagramHandle $job.pages.page4.instagram_handle -Output $p5 -PageNumber '05 / 05'

$job=Get-Content -Raw -Encoding UTF8 $jobPath | ConvertFrom-Json
$job.status='needs_rights_review'
$job.video_selection | Add-Member -Force -NotePropertyName source_url -NotePropertyValue $sourceUrl
$job.video_selection | Add-Member -Force -NotePropertyName source_clip -NotePropertyValue 'source-video-clip.mp4'
$job.video_selection | Add-Member -Force -NotePropertyName rendered_card -NotePropertyValue 'page-02-video.mp4'
$job.video_selection | Add-Member -Force -NotePropertyName copyright_label -NotePropertyValue "(c) $author"
Save-Utf8Json $job $jobPath

# Phase 5: delivery package. DB contains exactly the five postable assets.
$date=(Get-Date).ToString('yyyy-MM-dd');$package=Join-Path $DatabaseRoot ("$date-"+$job.article.article_id)
if(Test-Path -LiteralPath $package){if(-not $Force){throw "DB package already exists: $package"};Remove-Item -LiteralPath $package -Recurse -Force}
New-Item -ItemType Directory -Force -Path $package | Out-Null
$assets=[ordered]@{'01-훅.png'=$p1;'02-영상.mp4'=$videoOutput;'03-분석.png'=$p3;'04-판단.png'=$p4;'05-마무리.png'=$p5}
foreach($asset in $assets.GetEnumerator()){Copy-Item -LiteralPath $asset.Value -Destination (Join-Path $package $asset.Key)}
Save-Utf8Json ([ordered]@{article_id=$job.article.article_id;article_url=$job.article.article_url;generated_at=(Get-Date).ToUniversalTime().ToString('o');assets=$assets;rights_status='review_required';publish_status='needs_rights_review';database_package=$package}) (Join-Path $jobDir 'delivery-manifest.json')
Write-Output "N200 full workflow complete: $package"
