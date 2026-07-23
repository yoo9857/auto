param(
    [string]$JobPath = "",
    [string]$Logo = "NEWLOGO.png",
    [string]$InstagramHandle = "@onedaytrading.io",
    [string]$Output = "output/onedaytrading-card-04-modern-brand.png",
    [string]$PageNumber = ""
)

Add-Type -AssemblyName System.Drawing
$palette=$null
if($JobPath){$job=Get-Content -Raw -Encoding UTF8 $JobPath | ConvertFrom-Json; $palette=$job.visual.palette}
function Palette-Color([string]$key,[string]$fallback){if($palette -and $palette.$key){return [Drawing.ColorTranslator]::FromHtml([string]$palette.$key)}; return [Drawing.ColorTranslator]::FromHtml($fallback)}
$baseColor=Palette-Color 'background' '#030910'; $surfaceColor=Palette-Color 'surface' '#21070F'
$primaryColor=Palette-Color 'primary' '#49BEF7'; $secondaryColor=Palette-Color 'secondary' '#E8303E'
$w=1080; $h=1350
$bmp=New-Object System.Drawing.Bitmap($w,$h)
$bmp.SetResolution(144,144)
$g=[System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.TextRenderingHint=[System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear($baseColor)

# Same visual temperature as page 1: midnight navy, faded red, electric-cyan accent.
$baseRect=New-Object System.Drawing.Rectangle(-2,-2,$($w+4),$($h+4))
$base=New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $baseRect,
    $baseColor,
    $surfaceColor,
    24)
$g.FillRectangle($base,$baseRect)

function Add-SoftGlow($graphics,$x,$y,$width,$height,$centerColor) {
    $path=New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse($x,$y,$width,$height)
    $brush=New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
    $brush.CenterColor=$centerColor
    $brush.SurroundColors=@([System.Drawing.Color]::FromArgb(0,3,9,16))
    $graphics.FillEllipse($brush,$x,$y,$width,$height)
    $brush.Dispose(); $path.Dispose()
}
Add-SoftGlow $g 520 -120 700 850 ([System.Drawing.Color]::FromArgb(85,155,30,38))
Add-SoftGlow $g -250 650 700 700 ([System.Drawing.Color]::FromArgb(42,35,153,211))

$white=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$body=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(232,218,226,234))
$muted=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(170,151,168,183))
$cyan=New-Object System.Drawing.SolidBrush($primaryColor)
$red=New-Object System.Drawing.SolidBrush($secondaryColor)

# Contrast helpers: keep labels/buttons readable on the dark canvas regardless of palette.
function Lum($c){ return (0.299*$c.R + 0.587*$c.G + 0.114*$c.B) }
function TextColorOn($c){ if((Lum $c) -gt 150){ return [System.Drawing.Color]::FromArgb(255,12,16,22) } else { return [System.Drawing.Color]::White } }
function BrightAccent($c){ $l=Lum $c; if($l -ge 155){ return $c }; $t=(155-$l)/(255.0-$l); return [System.Drawing.Color]::FromArgb(255,[int]($c.R+(255-$c.R)*$t),[int]($c.G+(255-$c.G)*$t),[int]($c.B+(255-$c.B)*$t)) }
$accentWarm=New-Object System.Drawing.SolidBrush((BrightAccent $secondaryColor))
$accentCool=New-Object System.Drawing.SolidBrush((BrightAccent $primaryColor))
$pillText=New-Object System.Drawing.SolidBrush((TextColorOn $secondaryColor))

function Fill-Pill($graphics,$brush,$x,$y,$width,$height) {
    $r=$height
    $graphics.FillRectangle($brush,$($x+$height/2),$y,$($width-$height),$height)
    $graphics.FillEllipse($brush,$x,$y,$r,$r)
    $graphics.FillEllipse($brush,$($x+$width-$r),$y,$r,$r)
}

$family="Noto Sans KR"; $blackFamily="Noto Sans KR Black"
$micro=New-Object System.Drawing.Font($family,17,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
$title=New-Object System.Drawing.Font($blackFamily,67,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
$lead=New-Object System.Drawing.Font($family,27,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
$handle=New-Object System.Drawing.Font($blackFamily,43,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
$site=New-Object System.Drawing.Font($blackFamily,37,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
$cta=New-Object System.Drawing.Font($family,21,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
$center=New-Object System.Drawing.StringFormat
$center.Alignment=[System.Drawing.StringAlignment]::Center
$center.LineAlignment=[System.Drawing.StringAlignment]::Center

# Move the complete content group toward the optical center of the 4:5 canvas.
$g.TranslateTransform(0,85)

$logoImg=[System.Drawing.Image]::FromFile((Resolve-Path $Logo))
$g.DrawImage($logoImg,(New-Object System.Drawing.Rectangle(502,120,76,76)))
$g.DrawString("onedaytrading.",$micro,$muted,(New-Object System.Drawing.RectangleF(340,202,400,28)),$center)

$g.DrawString("오늘의 뉴스가`n내일의 판단이 되도록.",$title,$white,(New-Object System.Drawing.RectangleF(90,256,900,188)),$center)
$g.FillRectangle($cyan,492,456,96,6)
$g.DrawString("시장에 흩어진 신호를 읽기 쉬운 맥락으로 정리합니다.",$lead,$body,(New-Object System.Drawing.RectangleF(120,485,840,48)),$center)

# Compact follow block without panel or border.
$g.DrawString("매일 핵심 뉴스 받기",$micro,$accentWarm,(New-Object System.Drawing.RectangleF(220,596,640,28)),$center)
$g.DrawString($InstagramHandle,$handle,$white,(New-Object System.Drawing.RectangleF(180,632,720,64)),$center)
Fill-Pill $g $red 390 710 300 54
$g.DrawString("팔로우하기  +",$cta,$pillText,(New-Object System.Drawing.RectangleF(390,710,300,54)),$center)

$g.DrawString("더 많은 뉴스와 자료",$micro,$accentCool,(New-Object System.Drawing.RectangleF(220,842,640,30)),$center)
$g.DrawString("onedaytrading.net",$site,$white,(New-Object System.Drawing.RectangleF(120,878,840,60)),$center)
$g.DrawString("증시 분석  ·  종목별 뉴스  ·  시장 자료",$cta,$body,(New-Object System.Drawing.RectangleF(180,939,720,34)),$center)
$g.DrawString("사이트에서 더 보기  ↗",$cta,$accentCool,(New-Object System.Drawing.RectangleF(340,982,400,40)),$center)


$dir=Split-Path -Parent $Output
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$g.ResetTransform()
if ($PageNumber) {
    $pageFont = New-Object System.Drawing.Font($family,22,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
    $pageFormat = New-Object System.Drawing.StringFormat
    $pageFormat.Alignment = [System.Drawing.StringAlignment]::Far
    $g.DrawString($PageNumber,$pageFont,$muted,(New-Object System.Drawing.RectangleF(830,1242,178,34)),$pageFormat)
    $pageFormat.Dispose(); $pageFont.Dispose()
}
$bmp.Save([System.IO.Path]::GetFullPath($Output),[System.Drawing.Imaging.ImageFormat]::Png)

$logoImg.Dispose(); $center.Dispose(); $cta.Dispose(); $site.Dispose(); $handle.Dispose()
$lead.Dispose(); $title.Dispose(); $micro.Dispose()
$red.Dispose(); $cyan.Dispose(); $accentWarm.Dispose(); $accentCool.Dispose(); $pillText.Dispose(); $muted.Dispose(); $body.Dispose(); $white.Dispose(); $base.Dispose()
$g.Dispose(); $bmp.Dispose()
Write-Output (Resolve-Path $Output)
