# N200 영상 워크플로우 기록

작성일: 2026-07-15 (KST)  
작업: 워런 버핏·게이츠재단 기부 기사 영상 카드 검증

## 최종 결과

- 최종 카드: `page-02-context-video-auto.mp4`
- 역할: `person_context` — 기사 속 인물의 실제 연례총회 장면. 기사 사건의 직접 증거가 아님.
- 소스: CNBC Television, YouTube `j1vGFpd49wM`
- 사용 구간: `00:03:02–00:03:14` (12초)
- 프레임: 1080×1350, 4:5. 원본 16:9은 잘라내지 않고 전체 표시.
- 화면 표기: 영상 오른쪽 하단 `© CNBC Television / YouTube`
- 게시 상태: `needs_clip_review` 및 `review_required` — 편집 사실·재사용 권리 확인 후 게시.

## 자동 선택 알고리즘

1. 기사 제목·본문에서 주제, 별칭, 사건 키워드, 인물명, 영상 형식 키워드를 만든다.
2. 사건을 직접 보여 주는 짧은 증거 영상을 먼저 찾는다. 사건·주제·게시일·영상 길이·출처를 통과해야 한다.
3. 직접 증거가 없고 인물이 명시된 기사면 인물 컨텍스트 모드로 전환한다.
4. 컨텍스트 모드는 `연례총회`, `인터뷰`, `연설`, `발언` 등 형식 일치와 신뢰 가능한 채널을 우선한다. 긴 영상은 버리지 않고 `clip_required`로 표시한다.
5. 자막을 내려받아 인물명·주제·형식 키워드가 실제로 나오는 큐를 점수화한다.
6. 일치 큐를 중심으로 8–15초 클립만 추출한다. 일치가 없으면 첫 유효 큐를 쓰되 `opening_context_fallback`과 검토 상태를 남긴다.
7. 카드 렌더링 시 영상은 contain 방식으로 전체를 보이고, 외부 소스는 오른쪽 하단에 `© 채널명`을 넣는다.
8. 모든 외부 영상은 출처, 구간, 사용 역할, 권리 상태를 JSON으로 저장한다. 표기만으로 재사용 허가가 되지는 않는다.

## 적용 스크립트

- `automation/build_video_search_profile.ps1`: 기사에서 검색 프로필 생성
- `search_x_links.ps1`, `search_official_video_links.ps1`: 무료 링크 탐색
- `select_x_video_candidate.ps1`: 증거 우선, 인물 컨텍스트 폴백, S/A 등급 선택
- `find_context_clip.ps1`: VTT 자막 기반 구간 선택
- `extract_context_clip.ps1`: 선택 구간만 다운로드
- `render_page2_video_story.ps1`: N200 카드 렌더링 및 저작권 표기

## 보존 파일

- `job.json`: 기사·선택·검수 상태
- `context-clip-selection.json`: 자막 매칭 근거
- `context-video-manifest.json`: 최종 영상 역할·출처·권리·표기값
- `source-context-buffett-auto.mp4`: 최종 12초 원본 클립
- `source-context-buffett-auto.mp4.provenance.json`: 추출 구간과 원본 URL
- `video-20260715T064742Z-*.json`: 최신 검색·선별 감사 기록

## 정리 처리

최초 수동 클립(00:00:28–00:00:44)은 인물 장면은 맞지만 자막 기반 최적 구간이 아니어서 활성 폴더에서 제거했다. 원본을 지우지 않고 `_archive/superseded-manual-clip/`에 보관해 추적 가능성을 유지한다.
