param(
    [Parameter(Mandatory=$true)][string[]]$Query,
    [string]$Output = 'output/official-video-links.json',
    [ValidateRange(1,50)][int]$MaxLinks = 20,
    [string]$YtDlpPath = '',
    [ValidateRange(3,30)][int]$RequestTimeoutSeconds = 8
)

$ErrorActionPreference = 'Stop'
function Save-Utf8Json($Value,[string]$Path){$full=[IO.Path]::GetFullPath($Path);New-Item -ItemType Directory -Force -Path (Split-Path -Parent $full)|Out-Null;$tmp="$full.tmp-$([guid]::NewGuid().ToString('N'))";$Value|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $tmp -Encoding UTF8;Move-Item -LiteralPath $tmp -Destination $full -Force}
function Add-YouTubeUrl([string]$Value,[string]$Term,[hashtable]$Collection){
    foreach($match in [regex]::Matches($Value,'https?://(?:www\.)?youtube\.com/watch\?[^\s"''<>]*?v=([A-Za-z0-9_-]{11})')){
        $url="https://www.youtube.com/watch?v=$($match.Groups[1].Value)"
        if(-not $Collection.ContainsKey($url)){$Collection[$url]=[ordered]@{post_url=$url;post_id=$match.Groups[1].Value;author_hint='';source_type='official_video_search';discovered_by='web_search';matched_query=$Term;status='needs_fact_check';rights_status='review_required'}}
    }
    foreach($match in [regex]::Matches($Value,'https?://youtu\.be/([A-Za-z0-9_-]{11})')){
        $url="https://www.youtube.com/watch?v=$($match.Groups[1].Value)"
        if(-not $Collection.ContainsKey($url)){$Collection[$url]=[ordered]@{post_url=$url;post_id=$match.Groups[1].Value;author_hint='';source_type='official_video_search';discovered_by='web_search';matched_query=$Term;status='needs_fact_check';rights_status='review_required'}}
    }
}
function Add-YouTubeSearch([string]$Term,[string]$ToolPath,[hashtable]$Collection,[int]$Limit){
    try{
        $raw=& $ToolPath '--flat-playlist' '--dump-single-json' "ytsearch$Limit`:$Term" 2>$null
        $playlist=($raw -join "`n")|ConvertFrom-Json
        $items=if($playlist.entries){@($playlist.entries)}else{@($playlist)}
        foreach($item in $items){
            try{
                if(-not $item.id){continue}
                $url="https://www.youtube.com/watch?v=$($item.id)"
                if(-not $Collection.ContainsKey($url)){
                    $authorHint=if($item.uploader){$item.uploader}else{''}
                    $inlineMetadata=[ordered]@{uploader=$item.uploader;upload_date=$null;title=$item.title;description=$item.description;duration=$item.duration}
                    $Collection[$url]=[ordered]@{post_url=$url;post_id=$item.id;author_hint=$authorHint;source_type='youtube_search';discovered_by='yt_dlp_search';matched_query=$Term;metadata_inline=$inlineMetadata;status='needs_fact_check';rights_status='review_required'}
                }
            }catch{}
        }
    }catch{}
}

if(-not $YtDlpPath){$command=Get-Command yt-dlp -ErrorAction SilentlyContinue;if($command){$YtDlpPath=$command.Source}}

$found=@{}
foreach($term in $Query|Where-Object{$_}){
    $uris=@(
        ('https://www.bing.com/search?q='+[uri]::EscapeDataString('site:youtube.com '+$term)+'&count=50'),
        ('https://html.duckduckgo.com/html/?q='+[uri]::EscapeDataString('site:youtube.com '+$term))
    )
    foreach($uri in $uris){
        try{$response=Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec $RequestTimeoutSeconds -Headers @{'User-Agent'='Mozilla/5.0'}}catch{continue}
        Add-YouTubeUrl $response.Content $term $found
        foreach($redirect in [regex]::Matches($response.Content,'(?:[?&]u=|&amp;u=)a1([A-Za-z0-9_-]+)')){
            try{$encoded=$redirect.Groups[1].Value.Replace('-','+').Replace('_','/');$encoded+='='*((4-$encoded.Length%4)%4);Add-YouTubeUrl ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))) $term $found}catch{}
        }
        foreach($redirect in [regex]::Matches($response.Content,'(?:[?&]uddg=|uddg=)([^&"''\s]+)')){
            try{Add-YouTubeUrl ([uri]::UnescapeDataString([System.Net.WebUtility]::HtmlDecode($redirect.Groups[1].Value))) $term $found}catch{}
        }
    }
}
if($found.Count -eq 0 -and $YtDlpPath -and (Test-Path -LiteralPath $YtDlpPath)){
    foreach($term in $Query|Where-Object{$_}){
        Add-YouTubeSearch $term $YtDlpPath $found ([math]::Min(5,$MaxLinks))
        if($found.Count -ge $MaxLinks){break}
    }
}
$orderedCandidates=@($found.Values|Sort-Object @{Expression={
    $text=("$($_.metadata_inline.title) $($_.metadata_inline.description)").ToLowerInvariant();$score=0
    foreach($token in ([string]$_.matched_query -split '\s+'|Where-Object{$_.Length -ge 4})) { if($text.Contains($token.ToLowerInvariant())){$score+=20} }
    if($text -match 'annual\s+meeting|interview|speech|remarks|conversation|debate'){$score+=15}
    if($_.metadata_inline.upload_date){$score+=5}
    $score
};Descending=$true}, @{Expression='post_url';Descending=$false})
$result=[ordered]@{generated_at=(Get-Date).ToUniversalTime().ToString('o');source='Bing web search plus yt-dlp discovery; no YouTube API used';candidates=@($orderedCandidates|Select-Object -First $MaxLinks)}
Save-Utf8Json $result $Output
Write-Output ([IO.Path]::GetFullPath($Output))
