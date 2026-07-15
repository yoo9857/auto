param(
    [Parameter(Mandatory=$true)][string]$VideoUrl,
    [Parameter(Mandatory=$true)][string]$Start,
    [Parameter(Mandatory=$true)][string]$End,
    [Parameter(Mandatory=$true)][string]$Output,
    [Parameter(Mandatory=$true)][string]$YtDlpPath,
    [Parameter(Mandatory=$true)][string]$FfmpegPath,
    [string]$SourceLabel = 'CONTEXT VIDEO',
    [string]$UsageRule = 'Context footage only; not proof of the article event.'
)

$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $YtDlpPath)){throw "yt-dlp not found: $YtDlpPath"}
if(-not(Test-Path -LiteralPath $FfmpegPath)){throw "ffmpeg not found: $FfmpegPath"}
$outputPath=[IO.Path]::GetFullPath($Output);$outputDir=Split-Path -Parent $outputPath;New-Item -ItemType Directory -Force -Path $outputDir|Out-Null
$work=Join-Path $env:TEMP ('n200-context-'+[guid]::NewGuid());New-Item -ItemType Directory -Force -Path $work|Out-Null
try{
    $template=Join-Path $work 'clip.%(ext)s'
    & $YtDlpPath '--no-playlist' '--download-sections' "*$Start-$End" '--force-keyframes-at-cuts' '--remux-video' 'mp4' '--ffmpeg-location' $FfmpegPath '-f' 'best[height<=720]/best' '-o' $template $VideoUrl
    if($LASTEXITCODE -ne 0){throw 'Context clip extraction failed.'}
    $clip=Get-ChildItem -LiteralPath $work -Filter '*.mp4'|Select-Object -First 1
    if(-not $clip){throw 'No MP4 clip was produced.'}
    Move-Item -LiteralPath $clip.FullName -Destination $outputPath -Force
    $provenance=[ordered]@{source_url=$VideoUrl;source_label=$SourceLabel;start=$Start;end=$End;usage_rule=$UsageRule;rights_status='review_required';created_at=(Get-Date).ToUniversalTime().ToString('o')}
    $provenance|ConvertTo-Json -Depth 6|Set-Content -LiteralPath "$outputPath.provenance.json" -Encoding UTF8
    Write-Output $outputPath
}finally{if(Test-Path -LiteralPath $work){Remove-Item -LiteralPath $work -Recurse -Force}}
