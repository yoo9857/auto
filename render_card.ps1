param(
    [string]$JobPath = "",
    [string]$Background = "assets/backgrounds/far-cry-steve-buscemi.png",
    [string]$Logo = "NEWLOGO.png",
    [string]$Output = "output/far-cry-steve-buscemi-card-01.png",
    [string]$PageNumber = ""
)

Add-Type -AssemblyName System.Drawing
$breakingLabel="긴급속보"; $headline="파크라이 TV판에`n스티브 부시미 합류"
$subtitle="유비소프트가 기대하는`n제2의 '폴아웃 효과'"; $cta="핵심 분석 보기 →"; $marketLabel="해외주식"
if ($JobPath) {
    $job=Get-Content -Raw -Encoding UTF8 $JobPath | ConvertFrom-Json
    if ($job.visual.background_path) { $Background=$job.visual.background_path }
    $breakingLabel=$job.pages.page1.breaking_label; $headline=$job.pages.page1.headline
    $subtitle=$job.pages.page1.subtitle; $cta=$job.pages.page1.cta
    $marketLabel=$job.article.market_label
}
function Palette-Color([string]$key,[string]$fallback){if($job -and $job.visual.palette -and $job.visual.palette.$key){return [Drawing.ColorTranslator]::FromHtml([string]$job.visual.palette.$key)}; return [Drawing.ColorTranslator]::FromHtml($fallback)}
$baseColor=Palette-Color 'background' '#030910'; $primaryColor=Palette-Color 'primary' '#4AC0FF'; $secondaryColor=Palette-Color 'secondary' '#E0313E'

$width = 1080
$height = 1350
$canvas = New-Object System.Drawing.Bitmap($width, $height)
$canvas.SetResolution(144, 144)
$g = [System.Drawing.Graphics]::FromImage($canvas)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

function Draw-CoverImage($graphics, $image, $targetWidth, $targetHeight) {
    $sourceRatio = $image.Width / $image.Height
    $targetRatio = $targetWidth / $targetHeight
    if ($sourceRatio -gt $targetRatio) {
        $sourceHeight = $image.Height
        $sourceWidth = [int]($sourceHeight * $targetRatio)
        $sourceX = [int](($image.Width - $sourceWidth) / 2)
        $sourceY = 0
    } else {
        $sourceWidth = $image.Width
        $sourceHeight = [int]($sourceWidth / $targetRatio)
        $sourceX = 0
        $sourceY = [int](($image.Height - $sourceHeight) / 2)
    }
    $dest = New-Object System.Drawing.Rectangle(0, 0, $targetWidth, $targetHeight)
    $src = New-Object System.Drawing.Rectangle($sourceX, $sourceY, $sourceWidth, $sourceHeight)
    $graphics.DrawImage($image, $dest, $src, [System.Drawing.GraphicsUnit]::Pixel)
}

function New-VerticalGradientBrush($rect, $top, $bottom) {
    return New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $rect, $top, $bottom, [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
    )
}

function Draw-FitText($graphics, $text, $family, $maxSize, $minSize, $style, $brush, $rect, $format) {
    for ($size = $maxSize; $size -ge $minSize; $size -= 2) {
        $font = New-Object System.Drawing.Font($family, $size, $style, [System.Drawing.GraphicsUnit]::Pixel)
        $measured = $graphics.MeasureString($text, $font, $rect.Size, $format)
        if ($measured.Width -le $rect.Width -and $measured.Height -le $rect.Height) {
            $graphics.DrawString($text, $font, $brush, $rect, $format)
            $font.Dispose()
            return
        }
        $font.Dispose()
    }
    throw "Text does not fit: $text"
}

function New-RoundedRect([single]$x,[single]$y,[single]$w,[single]$h,[single]$r) {
    $d = $r * 2
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function Draw-HeadlineHL($graphics, $text, $family, $max, $min, $baseBrush, $accentBrush, $rect) {
    # Auto-fit 2-line headline, drawing numeric tokens (10%, 800억, B300, H200 ...) in the accent color.
    $lines = $text -split "`n"
    $tp = [System.Drawing.StringFormat]::GenericTypographic
    $size = $min
    for ($s = $max; $s -ge $min; $s -= 2) {
        $f = New-Object System.Drawing.Font($family, $s, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $ok = $true
        foreach ($ln in $lines) { if ($graphics.MeasureString($ln, $f, 10000, $tp).Width -gt $rect.Width) { $ok = $false } }
        $th = $f.GetHeight($graphics) * 1.14 * $lines.Count
        $f.Dispose()
        if ($ok -and $th -le $rect.Height) { $size = $s; break }
    }
    $font = New-Object System.Drawing.Font($family, $size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $lineH = $font.GetHeight($graphics) * 1.14
    $spaceW = $graphics.MeasureString("가 가", $font, 10000, $tp).Width - $graphics.MeasureString("가가", $font, 10000, $tp).Width
    $y = $rect.Y
    foreach ($ln in $lines) {
        $x = $rect.X
        foreach ($tok in ($ln -split ' ')) {
            if ($tok -eq '') { $x += $spaceW; continue }
            $brush = if ($tok -match '[0-9]') { $accentBrush } else { $baseBrush }
            $graphics.DrawString($tok, $font, $brush, [single]$x, [single]$y, $tp)
            $x += $graphics.MeasureString($tok, $font, 10000, $tp).Width + $spaceW
        }
        $y += $lineH
    }
    $font.Dispose()
}

$bg = [System.Drawing.Image]::FromFile((Resolve-Path $Background))
Draw-CoverImage $g $bg $width $height

# Headline readability without flattening the portrait.
$topRect = New-Object System.Drawing.Rectangle(0, 0, 1080, 820)
$topBrush = New-VerticalGradientBrush $topRect `
    ([System.Drawing.Color]::FromArgb(220,$baseColor.R,$baseColor.G,$baseColor.B)) `
    ([System.Drawing.Color]::FromArgb(0,$baseColor.R,$baseColor.G,$baseColor.B))
$g.FillRectangle($topBrush, $topRect)

$bottomRect = New-Object System.Drawing.Rectangle(0, 985, 1080, 365)
$bottomBrush = New-VerticalGradientBrush $bottomRect `
    ([System.Drawing.Color]::FromArgb(0,$baseColor.R,$baseColor.G,$baseColor.B)) `
    ([System.Drawing.Color]::FromArgb(238,$baseColor.R,$baseColor.G,$baseColor.B))
$g.FillRectangle($bottomBrush, $bottomRect)

$fontFamily = "Noto Sans KR"
$titleFontFamily = "Noto Sans KR Black"
$white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$muted = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(225, 224, 230, 236))
$cyan = New-Object System.Drawing.SolidBrush($primaryColor)
$red = New-Object System.Drawing.SolidBrush($secondaryColor)

# Trendy status chip: frosted-glass pill + sentiment glow dot + clean label.
$sentColor = switch -Regex ($breakingLabel) {
    '호재|상승|반등|긍정|훈풍' { [System.Drawing.Color]::FromArgb(255, 74, 222, 128) }   # emerald
    '악재|하락|부정|경고|하향'  { [System.Drawing.Color]::FromArgb(255, 248, 113, 113) }  # red
    '긴급|속보'                 { [System.Drawing.Color]::FromArgb(255, 255, 179, 71) }   # amber (urgent)
    default                     { [System.Drawing.Color]::FromArgb(255, 148, 163, 184) }  # slate (neutral/분석)
}
$labelFont = New-Object System.Drawing.Font($fontFamily, 21, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$labelSize = $g.MeasureString($breakingLabel, $labelFont)
$chipX = 72; $chipY = 66; $chipH = 54; $dotD = 12; $padL = 26; $padR = 30; $gap = 13
$chipW = [single]($padL + $dotD + $gap + $labelSize.Width + $padR)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$chip = New-RoundedRect $chipX $chipY $chipW $chipH ($chipH / 2)
# frosted glass fill + hairline border
$g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(140, 10, 14, 22))), $chip)
$chipPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(48, 255, 255, 255), 1.4)
$g.DrawPath($chipPen, $chip)
# status dot with soft glow
$dotX = $chipX + $padL; $dotY = $chipY + ($chipH - $dotD) / 2
$g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70, $sentColor.R, $sentColor.G, $sentColor.B))), ($dotX - 7), ($dotY - 7), ($dotD + 14), ($dotD + 14))
$g.FillEllipse((New-Object System.Drawing.SolidBrush($sentColor)), $dotX, $dotY, $dotD, $dotD)
# label text (vertically centered)
$chipFmt = New-Object System.Drawing.StringFormat
$chipFmt.Alignment = [System.Drawing.StringAlignment]::Near
$chipFmt.LineAlignment = [System.Drawing.StringAlignment]::Center
$labelTextRect = New-Object System.Drawing.RectangleF(($dotX + $dotD + $gap), $chipY, ($labelSize.Width + 8), $chipH)
$g.DrawString($breakingLabel, $labelFont, $white, $labelTextRect, $chipFmt)

$headlineFormat = New-Object System.Drawing.StringFormat
$headlineFormat.Alignment = [System.Drawing.StringAlignment]::Near
$headlineFormat.LineAlignment = [System.Drawing.StringAlignment]::Near
$headlineFormat.Trimming = [System.Drawing.StringTrimming]::Word
$headlineFormat.FormatFlags = [System.Drawing.StringFormatFlags]::LineLimit

$titleRect = New-Object System.Drawing.RectangleF(72, 153, 800, 235)
Draw-HeadlineHL $g $headline $titleFontFamily 72 48 $white $cyan $titleRect

$accentRect = New-Object System.Drawing.Rectangle(72, 410, 104, 7)
$g.FillRectangle($cyan, $accentRect)

$subtitleRect = New-Object System.Drawing.RectangleF(72, 440, 700, 112)
Draw-FitText $g $subtitle $fontFamily 35 25 `
    ([System.Drawing.FontStyle]::Bold) $muted $subtitleRect $headlineFormat

$ctaFont = New-Object System.Drawing.Font($fontFamily, 24, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$ctaFormat = New-Object System.Drawing.StringFormat
$ctaFormat.Alignment = [System.Drawing.StringAlignment]::Far
$ctaRect = New-Object System.Drawing.RectangleF(610, 1138, 398, 50)
$g.DrawString($cta, $ctaFont, $white, $ctaRect, $ctaFormat)

$rulePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(80, 255, 255, 255), 1)
$g.DrawLine($rulePen, 72, 1207, 1008, 1207)

$logoImg = [System.Drawing.Image]::FromFile((Resolve-Path $Logo))
$logoSize = 58
$logoRect = New-Object System.Drawing.Rectangle(72, 1231, $logoSize, $logoSize)
$g.DrawImage($logoImg, $logoRect)

$footerFont = New-Object System.Drawing.Font($fontFamily, 23, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$footerRect = New-Object System.Drawing.RectangleF(151, 1242, 600, 42)
$g.DrawString("onedaytrading.net | $marketLabel", $footerFont, $white, $footerRect)

$disclaimerFont = New-Object System.Drawing.Font($fontFamily, 16, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$disclaimerFormat = New-Object System.Drawing.StringFormat
$disclaimerFormat.Alignment = [System.Drawing.StringAlignment]::Far
$disclaimerRect = New-Object System.Drawing.RectangleF(730, 1248, 278, 30)
$g.DrawString("투자 참고용 · 매매 권유 아님", $disclaimerFont, $muted, $disclaimerRect, $disclaimerFormat)

if ($PageNumber) {
    $pageFont = New-Object System.Drawing.Font($fontFamily, 18, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $pageRect = New-Object System.Drawing.RectangleF(830, 1209, 178, 28)
    $g.DrawString($PageNumber, $pageFont, $muted, $pageRect, $disclaimerFormat)
}

$outputDir = Split-Path -Parent $Output
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$canvas.Save([System.IO.Path]::GetFullPath($Output), [System.Drawing.Imaging.ImageFormat]::Png)

if ($pageFont) { $pageFont.Dispose() }
$disclaimerFont.Dispose(); $footerFont.Dispose(); $logoImg.Dispose()
$rulePen.Dispose(); $ctaFont.Dispose(); $ctaFormat.Dispose()
$headlineFormat.Dispose(); $chipFmt.Dispose(); $chipPen.Dispose(); $labelFont.Dispose()
$white.Dispose(); $muted.Dispose(); $cyan.Dispose(); $red.Dispose()
$topBrush.Dispose(); $bottomBrush.Dispose(); $bg.Dispose(); $g.Dispose(); $canvas.Dispose()

Write-Output (Resolve-Path $Output)
