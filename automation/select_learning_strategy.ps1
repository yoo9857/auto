param([Parameter(Mandatory=$true)][string]$JobPath)

$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$design=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'learning.design.json') | ConvertFrom-Json
$job=Get-Content -Raw -Encoding UTF8 $JobPath | ConvertFrom-Json
$feedbackPath=Join-Path $root $design.selection.feedback_store
$records=@()
if(Test-Path $feedbackPath){$records=@(Get-Content -Encoding UTF8 $feedbackPath | Where-Object {$_} | ForEach-Object {$_ | ConvertFrom-Json})}

function Get-SeedNumber([string]$seed,[string]$group,[int]$offset){
    $bytes=[Text.Encoding]::UTF8.GetBytes("$seed/$group/$offset")
    $hash=([Security.Cryptography.SHA256]::Create()).ComputeHash($bytes)
    return [BitConverter]::ToUInt16($hash,0)
}
function Pick-Strategy($groupName,$groupConfig,[string]$seed){
    $items=@($groupConfig.candidates)
    $ranked=@()
    foreach($item in $items){
        $hits=@($records | Where-Object {$_.strategy.$groupName -eq $item.id -and -not $_.blocked_from_learning})
        $average=if($hits.Count){($hits | Measure-Object -Property reward -Average).Average}else{[double]$design.selection.cold_start_score}
        $confidence=[Math]::Min(1.0,$hits.Count/[double]$design.selection.minimum_samples_before_ranking)
        $score=($average*$confidence)+([double]$design.selection.cold_start_score*(1-$confidence))
        $ranked+=,[pscustomobject]@{item=$item;samples=$hits.Count;score=[Math]::Round($score,4)}
    }
    $roll=(Get-SeedNumber $seed $groupName 0)/65535.0
    if($roll -lt [double]$design.selection.exploration_rate){
        $index=(Get-SeedNumber $seed $groupName 1)%$items.Count
        return [pscustomobject]@{selected=$items[$index];reason='explore';ranking=$ranked}
    }
    $best=$ranked|Sort-Object -Property @{Expression='score';Descending=$true},@{Expression='samples';Descending=$true}|Select-Object -First 1
    return [pscustomobject]@{selected=$best.item;reason='best_score';ranking=$ranked}
}

$strategies=[ordered]@{};$instructions=[ordered]@{};$reasons=[ordered]@{}
foreach($property in $design.strategy_groups.PSObject.Properties){
    $choice=Pick-Strategy $property.Name $property.Value ([string]$job.article.article_id)
    $strategies[$property.Name]=$choice.selected.id
    $instructions[$property.Name]=$choice.selected.instruction
    $reasons[$property.Name]=$choice.reason
}
$learning=[ordered]@{design_version=$design.schema_version;selected_at=(Get-Date).ToUniversalTime().ToString('o');strategies=$strategies;instructions=$instructions;selection_reason=$reasons;feedback_samples=$records.Count;principles=$design.principles;guardrails=$design.guardrails}
if($job.PSObject.Properties['learning']){$job.learning=$learning}else{$job|Add-Member -NotePropertyName learning -NotePropertyValue $learning}
$job|ConvertTo-Json -Depth 30|Set-Content -Encoding UTF8 $JobPath
$learning|ConvertTo-Json -Depth 20
