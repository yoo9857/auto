# 자동화 운영 규칙

## 실행 단계

```text
1. URL 수집
2. source.json 생성
3. 카피 공급자 호출 또는 안전한 중립 초안 생성
4. 이미지 공급자 또는 편집자가 background_path 확정
5. job.json 검수
6. 4장 렌더링
7. qa-report.json과 manifest.json 생성
8. 사람 승인 후 게시
```

## 환경 변수

```text
ODT_COPY_WEBHOOK   source.json을 받아 pages 객체를 반환하는 카피 공급자
ODT_IMAGE_WEBHOOK  향후 이미지 공급자 연결용
```

카피 웹훅이 없으면 시스템은 중립 초안을 만들며 자동 게시하지 않는다.

## 안전 원칙

- 원문을 직접 읽지 못하면 생성하지 않는다.
- 배경 이미지가 없으면 렌더링하지 않는다.
- 이미지 라이선스가 불명확하면 `review_required`로 표시한다.
- 치명적 QA 실패가 있으면 출력하지 않는다.
- 모든 생성물은 사람 승인 전 `approved=false`다.
- 같은 기사 ID는 기본적으로 다시 처리하지 않는다.

## 폴더 구조

```text
output/jobs/<article-id>/
├─ source.json
├─ job.json
├─ qa-report.json
├─ manifest.json
├─ page-01.png
├─ page-02.png
├─ page-03.png
└─ page-04.png
```

## 버전 정책

```text
MAJOR: job.json 계약 또는 페이지 역할 변경
MINOR: 레이아웃·검수 규칙 기능 추가
PATCH: 문구·간격·잘림 수정
```

모든 결과물은 `workflow_version`과 페이지 템플릿 버전을 기록한다.
