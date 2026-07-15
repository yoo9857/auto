param(
    [Parameter(Mandatory=$true)][string]$JobPath,
    [string]$ReportPath = ""
)

$ErrorActionPreference="Stop"
Add-Type -AssemblyName System.Drawing
$job=Get-Content -Raw -Encoding UTF8 $JobPath | ConvertFrom-Json
$jobDir=Split-Path -Parent (Resolve-Path $JobPath)
$checks=New-Object System.Collections.Generic.List[object]
function Add-Check([string]$name,[bool]$passed,[string]$message,[bool]$critical=$false) {
    $checks.Add([pscustomobject]@{name=$name;passed=$passed;message=$message;critical=$critical})
}
function Has-Text($value) { return ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) }
function Get-ImageSize($path) { try {$image=[Drawing.Image]::FromFile((Resolve-Path -LiteralPath $path));try{return "$($image.Width)x$($image.Height)"}finally{$image.Dispose()}}catch{return ""} }

Add-Check "article_url" (Has-Text $job.article.article_url) "기사 URL 필수" $true
Add-Check "article_id" (Has-Text $job.article.article_id) "기사 ID 필수" $true
Add-Check "article_title" (Has-Text $job.article.title) "원문 제목 필수" $true
Add-Check "market_label" (@("국내주식","해외주식","글로벌증시","증시·경제","크립토") -contains $job.article.market_label) "시장 라벨 검증" $true
Add-Check "background" ((Has-Text $job.visual.background_path) -and (Test-Path -LiteralPath $job.visual.background_path)) "배경 이미지 파일 검증" $true
$sourcePath=Join-Path $jobDir "source.json"
$sourceOk=$false
if(Test-Path $sourcePath){$source=Get-Content -Raw -Encoding UTF8 $sourcePath|ConvertFrom-Json;$sourceOk=($source.article_id -eq $job.article.article_id -and $source.title -eq $job.article.title)}
Add-Check "source_snapshot" $sourceOk "원문 스냅샷과 작업 기사 일치" $true
$size=if(Test-Path -LiteralPath $job.visual.background_path){Get-ImageSize $job.visual.background_path}else{""}
Add-Check "background_readable" ($size -match '^\d+x\d+$') ("배경 이미지 해상도 검증: " + $size) $false
Add-Check "visual_license" (@('owned','licensed','generated_from_reference','review_required') -contains $job.visual.license) "이미지 라이선스 상태 기록" $false
Add-Check "page1_headline" (Has-Text $job.pages.page1.headline) "1페이지 제목 필수" $true
Add-Check "page1_subtitle" (Has-Text $job.pages.page1.subtitle) "1페이지 서브타이틀 필수" $true
Add-Check "page2_paragraphs" ($job.pages.page2.paragraphs.Count -eq 3) "2페이지 문단 3개" $true
Add-Check "page3_evaluation" (@("명확한 호재","제한적 호재","중립","제한적 악재","명확한 악재") -contains $job.pages.page3.evaluation) "3페이지 평가값 검증" $true
Add-Check "page3_paragraphs" ($job.pages.page3.paragraphs.Count -eq 3) "3페이지 문단 3개" $true
Add-Check "instagram" ($job.pages.page4.instagram_handle -eq "@onedaytrading.io") "인스타 계정 검증" $true
Add-Check "learning_strategy" ((Has-Text $job.learning.strategies.writing) -and (Has-Text $job.learning.strategies.visual)) "설계서 기반 작성·이미지 전략 기록" $false
Add-Check "evidence_ledger" (@($job.evidence).Count -ge 1) "원문 근거 기록" $false
Add-Check "headline_length" ($job.pages.page1.headline.Length -le 50) "1페이지 제목 길이" $false
Add-Check "memory2_length" ($job.pages.page2.memory_line.Length -le 55) "2페이지 결론 길이" $false
Add-Check "memory3_length" ($job.pages.page3.memory_line.Length -le 55) "3페이지 결론 길이" $false

$page2Text=($job.pages.page2.paragraphs -join " ")
$page3Text=($job.pages.page3.paragraphs -join " ")
$tokens2=$page2Text -split '\s+' | Where-Object {$_.Length -ge 3}
$tokens3=$page3Text -split '\s+' | Where-Object {$_.Length -ge 3}
$overlap=@($tokens2 | Where-Object {$tokens3 -contains $_} | Select-Object -Unique)
Add-Check "page_overlap" ($overlap.Count -le 8) ("2·3페이지 중복 토큰: " + ($overlap -join ", ")) $false

$criticalFailures=@($checks | Where-Object {$_.critical -and -not $_.passed})
$score=@($checks | Where-Object {$_.passed}).Count
$report=[ordered]@{
    job_path=(Resolve-Path $JobPath).Path
    generated_at=(Get-Date).ToUniversalTime().ToString("o")
    score=$score
    total=$checks.Count
    passed=($criticalFailures.Count -eq 0)
    checks=$checks
}
if (-not $ReportPath) { $ReportPath=Join-Path (Split-Path -Parent $JobPath) "qa-report.json" }
$report | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 $ReportPath
Write-Output $ReportPath
if ($criticalFailures.Count -gt 0) { exit 2 }
