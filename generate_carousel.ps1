param(
    [string]$Url = "",
    [string]$JobPath = "",
    [string]$Background = "",
    [ValidateSet('match','random','fixed')][string]$PaletteMode = 'match',
    [string]$OutputRoot = "output/jobs",
    [switch]$Force,
    [switch]$RenderDraft,
    [switch]$SelectXVideo,
    [string]$YtDlpPath = '',
    [ValidateRange(1,50)][int]$XMaxCandidates = 20,
    [bool]$AllowPersonContextFallback = $true
)

$ErrorActionPreference="Stop"
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$config=Get-Content -Raw -Encoding UTF8 (Join-Path $root "automation/config.json") | ConvertFrom-Json

function Get-Meta([string]$html,[string]$property) {
    $escaped=[regex]::Escape($property)
    $patterns=@(
        "<meta[^>]+property=[`"']$escaped[`"'][^>]+content=[`"']([^`"']+)",
        "<meta[^>]+content=[`"']([^`"']+)[`"'][^>]+property=[`"']$escaped[`"']",
        "<meta[^>]+name=[`"']$escaped[`"'][^>]+content=[`"']([^`"']+)"
    )
    foreach($pattern in $patterns) { $m=[regex]::Match($html,$pattern,[Text.RegularExpressions.RegexOptions]::IgnoreCase); if($m.Success){return [System.Net.WebUtility]::HtmlDecode($m.Groups[1].Value)} }
    return ""
}
function Get-Link([string]$html,[string]$rel) {
    $escaped=[regex]::Escape($rel)
    $m=[regex]::Match($html,"<link[^>]+rel=[`"']$escaped[`"'][^>]+href=[`"']([^`"']+)",[Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if($m.Success){return [System.Net.WebUtility]::HtmlDecode($m.Groups[1].Value)}; return ""
}
function Strip-Html([string]$html) {
    $text=[regex]::Replace($html,'<script[\s\S]*?</script>',' ','IgnoreCase')
    $text=[regex]::Replace($text,'<style[\s\S]*?</style>',' ','IgnoreCase')
    $text=[regex]::Replace($text,'<[^>]+>',' ')
    $text=[System.Net.WebUtility]::HtmlDecode($text)
    return ([regex]::Replace($text,'\s+',' ')).Trim()
}
function Get-MarketLabel([string]$html,[string]$category,[string]$title,[string]$description) {
    # 기사 경로보다 본문에 포함된 구조화 시장 정보와 핵심 종목 단서를 우선한다.
    if ($html -match '(?i)[`"''](?:market|marketCode|country)[`"'']\s*:\s*[`"''](?:US|USA|NASDAQ|NYSE)[`"'']') { return '해외주식' }
    if ($html -match '(?i)[`"''](?:market|marketCode|country)[`"'']\s*:\s*[`"''](?:KR|KOR|KOSPI|KOSDAQ)[`"'']') { return '국내주식' }
    $context="$title $description"
    if ($context -match '(?i)\b(?:NASDAQ|NYSE|S&P\s?500|NVDA|TSLA|AAPL|MSFT|AMZN|META|GOOGL?|BRK\.?B)\b|나스닥|뉴욕증시|미국\s*증시|엔비디아|테슬라|애플|마이크로소프트|아마존|메타|워런\s*버핏|버크셔|Berkshire|Warren\s*Buffett') { return '해외주식' }
    if ($context -match '코스피|코스닥|국내\s*증시|한국거래소') { return '국내주식' }
    if ($category -match '크립토|코인') { return '크립토' }
    if ($category -match '경제|부동산') { return '증시·경제' }
    return '해외주식'
}
function Save-Utf8Json($value,[string]$path) { $value | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 $path }
function Assert-PageContract($pages) {
    $required=@{
        page1=@('breaking_label','headline','subtitle','cta')
        page2=@('analysis_headline','quick_answer','paragraphs','memory_line')
        page3=@('evaluation','evaluation_headline','evaluation_summary','expect','verify','judge','paragraphs','memory_line')
        page4=@('instagram_handle','website')
    }
    foreach($pageName in $required.Keys){
        if($null -eq $pages.$pageName){throw "카피 제공자 계약 위반: $pageName 누락"}
        foreach($field in $required[$pageName]){if($null -eq $pages.$pageName.$field -or [string]::IsNullOrWhiteSpace([string]$pages.$pageName.$field)){throw "카피 제공자 계약 위반: $pageName.$field 누락"}}
    }
    if(@($pages.page2.paragraphs).Count -ne 3 -or @($pages.page3.paragraphs).Count -ne 3){throw "카피 제공자 계약 위반: 2·3페이지는 각각 3문단이어야 합니다."}
}

if (-not $JobPath) {
    if ([string]::IsNullOrWhiteSpace($Url)) { throw "-Url 또는 -JobPath가 필요합니다." }
    $uri=[uri]$Url
    if ($uri.Scheme -ne "https" -or $uri.Host -ne "onedaytrading.net") { throw "onedaytrading.net HTTPS 기사 URL만 허용됩니다." }
    $response=Invoke-WebRequest -Uri $Url -UseBasicParsing
    if ($response.StatusCode -ne 200) { throw "기사 조회 실패: HTTP $($response.StatusCode)" }
    $html=$response.Content
    $canonical=Get-Link $html "canonical"; if(-not $canonical){$canonical=$Url}
    $articleId=($uri.AbsolutePath.TrimEnd('/') -split '/')[-1]
    if (-not $articleId) { throw "기사 ID를 URL에서 찾지 못했습니다." }
    $jobDir=Join-Path $OutputRoot $articleId
    if ((Test-Path $jobDir) -and -not $Force) { throw "이미 처리된 기사입니다: $jobDir (-Force로 재생성)" }
    New-Item -ItemType Directory -Force -Path $jobDir | Out-Null
    $title=Get-Meta $html "og:title"; if(-not $title){$title=Get-Meta $html "twitter:title"}
    $description=Get-Meta $html "og:description"; if(-not $description){$description=Get-Meta $html "description"}
    $ogImage=Get-Meta $html "og:image"
    $category=Get-Meta $html "category"; if(-not $category){$category="경제"}
    $published=Get-Meta $html "article:published_time"
    $source=[ordered]@{
        workflow_version=$config.workflow_version; fetched_at=(Get-Date).ToUniversalTime().ToString("o")
        article_url=$Url; canonical_url=$canonical; article_id=$articleId; title=$title
        description=$description; body=Strip-Html $html; category=$category
        published_at=$published; og_image=$ogImage; source_hash=""
    }
    $bytes=[Text.Encoding]::UTF8.GetBytes(($source.title+$source.description+$source.body))
    $source.source_hash=([BitConverter]::ToString(([Security.Cryptography.SHA256]::Create()).ComputeHash($bytes))).Replace("-","").ToLower()
    Save-Utf8Json $source (Join-Path $jobDir "source.json")

    $copyWebhook=[Environment]::GetEnvironmentVariable($config.providers.copy_webhook_env)
    if ($copyWebhook) {
        # 전략 선택 뒤 학습 컨텍스트와 함께 호출한다.
        $pages=$null
    } else {
        $pages=[ordered]@{
            page1=[ordered]@{breaking_label="긴급속보";headline=$title;subtitle=$description;cta="핵심 분석 보기 →"}
            page2=[ordered]@{analysis_headline="이 뉴스가 시장에 중요한 이유는?";quick_answer=$description;paragraphs=@($description,"영향 경로와 미확인 변수는 추가 분석이 필요합니다.","후속 데이터가 확인되면 평가가 달라질 수 있습니다.");memory_line="핵심 변수는 후속 데이터에서 확인됩니다."}
            page3=[ordered]@{evaluation="중립";evaluation_headline="현재 평가는`n'중립'";evaluation_summary="원문 사실은 확인됐지만 시장 영향은 추가 근거가 필요합니다.";expect="기사의 직접 효과";verify="공개되지 않은 조건";judge="후속 수치와 일정";paragraphs=@("확인된 사실을 중심으로 봅니다.","공개되지 않은 조건은 단정하지 않습니다.","후속 수치가 평가를 바꿀 기준입니다.");memory_line="최종 판단은 후속 데이터가 말해줍니다."}
            page4=[ordered]@{instagram_handle=$config.brand.instagram_handle;website="onedaytrading.net"}
        }
    }
    $marketLabel=Get-MarketLabel $html $category $title $description
    $bgPath=$Background
    $job=[ordered]@{
        workflow_version=$config.workflow_version; status=if($bgPath){"draft"}else{"needs_image"}
        article=[ordered]@{article_url=$Url;canonical_url=$canonical;article_id=$articleId;title=$title;description=$description;body=$source.body;category=$category;market_label=$marketLabel;source_name="";published_at=$published;og_image=$ogImage}
        visual=[ordered]@{strategy=if($bgPath){"manual_background"}else{"manual_review"};subject="";background_path=$bgPath;source_url=$ogImage;license="review_required"}
        evidence=@([ordered]@{id='source_snapshot';type='article_source';title=$title;url=$canonical;captured_at=$source.fetched_at;source_hash=$source.source_hash}); pages=$pages; qa=[ordered]@{approved=$false;warnings=@("AI/편집 검수 필요","이미지 권리 검수 필요")}
    }
    $JobPath=Join-Path $jobDir "job.json"; Save-Utf8Json $job $JobPath
    & (Join-Path $root "automation/build_video_search_profile.ps1") -JobPath $JobPath | Out-Null
    if ($SelectXVideo) {
        $profile = (Get-Content -Raw -Encoding UTF8 $JobPath | ConvertFrom-Json).video_search_profile
        if (-not $profile.topic) { throw '영상 검색 주제를 안전하게 자동 추출하지 못했습니다. 편집자가 주제를 지정하세요.' }
        $videoRunId = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
        $job = Get-Content -Raw -Encoding UTF8 $JobPath | ConvertFrom-Json
        $inProgress = [ordered]@{ run_id=$videoRunId; status='search_in_progress'; started_at=(Get-Date).ToUniversalTime().ToString('o'); rights_status='review_required' }
        $job | Add-Member -Force -NotePropertyName video_selection -NotePropertyValue $inProgress
        Save-Utf8Json $job $JobPath
        $evidenceOutput = Join-Path $jobDir "video-$videoRunId-evidence-candidates.json"
        $evidenceQueries = @("$($profile.topic) $(@($profile.event_terms | Select-Object -First 2) -join ' ')", $profile.topic)
        & (Join-Path $root "select_x_video_candidate.ps1") -Topic $profile.topic -TopicAliases @($profile.aliases) -EventTerms @($profile.event_terms) -SearchQueries $evidenceQueries -MaxSearchQueries 2 -SearchRequestTimeoutSeconds 8 -MinimumGrade $profile.minimum_grade -SelectionMode evidence -YtDlpPath $YtDlpPath -MaxCandidates $XMaxCandidates -Output $evidenceOutput
        if (-not (Test-Path -LiteralPath $evidenceOutput)) { throw 'Evidence-video selection did not produce a candidates file.' }
        $candidateOutput = $evidenceOutput
        $evidenceRanked = Get-Content -Raw -Encoding UTF8 $evidenceOutput | ConvertFrom-Json
        $selectionMode = 'evidence'
        if (-not $evidenceRanked.recommended_candidate -and $AllowPersonContextFallback -and $profile.person_name) {
            $contextQueries = @($profile.person_format_terms | Select-Object -First 2 | ForEach-Object { "$($profile.person_name) $_" })
            $xContextLinks = Join-Path $jobDir "video-$videoRunId-person-context-x-links.json"
            $officialContextLinks = Join-Path $jobDir "video-$videoRunId-person-context-official-links.json"
            $contextInputs = Join-Path $jobDir "video-$videoRunId-person-context-inputs.json"
            & (Join-Path $root "search_x_links.ps1") -Query $contextQueries -Output $xContextLinks -MaxLinks $XMaxCandidates -RequestTimeoutSeconds 8
            & (Join-Path $root "search_official_video_links.ps1") -Query $contextQueries -Output $officialContextLinks -YtDlpPath $YtDlpPath -MaxLinks $XMaxCandidates -RequestTimeoutSeconds 8
            if (-not (Test-Path -LiteralPath $xContextLinks) -or -not (Test-Path -LiteralPath $officialContextLinks)) { throw 'Person-context source discovery did not produce both candidate files.' }
            $xCandidates = (Get-Content -Raw -Encoding UTF8 $xContextLinks | ConvertFrom-Json).candidates
            $officialCandidates = (Get-Content -Raw -Encoding UTF8 $officialContextLinks | ConvertFrom-Json).candidates
            $seen = @{}; $merged = @()
            foreach ($item in @($xCandidates) + @($officialCandidates)) { if ($item.post_url -and -not $seen.ContainsKey($item.post_url)) { $seen[$item.post_url] = $true; $merged += $item } }
            Save-Utf8Json ([ordered]@{ generated_at=(Get-Date).ToUniversalTime().ToString('o'); candidates=$merged }) $contextInputs
            $contextOutput = Join-Path $jobDir "video-$videoRunId-person-context-candidates.json"
            & (Join-Path $root "select_x_video_candidate.ps1") -Topic $profile.person_name -TopicAliases @($profile.aliases) -FormatTerms @($profile.person_format_terms) -SkipEventMatch -RequireFormatMatch -AllowUnknownPublishDate -AllowLongFormContext -MinimumGrade $profile.context_minimum_grade -SelectionMode person_context -OfficialAuthorHints @($profile.official_channel_hints) -CandidatesFile $contextInputs -YtDlpPath $YtDlpPath -MaxCandidates $XMaxCandidates -Output $contextOutput
            if (-not (Test-Path -LiteralPath $contextOutput)) { throw 'Person-context video selection did not produce a candidates file.' }
            $contextRanked = Get-Content -Raw -Encoding UTF8 $contextOutput | ConvertFrom-Json
            if ($contextRanked.recommended_candidate) { $candidateOutput = $contextOutput; $selectionMode = 'person_context' }
        }
        $job = Get-Content -Raw -Encoding UTF8 $JobPath | ConvertFrom-Json
        $ranked = Get-Content -Raw -Encoding UTF8 $candidateOutput | ConvertFrom-Json
        $selectionStatus = if ($ranked.recommended_candidate) { if($ranked.recommended_candidate.clip_required){'needs_clip_review'}else{'needs_fact_check'} } elseif (@($ranked.candidates).Count -eq 0) { 'no_candidate_found' } else { 'no_eligible_candidate' }
        $copyrightLabel = if ($ranked.recommended_candidate -and $ranked.recommended_candidate.author) { "© $($ranked.recommended_candidate.author)" } else { '© SOURCE / RIGHTS REVIEW' }
        $selection = [ordered]@{ run_id=$videoRunId; completed_at=(Get-Date).ToUniversalTime().ToString('o'); candidates_file=$candidateOutput; evidence_candidates_file=$evidenceOutput; mode=$selectionMode; source_label=if($ranked.recommended_candidate){$ranked.recommended_candidate.author}else{''}; copyright_label=$copyrightLabel; usage_rule=if($selectionMode -eq 'person_context'){'CONTEXT VIDEO: never present as direct proof of the article event.'}else{'EVIDENCE VIDEO: verify the event shown before publishing.'}; status=$selectionStatus; rights_status='review_required' }
        $job | Add-Member -Force -NotePropertyName video_selection -NotePropertyValue $selection
        Save-Utf8Json $job $JobPath
    }
    & (Join-Path $root "automation/select_learning_strategy.ps1") -JobPath $JobPath | Out-Null
    if ($copyWebhook) {
        $job=Get-Content -Raw -Encoding UTF8 $JobPath | ConvertFrom-Json
        $copyRequest=[ordered]@{article=$source;learning=$job.learning;output_contract="4-page OneDayTrading carousel JSON"}
        $job.pages=Invoke-RestMethod -Method Post -Uri $copyWebhook -ContentType "application/json; charset=utf-8" -Body ($copyRequest | ConvertTo-Json -Depth 20)
        Assert-PageContract $job.pages
        Save-Utf8Json $job $JobPath
    }
    if (-not $bgPath -or -not $RenderDraft) {
        Write-Output "작업 초안 생성: $JobPath"
        Write-Output "배경 이미지와 카피를 검수한 뒤 -JobPath로 다시 실행하세요."
        exit 0
    }
}

$job=Get-Content -Raw -Encoding UTF8 $JobPath | ConvertFrom-Json
$jobDir=Split-Path -Parent $JobPath
if ($Background) { $job.visual.background_path=$Background; Save-Utf8Json $job $JobPath }
if(@($job.evidence).Count -eq 0){
    $snapshotPath=Join-Path $jobDir 'source.json'
    if(Test-Path $snapshotPath){
        $snapshot=Get-Content -Raw -Encoding UTF8 $snapshotPath|ConvertFrom-Json
        $job.evidence=@([ordered]@{id='source_snapshot';type='article_source';title=$snapshot.title;url=$snapshot.canonical_url;captured_at=$snapshot.fetched_at;source_hash=$snapshot.source_hash})
        Save-Utf8Json $job $JobPath
    }
}
if(-not $job.PSObject.Properties['instagram_tracking']){
    $tracking=[ordered]@{handle=$config.instagram.handle;profile_url=$config.instagram.profile_url;collection_mode=$config.instagram.insights_mode;code=("{0}-{1}" -f $config.instagram.tracking_prefix,$job.article.article_id);media_id=""}
    $job|Add-Member -NotePropertyName instagram_tracking -NotePropertyValue $tracking
    Save-Utf8Json $job $JobPath
}
elseif(-not $job.instagram_tracking.PSObject.Properties['collection_mode']){
    $job.instagram_tracking|Add-Member -NotePropertyName collection_mode -NotePropertyValue $config.instagram.insights_mode
    Save-Utf8Json $job $JobPath
}
& (Join-Path $root "automation/select_learning_strategy.ps1") -JobPath $JobPath | Out-Null
 $job=Get-Content -Raw -Encoding UTF8 $JobPath | ConvertFrom-Json
if (-not $PSBoundParameters.ContainsKey('PaletteMode')) {
    $recommendedPalette=[string]$job.learning.strategies.palette
    if ($recommendedPalette -eq 'stable-random') { $PaletteMode='random' }
    elseif ($recommendedPalette -eq 'image-match') { $PaletteMode='match' }
}
if($job.learning.PSObject.Properties['palette_mode_applied']){$job.learning.palette_mode_applied=$PaletteMode}else{$job.learning|Add-Member -NotePropertyName palette_mode_applied -NotePropertyValue $PaletteMode}
Save-Utf8Json $job $JobPath
& (Join-Path $root "automation/resolve_palette.ps1") -JobPath $JobPath -Mode $PaletteMode
$job=Get-Content -Raw -Encoding UTF8 $JobPath | ConvertFrom-Json
$qaPath=Join-Path $jobDir "qa-report.json"
& (Join-Path $root "automation/validate_job.ps1") -JobPath $JobPath -ReportPath $qaPath
$qaResult=Get-Content -Raw -Encoding UTF8 $qaPath | ConvertFrom-Json
if (-not $qaResult.passed) { throw "품질 검수 실패: $qaPath" }
$job.status='ready'; $job.qa.approved=$false; Save-Utf8Json $job $JobPath

$page1=Join-Path $jobDir "page-01.png"; $page2=Join-Path $jobDir "page-02.png"
$page3=Join-Path $jobDir "page-03.png"; $page4=Join-Path $jobDir "page-04.png"
& (Join-Path $root "render_card.ps1") -JobPath $JobPath -Output $page1
& (Join-Path $root "render_page2.ps1") -JobPath $JobPath -Output $page2
& (Join-Path $root "render_page3.ps1") -JobPath $JobPath -Output $page3
& (Join-Path $root "render_page4.ps1") -JobPath $JobPath -InstagramHandle $job.pages.page4.instagram_handle -Output $page4

$manifest=[ordered]@{workflow_version=$config.workflow_version;article_id=$job.article.article_id;generated_at=(Get-Date).ToUniversalTime().ToString("o");outputs=@($page1,$page2,$page3,$page4);qa_report=$qaPath;learning_strategy=$job.learning;palette=$job.visual.palette;status='ready';approved=$false}
Save-Utf8Json $manifest (Join-Path $jobDir "manifest.json")
Write-Output "캐러셀 생성 완료: $jobDir"
