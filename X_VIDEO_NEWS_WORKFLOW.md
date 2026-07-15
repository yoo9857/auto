# X 영상 뉴스 플로우

기존 URL 기반 캐러셀 앞에 X 탐색 단계를 추가한다.

```text
감시 목록(키워드·공식 계정)
  → 웹 검색으로 X 링크 후보 수집
  → 반응·영상·민감성 기준으로 후보 큐 생성
  → 원문/공식 발표 교차 검증 및 영상 사용 권한 확인
  → 사실·권리 승인 작업 생성
  → EX1(영상 40%) 또는 EX2(영상 60%) 레이아웃 렌더
  → 사람 승인 후 게시
```

## 1. API 없는 X 링크 탐색

X API 비용 없이 웹 검색에 노출된 공개 X 게시물 링크를 수집한다.

```powershell
.\search_x_links.ps1 -Query 'OpenAI', 'Claude AI', 'AI 이미지 생성'
```

결과는 `output/x-search-links.json`에 저장된다. 영상·본문을 자동 복제하지 않으며, 링크를 열어 사실·권리·관련 영상 여부를 검토한 뒤에만 다음 단계로 넘긴다.

검토를 통과한 후보는 로컬 영상과 카피를 연결해 작업 폴더로 확정한다.

```powershell
.\approve_x_video_job.ps1 `
  -Candidates .\output\x-search-links.json `
  -PostId '게시물ID' `
  -Video .\approved-video.mp4 `
  -Headline "제목" `
  -Body "핵심 요약" `
  -Layout EX2 `
  -RightsApproved
```

명령은 `output/x-ready/<게시물ID>/job.json`과 `render-command.txt`를 만들고 승인 영상의 사본을 함께 보관한다.

## 2. API 기반 탐색 설정 (선택)

`automation/x-watchlist.example.json`을 `automation/x-watchlist.json`으로 복사해 키워드와 신뢰 계정을 정한다. Bearer Token은 파일에 적지 않고 환경 변수로 설정한다.

```powershell
$env:X_BEARER_TOKEN = '...'
.\search_x.ps1
```

명령은 `output/x-candidates/<UTC 실행시각>/candidates.json`을 만든다. 이 파일은 게시 큐가 아니라 검토 후보 목록이다.

## 3. 후보 승인 기준

- X 게시물만으로 단정하지 말고 공식 발표, 보도자료, 원문 영상으로 교차 확인한다.
- `possibly_sensitive`, 출처 불명, 재업로드 영상은 자동 탈락 처리한다.
- `rights_status`가 `approved`인 영상만 다운로드·편집·게시한다.
- 영상은 9:16으로 크롭하고, EX1은 상단 540px / EX2는 상단 810px을 사용한다.
- 영상 출처는 카드 우측 상단과 캡션에 함께 표기한다.

## 4. 운영 원칙

X 공식 Recent Search는 최근 7일 게시물을 대상으로 한다. API 플랜/권한에 따라 호출 가능 범위가 달라질 수 있다. 영상 후보의 MP4 URL은 검토 편의를 위한 값이며, 자동 재게시 권한을 뜻하지 않는다.

## 5. EX형 영상 렌더

사용 권한과 사실 검증이 끝난 로컬 영상만 렌더한다. `ffmpeg`가 PATH에 있어야 한다.

현재 PowerShell을 이미 열어둔 상태라면 설치 직후의 PATH 변경이 반영되지 않을 수 있다. 새 PowerShell을 열거나 `FFMPEG_PATH` 환경 변수에 `ffmpeg.exe`의 전체 경로를 설정한다.

```powershell
.\render_x_video.ps1 `
  -Video '.\approved-video.mp4' `
  -Layout EX2 `
  -Headline "자고 일어났더니,`n전설의 클로드가 풀렸다" `
  -Body "공식 발표에서 확인된 핵심 내용을`n짧고 정확하게 정리합니다." `
  -SourceLabel 'X / Claude' `
  -Output '.\output\news-reel.mp4'
```

`EX1`은 영상 40%(540px), `EX2`는 영상 60%(810px)를 차지한다. 영상은 자동으로 1080px 폭에 맞춰 중앙 크롭되며, 출력은 1080×1350 MP4다.

## 5. 후보에서 최종 영상까지

검증한 원문 URL, 카드 카피, 권한 승인 기록을 남기며 작업을 생성한다. 권한을 확인한 X 영상만 `-DownloadApprovedVideo`으로 받을 수 있다.

```powershell
.\approve_x_candidate.ps1 `
  -CandidatesFile '.\output\x-candidates\<run>\candidates.json' `
  -CandidateId '<x-post-id>' `
  -VerifiedSourceUrl 'https://공식-원문-링크' `
  -Headline "제목" -Body "요약" -Layout EX2 -RightsApproved `
  -VideoPath '.\approved-video.mp4'

.\render_approved_x_news.ps1 -JobPath '.\output\x-news-jobs\<x-post-id>\news-job.json'
```
