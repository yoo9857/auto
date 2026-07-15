param(
    [Parameter(Mandatory=$true)][string]$JobPath,
    [ValidateSet('match','random','fixed')][string]$Mode = 'match'
)

$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$job=Get-Content -Raw -Encoding UTF8 $JobPath | ConvertFrom-Json

$palettes=@(
    [ordered]@{name='electric-blue';background='#030910';surface='#21070F';primary='#49BEF7';secondary='#E8303E'},
    [ordered]@{name='violet-signal';background='#080713';surface='#24102F';primary='#9C7CFF';secondary='#FF496C'},
    [ordered]@{name='emerald-terminal';background='#03100E';surface='#102A25';primary='#35D6AE';secondary='#FF6B4A'},
    [ordered]@{name='amber-market';background='#100B04';surface='#30200C';primary='#FFB547';secondary='#F0445A'},
    [ordered]@{name='cobalt-lime';background='#050B16';surface='#102747';primary='#4F8CFF';secondary='#B7E34B'}
)

function Get-StableIndex([string]$text,[int]$count) {
    $bytes=[Text.Encoding]::UTF8.GetBytes($text)
    $hash=([Security.Cryptography.SHA256]::Create()).ComputeHash($bytes)
    return [BitConverter]::ToUInt32($hash,0) % $count
}
function Get-ImageHue([string]$path) {
    $img=[Drawing.Bitmap]::FromFile((Resolve-Path -LiteralPath $path))
    try {
        $sin=0.0; $cos=0.0; $weight=0.0
        $stepX=[Math]::Max(1,[int]($img.Width/28)); $stepY=[Math]::Max(1,[int]($img.Height/28))
        for($y=0;$y -lt $img.Height;$y+=$stepY){ for($x=0;$x -lt $img.Width;$x+=$stepX){
            $c=$img.GetPixel($x,$y); $s=$c.GetSaturation(); $b=$c.GetBrightness()
            if($s -gt .16 -and $b -gt .08 -and $b -lt .92){$r=$c.GetHue()*[Math]::PI/180; $w=$s*(.35+$b); $sin+=[Math]::Sin($r)*$w; $cos+=[Math]::Cos($r)*$w; $weight+=$w}
        }}
        if($weight -eq 0){return 210.0}
        $h=[Math]::Atan2($sin,$cos)*180/[Math]::PI; if($h -lt 0){$h+=360}; return $h
    } finally {$img.Dispose()}
}

if($Mode -eq 'fixed' -and $job.visual.palette -and $job.visual.palette.primary){$selected=$job.visual.palette}
elseif($Mode -eq 'random'){$selected=$palettes[(Get-StableIndex ([string]$job.article.article_id) $palettes.Count)]}
else {
    $hue=Get-ImageHue ([string]$job.visual.background_path)
    $targets=@(205,275,160,38,220); $best=0; $distance=999
    for($i=0;$i -lt $targets.Count;$i++){$d=[Math]::Abs($hue-$targets[$i]); $d=[Math]::Min($d,360-$d); if($d -lt $distance){$distance=$d;$best=$i}}
    $selected=$palettes[$best]
}
$palette=[ordered]@{mode=$Mode;name=$selected.name;background=$selected.background;surface=$selected.surface;primary=$selected.primary;secondary=$selected.secondary}
if($job.visual.PSObject.Properties['palette']){$job.visual.palette=$palette}else{$job.visual | Add-Member -NotePropertyName palette -NotePropertyValue $palette}
$job | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 $JobPath
Write-Output ("팔레트: {0} ({1})" -f $palette.name,$Mode)
