param(
    [Parameter(Mandatory=$true)][string]$Image,
    [Parameter(Mandatory=$true)][string]$Output,
    [string]$FfmpegPath = '',
    [ValidateRange(6,30)][int]$Seconds = 12
)
# Guaranteed fallback for the video page: a slow Ken Burns zoom over the article's
# own hero background. Always available, no third-party rights. Output fills the
# 1080x760 video region used by render_page2_video_story.
$ErrorActionPreference = 'Stop'
if (-not $FfmpegPath) { $FfmpegPath = [Environment]::GetEnvironmentVariable('FFMPEG_PATH') }
if (-not $FfmpegPath) { $c = Get-Command ffmpeg -ErrorAction SilentlyContinue; if ($c) { $FfmpegPath = $c.Source } }
if (-not $FfmpegPath -or -not (Test-Path $FfmpegPath)) { throw 'ffmpeg is required (FFMPEG_PATH or -FfmpegPath).' }
if (-not (Test-Path -LiteralPath $Image)) { throw "image not found: $Image" }
$outPath = [IO.Path]::GetFullPath($Output)
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outPath) | Out-Null

$frames = $Seconds * 25
$vf = "scale=1620:1140:force_original_aspect_ratio=increase,crop=1620:1140,zoompan=z='min(zoom+0.0005,1.12)':d=$frames`:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=1080x760:fps=25"
& $FfmpegPath '-y' '-loop' '1' '-framerate' '25' '-i' (Resolve-Path -LiteralPath $Image).Path '-t' $Seconds.ToString() '-vf' $vf '-c:v' 'libx264' '-pix_fmt' 'yuv420p' '-an' $outPath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outPath)) { throw 'Motion clip render failed.' }
Write-Output $outPath
