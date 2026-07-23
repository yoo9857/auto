# Chrome 세션 반자동 배포 가이드 (Meta API 불필요)

Meta 앱·권한·비즈니스·공개 호스팅 없이, 전용 Chrome 프로필에 **한 번 로그인**해두고
사람이 올리듯 5장 캐러셀 + 캡션을 자동 업로드한다. 로컬 DB 파일을 그대로 쓴다.

## 0. 최초 1회 — 인스타 로그인 (사용자 직접)

```
npm run instagram:setup
```
열린 Chrome 창에서 **@onedaytrading.io** 로 직접 로그인(비밀번호·2단계 인증 포함) 후 Enter.
세션은 전용 프로필(`automation/chrome-instagram-profile`)에 저장되어 이후 재사용된다.
> 이 단계는 대화형이라 프롬프트에 `! npm run instagram:setup` 로 실행하는 걸 권장.

확인: `npm run instagram:check`

## 1. 카러셀 생성

```powershell
.\build_auto.ps1 -Url "https://onedaytrading.net/crypto-news/<id>"
```
→ `DB/<YYYY-MM-DD>-<id>/` 에 6개 산출물(5페이지 + 06-캡션.md).

## 2~4. 반자동 배포 (publish_chrome.ps1)

```powershell
# 2) 계획 확인 — 어떤 자산/캡션으로 올릴지
.\publish_chrome.ps1 -ArticleId <id>

# 3) 미리보기 — Chrome에서 실제로 구성 후 "공유 직전" 스크린샷 (공유 안 함)
.\publish_chrome.ps1 -ArticleId <id> -Preview
#   → output/jobs/<id>/chrome-publish-preview.png 로 최종 확인

# 4) 게시 — 승인 + 실제 공유
.\publish_chrome.ps1 -ArticleId <id> -Confirm
```
- `-Date <YYYY-MM-DD>` 로 과거 날짜 패키지 지정 가능(기본: 오늘).
- `-Confirm` 은 실행 시 자동으로 사람 승인(approve_carousel) 처리 후 게시한다.
- 캡션은 `06-캡션.md`의 AI 캡션 + 해시태그 5개를 사용.

## 반자동 원칙

- **로그인·최종 확인·게시 트리거는 사람**, 파일 선택·4:5 크롭·캡션 입력·음악·공유 클릭은 자동.
- 게시 전 항상 `-Preview` 로 눈으로 확인하는 습관 권장.
- 계정 안전을 위해 과도한 연속 자동 게시는 지양(하루 소량).

## 주의

- 비공식 자동화라 인스타 UI가 바뀌면 `automation/chrome_instagram_publisher.js`의 셀렉터를 손봐야 할 수 있다.
- 오류 시 `output/jobs/<id>/chrome-publish-diagnostic.png` 진단 스크린샷 확인.
- 영상(02) 포함 캐러셀도 지원(4:5 1080×1350 검증 통과 필요).
