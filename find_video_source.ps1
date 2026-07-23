param(
    [Parameter(Mandatory=$true)][string]$JobPath,
    [string]$YtDlpPath = '',
    [ValidateRange(1,50)][int]$MaxCandidates = 20,
    [bool]$AllowPersonContextFallback = $true
)
# Reusable video-source finder: reads job.video_search_profile (whitelist- or
# AI-derived) and runs the same evidence + person-context search generate_carousel
# uses, writing job.video_selection. Missing topic = graceful skip (no video).
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$jobDir = Split-Path -Parent (Resolve-Path $JobPath)
function Save-Utf8Json($value,[string]$path){ $value | ConvertTo-Json -Depth 30 | Set-Content -Encoding UTF8 $path }

$job0 = Get-Content -Raw -Encoding UTF8 $JobPath | ConvertFrom-Json
$profile = $job0.video_search_profile
if (-not $profile -or [string]::IsNullOrWhiteSpace([string]$profile.topic)) {
    Write-Warning 'no safe video topic in profile; skipping video search'
    return
}

# Category-aware trusted channels (news/official) + copyright risk flag.
$category = [string]$job0.article.category
$trusted = @('Reuters', 'AP', 'Bloomberg', 'CNBC')
$channelsPath = Join-Path $root 'automation/video_channels.json'
if (Test-Path $channelsPath) {
    $ch = Get-Content -Raw -Encoding UTF8 $channelsPath | ConvertFrom-Json
    $trusted = @($ch.default)
    foreach ($k in $ch.PSObject.Properties.Name) { if ($k -notin @('_comment', 'default') -and $category -like "*$k*") { $trusted += @($ch.$k) } }
}
$trusted = @(@($trusted) + @($profile.official_channel_hints)) | Where-Object { $_ } | Select-Object -Unique
$rightsRisk = if ($profile.rights_risk -eq 'high') { 'high' } else { 'low' }

$videoRunId = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$job = Get-Content -Raw -Encoding UTF8 $JobPath | ConvertFrom-Json
$inProgress = [ordered]@{ run_id=$videoRunId; status='search_in_progress'; started_at=(Get-Date).ToUniversalTime().ToString('o'); rights_status='review_required' }
$job | Add-Member -Force -NotePropertyName video_selection -NotePropertyValue $inProgress
Save-Utf8Json $job $JobPath

$evidenceOutput = Join-Path $jobDir "video-$videoRunId-evidence-candidates.json"
$evidenceQueries = @("$($profile.topic) $(@($profile.event_terms | Select-Object -First 2) -join ' ')", $profile.topic)
& (Join-Path $root "select_x_video_candidate.ps1") -Topic $profile.topic -TopicAliases @($profile.aliases) -EventTerms @($profile.event_terms) -SearchQueries $evidenceQueries -MaxSearchQueries 2 -SearchRequestTimeoutSeconds 8 -MinimumGrade $profile.minimum_grade -SelectionMode evidence -TrustedAuthors $trusted -YtDlpPath $YtDlpPath -MaxCandidates $MaxCandidates -Output $evidenceOutput
if (-not (Test-Path -LiteralPath $evidenceOutput)) { throw 'Evidence-video selection did not produce a candidates file.' }
$candidateOutput = $evidenceOutput
$evidenceRanked = Get-Content -Raw -Encoding UTF8 $evidenceOutput | ConvertFrom-Json
$selectionMode = 'evidence'

# Context fallback (YouTube + X): person interview, or — for non-person categories —
# a product reveal (official teaser/trailer) or an official event/briefing keyed on the topic.
$isPerson = -not [string]::IsNullOrWhiteSpace([string]$profile.person_name)
$doContext = $isPerson -or (@('product_reveal', 'official_event') -contains [string]$profile.search_kind)
if (-not $evidenceRanked.recommended_candidate -and $AllowPersonContextFallback -and $doContext) {
    if ($isPerson) { $subject = [string]$profile.person_name; $ctxTerms = @($profile.person_format_terms); $ctxGrade = $profile.context_minimum_grade; $requireFmt = $true }
    elseif ([string]$profile.search_kind -eq 'product_reveal') { $subject = [string]$profile.topic; $ctxTerms = @('official', 'teaser', 'trailer', 'MV', 'reveal', 'showcase'); $ctxGrade = 'A'; $requireFmt = $true }
    else { $subject = [string]$profile.topic; $ctxTerms = @('briefing', 'press conference', 'announcement', 'keynote'); $ctxGrade = 'A'; $requireFmt = $false }
    $contextQueries = @(@($ctxTerms | Select-Object -First 3 | ForEach-Object { "$subject $_" }) + @($subject))
    $xContextLinks = Join-Path $jobDir "video-$videoRunId-person-context-x-links.json"
    $officialContextLinks = Join-Path $jobDir "video-$videoRunId-person-context-official-links.json"
    $contextInputs = Join-Path $jobDir "video-$videoRunId-person-context-inputs.json"
    & (Join-Path $root "search_x_links.ps1") -Query $contextQueries -Output $xContextLinks -MaxLinks $MaxCandidates -RequestTimeoutSeconds 8
    & (Join-Path $root "search_official_video_links.ps1") -Query $contextQueries -Output $officialContextLinks -YtDlpPath $YtDlpPath -MaxLinks $MaxCandidates -RequestTimeoutSeconds 8
    if (-not (Test-Path -LiteralPath $xContextLinks) -or -not (Test-Path -LiteralPath $officialContextLinks)) { throw 'Context source discovery did not produce both candidate files.' }
    $xCandidates = (Get-Content -Raw -Encoding UTF8 $xContextLinks | ConvertFrom-Json).candidates
    $officialCandidates = (Get-Content -Raw -Encoding UTF8 $officialContextLinks | ConvertFrom-Json).candidates
    $seen = @{}; $merged = @()
    foreach ($item in @($xCandidates) + @($officialCandidates)) { if ($item.post_url -and -not $seen.ContainsKey($item.post_url)) { $seen[$item.post_url] = $true; $merged += $item } }
    Save-Utf8Json ([ordered]@{ generated_at=(Get-Date).ToUniversalTime().ToString('o'); candidates=$merged }) $contextInputs
    $contextOutput = Join-Path $jobDir "video-$videoRunId-person-context-candidates.json"
    $selArgs = @{ Topic=$subject; TopicAliases=@($profile.aliases); FormatTerms=@($ctxTerms); SkipEventMatch=$true; AllowUnknownPublishDate=$true; AllowLongFormContext=$true; MinimumGrade=$ctxGrade; SelectionMode='person_context'; OfficialAuthorHints=@($profile.official_channel_hints); TrustedAuthors=$trusted; CandidatesFile=$contextInputs; YtDlpPath=$YtDlpPath; MaxCandidates=$MaxCandidates; Output=$contextOutput }
    if ($requireFmt) { $selArgs.RequireFormatMatch = $true }
    & (Join-Path $root "select_x_video_candidate.ps1") @selArgs
    if (-not (Test-Path -LiteralPath $contextOutput)) { throw 'Context video selection did not produce a candidates file.' }
    $contextRanked = Get-Content -Raw -Encoding UTF8 $contextOutput | ConvertFrom-Json
    if ($contextRanked.recommended_candidate) { $candidateOutput = $contextOutput; $selectionMode = if ($isPerson) { 'person_context' } else { 'topic_context' } }
}

$job = Get-Content -Raw -Encoding UTF8 $JobPath | ConvertFrom-Json
$ranked = Get-Content -Raw -Encoding UTF8 $candidateOutput | ConvertFrom-Json
$selectionStatus = if ($ranked.recommended_candidate) { if($ranked.recommended_candidate.clip_required){'needs_clip_review'}else{'needs_fact_check'} } elseif (@($ranked.candidates).Count -eq 0) { 'no_candidate_found' } else { 'no_eligible_candidate' }
$copyrightLabel = if ($ranked.recommended_candidate -and $ranked.recommended_candidate.author) { "(c) $($ranked.recommended_candidate.author)" } else { '(c) SOURCE / RIGHTS REVIEW' }
$selection = [ordered]@{ run_id=$videoRunId; completed_at=(Get-Date).ToUniversalTime().ToString('o'); candidates_file=$candidateOutput; evidence_candidates_file=$evidenceOutput; mode=$selectionMode; source_label=if($ranked.recommended_candidate){$ranked.recommended_candidate.author}else{''}; copyright_label=$copyrightLabel; usage_rule=if($selectionMode -eq 'person_context'){'CONTEXT VIDEO: never present as direct proof of the article event.'}else{'EVIDENCE VIDEO: verify the event shown before publishing.'}; status=$selectionStatus; rights_risk=$rightsRisk; rights_status='review_required' }
$job | Add-Member -Force -NotePropertyName video_selection -NotePropertyValue $selection
Save-Utf8Json $job $JobPath
Write-Output "video_selection: $selectionMode / $selectionStatus"
