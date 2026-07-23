param(
    [string]$JobPath = "",
    [string]$Background = "assets/backgrounds/far-cry-steve-buscemi.png",
    [string]$Logo = "NEWLOGO.png",
    [string]$Output = "output/far-cry-steve-buscemi-card-03-evaluation.png",
    [string]$PageNumber = "03 / 04"
)

Add-Type -AssemblyName System.Drawing
$evaluation="제한적 호재"; $evaluationHeadline="지금 평가는`n'제한적 호재'"
$evaluationSummary="방향은 긍정적이지만 아직 숫자가 없다. 평가는 아래 세 가지가 확인될 때 달라진다."
$expect="원작 게임의 재노출"; $verify="공개 플랫폼과 수익 구조"; $judge="방영 후 구작 판매량 변화"
$analysisParagraphs=@("예시 근거 1","예시 근거 2","예시 근거 3"); $memoryLine="시청률보다 중요한 숫자는 파크라이의 판매량이다."
$category="게임"; $marketLabel="해외주식"
if ($JobPath) {
    $job=Get-Content -Raw -Encoding UTF8 $JobPath | ConvertFrom-Json
    if ($job.visual.background_path) { $Background=$job.visual.background_path }
    $evaluation=$job.pages.page3.evaluation; $evaluationHeadline=$job.pages.page3.evaluation_headline
    $evaluationSummary=$job.pages.page3.evaluation_summary; $expect=$job.pages.page3.expect
    $verify=$job.pages.page3.verify; $judge=$job.pages.page3.judge
    $analysisParagraphs=$job.pages.page3.paragraphs; $memoryLine=$job.pages.page3.memory_line
    $category=$job.article.category; $marketLabel=$job.article.market_label
}
function Palette-Color([string]$key,[string]$fallback){if($job -and $job.visual.palette -and $job.visual.palette.$key){return [Drawing.ColorTranslator]::FromHtml([string]$job.visual.palette.$key)}; return [Drawing.ColorTranslator]::FromHtml($fallback)}
$baseColor=Palette-Color 'background' '#030910'; $surfaceColor=Palette-Color 'surface' '#80161B'; $primaryColor=Palette-Color 'primary' '#49BEF7'
$w=1080; $h=1350
$bmp=New-Object System.Drawing.Bitmap($w,$h)
$bmp.SetResolution(144,144)
$g=[System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.TextRenderingHint=[System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

$bg=[System.Drawing.Image]::FromFile((Resolve-Path $Background))
$g.DrawImage($bg,(New-Object System.Drawing.Rectangle(0,0,$w,$h)))
$shade=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(224,$baseColor.R,$baseColor.G,$baseColor.B))
$g.FillRectangle($shade,0,0,$w,$h)
$redGlow=New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Rectangle(690,0,390,$h)),
    ([System.Drawing.Color]::FromArgb(0,$surfaceColor.R,$surfaceColor.G,$surfaceColor.B)),
    ([System.Drawing.Color]::FromArgb(92,$surfaceColor.R,$surfaceColor.G,$surfaceColor.B)),
    [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal)
$g.FillRectangle($redGlow,690,0,390,$h)

$family="Noto Sans KR"; $blackFamily="Noto Sans KR Black"
$white=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$body=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(235,220,226,232))
$muted=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(190,172,184,196))
$blue=New-Object System.Drawing.SolidBrush($primaryColor)
$labelBg=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(215,$primaryColor.R,$primaryColor.G,$primaryColor.B))
$border=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(62,255,255,255),1)
$fmt=New-Object System.Drawing.StringFormat
$fmt.Alignment=[System.Drawing.StringAlignment]::Near
$fmt.LineAlignment=[System.Drawing.StringAlignment]::Near
$fmt.Trimming=[System.Drawing.StringTrimming]::Word

$eyebrowFont=New-Object System.Drawing.Font($family,20,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
$titleFont=New-Object System.Drawing.Font($blackFamily,58,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
$labelFont=New-Object System.Drawing.Font($family,20,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
$summaryFont=New-Object System.Drawing.Font($family,25,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
$articleFont=New-Object System.Drawing.Font($family,29,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
$footerFont=New-Object System.Drawing.Font($family,22,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
$smallFont=New-Object System.Drawing.Font($family,16,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)

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

$g.DrawString("투자 판단",$eyebrowFont,$blue,72,60)
$titleRect=New-Object System.Drawing.RectangleF(72,108,890,174)
$g.DrawString($evaluationHeadline,$titleFont,$white,$titleRect,$fmt)
$g.FillRectangle($blue,72,281,104,7)

$labelRect=New-Object System.Drawing.Rectangle(72,320,152,46)
$g.FillRectangle($labelBg,$labelRect)
$center=New-Object System.Drawing.StringFormat
$center.Alignment=[System.Drawing.StringAlignment]::Center
$center.LineAlignment=[System.Drawing.StringAlignment]::Center
$g.DrawString($evaluation,$labelFont,$white,(New-Object System.Drawing.RectangleF(72,320,152,46)),$center)

$summaryRect=New-Object System.Drawing.RectangleF(246,317,748,88)
$summary=$evaluationSummary
$g.DrawString($summary,$summaryFont,$body,$summaryRect,$fmt)

$bylineFont=New-Object System.Drawing.Font($family,17,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
$g.DrawString("ONEDAYTRADING 편집팀  |  $category·$marketLabel",$bylineFont,$muted,72,431)
$g.DrawLine($border,72,474,1008,474)

# 기대/확인/판단 — designed tag rows (accent ghost tag + value).
function RR([single]$x,[single]$y,[single]$w,[single]$h,[single]$r){$d=$r*2;$p=New-Object System.Drawing.Drawing2D.GraphicsPath;$p.AddArc($x,$y,$d,$d,180,90);$p.AddArc($x+$w-$d,$y,$d,$d,270,90);$p.AddArc($x+$w-$d,$y+$h-$d,$d,$d,0,90);$p.AddArc($x,$y+$h-$d,$d,$d,90,90);$p.CloseFigure();return $p}
$rowsY=520;$rowH=62;$tagW=92;$tagH=44
$tagFont=New-Object System.Drawing.Font($family,21,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
$valFont=New-Object System.Drawing.Font($family,28,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
$tagFill=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(36,$primaryColor.R,$primaryColor.G,$primaryColor.B))
$tagPen=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(150,$primaryColor.R,$primaryColor.G,$primaryColor.B),1.4)
$midFmt=New-Object System.Drawing.StringFormat;$midFmt.Alignment=[System.Drawing.StringAlignment]::Center;$midFmt.LineAlignment=[System.Drawing.StringAlignment]::Center
$leftMid=New-Object System.Drawing.StringFormat;$leftMid.LineAlignment=[System.Drawing.StringAlignment]::Center;$leftMid.Trimming=[System.Drawing.StringTrimming]::EllipsisWord;$leftMid.FormatFlags=[System.Drawing.StringFormatFlags]::NoWrap
$rows=@(@('기대',$expect),@('확인',$verify),@('판단',$judge))
for($i=0;$i -lt 3;$i++){
    $ry=$rowsY+$i*$rowH
    $tag=RR 76 $ry $tagW $tagH 12
    $g.FillPath($tagFill,$tag);$g.DrawPath($tagPen,$tag)
    $g.DrawString($rows[$i][0],$tagFont,$blue,(New-Object System.Drawing.RectangleF(76,$ry,$tagW,$tagH)),$midFmt)
    $g.DrawString($rows[$i][1],$valFont,$white,(New-Object System.Drawing.RectangleF(190,$ry,818,$tagH)),$leftMid)
}
$rowsBottom=$rowsY+3*$rowH+14
$g.DrawLine($border,72,$rowsBottom,1008,$rowsBottom)
$paraRect=New-Object System.Drawing.RectangleF(76,($rowsBottom+24),902,(1122-($rowsBottom+24)))
Draw-FitText $g ($analysisParagraphs -join "`n`n") $family 28 18 ([System.Drawing.FontStyle]::Regular) $body $paraRect $fmt

$g.DrawLine($border,72,1145,1008,1145)
$closingFont=New-Object System.Drawing.Font($family,19,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
$g.DrawString($memoryLine,$closingFont,$blue,76,1162)

$g.DrawLine($border,72,1207,1008,1207)
$logoImg=[System.Drawing.Image]::FromFile((Resolve-Path $Logo))
$g.DrawImage($logoImg,(New-Object System.Drawing.Rectangle(72,1231,58,58)))
$g.DrawString("onedaytrading.net | $marketLabel",$footerFont,$white,151,1242)
$right=New-Object System.Drawing.StringFormat
$right.Alignment=[System.Drawing.StringAlignment]::Far
$g.DrawString($PageNumber,$footerFont,$muted,(New-Object System.Drawing.RectangleF(830,1242,178,34)),$right)
$g.DrawString("투자 참고용 · 매매 권유 아님",$smallFont,$muted,(New-Object System.Drawing.RectangleF(700,1276,308,28)),$right)

$dir=Split-Path -Parent $Output
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$bmp.Save([System.IO.Path]::GetFullPath($Output),[System.Drawing.Imaging.ImageFormat]::Png)

$right.Dispose(); $logoImg.Dispose(); $closingFont.Dispose(); $bylineFont.Dispose()
$smallFont.Dispose(); $footerFont.Dispose(); $articleFont.Dispose(); $summaryFont.Dispose()
$labelFont.Dispose(); $titleFont.Dispose(); $eyebrowFont.Dispose(); $center.Dispose(); $fmt.Dispose()
$border.Dispose(); $labelBg.Dispose(); $blue.Dispose(); $muted.Dispose(); $body.Dispose(); $white.Dispose()
$redGlow.Dispose(); $shade.Dispose(); $bg.Dispose(); $g.Dispose(); $bmp.Dispose()
Write-Output (Resolve-Path $Output)
