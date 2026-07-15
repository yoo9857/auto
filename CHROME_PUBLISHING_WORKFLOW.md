# Chrome 기반 Instagram 게시

## Article-matched music (automatic)

Each plan selects one track from `automation/music_catalog.json` using the article tone (breaking news, analysis, technology, and outlook). The choice is frozen in the job before upload, so preview and publish use the same track. Only music that was actually attached and shared is written to `automation/music-history.jsonl`; future posts avoid every recorded track until the catalog is exhausted.

Between the carousel-edit and caption steps, the publisher looks for Instagram's **Add music / 음악 추가** control, searches the selected title and artist, and attaches the matching result. If the web UI does not expose music or the local library does not contain the track, publishing continues safely and that track is not consumed from the no-repeat history.

이 워크플로우는 Meta API를 사용하지 않고, 전용 Chrome 프로필의 로그인 세션으로 Instagram 웹 UI를 조작한다. 로그인·비밀번호·2단계 인증은 반드시 사람이 Chrome에서 직접 수행한다.

## 한 번만 설정

```powershell
npm install
npm run instagram:setup
```

열린 Chrome에서 `@onedaytrading.io`로 로그인한 뒤 터미널에서 Enter를 누른다. 세션은 `automation/chrome-instagram-profile`에 보관되므로 다른 사람과 공유하지 않는다.

## 게시 전 확인

```powershell
npm run instagram:plan -- --job ".\output\jobs\ARTICLE_ID\job.final.json"
```

작업 상태가 `approved`인지, 4장의 이미지와 캡션이 맞는지 확인한다.

별도 폴더의 이미지·영상(2~10개)을 캐러셀로 올릴 때는 `--assets-dir`을 사용한다. 파일명 순서가 게시 순서다.

```powershell
npm run instagram:plan -- --job ".\output\jobs\ARTICLE_ID\job.final.json" --assets-dir ".\DB\step1"
```

## 실제 게시

```powershell
npm run instagram:publish -- --job ".\output\jobs\ARTICLE_ID\job.final.json" --confirm
```

`--confirm` 없이는 실제 게시되지 않는다. UI 자동화는 Instagram 화면 변경, 로그인 만료, 업로드 오류의 영향을 받을 수 있으므로 게시 결과를 Instagram 앱에서 한 번 확인한다.

## 백그라운드 모드

Chrome 창을 띄우지 않고 저장된 전용 세션으로 실행하려면 `--background`를 추가한다. 먼저 로그인 상태만 검사한다.

```powershell
npm run instagram:check-background
```

검사를 통과한 경우에만 게시 명령에 `--background`를 붙인다.
