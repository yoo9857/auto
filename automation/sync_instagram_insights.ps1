param(
    [Parameter(Mandatory=$true)][string]$JobPath,
    [string]$MediaId = ""
)

$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$config=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'config.json') | ConvertFrom-Json
$job=Get-Content -Raw -Encoding UTF8 $JobPath | ConvertFrom-Json
if($job.status -ne 'approved'){throw '승인된 작업만 인스타그램 성과와 연결할 수 있습니다.'}
$token=[Environment]::GetEnvironmentVariable($config.instagram.access_token_env)
if(-not $token){throw "환경 변수 $($config.instagram.access_token_env)에 Meta Instagram 액세스 토큰이 필요합니다."}
if(-not $MediaId){$MediaId=[Environment]::GetEnvironmentVariable($config.instagram.media_id_env)}
if(-not $MediaId -and $job.instagram_tracking.media_id){$MediaId=$job.instagram_tracking.media_id}
if(-not $MediaId){throw '게시된 Instagram Media ID가 필요합니다. -MediaId 또는 환경 변수를 설정하세요.'}

$base="https://graph.instagram.com/$($config.instagram.api_version)/$MediaId"
$media=Invoke-RestMethod -Uri "$base?fields=id,permalink,caption,timestamp,media_type,like_count,comments_count&access_token=$token" -Method Get
$metrics=@{}
try {
    $insights=Invoke-RestMethod -Uri "$base/insights?metric=reach,shares,saved,views&access_token=$token" -Method Get
    foreach($item in @($insights.data)){if($item.name -and $item.values){$metrics[$item.name]=$item.values[0].value}}
} catch {
    $metrics.insights_warning='일부 미디어 지표를 현재 API에서 가져오지 못했습니다.'
}
$reach=if($metrics.ContainsKey('reach')){[double]$metrics.reach}else{0}
$saves=if($metrics.ContainsKey('saved')){[double]$metrics.saved}else{0}
$shares=if($metrics.ContainsKey('shares')){[double]$metrics.shares}else{0}
$comments=if($media.comments_count){[double]$media.comments_count}else{0}
$likes=if($media.like_count){[double]$media.like_count}else{0}
$engagementRate=if($reach -gt 0){[Math]::Round(($likes+$comments+$saves+$shares)/$reach,4)}else{0}
$result=[ordered]@{article_id=$job.article.article_id;tracking_code=$job.instagram_tracking.code;instagram=[ordered]@{handle=$config.instagram.handle;media_id=$media.id;permalink=$media.permalink;timestamp=$media.timestamp;media_type=$media.media_type};metrics=[ordered]@{reach=$reach;likes=$likes;comments=$comments;saves=$saves;shares=$shares;views=if($metrics.ContainsKey('views')){$metrics.views}else{0};engagement_rate=$engagementRate};raw_metrics=$metrics;collected_at=(Get-Date).ToUniversalTime().ToString('o')}
$jobDir=Split-Path -Parent (Resolve-Path $JobPath)
$output=Join-Path $jobDir 'instagram-insights.json'
$result|ConvertTo-Json -Depth 20|Set-Content -Encoding UTF8 $output
if($job.instagram_tracking.PSObject.Properties['media_id']){$job.instagram_tracking.media_id=$media.id}else{$job.instagram_tracking|Add-Member -NotePropertyName media_id -NotePropertyValue $media.id}
$job|ConvertTo-Json -Depth 30|Set-Content -Encoding UTF8 $JobPath
Write-Output $output
