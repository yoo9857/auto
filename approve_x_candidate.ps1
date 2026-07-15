param(
    [Parameter(Mandatory=$true)][string]$CandidatesFile,
    [Parameter(Mandatory=$true)][string]$CandidateId,
    [Parameter(Mandatory=$true)][string]$VerifiedSourceUrl,
    [Parameter(Mandatory=$true)][string]$Headline,
    [Parameter(Mandatory=$true)][string]$Body,
    [ValidateSet('EX1','EX2')][string]$Layout = 'EX2',
    [string]$VideoPath = '',
    [switch]$DownloadApprovedVideo,
    [switch]$RightsApproved,
    [string]$OutputRoot = 'output/x-news-jobs'
)

$ErrorActionPreference = 'Stop'
if (-not $RightsApproved) { throw '영상 편집·게시 권한을 확인한 뒤 -RightsApproved를 명시해야 합니다.' }
if (-not (Test-Path $CandidatesFile)) { throw "후보 파일을 찾을 수 없습니다: $CandidatesFile" }
$queue = Get-Content -Raw -Encoding UTF8 $CandidatesFile | ConvertFrom-Json
$candidate = @($queue.candidates | Where-Object { $_.id -eq $CandidateId } | Select-Object -First 1)
if (-not $candidate) { throw "후보 ID를 찾지 못했습니다: $CandidateId" }
if ($candidate.possibly_sensitive) { throw '민감 가능성 표시가 있는 X 게시물은 자동 승인할 수 없습니다.' }

$jobDir = Join-Path $OutputRoot $CandidateId
New-Item -ItemType Directory -Force -Path $jobDir | Out-Null
$localVideo = $VideoPath
if ($DownloadApprovedVideo) {
    if (-not $candidate.video_candidate.mp4_url) { throw '다운로드 가능한 MP4 영상 후보가 없습니다.' }
    $localVideo = Join-Path $jobDir 'source-video.mp4'
    Invoke-WebRequest -Uri $candidate.video_candidate.mp4_url -OutFile $localVideo
}
if (-not $localVideo -or -not (Test-Path $localVideo)) { throw '검토·승인된 로컬 영상 파일을 -VideoPath로 제공하거나 -DownloadApprovedVideo를 사용하세요.' }

$job = [ordered]@{
    status = 'approved_for_render'
    approved_at = (Get-Date).ToUniversalTime().ToString('o')
    source = [ordered]@{
        x_post_url = $candidate.post_url
        verified_source_url = $VerifiedSourceUrl
        author = $candidate.author
        created_at = $candidate.created_at
    }
    rights = [ordered]@{ status='approved'; approved_by=$env:USERNAME }
    video = [ordered]@{ local_path=[IO.Path]::GetFullPath($localVideo); source_label="X / $($candidate.author.username)" }
    layout = $Layout
    copy = [ordered]@{ headline=$Headline; body=$Body }
}
$jobPath = Join-Path $jobDir 'news-job.json'
$job | ConvertTo-Json -Depth 12 | Set-Content -Encoding UTF8 $jobPath
Write-Output $jobPath
