param(
    [Parameter(Mandatory=$true)][string]$Subtitle,
    [Parameter(Mandatory=$true)][string[]]$Terms,
    [string]$PersonName = '',
    [switch]$RequirePersonVoice,
    [ValidateRange(8,30)][int]$ClipSeconds = 12,
    [ValidateRange(0,3600)][int]$MinimumStartSeconds = 20,
    [string]$Output = 'output/context-clip-selection.json'
)

$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $Subtitle)){throw "Subtitle not found: $Subtitle"}
function ToSeconds([string]$Value){$parts=$Value.Trim().Split(':');return ([int]$parts[0]*3600)+([int]$parts[1]*60)+[double]$parts[2]}
function ToTimestamp([double]$Seconds){return ('{0:00}:{1:00}:{2:00}' -f [math]::Floor($Seconds/3600),[math]::Floor(($Seconds%3600)/60),[math]::Floor($Seconds%60))}

$terms=@($Terms|ForEach-Object{$_ -split '\s*,\s*'}|Where-Object{$_}|Select-Object -Unique)
$personTokens=@($PersonName -split '\s+' | Where-Object { $_.Length -ge 3 })
$lines=Get-Content -LiteralPath $Subtitle
$cues=@()
for($index=0;$index -lt $lines.Count;$index++){
    if($lines[$index] -match '^(\d{2}:\d{2}:\d{2}\.\d+)\s+-->\s+(\d{2}:\d{2}:\d{2}\.\d+)'){
        $start=ToSeconds $matches[1];$end=ToSeconds $matches[2];$text=''
        for($next=$index+1;$next -lt $lines.Count -and $lines[$next] -notmatch '^\d{2}:\d{2}:\d{2}\.\d+\s+-->';$next++){$text+=' '+$lines[$next]}
        $clean=([regex]::Replace($text,'<[^>]+>',' ') -replace '\s+',' ').Trim()
        if($start -ge $MinimumStartSeconds -and $clean){
            $hits=@($terms|Where-Object{$clean.ToLowerInvariant().Contains($_.ToLowerInvariant())})
            $selfIntro=$false
            if($personTokens.Count -gt 0){
                $namePattern=($personTokens|ForEach-Object{[regex]::Escape($_)}) -join '\s+'
                $selfIntro=($clean -match "(?i)\b(?:i(?:'m| am)|my name is)\s+(?:[a-z.'-]+\s+){0,2}$namePattern\b")
            }
            $hostIntroduction=($clean -match '(?i)\b(?:thank you|with us today|let.s talk|welcome|chairman of|interview with|joined by)\b')
            $score=$hits.Count + $(if($selfIntro){20}else{0}) - $(if($hostIntroduction){12}else{0})
            $cues += [pscustomobject]@{start=$start;end=$end;text=$clean;matches=$hits;self_introduction=$selfIntro;host_introduction=$hostIntroduction;score=$score}
        }
    }
}
if(-not $cues){throw 'No usable subtitle cues found.'}
$eligible=$cues
if($RequirePersonVoice){$eligible=@($cues|Where-Object{$_.self_introduction});if(-not $eligible){throw "No self-identification cue found for '$PersonName'. Reject this source rather than using a host or another person."}}
$best=@($eligible|Sort-Object @{Expression='score';Descending=$true},@{Expression='start';Descending=$false}|Select-Object -First 1)
$strategy=if($best.self_introduction){'person_self_identification'}elseif($best.score -gt 0){'keyword_match'}else{'opening_context_fallback'}
$selection=[ordered]@{subtitle=[IO.Path]::GetFullPath($Subtitle);terms=$terms;person_name=$PersonName;strategy=$strategy;clip_start=ToTimestamp $best.start;clip_end=ToTimestamp ($best.start+$ClipSeconds);matched_terms=$best.matches;self_introduction=$best.self_introduction;host_introduction=$best.host_introduction;cue_text=$best.text;review_status='needs_clip_review';created_at=(Get-Date).ToUniversalTime().ToString('o')}
$outputPath=[IO.Path]::GetFullPath($Output);New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outputPath)|Out-Null;$selection|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $outputPath -Encoding UTF8
Write-Output $outputPath
