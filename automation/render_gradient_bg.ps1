param(
    [Parameter(Mandatory=$true)][string]$JobPath,
    [string]$Output = ""
)
# Non-generative fallback background: a clean, text-free editorial gradient
# derived from the job palette. Used when a generative image provider is
# unavailable (e.g. OpenAI billing limit, no Gemini key).
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$job = Get-Content -Raw -Encoding UTF8 $JobPath | ConvertFrom-Json
if (-not $Output) { $Output = Join-Path (Split-Path -Parent $JobPath) "background-gradient.png" }

function Hex([string]$key,[string]$fallback) {
    if ($job.visual.palette -and $job.visual.palette.$key) { return [Drawing.ColorTranslator]::FromHtml([string]$job.visual.palette.$key) }
    return [Drawing.ColorTranslator]::FromHtml($fallback)
}
$base    = Hex 'background' '#050B16'
$surface = Hex 'surface'    '#102747'
$primary = Hex 'primary'    '#4F8CFF'

$w = 1080; $h = 1350
$bmp = New-Object System.Drawing.Bitmap($w, $h)
$bmp.SetResolution(144,144)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

# Diagonal base gradient: surface (top-right) -> base (bottom-left)
$rect = New-Object System.Drawing.Rectangle(0,0,$w,$h)
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $surface, $base, 45.0)
$g.FillRectangle($grad, $rect)

# Soft radial glow of the primary color, lower-right (editorial accent), text-free
$glow = New-Object System.Drawing.Drawing2D.GraphicsPath
$glow.AddEllipse(560, 760, 900, 900)
$pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush($glow)
$pgb.CenterColor = [System.Drawing.Color]::FromArgb(120, $primary.R, $primary.G, $primary.B)
$pgb.SurroundColors = @([System.Drawing.Color]::FromArgb(0, $primary.R, $primary.G, $primary.B))
$g.FillRectangle($pgb, $rect)

# Top-left darkening so the headline area stays clean and high-contrast
$dark = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point(0,0)), (New-Object System.Drawing.Point([int]($w*0.9),[int]($h*0.55))),
    [System.Drawing.Color]::FromArgb(190,0,0,0), [System.Drawing.Color]::FromArgb(0,0,0,0))
$g.FillRectangle($dark, $rect)

# Bottom scrim for footer legibility
$foot = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point(0,[int]($h*0.6))), (New-Object System.Drawing.Point(0,$h)),
    [System.Drawing.Color]::FromArgb(0,0,0,0), [System.Drawing.Color]::FromArgb(150,0,0,0))
$g.FillRectangle($foot, (New-Object System.Drawing.Rectangle(0,[int]($h*0.6),$w,[int]($h*0.4))))

$g.Dispose()
$bmp.Save($Output, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output $Output
