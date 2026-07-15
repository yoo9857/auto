param(
    [Parameter(Mandatory=$true)][string]$JobPath,
    [Parameter(Mandatory=$true)][ValidateSet('approved','rejected')][string]$Decision,
    [Parameter(Mandatory=$true)][string]$Reviewer,
    [string]$Notes=''
)

$ErrorActionPreference='Stop'
$job=Get-Content -Raw -Encoding UTF8 $JobPath | ConvertFrom-Json
$jobDir=Split-Path -Parent (Resolve-Path $JobPath)
$qaPath=Join-Path $jobDir 'qa-report.json'
if(-not(Test-Path $qaPath)){throw 'QA 보고서가 없습니다. 먼저 캐러셀을 생성하세요.'}
$qa=Get-Content -Raw -Encoding UTF8 $qaPath|ConvertFrom-Json
if(-not $qa.passed){throw 'QA 실패 작업은 승인할 수 없습니다.'}
if($Decision -eq 'approved' -and $job.visual.license -eq 'not_for_use'){throw '사용 불가 라이선스 이미지는 승인할 수 없습니다.'}
$approval=[ordered]@{decision=$Decision;reviewer=$Reviewer;reviewed_at=(Get-Date).ToUniversalTime().ToString('o');notes=$Notes;qa_report=$qaPath}
$job|Add-Member -Force -NotePropertyName approval -NotePropertyValue $approval
$job.status=$Decision;$job.qa.approved=($Decision -eq 'approved')
$job|ConvertTo-Json -Depth 30|Set-Content -Encoding UTF8 $JobPath
$manifestPath=Join-Path $jobDir 'manifest.json'
if(Test-Path $manifestPath){$manifest=Get-Content -Raw -Encoding UTF8 $manifestPath|ConvertFrom-Json;$manifest.status=$Decision;$manifest.approved=($Decision -eq 'approved');$manifest|Add-Member -Force -NotePropertyName approval -NotePropertyValue $approval;$manifest|ConvertTo-Json -Depth 30|Set-Content -Encoding UTF8 $manifestPath}
$approval|ConvertTo-Json -Depth 10
