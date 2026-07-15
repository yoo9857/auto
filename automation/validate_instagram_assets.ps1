param([Parameter(Mandatory=$true)][string]$Paths)

$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$items=@($Paths -split '\|' | Where-Object {$_})
if($items.Count -lt 2 -or $items.Count -gt 10){throw 'Instagram 캐러셀은 2~10개 파일만 지원합니다.'}
foreach($path in $items){
    if(-not(Test-Path -LiteralPath $path)){throw "파일을 찾지 못했습니다: $path"}
    $extension=[IO.Path]::GetExtension($path).ToLowerInvariant()
    if($extension -in @('.png','.jpg','.jpeg','.webp')){
        $image=[Drawing.Image]::FromFile((Resolve-Path -LiteralPath $path))
        try {$width=$image.Width;$height=$image.Height}finally{$image.Dispose()}
    } elseif($extension -in @('.mp4','.mov')) {
        $shell=New-Object -ComObject Shell.Application
        $folder=$shell.Namespace((Split-Path -Parent (Resolve-Path -LiteralPath $path)))
        $item=$folder.ParseName((Split-Path -Leaf $path))
        $width=[int]$item.ExtendedProperty('System.Video.FrameWidth')
        $height=[int]$item.ExtendedProperty('System.Video.FrameHeight')
    } else {throw "지원하지 않는 파일 형식: $extension"}
    if($width -le 0 -or $height -le 0){throw "해상도를 확인할 수 없습니다: $path"}
    $ratio=[Math]::Round($width/[double]$height,4)
    if([Math]::Abs($ratio-0.8) -gt 0.005){throw "4:5가 아닌 파일은 자동 게시를 중단합니다: $path ($width x $height)"}
    Write-Output "PASS $([IO.Path]::GetFileName($path)): ${width}x${height} (4:5)"
}
