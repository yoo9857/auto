param(
    [string]$JobPath = "",
    [string]$Background = "assets/backgrounds/far-cry-steve-buscemi.png",
    [string]$Logo = "NEWLOGO.png",
    [string]$Output = "output/far-cry-steve-buscemi-card-02-detail.png",
    [string]$PageNumber = "02 / 04"
)

Add-Type -AssemblyName System.Drawing
$analysisHeadline="유명 배우 한 명이`n게임 매출까지 바꿀까"
$quickAnswer="가능성은 있다. 다만 배우의 화제성이 게임 구매로 이어지려면 넘어야 할 조건이 남아 있다."
$article="예시 분석 1`n`n예시 분석 2`n`n예시 분석 3"; $memoryLine="이번 TV판은 IP 확장이 매출로 이어지는지 볼 첫 시험대다."
$category="게임"; $marketLabel="해외주식"
if ($JobPath) {
    $job=Get-Content -Raw -Encoding UTF8 $JobPath | ConvertFrom-Json
    if ($job.visual.background_path) { $Background=$job.visual.background_path }
    $analysisHeadline=$job.pages.page2.analysis_headline; $quickAnswer=$job.pages.page2.quick_answer
    $article=($job.pages.page2.paragraphs -join "`n`n"); $memoryLine=$job.pages.page2.memory_line
    $category=$job.article.category; $marketLabel=$job.article.market_label
}
function Palette-Color([string]$key,[string]$fallback){if($job -and $job.visual.palette -and $job.visual.palette.$key){return [Drawing.ColorTranslator]::FromHtml([string]$job.visual.palette.$key)}; return [Drawing.ColorTranslator]::FromHtml($fallback)}
$baseColor=Palette-Color 'background' '#030910'; $surfaceColor=Palette-Color 'surface' '#80161B'; $primaryColor=Palette-Color 'primary' '#49BEF7'; $secondaryColor=Palette-Color 'secondary' '#E8303E'

$w = 1080; $h = 1350
$bmp = New-Object System.Drawing.Bitmap($w, $h)
$bmp.SetResolution(144, 144)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

$bg = [System.Drawing.Image]::FromFile((Resolve-Path $Background))
$g.DrawImage($bg, (New-Object System.Drawing.Rectangle(0,0,$w,$h)))

# Preserve the cover palette while turning the photograph into a quiet reading surface.
$shade = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(222,$baseColor.R,$baseColor.G,$baseColor.B))
$g.FillRectangle($shade, 0, 0, $w, $h)
$redGlow = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Rectangle(690,0,390,$h)),
    ([System.Drawing.Color]::FromArgb(0,$surfaceColor.R,$surfaceColor.G,$surfaceColor.B)),
    ([System.Drawing.Color]::FromArgb(92,$surfaceColor.R,$surfaceColor.G,$surfaceColor.B)),
    [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal
)
$g.FillRectangle($redGlow, 690, 0, 390, $h)

$family = "Noto Sans KR"
$blackFamily = "Noto Sans KR Black"
$sectionNumber=if($PageNumber -match '^\s*(\d+)'){$matches[1]}else{'03'}
$white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$body = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(235,220,226,232))
$muted = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(190,172,184,196))
$blue = New-Object System.Drawing.SolidBrush($primaryColor)
$red = New-Object System.Drawing.SolidBrush($secondaryColor)
$border = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(62,255,255,255),1)

$fmt = New-Object System.Drawing.StringFormat
$fmt.Alignment = [System.Drawing.StringAlignment]::Near
$fmt.LineAlignment = [System.Drawing.StringAlignment]::Near
$fmt.Trimming = [System.Drawing.StringTrimming]::Word

$eyebrowFont = New-Object System.Drawing.Font($family,20,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
$titleFont = New-Object System.Drawing.Font($blackFamily,58,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
$leadFont = New-Object System.Drawing.Font($family,27,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
$bodyFont = New-Object System.Drawing.Font($family,27,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
$articleFont = New-Object System.Drawing.Font($family,29,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
$footerFont = New-Object System.Drawing.Font($family,22,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
$smallFont = New-Object System.Drawing.Font($family,16,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)

# Auto-shrink body text so long copy never clips the fixed reading area.
function Draw-FitText($graphics,$text,$fam,$max,$min,$style,$brush,$rect,$format){
    for($size=$max;$size -ge $min;$size-=1){
        $font=New-Object System.Drawing.Font($fam,$size,$style,[System.Drawing.GraphicsUnit]::Pixel)
        $measured=$graphics.MeasureString($text,$font,$rect.Size,$format)
        if($measured.Height -le $rect.Height){$graphics.DrawString($text,$font,$brush,$rect,$format);$font.Dispose();return}
        $font.Dispose()
    }
    $font=New-Object System.Drawing.Font($fam,$min,$style,[System.Drawing.GraphicsUnit]::Pixel);$graphics.DrawString($text,$font,$brush,$rect,$format);$font.Dispose()
}

function Draw-HeadlineHL($graphics, $text, $family, $max, $min, $baseBrush, $accentBrush, $rect) {
    $lines = $text -split "`n"; $tp = [System.Drawing.StringFormat]::GenericTypographic; $size = $min
    for ($s = $max; $s -ge $min; $s -= 2) { $f = New-Object System.Drawing.Font($family, $s, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel); $ok = $true; foreach ($ln in $lines) { if ($graphics.MeasureString($ln, $f, 10000, $tp).Width -gt $rect.Width) { $ok = $false } }; $th = $f.GetHeight($graphics) * 1.14 * $lines.Count; $f.Dispose(); if ($ok -and $th -le $rect.Height) { $size = $s; break } }
    $font = New-Object System.Drawing.Font($family, $size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel); $lineH = $font.GetHeight($graphics) * 1.14
    $spaceW = $graphics.MeasureString("가 가", $font, 10000, $tp).Width - $graphics.MeasureString("가가", $font, 10000, $tp).Width; $yy = $rect.Y
    foreach ($ln in $lines) { $xx = $rect.X; foreach ($tok in ($ln -split ' ')) { if ($tok -eq '') { $xx += $spaceW; continue }; $brush = if ($tok -match '[0-9]') { $accentBrush } else { $baseBrush }; $graphics.DrawString($tok, $font, $brush, [single]$xx, [single]$yy, $tp); $xx += $graphics.MeasureString($tok, $font, 10000, $tp).Width + $spaceW }; $yy += $lineH }
    $font.Dispose()
}
$g.DrawString("핵심 분석", $eyebrowFont, $blue, 72, 60)
$headlineRect = New-Object System.Drawing.RectangleF(72,108,880,180)
Draw-HeadlineHL $g $analysisHeadline $blackFamily 58 40 $white $blue $headlineRect
$g.FillRectangle($blue, 72, 281, 104, 7)

$leadRect = New-Object System.Drawing.RectangleF(72,314,906,92)
$g.DrawString($quickAnswer, $leadFont, $body, $leadRect, $fmt)

$bylineFont = New-Object System.Drawing.Font($family,17,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
$g.DrawString("ONEDAYTRADING 편집팀  |  $category·$marketLabel", $bylineFont, $muted, 72, 425)
$g.DrawLine($border,72,468,1008,468)

$articleRect = New-Object System.Drawing.RectangleF(76,518,902,570)
$g.DrawString($article,$articleFont,$body,$articleRect,$fmt)

$g.DrawLine($border,72,1145,1008,1145)
$closingFont = New-Object System.Drawing.Font($family,19,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
$g.DrawString($memoryLine,$closingFont,$blue,76,1162)

$g.DrawLine($border,72,1207,1008,1207)
$logoImg = [System.Drawing.Image]::FromFile((Resolve-Path $Logo))
$g.DrawImage($logoImg,(New-Object System.Drawing.Rectangle(72,1231,58,58)))
$g.DrawString("onedaytrading.net | $marketLabel",$footerFont,$white,151,1242)
$right = New-Object System.Drawing.StringFormat
$right.Alignment = [System.Drawing.StringAlignment]::Far
$g.DrawString($PageNumber,$footerFont,$muted,(New-Object System.Drawing.RectangleF(830,1242,178,34)),$right)
$g.DrawString("투자 참고용 · 매매 권유 아님",$smallFont,$muted,(New-Object System.Drawing.RectangleF(700,1276,308,28)),$right)

$dir = Split-Path -Parent $Output
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$bmp.Save([System.IO.Path]::GetFullPath($Output),[System.Drawing.Imaging.ImageFormat]::Png)

$right.Dispose(); $logoImg.Dispose(); $smallFont.Dispose(); $footerFont.Dispose()
$closingFont.Dispose(); $articleFont.Dispose(); $bodyFont.Dispose(); $leadFont.Dispose(); $titleFont.Dispose(); $eyebrowFont.Dispose(); $bylineFont.Dispose()
$fmt.Dispose(); $border.Dispose(); $red.Dispose(); $blue.Dispose()
$muted.Dispose(); $body.Dispose(); $white.Dispose(); $redGlow.Dispose(); $shade.Dispose()
$bg.Dispose(); $g.Dispose(); $bmp.Dispose()

Write-Output (Resolve-Path $Output)
