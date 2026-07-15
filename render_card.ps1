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

$labelRect = New-Object System.Drawing.Rectangle(72, 68, 174, 50)
$g.FillRectangle($red, $labelRect)
$labelFont = New-Object System.Drawing.Font($fontFamily, 22, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$center = New-Object System.Drawing.StringFormat
$center.Alignment = [System.Drawing.StringAlignment]::Center
$center.LineAlignment = [System.Drawing.StringAlignment]::Center
$labelTextRect = New-Object System.Drawing.RectangleF(72, 68, 174, 50)
$g.DrawString($breakingLabel, $labelFont, $white, $labelTextRect, $center)

$headlineFormat = New-Object System.Drawing.StringFormat
$headlineFormat.Alignment = [System.Drawing.StringAlignment]::Near
$headlineFormat.LineAlignment = [System.Drawing.StringAlignment]::Near
$headlineFormat.Trimming = [System.Drawing.StringTrimming]::Word
$headlineFormat.FormatFlags = [System.Drawing.StringFormatFlags]::LineLimit

$titleRect = New-Object System.Drawing.RectangleF(72, 153, 790, 235)
Draw-FitText $g $headline $titleFontFamily 72 48 `
    ([System.Drawing.FontStyle]::Bold) $white $titleRect $headlineFormat

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
$headlineFormat.Dispose(); $center.Dispose(); $labelFont.Dispose()
$white.Dispose(); $muted.Dispose(); $cyan.Dispose(); $red.Dispose()
$topBrush.Dispose(); $bottomBrush.Dispose(); $bg.Dispose(); $g.Dispose(); $canvas.Dispose()

Write-Output (Resolve-Path $Output)
