param(
    [Parameter(Mandatory=$true)][string]$Topic,
    [string[]]$TopicAliases = @(),
    [string[]]$EventTerms = @(),
    [string[]]$FormatTerms = @(),
    [string[]]$SearchQueries = @(),
    [string]$CandidatesFile = '',
    [string]$Output = '',
    [string]$YtDlpPath = '',
    [datetime]$ReferenceDate = (Get-Date),
    [ValidateRange(1,3650)][int]$MaxAgeDays = 365,
    [ValidateRange(1,50)][int]$MaxCandidates = 20,
    [ValidateRange(1,5)][int]$MaxSearchQueries = 2,
    [ValidateRange(3,30)][int]$SearchRequestTimeoutSeconds = 8,
    [ValidateRange(1,600)][int]$MinVideoSeconds = 6,
    [ValidateRange(10,3600)][int]$MaxVideoSeconds = 180,
    [ValidateSet('SSS','S','A','B')][string]$MinimumGrade = 'A',
    [switch]$SkipEventMatch,
    [switch]$RequireFormatMatch,
    [switch]$AllowUnknownPublishDate,
    [switch]$AllowLongFormContext,
    [ValidateSet('evidence','person_context')][string]$SelectionMode = 'evidence',
    [string[]]$TrustedAuthors = @('Reuters','AP','BBC','CNBC','Bloomberg','NVIDIA','Samsung'),
    [string[]]$OfficialAuthorHints = @()
)

$ErrorActionPreference = 'Stop'
function Normalize-Terms($Values) { return @($Values | ForEach-Object { $_ -split '\s*,\s*' } | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique) }
function Save-Utf8Json($Value, [string]$Path) {
    $fullPath = [IO.Path]::GetFullPath($Path)
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $fullPath) | Out-Null
    $temporaryPath = "$fullPath.tmp-$([guid]::NewGuid().ToString('N'))"
    $Value | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $temporaryPath -Encoding UTF8
    Move-Item -LiteralPath $temporaryPath -Destination $fullPath -Force
    return $fullPath
}
function Get-VideoMetadata([string]$Url, [string]$ToolPath) {
    try { $raw = & $ToolPath '--dump-single-json' '--no-playlist' '--skip-download' $Url 2>$null; if ($LASTEXITCODE -ne 0 -or -not $raw) { return $null }; return ($raw -join "`n" | ConvertFrom-Json) } catch { return $null }
}
function Get-CachedMetadata($Candidate) {
    if ($Candidate.metadata_inline) { return $Candidate.metadata_inline }
    if (-not $Candidate.metadata_file) { return $null }
    try { $path=[IO.Path]::GetFullPath([string]$Candidate.metadata_file); if(Test-Path -LiteralPath $path){return (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json)} } catch { }
    return $null
}
function Get-PublishedDate($Value) { if(-not $Value){return $null}; try{return [datetime]::ParseExact([string]$Value,'yyyyMMdd',[Globalization.CultureInfo]::InvariantCulture)}catch{return $null} }
function Get-Matches([string]$Text,$Terms) { return @($Terms | Where-Object { $_ -and $Text.Contains(([string]$_).ToLowerInvariant()) }) }
function Get-GradeRank([string]$Grade) { switch($Grade){'SSS'{4};'S'{3};'A'{2};default{1}} }

$TopicAliases=Normalize-Terms $TopicAliases; $EventTerms=Normalize-Terms $EventTerms; $FormatTerms=Normalize-Terms $FormatTerms; $OfficialAuthorHints=Normalize-Terms $OfficialAuthorHints
if (-not $YtDlpPath) { $command=Get-Command yt-dlp -ErrorAction SilentlyContinue; if($command){$YtDlpPath=$command.Source} }
if (-not $YtDlpPath -or -not(Test-Path -LiteralPath $YtDlpPath)){throw 'yt-dlp is required to confirm video metadata. Pass -YtDlpPath.'}

$runId=(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
if(-not $CandidatesFile){
    $CandidatesFile="output/x-candidates/$runId/links.json"
    $queries=Normalize-Terms $SearchQueries
    if(-not $queries){
        if($SelectionMode -eq 'person_context'){$queries=@("$Topic $($FormatTerms|Select-Object -First 1)","$Topic interview")}
        else{$eventQueryTerms=@($EventTerms|Select-Object -First 2);$queries=@("$Topic $($eventQueryTerms -join ' ')",$Topic)}
    }
    $queries=@($queries|Select-Object -First $MaxSearchQueries)
    & (Join-Path $PSScriptRoot 'search_x_links.ps1') -Query $queries -Output $CandidatesFile -MaxLinks $MaxCandidates -RequestTimeoutSeconds $SearchRequestTimeoutSeconds
    if(-not(Test-Path -LiteralPath $CandidatesFile)){throw 'X link discovery failed: candidates file was not created.'}
}
if(-not(Test-Path -LiteralPath $CandidatesFile)){throw "Candidates file not found: $CandidatesFile"}
if(-not $Output){$Output="output/x-candidates/$runId/ranked-video-candidates.json"}

$queue=Get-Content -LiteralPath $CandidatesFile -Raw -Encoding UTF8|ConvertFrom-Json
$topicTerms=Normalize-Terms (@($Topic)+$TopicAliases)
$ranked=@()
foreach($candidate in @($queue.candidates|Select-Object -First $MaxCandidates)){
    $metadata=Get-CachedMetadata $candidate
    # Flat search metadata often omits upload_date. Fetch full metadata before letting an unknown date compete with recent footage.
    if(-not $metadata -or -not $metadata.upload_date){$liveMetadata=Get-VideoMetadata $candidate.post_url $YtDlpPath;if($liveMetadata){$metadata=$liveMetadata}}
    $title=if($metadata){[string]$metadata.title}else{''};$description=if($metadata){[string]$metadata.description}else{''};$text=("$title $description").ToLowerInvariant()
    $topicMatches=Get-Matches $text $topicTerms;$eventMatches=Get-Matches $text $EventTerms;$formatMatches=Get-Matches $text $FormatTerms
    $published=if($metadata){Get-PublishedDate $metadata.upload_date}else{$null};$ageDays=if($published){[math]::Max(0,($ReferenceDate.Date-$published.Date).Days)}else{$null}
    $duration=if($metadata -and $metadata.duration){[double]$metadata.duration}else{0};$hasVideo=$duration -gt 0
    $author=if($metadata.uploader){[string]$metadata.uploader}else{[string]$candidate.author_hint};$trusted=@($TrustedAuthors|Where-Object{$author -like "*$_*"}).Count -gt 0;$officialAuthor=@($OfficialAuthorHints|Where-Object{$author -like "*$_*"}).Count -gt 0
    $topicScore=if($topicMatches.Count){45+[math]::Min(15,($topicMatches.Count-1)*8)}else{0}
    $eventScore=if($eventMatches.Count){[math]::Min(35,$eventMatches.Count*18)}else{0};$formatScore=if($formatMatches.Count){[math]::Min(15,$formatMatches.Count*8)}else{0}
    $recencyScore=if($null -eq $ageDays){0}elseif($ageDays -le 30){10}elseif($ageDays -le 90){7}else{3}
    $durationIdeal=$duration -ge 8 -and $duration -le 150;$clipRequired=$AllowLongFormContext -and $SelectionMode -eq 'person_context' -and $duration -gt $MaxVideoSeconds -and $duration -le 21600;$durationScore=if($durationIdeal){8}elseif($clipRequired){3}elseif($hasVideo){3}else{0};$authorityScore=if($officialAuthor){15}elseif($trusted){10}else{0};$longFormScore=if($clipRequired -and ($trusted -or $officialAuthor)){5}else{0}
    # Prefer footage that actually shows the person (interview/talk/keynote/fireside) over anchor recaps or demos.
    $interviewBonus=if($SelectionMode -eq 'person_context' -and $formatMatches.Count){12}else{0}
    $qualityScore=$topicScore+$eventScore+$formatScore+$recencyScore+$durationScore+$authorityScore+$longFormScore+$interviewBonus
    $reasons=@();if(-not $hasVideo){$reasons+='no_confirmed_video'};if(-not $topicMatches.Count){$reasons+='topic_not_found_in_metadata'};if(-not $SkipEventMatch -and $EventTerms.Count -and -not $eventMatches.Count){$reasons+='event_not_found_in_metadata'};if($RequireFormatMatch -and $FormatTerms.Count -and -not $formatMatches.Count){$reasons+='person_format_not_found_in_metadata'};if($null -eq $ageDays -and -not $AllowUnknownPublishDate){$reasons+='missing_publish_date'}elseif($null -ne $ageDays -and $ageDays -gt $MaxAgeDays){$reasons+="older_than_${MaxAgeDays}_days"};if($hasVideo -and $duration -lt $MinVideoSeconds){$reasons+='video_too_short'};if($duration -gt $MaxVideoSeconds -and -not $clipRequired){$reasons+='video_too_long'}
    $eligible=($reasons.Count -eq 0)
    $grade=if(-not $eligible){'B'}elseif($trusted -and $qualityScore -ge 95 -and $ageDays -le 30 -and $durationIdeal){'SSS'}elseif($qualityScore -ge 82){'S'}elseif($qualityScore -ge 65){'A'}else{'B'}
    $usageRule=if($SelectionMode -eq 'person_context'){'Use only as person/context footage. Do not present it as proof of the article event.'}else{'Use as event evidence only after editorial verification.'}
    $review=@('Confirm the actual footage depicts the matched event.','Confirm article facts against the original report.','Confirm publication and reuse rights.')
    if($clipRequired){$review+='Choose and verify an 8-150 second excerpt before rendering.'}
    $ranked += [pscustomobject][ordered]@{post_url=$candidate.post_url;post_id=$candidate.post_id;source_type=if($candidate.source_type){$candidate.source_type}else{'x_post'};author=$author;official_author_match=$officialAuthor;discovered_by=$candidate.discovered_by;selection_mode=$SelectionMode;usage_rule=$usageRule;video_confirmed=$hasVideo;duration_seconds=$duration;clip_required=$clipRequired;published_at=if($published){$published.ToString('yyyy-MM-dd')}else{$null};age_days=$ageDays;topic_matches=$topicMatches;event_matches=$eventMatches;format_matches=$formatMatches;trusted_author=$trusted;quality_score=$qualityScore;quality_grade=$grade;quality_grade_rank=(Get-GradeRank $grade);eligible=$eligible;rejection_reasons=$reasons;title=$title;description=$description;metadata_source=if($candidate.metadata_file){'cache'}else{'live'};editorial_review=$review;status=if($eligible){if($clipRequired){'needs_clip_review'}else{'needs_fact_check'}}else{'rejected_by_selector'};rights_status='review_required'}
}

# Quality gates come first; inside the same quality tier, newest matching footage wins.
$ordered=@($ranked|Sort-Object @{Expression='eligible';Descending=$true},@{Expression='quality_grade_rank';Descending=$true},@{Expression={if($_.published_at){[datetime]$_.published_at}else{[datetime]::MinValue}};Descending=$true},@{Expression='quality_score';Descending=$true})
$minimumRank=Get-GradeRank $MinimumGrade;$recommended=@($ordered|Where-Object{$_.eligible -and $_.quality_grade_rank -ge $minimumRank}|Select-Object -First 1)
$result=[ordered]@{generated_at=(Get-Date).ToUniversalTime().ToString('o');selector_version='2.2.0';selection_mode=$SelectionMode;topic=$Topic;topic_aliases=$TopicAliases;event_terms=$EventTerms;format_terms=$FormatTerms;reference_date=$ReferenceDate.ToString('yyyy-MM-dd');policy=[ordered]@{gates=@('confirmed_video','topic_match','event_match','person_format_match','publish_date','age_window','duration_window');allow_unknown_publish_date=[bool]$AllowUnknownPublishDate;ranking=@('quality_grade','newest_published_at','quality_score');minimum_grade=$MinimumGrade;automatic_download=$false;automatic_publish=$false};recommended_candidate=$recommended;candidates=$ordered}
$written=Save-Utf8Json $result $Output;Write-Output $written
