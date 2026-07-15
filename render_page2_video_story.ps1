param(
    [Parameter(Mandatory=$true)][string]$Video,
    [Parameter(Mandatory=$true)][string]$Headline,
    [Parameter(Mandatory=$true)][string]$Summary,
    [string]$SourceLabel = 'SOURCE / VERIFY BEFORE POSTING',
    # Displayed inside the video frame at bottom-right for third-party footage.
    [string]$CopyrightLabel = '',
    [string]$EyebrowText = 'N200 / EVIDENCE',
    [string]$Logo = 'NEWLOGO.png',
    [string]$Output = 'output/page-02-video-story.mp4',
    [string]$FfmpegPath = '',
    [ValidateRange(6,60)][int]$DurationSeconds = 12,
    [ValidateRange(600,820)][int]$VideoHeight = 760,
    [string]$PageNumber = "02 / 05"
)

$ErrorActionPreference='Stop'
if(-not(Test-Path $Video)){throw "Video not found: $Video"}
if(-not $FfmpegPath){$FfmpegPath=[Environment]::GetEnvironmentVariable('FFMPEG_PATH')}
if(-not $FfmpegPath){$cmd=Get-Command ffmpeg -ErrorAction SilentlyContinue;if($cmd){$FfmpegPath=$cmd.Source}}
if(-not $FfmpegPath -or -not(Test-Path $FfmpegPath)){throw 'ffmpeg is required. Set FFMPEG_PATH or pass -FfmpegPath.'}

Add-Type -AssemblyName System.Drawing
function Draw-FitText($g,$Text,$Family,$Max,$Min,$Style,$Brush,$Rect,$Fmt){
    for($size=$Max;$size -ge $Min;$size-=2){
        $font=New-Object Drawing.Font($Family,$size,$Style,[Drawing.GraphicsUnit]::Pixel)
        $measure=$g.MeasureString($Text,$font,$Rect.Size,$Fmt)
        if($measure.Height -le $Rect.Height -and $measure.Width -le $Rect.Width){$g.DrawString($Text,$font,$Brush,$Rect,$Fmt);$font.Dispose();return}
        $font.Dispose()
    }
    throw "Text does not fit. Shorten the headline or summary."
}

$w=1080;$h=1350;$lowerY=$VideoHeight;$outPath=[IO.Path]::GetFullPath($Output);$outDir=Split-Path -Parent $outPath;New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$work=Join-Path $env:TEMP ('page2-video-'+[guid]::NewGuid());New-Item -ItemType Directory -Force -Path $work|Out-Null;$overlayPath=Join-Path $work 'overlay.png'
try{
    $overlay=New-Object Drawing.Bitmap($w,$h,[Drawing.Imaging.PixelFormat]::Format32bppArgb);$g=[Drawing.Graphics]::FromImage($overlay);$g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::HighQuality;$g.TextRenderingHint=[Drawing.Text.TextRenderingHint]::AntiAliasGridFit;$g.Clear([Drawing.Color]::Transparent)
    # N200 identity: midnight navy base, electric blue signal, restrained red alert.
    $white=New-Object Drawing.SolidBrush([Drawing.Color]::White);$ink=New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml('#F7FAFF'));$muted=New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml('#9DAABD'));$blue=New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml('#3E82FF'));$red=New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml('#FF4D63'));$panel=New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml('#030B18'));$rule=New-Object Drawing.Pen([Drawing.ColorTranslator]::FromHtml('#21324D'),2)
    $g.FillRectangle($panel,0,$lowerY,$w,$h-$lowerY)
    $sourceBg=New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(224,3,11,24));$g.FillRectangle($sourceBg,0,$lowerY-38,$w,38)
    $g.FillRectangle($red,72,$lowerY-25,5,13)
    $sourceFont=New-Object Drawing.Font('Noto Sans KR',16,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel);$g.DrawString($SourceLabel,$sourceFont,$white,90,$lowerY-31)
    if($CopyrightLabel){
        $creditFmt=New-Object Drawing.StringFormat;$creditFmt.Alignment=[Drawing.StringAlignment]::Far;$creditFmt.LineAlignment=[Drawing.StringAlignment]::Center
        $creditFont=New-Object Drawing.Font('Noto Sans KR',18,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel)
        $creditRect=New-Object Drawing.RectangleF(430,[single]($lowerY-58),590,36)
        $creditBg=New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(176,0,0,0))
        $creditInk=New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(238,247,250,255))
        $g.FillRectangle($creditBg,$creditRect)
        $g.DrawString($CopyrightLabel,$creditFont,$creditInk,$creditRect,$creditFmt)
        $creditInk.Dispose();$creditBg.Dispose();$creditFont.Dispose();$creditFmt.Dispose()
    }
    $fmt=New-Object Drawing.StringFormat;$fmt.Trimming=[Drawing.StringTrimming]::EllipsisWord
    $eyebrow=New-Object Drawing.Font('Noto Sans KR',18,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel);$g.DrawString($EyebrowText,$eyebrow,$blue,72,$lowerY+34)
    $g.FillRectangle($red,72,$lowerY+61,54,3)
    $titleRect=[Drawing.RectangleF]::new(72.0,[single]($lowerY+72),920.0,155.0);Draw-FitText $g $Headline 'Noto Sans KR Black' 58 38 ([Drawing.FontStyle]::Bold) $ink $titleRect $fmt
    $g.DrawLine($rule,72,$lowerY+248,1008,$lowerY+248)
    $summaryRect=[Drawing.RectangleF]::new(72.0,[single]($lowerY+280),900.0,128.0);Draw-FitText $g $Summary 'Noto Sans KR' 30 22 ([Drawing.FontStyle]::Regular) $ink $summaryRect $fmt
    $g.DrawLine($rule,72,1207,1008,1207)
    $logoImg=[Drawing.Image]::FromFile((Resolve-Path $Logo));$g.DrawImage($logoImg,(New-Object Drawing.Rectangle(72,1231,58,58)))
    $footer=New-Object Drawing.Font('Noto Sans KR',22,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel);$g.DrawString('NEWS SIGNAL / CONTEXT / JUDGMENT',$footer,$ink,151,1242)
    $right=New-Object Drawing.StringFormat;$right.Alignment=[Drawing.StringAlignment]::Far;$g.DrawString($PageNumber,$footer,$muted,(New-Object Drawing.RectangleF(830,1242,178,34)),$right)
    $overlay.Save($overlayPath,[Drawing.Imaging.ImageFormat]::Png)
    $right.Dispose();$footer.Dispose();$logoImg.Dispose();$eyebrow.Dispose();$fmt.Dispose();$sourceFont.Dispose();$sourceBg.Dispose();$rule.Dispose();$panel.Dispose();$red.Dispose();$blue.Dispose();$muted.Dispose();$ink.Dispose();$white.Dispose();$g.Dispose();$overlay.Dispose()
    # Draw the video first, then place the transparent text/footer layer on top.
    $filter="[1:v]scale=1080:$VideoHeight`:force_original_aspect_ratio=decrease,pad=1080:$VideoHeight`:(ow-iw)/2`:(oh-ih)/2:color=0x101114[video];color=c=0x101114:s=1080x1350:d=$DurationSeconds[base];[base][video]overlay=0:0[withvideo];[withvideo][0:v]overlay=0:0:format=auto[out]"
    $args=@('-y','-loop','1','-i',$overlayPath,'-stream_loop','-1','-i',$Video,'-t',$DurationSeconds.ToString(),'-filter_complex',$filter,'-map','[out]','-map','1:a?','-c:v','libx264','-pix_fmt','yuv420p','-c:a','aac','-shortest',$outPath)
    & $FfmpegPath @args
    if($LASTEXITCODE -ne 0 -or -not(Test-Path $outPath)){throw 'Video render failed.'}
    Write-Output $outPath
}finally{if(Test-Path $work){Remove-Item -LiteralPath $work -Recurse -Force}}
