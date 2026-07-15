param(
    [Parameter(Mandatory=$true)][string]$JobPath,
    [Parameter(Mandatory=$true)][string]$FeedbackPath,
    [string]$InstagramInsightsPath = ''
)

$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$design=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'learning.design.json') | ConvertFrom-Json
$job=Get-Content -Raw -Encoding UTF8 $JobPath | ConvertFrom-Json
$feedback=Get-Content -Raw -Encoding UTF8 $FeedbackPath | ConvertFrom-Json
if(@('approved','rejected') -notcontains $job.status){throw '사람 승인 또는 반려가 기록된 작업만 학습 피드백으로 저장할 수 있습니다.'}
if($InstagramInsightsPath){
    $instagram=Get-Content -Raw -Encoding UTF8 $InstagramInsightsPath | ConvertFrom-Json
    if($instagram.article_id -ne $job.article.article_id){throw '인스타그램 성과 파일과 기사 ID가 일치하지 않습니다.'}
    if(-not $feedback.PSObject.Properties['metrics']){$feedback|Add-Member -NotePropertyName metrics -NotePropertyValue ([ordered]@{})}
    foreach($property in $instagram.metrics.PSObject.Properties){$feedback.metrics|Add-Member -Force -NotePropertyName $property.Name -NotePropertyValue $property.Value}
}
if($feedback.metrics -and -not $feedback.metrics.PSObject.Properties['engagement_rate'] -and [double]$feedback.metrics.reach -gt 0){
    $interactions=0.0
    foreach($name in @('likes','comments','saves','shares')){if($feedback.metrics.PSObject.Properties[$name]){$interactions+=[double]$feedback.metrics.$name}}
    $feedback.metrics|Add-Member -NotePropertyName engagement_rate -NotePropertyValue ([Math]::Round($interactions/[double]$feedback.metrics.reach,4))
}

function Get-PathValue($object,[string]$path){
    $value=$object
    foreach($part in $path.Split('.')){if($null -eq $value -or -not $value.PSObject.Properties[$part]){return $null};$value=$value.$part}
    return $value
}
$missing=@($design.feedback_contract.required|Where-Object {$null -eq (Get-PathValue $feedback $_)})
if($missing.Count){throw "피드백 필수값 누락: $($missing -join ', ')"}

$weighted=0.0;$weightTotal=0.0
foreach($dimension in $design.feedback_contract.dimensions){
    $value=Get-PathValue $feedback $dimension.path
    if($null -eq $value){if($dimension.optional){continue};throw "피드백 값 누락: $($dimension.path)"}
    switch($dimension.type){
        'scale' {$normalized=[Math]::Min(1.0,[Math]::Max(0.0,[double]$value/[double]$dimension.maximum))}
        'decision' {$normalized=[double]$dimension.map.([string]$value)}
        default {throw "설계서에 정의되지 않은 평가 타입: $($dimension.type)"}
    }
    $weighted+=$normalized*[double]$dimension.weight;$weightTotal+=[double]$dimension.weight
}
$riskFlags=@($feedback.risk_flags)
$blocked=(@($riskFlags|Where-Object {$design.guardrails.block_learning_on -contains $_}).Count -gt 0) -or ($job.status -eq 'rejected')
$reward=if($weightTotal){[Math]::Round($weighted/$weightTotal,4)}else{0}
$record=[ordered]@{recorded_at=(Get-Date).ToUniversalTime().ToString('o');article_id=$job.article.article_id;job_path=(Resolve-Path $JobPath).Path;strategy=$job.learning.strategies;palette=$job.visual.palette.name;feedback=$feedback;reward=$reward;blocked_from_learning=$blocked;design_version=$design.schema_version}
$storePath=Join-Path $root $design.selection.feedback_store
New-Item -ItemType Directory -Force (Split-Path -Parent $storePath)|Out-Null
($record|ConvertTo-Json -Compress -Depth 30)|Add-Content -Encoding UTF8 $storePath
$record|ConvertTo-Json -Depth 30
