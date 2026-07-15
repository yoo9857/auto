# DB 자동 업로드 운영 문서

## 목적

`DB`에 새 콘텐츠 폴더를 추가하면 자동화가 폴더 순서대로 검사한다. 승인된 작업 중 아직 Instagram에 올리지 않은 첫 번째 캐러셀만 게시 대상으로 선택한다. 이미 게시된 자료는 기사 ID와 이미지·영상 지문을 함께 비교해 다시 올리지 않는다.

## DB 폴더 규칙

폴더명은 게시 우선순위가 보이도록 날짜와 기사 ID 또는 짧은 주제를 사용한다.

```text
DB/
  2026-07-16-<article-id>/
    01-훅.png
    02-영상.mp4
    03-분석.png
    04-판단.png
    05-마무리.png
```

- 파일은 2~10개여야 한다.
- 이미지와 영상 모두 4:5 비율(1080×1350 권장)이어야 한다.
- 파일명은 `01`, `02`처럼 번호로 시작해야 캐러셀 순서가 고정된다.
- 지원 형식은 PNG, JPG, JPEG, WEBP, MP4, MOV다.
- `step1`은 이전 수동 작업용 별칭이므로 자동 큐에서는 제외된다.

## 기사 작업 연결

DB 폴더명에 기사 UUID를 넣으면 `output/jobs/<article-id>/job.final.json` 또는 `job.json`과 자동으로 연결된다. UUID가 폴더명에 없을 때는 폴더 안 JSON의 `article_id`를 읽어 연결한다.

자동 게시 전 해당 작업은 반드시 아래 조건을 만족해야 한다.

```json
{
  "status": "approved",
  "qa": { "approved": true }
}
```

승인 전 자료는 `waiting_for_approval`으로 남으며 게시하지 않는다. 기사 작업이 아직 생성되지 않았다면 `needs_generated_job`으로 남는다.

## 자동 캡션과 음악

- 캡션은 기사 근거, 분석 문단, 기대·확인·판단 포인트, 출처를 사용해 생성한다.
- 해시태그는 고정 브랜드 태그 없이 기사별로 정확히 5개 생성한다.
- 음악은 기사 톤에 맞춰 선택하고, 실제로 Instagram에 적용되어 공유된 곡만 중복 방지 이력에 기록한다.

## 실행 명령

```powershell
# DB의 모든 상태와 다음 후보 확인
node automation/chrome_instagram_publisher.js db-status

# 다음 후보의 이미지·영상·캡션·음악 계획만 생성
node automation/chrome_instagram_publisher.js plan-next

# 다음 승인 후보를 백그라운드 Chrome에서 실제 공유
node automation/chrome_instagram_publisher.js publish-next --confirm --background
```

`publish-next`는 승인된 후보가 없으면 중단한다. 임의의 폴더를 골라 게시하지 않는다.

## 중복 방지 기준

다음 중 하나라도 일치하면 `already_posted`로 처리한다.

1. 과거 자동 업로드 이력의 기사 ID
2. 과거 자동 업로드 이력의 자산 지문
3. Instagram 게시 검증이 성공한 기존 작업의 기사 ID 또는 자산 지문

공유가 성공한 뒤에만 `automation/instagram-upload-ledger.jsonl`에 기록한다. 실패하거나 취소된 시도는 사용 처리되지 않으므로, 수정 후 다시 게시할 수 있다.

## 상태값

| 상태 | 의미 | 필요한 조치 |
| --- | --- | --- |
| `ready` | 승인·자산·중복 검사를 통과한 다음 게시 대상 | `plan-next` 확인 후 `publish-next` 실행 |
| `already_posted` | 기존 게시물과 기사 또는 자산이 일치 | 조치 없음 |
| `waiting_for_approval` | 기사 작업은 있으나 승인 전 | QA 및 최종 승인 |
| `needs_generated_job` | 자산은 있으나 연결할 기사 작업이 없음 | 기사 워크플로우 생성 |
| `needs_2_to_10_carousel_assets` | 캐러셀 자산 수가 조건 밖 | 2~10개 4:5 자산 준비 |
