param(
    [string]$Output = "output/page-02-visual-wireframe.png",
    [string]$Logo = "NEWLOGO.png"
)

Add-Type -AssemblyName System.Drawing
$w=1080; $h=1350; $bmp=New-Object Drawing.Bitmap($w,$h); $bmp.SetResolution(144,144)
$g=[Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::HighQuality; $g.TextRenderingHint=[Drawing.Text.TextRenderingHint]::AntiAliasGridFit
function Color($hex){[Drawing.ColorTranslator]::FromHtml($hex)}
function Text($value,$font,$brush,$x,$y){$g.DrawString($value,$font,$brush,$x,$y)}

$paper=New-Object Drawing.SolidBrush (Color '#F7F8FA'); $ink=New-Object Drawing.SolidBrush (Color '#101114'); $blue=New-Object Drawing.SolidBrush (Color '#325CFF'); $muted=New-Object Drawing.SolidBrush (Color '#687080'); $white=New-Object Drawing.SolidBrush ([Drawing.Color]::White)
$line=New-Object Drawing.Pen ((Color '#DCE0E7'),2); $g.FillRectangle($paper,0,0,$w,$h)
$small=New-Object Drawing.Font('Noto Sans KR',18,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel); $meta=New-Object Drawing.Font('Noto Sans KR',17,[Drawing.FontStyle]::Regular,[Drawing.GraphicsUnit]::Pixel); $title=New-Object Drawing.Font('Noto Sans KR Black',56,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel); $body=New-Object Drawing.Font('Noto Sans KR',26,[Drawing.FontStyle]::Regular,[Drawing.GraphicsUnit]::Pixel); $footer=New-Object Drawing.Font('Noto Sans KR',22,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel)

Text 'VISUAL SIGNAL / 02' $small $blue 72 48; Text 'ONE IMAGE / ONE POINT' $meta $muted 790 50

# Image field: a single focused visual, never a collage or a text-heavy screenshot.
$field=New-Object Drawing.Rectangle(72,96,936,516); $g.FillRectangle((New-Object Drawing.SolidBrush (Color '#1C2230')),$field)
$halo=New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(210,50,92,255)); $g.FillEllipse($halo,650,144,245,245)
$subject=New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(255,225,231,244)); $g.FillEllipse($subject,390,168,270,270); $g.FillRectangle($subject,458,408,134,152)
$safePen=New-Object Drawing.Pen ([Drawing.Color]::FromArgb(150,255,255,255),2); $safePen.DashStyle=[Drawing.Drawing2D.DashStyle]::Dash; $g.DrawRectangle($safePen,108,132,560,408)
$tag=New-Object Drawing.Rectangle(96,120,165,42); $g.FillRectangle($blue,$tag); Text 'IMAGE FIELD' $small $white 113 129
Text 'ONE SUBJECT / CLEAN CROP / NO EMBEDDED TEXT' $meta $white 96 570
Text 'SAFE AREA FOR SUBJECT' $meta $white 123 150

$g.DrawLine($line,72,654,1008,654); Text 'OUR EDITORIAL TAKE' $small $blue 72 688
Text 'A headline that explains' $title $ink 72 736; Text 'why this image matters' $title $ink 72 810
Text 'FACT IN THE IMAGE' $small $muted 72 914
Text 'The image supports one confirmed fact from the source.' $body $ink 72 948
$take=New-Object Drawing.Rectangle(72,1040,936,102); $g.FillRectangle($blue,$take)
Text 'OUR TAKE' $small $white 96 1063
$takeFont=New-Object Drawing.Font('Noto Sans KR',23,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel)
Text 'Our interpretation turns the fact into a useful point of view.' $takeFont $white 250 1058

$g.DrawLine($line,72,1207,1008,1207); $logoImg=[Drawing.Image]::FromFile((Resolve-Path $Logo)); $g.DrawImage($logoImg,(New-Object Drawing.Rectangle(72,1231,58,58)))
Text 'NEWS SIGNAL / CONTEXT / JUDGMENT' $footer $ink 151 1242
$right=New-Object Drawing.StringFormat; $right.Alignment=[Drawing.StringAlignment]::Far; $g.DrawString('02 / 04',$footer,$muted,(New-Object Drawing.RectangleF(830,1242,178,34)),$right)

$dir=Split-Path -Parent $Output; New-Item -ItemType Directory -Force -Path $dir | Out-Null; $bmp.Save((Join-Path (Get-Location) $Output),[Drawing.Imaging.ImageFormat]::Png)
$right.Dispose();$logoImg.Dispose();$takeFont.Dispose();$safePen.Dispose();$subject.Dispose();$halo.Dispose();$footer.Dispose();$body.Dispose();$title.Dispose();$meta.Dispose();$small.Dispose();$line.Dispose();$white.Dispose();$muted.Dispose();$blue.Dispose();$ink.Dispose();$paper.Dispose();$g.Dispose();$bmp.Dispose()
Write-Output (Resolve-Path $Output)
