param(
    [Parameter(Mandatory=$true)][string]$JobPath,
    [string]$Output = '',
    [string]$FfmpegPath = ''
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $JobPath)) { throw "작업 파일을 찾을 수 없습니다: $JobPath" }
$job = Get-Content -Raw -Encoding UTF8 $JobPath | ConvertFrom-Json
if ($job.status -ne 'approved_for_render' -or $job.rights.status -ne 'approved') { throw '승인된 작업만 렌더할 수 있습니다.' }
if (-not $Output) { $Output = Join-Path (Split-Path -Parent $JobPath) 'news-reel.mp4' }
& (Join-Path $PSScriptRoot 'render_x_video.ps1') `
    -Video $job.video.local_path `
    -Layout $job.layout `
    -Headline $job.copy.headline `
    -Body $job.copy.body `
    -SourceLabel $job.video.source_label `
    -FfmpegPath $FfmpegPath `
    -Output $Output
