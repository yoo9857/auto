# Meta(Instagram Graph API) 자동배포 설정 가이드

`@onedaytrading.io` 캐러셀을 코드로 자동 게시하려면 아래 4가지가 필요하다.
① IG 비즈니스 계정 + FB 페이지 연결 ② Meta 앱 + 권한 ③ 장기 토큰 + IG 계정 ID ④ 에셋 공개 호스팅.

---

## 1. IG 비즈니스 계정 + 페이스북 페이지 연결

1. 인스타그램 앱 → `@onedaytrading.io` → 설정 → 계정 유형 → **프로페셔널(비즈니스/크리에이터)** 로 전환.
2. 페이스북 **페이지**를 하나 만들고(없으면), 인스타 설정에서 그 페이지와 **연결**.
   - Instagram Content Publishing API는 "IG 비즈니스 계정 ↔ FB 페이지 연결"이 전제다.

## 2. Meta 앱 생성 + 권한

1. https://developers.facebook.com → 내 앱 → **앱 만들기** → 유형 **비즈니스**.
2. 제품 추가 → **Instagram** (Instagram Graph API / content publishing).
3. 필요한 권한(App Review 대상): `instagram_basic`, `instagram_content_publish`, `pages_show_list`, `pages_read_engagement`, `business_management`.
   - **개발 모드**에서는 앱 관리자/테스터 계정으로 승인 없이 즉시 테스트 가능(먼저 이걸로 검증).
   - 상시 운영하려면 App Review로 위 권한 승인 필요.

## 3. 토큰 + IG 계정 ID 발급

### 3-1. 단기 사용자 토큰
- 그래프 API 탐색기(Graph API Explorer)에서 앱 선택 → 위 권한 체크 → **Generate Access Token**.

### 3-2. 장기 토큰(약 60일)으로 교환
```bash
curl "https://graph.facebook.com/v24.0/oauth/access_token?grant_type=fb_exchange_token&client_id=<APP_ID>&client_secret=<APP_SECRET>&fb_exchange_token=<SHORT_TOKEN>"
```
→ 응답의 `access_token` 이 장기 사용자 토큰.

### 3-3. 페이지 토큰 + IG 비즈니스 계정 ID
```bash
# 연결된 페이지와 IG 비즈니스 계정 id 조회
curl "https://graph.facebook.com/v24.0/me/accounts?fields=name,access_token,instagram_business_account&access_token=<LONG_USER_TOKEN>"
```
→ 해당 페이지 객체의 `instagram_business_account.id` = **IG 계정 ID**, `access_token` = **페이지 토큰**(게시에 사용 권장).

> 페이지 토큰도 장기화하려면 위 장기 사용자 토큰으로 `me/accounts`를 호출해 받은 페이지 토큰을 쓰면 장기 유지된다. 만료 전 갱신 필요.

## 4. 환경변수 설정 (PowerShell, User 스코프)

```powershell
[Environment]::SetEnvironmentVariable('ODT_IG_USER_ID','<instagram_business_account.id>','User')
[Environment]::SetEnvironmentVariable('ODT_INSTAGRAM_ACCESS_TOKEN','<페이지 또는 장기 토큰>','User')
# 선택: [Environment]::SetEnvironmentVariable('ODT_META_API_VERSION','v24.0','User')
```
새 터미널부터 적용된다. (키 이름은 `automation/config.json`의 `instagram.access_token_env` 기준)

## 5. 에셋 공개 호스팅 (필수)

Meta는 **로컬 파일을 못 받고 공개 https URL에서 미디어를 가져간다.** 그래서 게시 전에
`DB/<날짜>-<id>/` 의 5개 파일(png/mp4)을 공개 URL로 올려야 한다.

- 예: `https://onedaytrading.net/i/ig/<article-id>/01-훅.png` … `05-마무리.png`, `02-영상.mp4`
- 한글 파일명은 자동으로 URL 인코딩된다. (원하면 파일명을 영문으로 바꿔도 됨)
- 업로드 방법(택1): 사이트 정적 경로에 배치 / 오브젝트 스토리지(S3·R2 등) / 사이트 업로드 API.
- 업로드가 자동화되면 `publish_auto.ps1 -BaseUrl <업로드된 폴더 URL>` 로 끝까지 자동화된다.

## 6. 발행

```powershell
# 계획만(미발행): 캐러셀 구성·캡션 확인
npm run instagram:meta-plan  -- "DB/2026-07-22-<id>" --base-url "https://onedaytrading.net/i/ig/<id>"

# 실제 발행(토큰·IG ID·공개 URL 필요)
npm run instagram:meta-publish -- "DB/2026-07-22-<id>" --base-url "https://onedaytrading.net/i/ig/<id>" --publish
```

발행 성공 시 `media_id`를 반환한다. 이를 기사 추적코드 `ODT-<article-id>`와 연결해 성과를 기록한다.

## 제약 / 주의

- Instagram 게시 한도: 24시간당 컨텐츠 게시 한도 존재(계정 규모별). 대량 배포 시 유의.
- 캐러셀 항목 2~10개. 영상 항목은 처리 대기(수 초~수십 초) 후 발행 가능.
- 게시는 **사람 승인 후에만**. 영상은 권리(rights_status) 검수 완료 후.
- 토큰 만료 대비 갱신 스케줄 필요.
