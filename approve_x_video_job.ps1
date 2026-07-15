param(
    [Parameter(Mandatory=$true)][string]$Candidates,
    [Parameter(Mandatory=$true)][string]$PostId,
    [Parameter(Mandatory=$true)][string]$Video,
    [Parameter(Mandatory=$true)][string]$Headline,
    [Parameter(Mandatory=$true)][string]$Body,
    [ValidateSet('EX1','EX2')][string]$Layout = 'EX2',
    [string]$SourceLabel = 'X / 원문 출처',
    [string]$OutputRoot = 'output/x-ready',
    [switch]$RightsApproved
)

$ErrorActionPreference = 'Stop'
if (-not $RightsApproved) { throw '-RightsApproved가 필요합니다. 원저작자/라이선스의 영상 편집·재게시 권한을 먼저 확인하세요.' }
if (-not (Test-Path $Candidates)) { throw "후보 파일을 찾을 수 없습니다: $Candidates" }
if (-not (Test-Path $Video)) { throw "영상 파일을 찾을 수 없습니다: $Video" }

$queue = Get-Content -Raw -Encoding UTF8 $Candidates | ConvertFrom-Json
$candidate = $queue.candidates | Where-Object { $_.post_id -eq $PostId } | Select-Object -First 1
if (-not $candidate) { throw "후보 큐에 없는 Post ID입니다: $PostId" }

$jobDir = Join-Path $OutputRoot $PostId
New-Item -ItemType Directory -Force -Path $jobDir | Out-Null
$extension = [IO.Path]::GetExtension($Video); if (-not $extension) { $extension = '.mp4' }
$videoCopy = Join-Path $jobDir ("source-video$extension")
Copy-Item -LiteralPath $Video -Destination $videoCopy -Force
$job = [ordered]@{
    status = 'approved_for_render'
    approved_at = (Get-Date).ToUniversalTime().ToString('o')
    source = [ordered]@{ post_url=$candidate.post_url; post_id=$candidate.post_id; author_hint=$candidate.author_hint; source_label=$SourceLabel; rights_status='approved_by_operator' }
    copy = [ordered]@{ headline=$Headline; body=$Body }
    layout = $Layout
    video_path = [IO.Path]::GetFullPath($videoCopy)
    render_output = [IO.Path]::GetFullPath((Join-Path $jobDir 'instagram-news.mp4'))
}
$jobPath = Join-Path $jobDir 'job.json'
$job | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 $jobPath
$command = ".\render_x_video.ps1 -Video '$($job.video_path)' -Layout $($job.layout) -Headline '$Headline' -Body '$Body' -SourceLabel '$SourceLabel' -Output '$($job.render_output)'"
Set-Content -Encoding UTF8 (Join-Path $jobDir 'render-command.txt') $command
Write-Output $jobPath
