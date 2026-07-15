param(
    [string]$Output = "output/page-02-evidence-wireframe.png",
    [string]$Logo = "NEWLOGO.png",
    [string]$SourceLabel = "SOURCE: VERIFY BEFORE POSTING",
    [string]$Headline = "A clear editorial headline`nfits in two lines",
    [string]$Fact = "One verified fact taken directly from the source video.",
    [string]$Take = "Our interpretation gives the viewer a reason to keep reading.",
    [string]$Page = "02 / 04"
)

Add-Type -AssemblyName System.Drawing
$w=1080; $h=1350
$bmp=New-Object System.Drawing.Bitmap($w,$h); $bmp.SetResolution(144,144)
$g=[System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.TextRenderingHint=[Drawing.Text.TextRenderingHint]::AntiAliasGridFit

function Draw-FitText($Text,$Family,$MaxSize,$MinSize,$Style,$Brush,$Rect,$Format) {
    for($size=$MaxSize;$size -ge $MinSize;$size-=2) {
        $font=New-Object Drawing.Font($Family,$size,$Style,[Drawing.GraphicsUnit]::Pixel)
        $measure=$g.MeasureString($Text,$font,$Rect.Size,$Format)
        if($measure.Height -le $Rect.Height -and $measure.Width -le $Rect.Width) { $g.DrawString($Text,$font,$Brush,$Rect,$Format); $font.Dispose(); return }
        $font.Dispose()
    }
    throw "Text does not fit: $Text"
}

$black=[Drawing.ColorTranslator]::FromHtml('#101114'); $blue=[Drawing.ColorTranslator]::FromHtml('#325CFF'); $line=[Drawing.ColorTranslator]::FromHtml('#DCE0E7')
$white=New-Object Drawing.SolidBrush([Drawing.Color]::White); $ink=New-Object Drawing.SolidBrush($black)
$muted=New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml('#6D7480')); $blueBrush=New-Object Drawing.SolidBrush($blue)
$canvasBrush=New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml('#F7F8FA')); $linePen=New-Object Drawing.Pen($line,2)
$g.FillRectangle($canvasBrush,0,0,$w,$h)

$fmt=New-Object Drawing.StringFormat; $fmt.Trimming=[Drawing.StringTrimming]::EllipsisWord
$bold=New-Object Drawing.Font('Noto Sans KR',20,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel)
$small=New-Object Drawing.Font('Noto Sans KR',18,[Drawing.FontStyle]::Regular,[Drawing.GraphicsUnit]::Pixel)
$g.DrawString('EVIDENCE / 02',$bold,$blueBrush,72,48)
$g.DrawString('VIDEO + EDITORIAL',$small,$muted,765,50)

# Video zone: actual footage is inserted here later without changing any text coordinates.
$videoRect=New-Object Drawing.Rectangle(72,96,936,552)
$videoBrush=New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(255,24,29,40))
$g.FillRectangle($videoBrush,$videoRect)
$g.DrawRectangle((New-Object Drawing.Pen([Drawing.Color]::FromArgb(90,255,255,255),2)),$videoRect)
$pill=New-Object Drawing.Rectangle(96,120,205,42); $g.FillRectangle($blueBrush,$pill)
$pillFont=New-Object Drawing.Font('Noto Sans KR',17,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel)
$g.DrawString('SOURCE VIDEO',$pillFont,$white,113,129)
$g.DrawString($SourceLabel,$small,(New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(205,255,255,255))),96,595)
$play=[Drawing.Point[]]@((New-Object Drawing.Point(492,300)),(New-Object Drawing.Point(492,420)),(New-Object Drawing.Point(600,360)))
$g.FillPolygon($white,$play)
$safe=New-Object Drawing.Rectangle(777,560,207,58); $g.FillRectangle((New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(190,0,0,0))),$safe)
$safeFont=New-Object Drawing.Font('Noto Sans KR',15,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel)
$g.DrawString('7-12 SECOND CLIP',$safeFont,$white,797,579)

$ruleY=684; $g.DrawLine($linePen,72,$ruleY,1008,$ruleY)
$eyebrow=New-Object Drawing.Font('Noto Sans KR',18,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel)
$g.DrawString('OUR TAKE',$eyebrow,$blueBrush,72,718)
$titleRect=New-Object Drawing.RectangleF(72,758,910,144)
Draw-FitText $Headline 'Noto Sans KR Black' 57 42 ([Drawing.FontStyle]::Bold) $ink $titleRect $fmt

$factLabel=New-Object Drawing.Font('Noto Sans KR',18,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel)
$bodyFont=New-Object Drawing.Font('Noto Sans KR',27,[Drawing.FontStyle]::Regular,[Drawing.GraphicsUnit]::Pixel)
$g.DrawString('WHAT THE VIDEO SHOWS',$factLabel,$muted,72,944)
$g.DrawString($Fact,$bodyFont,$ink,(New-Object Drawing.RectangleF(72,976,900,60)),$fmt)
$takeRect=New-Object Drawing.Rectangle(72,1064,936,92); $g.FillRectangle($blueBrush,$takeRect)
$g.DrawString('OUR TAKE',$factLabel,$white,96,1084)
$takeText=New-Object Drawing.Font('Noto Sans KR',23,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel)
$g.DrawString($Take,$takeText,$white,(New-Object Drawing.RectangleF(245,1080,725,48)),$fmt)

$g.DrawLine($linePen,72,1207,1008,1207)
$logoImg=[Drawing.Image]::FromFile((Resolve-Path $Logo)); $g.DrawImage($logoImg,(New-Object Drawing.Rectangle(72,1231,58,58)))
$footer=New-Object Drawing.Font('Noto Sans KR',22,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel)
$g.DrawString('NEWS SIGNAL / CONTEXT / JUDGMENT',$footer,$ink,151,1242)
$right=New-Object Drawing.StringFormat; $right.Alignment=[Drawing.StringAlignment]::Far
$g.DrawString($Page,$footer,$muted,(New-Object Drawing.RectangleF(830,1242,178,34)),$right)

$dir=Split-Path -Parent $Output; New-Item -ItemType Directory -Force -Path $dir | Out-Null
$bmp.Save((Join-Path (Get-Location) $Output),[Drawing.Imaging.ImageFormat]::Png)
$right.Dispose(); $footer.Dispose(); $logoImg.Dispose(); $takeText.Dispose(); $bodyFont.Dispose(); $factLabel.Dispose(); $eyebrow.Dispose(); $safeFont.Dispose(); $pillFont.Dispose(); $small.Dispose(); $bold.Dispose(); $fmt.Dispose(); $videoBrush.Dispose(); $linePen.Dispose(); $canvasBrush.Dispose(); $blueBrush.Dispose(); $muted.Dispose(); $ink.Dispose(); $white.Dispose(); $g.Dispose(); $bmp.Dispose()
Write-Output (Resolve-Path $Output)
