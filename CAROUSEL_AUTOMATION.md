# OneDayTrading URL 기반 4장 자동 생성 알고리즘

## 목표

사용자가 OneDayTrading 기사 링크 하나를 입력하면 기사 내용과 대표 이미지를 직접 확인하고, 기사별 4장 인스타그램 캐러셀을 자동 생성한다.

```text
기사 URL 입력
→ 원문 직접 조회
→ 기사 구조화
→ 이미지 전략 결정
→ 1~4장 카피 작성
→ 기사 전용 배경 이미지 준비
→ 정확한 한글 텍스트 후처리
→ 자동 검수
→ 4장 PNG 출력
```

## 사용 형태

```powershell
.\generate_carousel.ps1 -Url "https://onedaytrading.net/..."
```

선택 입력:

```powershell
.\generate_carousel.ps1 `
  -Url "https://onedaytrading.net/..." `
  -InstagramHandle "@onedaytrading.io" `
  -OutputDirectory "output/<article-id>"
```

## 1단계: URL 검증

허용 조건:

- `https://onedaytrading.net/` 도메인
- 기사 상세 URL
- HTTP 상태 `200`
- canonical URL과 입력 URL이 같은 기사를 가리킴

실패 조건:

- 목록·검색·로그인 페이지
- 삭제되거나 접근할 수 없는 기사
- 제목 또는 본문이 없는 페이지
- 이미 처리된 기사 ID

검색 결과나 비슷한 제목의 기사로 대체하지 않는다. 입력받은 URL의 HTML을 직접 읽지 못하면 생성 작업을 중단한다.

## 2단계: 기사 추출

HTML과 구조화 데이터에서 다음 값을 수집한다.

```json
{
  "article_url": "",
  "canonical_url": "",
  "article_id": "",
  "title": "",
  "description": "",
  "body": "",
  "briefing": "",
  "published_at": "",
  "modified_at": "",
  "source_name": "",
  "author": "",
  "category": "",
  "sector": "",
  "sentiment": "neutral",
  "entities": [],
  "tickers": [],
  "og_image": ""
}
```

추출 우선순위:

1. JSON-LD `NewsArticle`
2. Open Graph 메타데이터
3. 페이지 내 기사 데이터
4. 본문 HTML

## 3단계: 사실 구조화

기사에서 다음 네 묶음을 분리한다.

```text
confirmed_facts     기사에서 확인된 사실
market_meaning      투자자에게 중요한 이유
unknown_variables   아직 공개되지 않은 조건
decision_data       이후 판단을 바꿀 데이터
```

각 문장은 반드시 원문 근거 위치를 함께 저장한다.

```json
{
  "statement": "스티브 부시미가 파크라이 TV 시리즈에 합류했다.",
  "type": "confirmed_fact",
  "evidence": "본문 1문단",
  "confidence": 1.0
}
```

신뢰도 `0.85` 미만 문장은 카드에 사용하지 않는다.

## 4단계: 시장 라벨

```text
한국 거래소 종목 중심        → 국내주식
미국·유럽 등 해외 종목 중심  → 해외주식
국내외 종목 동시 영향        → 글로벌증시
거시경제·금리·환율 중심      → 증시·경제
가상자산 중심                → 크립토
```

기업 소재지가 아니라 기사에서 연결한 실제 거래 시장을 기준으로 한다.

## 5단계: 핵심 긴장과 독자 질문

기사에서 가장 강한 대립쌍 하나만 선택한다.

```text
기대 vs 현실
화제성 vs 실적
발표 vs 실제 이행
기회 vs 비용
단기 반응 vs 장기 가치
```

이를 바탕으로 독자 질문을 만든다.

```json
{
  "central_tension": "화제성 vs 실제 매출",
  "reader_question": "유명 배우 한 명이 게임 매출까지 바꿀까?",
  "short_answer": "가능성은 있지만 확인할 조건이 남아 있다."
}
```

## 6단계: 이미지 전략

### 핵심 대상 우선순위

1. 기사 핵심 인물
2. 제품·게임·차량·시설·장소
3. 사건을 설명하는 구체적인 현장
4. 기업 활동을 보여주는 에디토리얼 장면

범용 차트·지구본·돈다발·악수·의미 없는 트레이더 화면은 사용하지 않는다.

### 이미지 처리 분기

```text
대표 이미지가 기사와 정확히 일치
→ 인물·대상 참고 이미지로 사용해 4:5 무문자 배경 재구성

대표 이미지 재사용 권한 확인
→ 원본을 4:5로 크롭·확장하고 텍스트 안전 영역 생성

대표 이미지 부정확·저품질
→ 핵심 대상과 기사 맥락으로 새로운 에디토리얼 이미지 생성

핵심 대상 불명확
→ 자동 게시 금지, 수동 검수
```

생성 이미지 필수 프롬프트:

```text
portrait 4:5 editorial news background
article-specific subject and setting
subject positioned away from headline safe area
realistic texture and natural lighting
no text, no letters, no numbers, no logo, no watermark
no generic financial charts or stock-photo clichés
```

이미지 생성 모델은 배경만 만든다. 제목·본문·로고·사이트 주소는 렌더러가 삽입한다.

## 7단계: 4장 카피 생성

### 1페이지 — 무슨 일이 발생했나?

```json
{
  "breaking_label": "긴급속보",
  "headline": "최대 2줄",
  "subtitle": "왜 중요한지 최대 2줄",
  "cta": "핵심 분석 보기 →",
  "market_label": "해외주식"
}
```

규칙:

- 핵심 인물·기업·사건 포함
- 제목 18~32자 권장
- 확인되지 않은 단정 금지
- CTA는 기사 성격에 따라 변경 가능

```text
분석 기사 → 핵심 분석 보기 →
단순 속보 → 기사 자세히 보기 →
공시 기사 → 투자 포인트 보기 →
인물 기사 → 전체 내용 보기 →
```

### 2페이지 — 왜 중요한가?

```json
{
  "analysis_headline": "독자 질문 최대 2줄",
  "quick_answer": "질문에 대한 잠정 답",
  "paragraphs": [
    "확인된 사실과 직접 효과",
    "수익·산업 영향 경로와 미확인 변수",
    "확장 가능성과 실패 가능성"
  ],
  "memory_line": "판단 기준 한 줄"
}
```

본문은 전체 8~11줄. 한 문단은 2~3문장으로 제한한다.

### 3페이지 — 어떻게 평가해야 하나?

```json
{
  "evaluation": "제한적 호재",
  "evaluation_summary": "현재 평가 근거 최대 2줄",
  "expect": "기대할 것 한 줄",
  "verify": "확인할 것 한 줄",
  "judge": "판단할 것 한 줄",
  "paragraphs": [
    "긍정 근거",
    "아직 부족한 정보",
    "평가를 바꿀 데이터"
  ],
  "memory_line": "최종 평가 한 줄"
}
```

평가 허용값:

```text
명확한 호재
제한적 호재
중립
제한적 악재
명확한 악재
```

매수·매도·목표가·수익률을 생성하지 않는다.

### 4페이지 — 브랜드 CTA

기사와 무관하게 고정한다.

```json
{
  "brand_headline": "오늘의 뉴스가 내일의 판단이 되도록.",
  "brand_description": "시장에 흩어진 신호를 읽기 쉬운 맥락으로 정리합니다.",
  "instagram_handle": "@onedaytrading.io",
  "instagram_cta": "팔로우하기 +",
  "website": "onedaytrading.net",
  "website_features": "증시 분석 · 종목별 뉴스 · 시장 자료",
  "website_cta": "사이트에서 더 보기 ↗"
}
```

## 8단계: 중복 제거

페이지별 역할을 비교한다.

```text
1페이지 사실 ≠ 2페이지 의미
2페이지 의미 ≠ 3페이지 평가
3페이지 평가 ≠ 2페이지 요약 반복
```

유사 문장이 발견되면 다음 우선순위로 남긴다.

```text
사실 문장       → 1페이지
원인·영향       → 2페이지
평가·판단 조건  → 3페이지
브랜드 안내     → 4페이지
```

## 9단계: 렌더링

공통 사양:

```text
크기: 1080×1350px
제목: Noto Sans KR Black
본문: Noto Sans KR
로고: NEWLOGO.png
배경: 기사별 4:5 무문자 이미지
색상: 이미지에서 추출한 어두운 배경 + 적색 + 하늘색
```

렌더러 매핑:

```text
1페이지 → render_card.ps1
2페이지 → render_page2.ps1
3페이지 → render_page3.ps1
4페이지 → render_page4.ps1
```

현재 렌더러의 고정 문구를 최종 구현에서는 `job.json` 입력값으로 교체한다.

## 10단계: 자동 검수

### 사실 검수

- 제목·숫자·인물·기업명이 원문에 존재하는가
- 기사와 다른 유사 기사를 참조하지 않았는가
- 미확인 변수를 사실처럼 단정하지 않았는가
- 평가 강도와 기사 근거가 일치하는가

### 이미지 검수

- 핵심 인물·대상이 기사와 일치하는가
- AI 생성 글자·로고·워터마크가 없는가
- 제목 영역이 충분히 어두운가
- 얼굴과 핵심 피사체를 글자가 가리지 않는가

### 레이아웃 검수

- 모든 글자가 캔버스 안에 들어가는가
- 제목 하단 획이 잘리지 않는가
- 마지막 본문 문장이 잘리지 않는가
- 1~3페이지 푸터 좌표가 같은가
- 4페이지 인스타 계정이 `@onedaytrading.io`인가

### 정독률 검수

- 1페이지 첫 2초 안에 사건을 이해할 수 있는가
- 2페이지 질문 직후 답을 제공하는가
- 2·3페이지의 내용이 반복되지 않는가
- 각 페이지가 한 가지 질문에만 답하는가
- 기억 문장이 구체적인 판단 기준을 남기는가

12개 검수 항목 중 하나라도 치명적 실패이면 출력하지 않고 재작성한다.

## 11단계: 출력 구조

```text
output/
└─ <article-id>/
   ├─ source.json
   ├─ job.json
   ├─ background.png
   ├─ page-01.png
   ├─ page-02.png
   ├─ page-03.png
   ├─ page-04.png
   └─ qa-report.json
```

## 12단계: 작업 상태

```text
received
→ fetching
→ extracting
→ structuring
→ image_preparing
→ copywriting
→ rendering
→ validating
→ ready
```

실패 상태:

```text
blocked_fetch
blocked_image
blocked_facts
blocked_layout
needs_review
```

## 13단계: 최종 작업 데이터

```json
{
  "status": "ready",
  "article": {},
  "visual": {
    "strategy": "reference_recompose",
    "subject": "",
    "background_path": ""
  },
  "pages": {
    "page1": {},
    "page2": {},
    "page3": {},
    "page4": {}
  },
  "qa": {
    "facts_passed": true,
    "image_passed": true,
    "layout_passed": true,
    "engagement_passed": true,
    "warnings": []
  },
  "outputs": [
    "page-01.png",
    "page-02.png",
    "page-03.png",
    "page-04.png"
  ]
}
```

## 연결된 세부 워크플로우

- `WORKFLOW.md`: 전체 디자인 및 기본 규칙
- `WORKFLOW_PAGE2.md`: 2페이지 뉴스 분석면
- `WORKFLOW_PAGE3.md`: 3페이지 평가면
- `WORKFLOW_PAGE4.md`: 4페이지 브랜드 CTA
- `ENGAGEMENT_ALGORITHM.md`: 정독률 중심 카피 알고리즘
