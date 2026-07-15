param(
    [Parameter(Mandatory=$true)][string[]]$Query,
    [string]$Output = "output/x-search-links.json",
    [ValidateRange(1,50)][int]$MaxLinks = 20,
    [ValidateRange(3,30)][int]$RequestTimeoutSeconds = 8
)

$ErrorActionPreference = 'Stop'
function Save-Utf8Json($Value, [string]$Path) {
    $fullPath = [IO.Path]::GetFullPath($Path)
    $directory = Split-Path -Parent $fullPath
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $temporaryPath = "$fullPath.tmp-$([guid]::NewGuid().ToString('N'))"
    $Value | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 $temporaryPath
    Move-Item -LiteralPath $temporaryPath -Destination $fullPath -Force
}
function Add-XUrl([string]$Value, [string]$Term, [hashtable]$Collection) {
    foreach ($match in [regex]::Matches($Value, 'https?://(?:www\.)?x\.com/([A-Za-z0-9_]{1,15})/status/(\d+)')) {
        $url = "https://x.com/$($match.Groups[1].Value)/status/$($match.Groups[2].Value)"
        if (-not $Collection.ContainsKey($url)) {
            $Collection[$url] = [ordered]@{
                post_url = $url; author_hint = $match.Groups[1].Value; post_id = $match.Groups[2].Value
                discovered_by = 'web_search'; matched_query = $Term; status = 'needs_fact_check'; rights_status = 'review_required'
            }
        }
    }
}

$found = @{}
foreach ($term in $Query) {
    # 검색엔진이 색인한 X 게시물만 대상으로 한다. X API 인증은 사용하지 않는다.
    $search = 'site:x.com "' + $term + '"'
    $uris = @(
        ('https://www.bing.com/search?q=' + [uri]::EscapeDataString($search) + '&count=50'),
        ('https://html.duckduckgo.com/html/?q=' + [uri]::EscapeDataString($search))
    )
    foreach ($uri in $uris) {
        try { $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec $RequestTimeoutSeconds -Headers @{ 'User-Agent' = 'Mozilla/5.0' } } catch { continue }
        Add-XUrl $response.Content $term $found
        # Bing은 결과 URL을 u=a1<base64> 리다이렉트로 감싸기도 한다.
        foreach ($redirect in [regex]::Matches($response.Content, '(?:[?&]u=|&amp;u=)a1([A-Za-z0-9_-]+)')) {
            try {
                $encoded = $redirect.Groups[1].Value.Replace('-', '+').Replace('_', '/')
                $encoded += '=' * ((4 - $encoded.Length % 4) % 4)
                Add-XUrl ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))) $term $found
            } catch { }
        }
        # DuckDuckGo HTML 결과는 uddg URL 매개 변수에 원본 링크를 넣는다.
        foreach ($redirect in [regex]::Matches($response.Content, '(?:[?&]uddg=|uddg=)([^&"''\s]+)')) {
            try { Add-XUrl ([uri]::UnescapeDataString([System.Net.WebUtility]::HtmlDecode($redirect.Groups[1].Value))) $term $found } catch { }
        }
    }
}

$result = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString('o')
    query = $Query
    source = 'Bing web search; no X API used'
    limitations = @('검색엔진에 색인된 공개 게시물만 반환', '게시물 본문·영상 파일·정확한 반응 수는 별도 검토 필요')
    candidates = @($found.Values | Select-Object -First $MaxLinks)
}
Save-Utf8Json $result $Output
Write-Output ([IO.Path]::GetFullPath($Output))
