# OneDayTrading — 뉴스 카러셀 자동 생성 파이프라인

기사 URL 하나로 인스타그램용 **6개 산출물**(5페이지 카러셀 + 캡션)을 자동 생성한다.
카피·배경·영상 생성은 모두 **구독 기반 CLI**(claude/codex)로 동작해 **API 과금이 없다**.

## 한 줄 실행

```powershell
.\build_auto.ps1 -Url "https://onedaytrading.net/economy-news/<article-id>"
```

옵션:
- `-VideoUrl <url> -VideoStart 00:09:02 -VideoEnd 00:09:17` — 영상 자동검색 대신 특정 소스/구간 지정
- `-ImageOnly` — 영상 페이지 생략(4페이지)
- `-ImageEngine codex|gradient|openai|gemini` — 배경 엔진(기본 codex)
- `-Force` — 기존 작업 재생성

산출물: `output/jobs/<article-id>/` (작업본) + `DB/<YYYY-MM-DD>-<article-id>/` (배포 패키지)

## 6개 산출물 / 5페이지 구조

| # | 파일 | 내용 | 렌더러 | 카피 |
|---|------|------|--------|------|
| 1 | `01-훅.png` | 훅(대표 이미지 recompose 배경 + 상태 칩) | `render_card.ps1` | page1 |
| 2 | `02-영상.mp4` | 영상(인물 인터뷰/맥락 클립, 자동검색) | `render_page2_video_story.ps1` | — |
| 3 | `03-분석.png` | 분석 | `render_page2.ps1` | page2 |
| 4 | `04-판단.png` | 판단(평가) | `render_page3.ps1` | page3 |
| 5 | `05-마무리.png` | 브랜드 CTA | `render_page4.ps1` | page4 |
| 6 | `06-캡션.md` | 인스타 캡션 + 해시태그 5개 | build_auto | — |

## 파이프라인 단계 (build_auto.ps1)

```
1  기사 스냅샷      generate_carousel.ps1  (원문 HTML → source.json + job.json)
2  AI 카피          automation/generate_copy.js  (claude CLI)
     → 4페이지 카피 + hero 이미지 프롬프트 + video_search_profile + 캡션/태그
2b 영상 소스 검색   find_video_source.ps1  (X[Bing] + YouTube[yt-dlp] , 인터뷰 우선)
3  훅 배경 recompose automation/generate_background.js  (codex: 등록 대표이미지 글자제거 + 4:5 확장, 로고 보존)
4  팔레트 + QA      automation/resolve_palette.ps1 · automation/validate_job.ps1
5  영상 페이지      자막→find_context_clip.ps1→extract_context_clip.ps1→렌더
6  이미지 4장 + 06-캡션.md + DB 패키지
```

## 생성 알고리즘 요약

### 카피 (generate_copy.js, claude)
- 전개: 독자 질문 → 근거 → 기대·위험 → 조건부 결론. 원문에 없는 사실·수치 금지.
- 길이(렌더 영역 정합): 헤드라인 2줄 각 9자 이내, page2/3 문단 정확히 3개.
- 평가값은 통제 어휘 5개: `명확한 호재 / 제한적 호재 / 중립 / 제한적 악재 / 명확한 악재`.
- 2·3페이지 문구 중복 회피. 상세 규칙은 `ENGAGEMENT_ALGORITHM.md`.

### 배경 (generate_background.js, codex 기본)
- 새 그림을 상상하지 않고 **기사에 이미 등록된 대표 이미지(og:image)를 recompose**:
  뉴스 오버레이 텍스트/워터마크만 제거, **원본 브랜드 로고는 보존**, 세로 4:5로 outpaint,
  좌상단은 제목 자리로 어둡게. → 항상 기사와 관련된 무문자 배경.
- 폴백: `render_gradient_bg.ps1`(무문자 그라데이션). 대안 엔진: openai(gpt-image-2)/gemini.

### 영상 소스 (find_video_source.ps1) — 카테고리 인지형
- 주제는 카피 단계가 기사마다 자동 추출(`video_search_profile`). `search_kind`로 전략 선택:
  · **person** (IT·증시·모빌리티): 대표 인물 인터뷰/키노트
  · **official_event** (부동산 정책·바이오·거시): 인물 없이 기관/뉴스 공식 채널의 브리핑·발표
  · **product_reveal** (게임·하드웨어): 공식 트레일러/쇼케이스
  · **none**: 관련 영상 없음 → 훅 배경 **모션 폴백**으로 영상 페이지 생성(영상 페이지는 절대 생략 안 함)
- 카테고리별 **신뢰 채널 화이트리스트**(`automation/video_channels.json`)를 TrustedAuthors로 주입(크립토→Coindesk, 부동산→국토교통부, 게임→PlayStation 등) + 기사별 AI 채널 힌트 병합.
- **저작권 가드레일**: 엔터(K팝)·게임 트레일러 등은 `rights_risk=high` → build_auto가 경고, 권리 검수 전 자동게시 금지.
- evidence(X+YouTube) → person_context 폴백. 선호 랭킹: 인물 인터뷰 > 앵커 코멘트 > 제품 데모. 롱폼은 자막 기반 12초 추출. 항상 "CONTEXT VIDEO" 라벨.

### 상태 칩 (render_card.ps1)
- 프로스티드 글래스 필 + 감정색 글로우 도트: 호재=그린 / 악재=레드 / 속보=앰버 / 중립·분석=슬레이트.

### 캡션 (06-캡션.md)
- 알고리즘 최적화: 훅 1줄 → 사실+미확인 변수 → 캐러셀 유도 → 저장·팔로우·댓글 유도 → 고지.
- 해시태그 정확히 5개(엔티티+주제+시장, 키워드 스터핑 금지).

## 요구 사항 / 툴체인

- Node.js 22+, `playwright`(인스타 게시용), Chrome
- `tools/`: `ffmpeg.exe`, `ffprobe.exe`, `yt-dlp.exe`, **`deno.exe`**(yt-dlp YouTube JS 런타임 — 필수)
- 구독 CLI: **claude**(카피), **codex**(배경 이미지) — ChatGPT/Claude 구독 인증, API 과금 없음
- 환경변수: `FFMPEG_PATH`, `YT_DLP_PATH`(User 스코프). OpenAI 이미지 엔진 사용 시 `OPENAI_API_KEY`(현재 결제 한도 도달로 미사용)

## 주의점

- `build_auto.ps1`은 **UTF-8 BOM 필수**(Copy-Item에 한글 파일명이 있어 PS 5.1이 BOM 없으면 오독).
- YouTube 자막은 `--sub-langs en`(다국어는 429 유발) + 재시도/슬립. 과다 호출 시 일시적 429 스로틀 발생.
- 게시는 항상 사람 승인 후에만. 영상은 rights_status=review_required.

## 상태

- 검증: `562b26f3`(오픈AI, 5페이지+영상) / `59a3391d`(크립토, 6산출물).
- `build_n200_full.ps1`은 레거시 엔진(현재는 build_auto가 정식 진입점).
