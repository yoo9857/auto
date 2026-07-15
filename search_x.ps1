param(
    [string]$Watchlist = "automation/x-watchlist.json",
    [string]$OutputRoot = "output/x-candidates",
    [ValidateRange(10,100)][int]$MaxResults = 30
)

$ErrorActionPreference = 'Stop'

function Save-Utf8Json($Value, [string]$Path) {
    $Value | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 $Path
}
function Get-MetricScore($Metrics, [bool]$HasVideo) {
    $likes = if ($Metrics.like_count) { [int]$Metrics.like_count } else { 0 }
    $reposts = if ($Metrics.retweet_count) { [int]$Metrics.retweet_count } else { 0 }
    $quotes = if ($Metrics.quote_count) { [int]$Metrics.quote_count } else { 0 }
    return [math]::Round(([math]::Log10(1 + $likes) * 10) + ([math]::Log10(1 + $reposts) * 14) + ([math]::Log10(1 + $quotes) * 8) + $(if ($HasVideo) { 8 } else { 0 }), 1)
}

if (-not (Test-Path $Watchlist)) {
    throw "감시 목록이 없습니다: $Watchlist (automation/x-watchlist.example.json을 복사해 설정하세요.)"
}
$token = [Environment]::GetEnvironmentVariable('X_BEARER_TOKEN')
if ([string]::IsNullOrWhiteSpace($token)) {
    throw 'X_BEARER_TOKEN 환경 변수가 필요합니다. X 공식 API Bearer Token을 설정한 후 다시 실행하세요.'
}

$profile = Get-Content -Raw -Encoding UTF8 $Watchlist | ConvertFrom-Json
$queries = @($profile.queries)
if ($profile.trusted_accounts) {
    $accounts = @($profile.trusted_accounts | ForEach-Object { "from:$($_)" })
    if ($accounts.Count) { $queries += '(' + ($accounts -join ' OR ') + ') -is:retweet' }
}
if (-not $queries.Count) { throw 'queries 또는 trusted_accounts 중 하나가 필요합니다.' }

$headers = @{ Authorization = "Bearer $token" }
$all = @()
foreach ($query in $queries) {
    $encoded = [uri]::EscapeDataString($query)
    $uri = "https://api.x.com/2/tweets/search/recent?query=$encoded&max_results=$MaxResults&sort_order=relevancy&tweet.fields=created_at,author_id,public_metrics,entities,possibly_sensitive,attachments&expansions=author_id,attachments.media_keys&user.fields=username,name,verified&media.fields=type,preview_image_url,variants,duration_ms,width,height"
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
    $users = @{}; foreach ($user in @($response.includes.users)) { $users[$user.id] = $user }
    $mediaByKey = @{}; foreach ($media in @($response.includes.media)) { $mediaByKey[$media.media_key] = $media }
    foreach ($post in @($response.data)) {
        $postMedia = @(); foreach ($key in @($post.attachments.media_keys)) { if ($mediaByKey.ContainsKey($key)) { $postMedia += $mediaByKey[$key] } }
        $video = @($postMedia | Where-Object { $_.type -in @('video','animated_gif') } | Select-Object -First 1)
        $bestVariant = @($video.variants | Where-Object { $_.content_type -eq 'video/mp4' } | Sort-Object -Property bitrate -Descending | Select-Object -First 1)
        if ($profile.require_video -and -not $video) { continue }
        $author = $users[$post.author_id]
        $all += [ordered]@{
            id = $post.id
            post_url = "https://x.com/$($author.username)/status/$($post.id)"
            text = $post.text
            created_at = $post.created_at
            author = [ordered]@{ username = $author.username; name = $author.name; verified = [bool]$author.verified }
            public_metrics = $post.public_metrics
            possibly_sensitive = [bool]$post.possibly_sensitive
            media = @($postMedia | ForEach-Object { [ordered]@{ media_key=$_.media_key; type=$_.type; preview_image_url=$_.preview_image_url; duration_ms=$_.duration_ms; width=$_.width; height=$_.height } })
            video_candidate = if ($video) { [ordered]@{ preview_image_url=$video.preview_image_url; duration_ms=$video.duration_ms; mp4_url=$bestVariant.url } } else { $null }
            score = Get-MetricScore $post.public_metrics ([bool]$video)
            status = 'needs_fact_check'
            rights_status = 'review_required'
        }
    }
}

$minimum = if ($profile.minimum_score) { [double]$profile.minimum_score } else { 0 }
$candidates = @($all | Group-Object id | ForEach-Object { $_.Group | Select-Object -First 1 } | Where-Object { $_.score -ge $minimum } | Sort-Object score -Descending)
$runId = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
$outDir = Join-Path $OutputRoot $runId
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$result = [ordered]@{ profile=$profile.profile_name; generated_at=(Get-Date).ToUniversalTime().ToString('o'); candidate_count=$candidates.Count; candidates=$candidates }
Save-Utf8Json $result (Join-Path $outDir 'candidates.json')
Write-Output (Join-Path $outDir 'candidates.json')
