param(
    [Parameter(Mandatory=$true)][string]$Video,
    [Parameter(Mandatory=$true)][string]$Headline,
    [Parameter(Mandatory=$true)][string]$Body,
    [ValidateSet('EX1','EX2')][string]$Layout = 'EX2',
    [string]$SourceLabel = 'X / 원문 출처 확인',
    [string]$Output = 'output/x-video-news.mp4',
    [string]$FfmpegPath = '',
    [ValidateRange(5,60)][int]$DurationSeconds = 15
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $Video)) { throw "영상 파일을 찾을 수 없습니다: $Video" }
if (-not $FfmpegPath) { $FfmpegPath = [Environment]::GetEnvironmentVariable('FFMPEG_PATH') }
if (-not $FfmpegPath) {
    $ffmpegCommand = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($ffmpegCommand) { $FfmpegPath = $ffmpegCommand.Source }
}
if (-not $FfmpegPath -or -not (Test-Path $FfmpegPath)) { throw 'ffmpeg가 필요합니다. 새 PowerShell을 열거나 FFMPEG_PATH에 ffmpeg.exe 경로를 설정하세요.' }

function Write-TextFile([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}
function ConvertTo-FilterPath([string]$Path) {
    return (([IO.Path]::GetFullPath($Path) -replace '\\','/') -replace ':','\:') -replace "'","\\'"
}

$outputPath = [IO.Path]::GetFullPath($Output)
$outputDirectory = Split-Path -Parent $outputPath
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$work = Join-Path $env:TEMP ("x-video-news-" + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Force -Path $work | Out-Null

try {
    $headlineFile = Join-Path $work 'headline.txt'; $bodyFile = Join-Path $work 'body.txt'; $sourceFile = Join-Path $work 'source.txt'
    Write-TextFile $headlineFile $Headline; Write-TextFile $bodyFile $Body; Write-TextFile $sourceFile $SourceLabel
    $videoHeight = if ($Layout -eq 'EX1') { 540 } else { 810 }
    $titleY = $videoHeight + 72
    $bodyY = $videoHeight + 285
    $fontBold = 'C\:/Windows/Fonts/malgunbd.ttf'; $font = 'C\:/Windows/Fonts/malgun.ttf'
    $filter = "[0:v]scale=1080:${videoHeight}:force_original_aspect_ratio=increase,crop=1080:${videoHeight},setsar=1[v];" +
        "color=c=white:s=1080x1350:d=$DurationSeconds[canvas];[canvas][v]overlay=0:0[base];" +
        "[base]drawbox=x=0:y=${videoHeight}:w=1080:h=2:color=0xE5E5E5:t=fill," +
        "drawtext=fontfile='$font':textfile='$(ConvertTo-FilterPath $sourceFile)':fontcolor=black:fontsize=24:x=w-text_w-50:y=$($videoHeight-48)," +
        "drawtext=fontfile='$fontBold':textfile='$(ConvertTo-FilterPath $headlineFile)':fontcolor=black:fontsize=58:line_spacing=10:x=70:y=${titleY}:box=0," +
        "drawtext=fontfile='$font':textfile='$(ConvertTo-FilterPath $bodyFile)':fontcolor=black:fontsize=31:line_spacing=13:x=72:y=${bodyY}[out]"
    # 원본 오디오가 있으면 함께 반복·보존하고, 무음 원본도 오류 없이 렌더한다.
    $arguments = @('-y','-stream_loop','-1','-i',$Video,'-t',$DurationSeconds.ToString(),'-filter_complex',$filter,'-map','[out]','-map','0:a?','-c:v','libx264','-pix_fmt','yuv420p','-c:a','aac','-shortest',$outputPath)
    & $FfmpegPath @arguments
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $outputPath)) { throw '영상 렌더링에 실패했습니다.' }
    Write-Output $outputPath
} finally {
    if (Test-Path $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
