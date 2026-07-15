param(
    [Parameter(Mandatory=$true)][string]$JobPath
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $JobPath)) { throw "Job not found: $JobPath" }
$job = Get-Content -LiteralPath $JobPath -Raw -Encoding UTF8 | ConvertFrom-Json
$text = "$($job.article.title) $($job.article.description)"
$profile = $null

# Korean entities are written as regex Unicode escapes so this script remains ASCII-safe.
if ($text -match '(?i)\bH200\b|\uC5D4\uBE44\uB514\uC544\s*H200|Nvidia\s*H200') {
    $profile = [ordered]@{ topic='H200'; aliases=@('Nvidia H200','NVIDIA China AI chip'); event_terms=@('China','Beijing','approval','sales','shipment'); person_name=''; person_format_terms=@(); official_channel_hints=@(); minimum_grade='A'; context_minimum_grade='S'; confidence='high'; matched_rule='nvidia_h200' }
}
elseif ($text -match '(?i)\uC6CC\uB7F0\s*\uBC84\uD54F|Warren\s*Buffett|\uBC84\uD06C\uC154\s*(\uD574\uC11C\uC6E8\uC774|B\uC8FC)?|Berkshire\s*Hathaway') {
    $profile = [ordered]@{ topic='Warren Buffett'; aliases=@('Berkshire Hathaway','Berkshire B','Buffett foundation donation'); event_terms=@('Gates Foundation','Bill Gates','foundation donation','Berkshire donation'); person_name='Warren Buffett'; person_format_terms=@('annual meeting','interview','speech','remarks','conversation'); official_channel_hints=@('Berkshire Hathaway'); minimum_grade='A'; context_minimum_grade='S'; confidence='high'; matched_rule='buffett_berkshire' }
}
elseif ($text -match '(?i)\uC0BC\uC131\uC804\uC790|Samsung\s*Electronics') {
    $profile = [ordered]@{ topic='Samsung Electronics'; aliases=@('Samsung','Samsung semiconductor'); event_terms=@(); person_name=''; person_format_terms=@(); official_channel_hints=@('Samsung Electronics'); minimum_grade='A'; context_minimum_grade='S'; confidence='high'; matched_rule='samsung' }
}
else {
    # A fallback is intentionally not auto-searched: an editor must lock a precise topic first.
    $profile = [ordered]@{ topic=''; aliases=@(); event_terms=@(); person_name=''; person_format_terms=@(); official_channel_hints=@(); minimum_grade='A'; context_minimum_grade='S'; confidence='low'; matched_rule='none'; reason='No safe topic entity could be derived automatically.' }
}

$profile.generated_at = (Get-Date).ToUniversalTime().ToString('o')
if ($job.PSObject.Properties['video_search_profile']) { $job.video_search_profile = $profile }
else { $job | Add-Member -NotePropertyName video_search_profile -NotePropertyValue $profile }
$job | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $JobPath -Encoding UTF8
Write-Output ($profile | ConvertTo-Json -Compress)
