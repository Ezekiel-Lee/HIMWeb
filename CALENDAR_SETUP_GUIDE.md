# Google Calendar 연동 설정 가이드

## 1단계 — 캘린더 생성

1. https://calendar.google.com 접속 (선교회 대표 Google 계정으로 로그인)
2. 좌측 "다른 캘린더" 옆 + 버튼 → "새 캘린더 만들기"
3. 이름: "JD 미디어 선교회 활동·교육 일정"
4. 만들기

## 2단계 — 캘린더를 공개로 전환 (임베드를 위해 필수)

1. 좌측에서 방금 만든 캘린더에 마우스를 올리고 ⋮ (점 3개) 클릭 → "설정 및 공유"
2. "액세스 권한" 섹션에서 **"공개 사용 설정"** 체크
   - 주의: 이 캘린더의 일정 제목/시간이 누구나 볼 수 있게 됩니다.
     민감한 내용은 적지 말고 "2024 시드니 창조과학 교실" 같은 제목만 사용하세요.
3. 페이지 하단으로 스크롤 → "캘린더 통합" 섹션에서 **캘린더 ID** 복사
   - 형태: `xxxxxxxxxxxx@group.calendar.google.com`
   - 이 ID를 메모해 두세요. (다음 단계에서 사용)

## 3단계 — 임베드 코드 가져오기

같은 "캘린더 통합" 섹션에 있는 **"퍼가기 코드"**(Embed code) 박스에서
`src="https://calendar.google.com/calendar/embed?src=..."` 부분의 URL만 복사하세요.

예시:
```
https://calendar.google.com/calendar/embed?src=xxxxxxxxxxxx%40group.calendar.google.com&ctz=Australia%2FSydney
```

이 URL을 about.html과 support.html의 `YOUR_CALENDAR_EMBED_URL_HERE` 부분에 붙여넣으면 됩니다.

## 4단계 — Apps Script에 캘린더 자동 기록 기능 추가

게시판 백엔드(apps-script-backend.gs.txt)에 이미 작성된 코드 외에,
`calendar-booking.gs.txt` 파일의 코드를 **같은 Apps Script 프로젝트에 추가**하세요.

1. 게시판용 Apps Script 편집기를 다시 엽니다 (Google Sheets → 확장 프로그램 → Apps Script)
2. 좌측 파일 목록에서 + 버튼 → "스크립트" → 새 파일 이름을 "Calendar"로 지정
3. `calendar-booking.gs.txt`의 내용을 전체 복사해서 붙여넣기
4. 코드 상단의 `CALENDAR_ID`를 2단계에서 복사한 캘린더 ID로 교체
5. 다시 [배포] → [배포 관리] → 기존 배포의 ✎(편집) 아이콘 클릭 → 새 버전으로 배포
   (URL은 그대로 유지되므로 board.html, media.html 수정은 필요 없습니다)

## 5단계 — support.html에 신청 폼 연결

support.html의 `SCRIPT_URL`도 board.html과 **동일한 Apps Script URL**로 설정하세요.
(이미 board.html에서 설정하셨다면 같은 URL을 그대로 복사해서 넣으면 됩니다)

## 완료 후 확인 방법

1. support.html에서 빈 날짜를 선택하고 "신청하기" 클릭
2. Google Calendar(calendar.google.com)에 가서 해당 날짜에 "[승인대기]"로
   시작하는 새 이벤트가 자동으로 생성되었는지 확인
3. 같은 날짜를 다시 신청 시도하면 "이미 마감된 날짜입니다" 메시지가
   뜨는지 확인

## 6단계 — 관리자 페이지(admin.html) 설정

게시글과 교육 신청은 모두 "대기" 상태로 들어가고, admin.html에서
한 화면에 모아 승인하거나 거절할 수 있습니다.

1. admin.html을 열어 `ADMIN_PASSWORD`와 `SCRIPT_URL`을
   board.html / support.html / media.html과 **완전히 동일한 값**으로 설정하세요.
   (네 파일 모두 같은 비밀번호, 같은 Apps Script URL을 써야 합니다)
2. admin.html을 비밀번호로 열면:
   - **승인 대기 게시글** — 일반 사용자가 작성한 글이 여기 모입니다.
     "승인"을 누르면 게시판에 바로 게시되고, "거절"을 누르면 삭제됩니다.
   - **승인 대기 교육 신청** — support.html에서 신청된 교육이 여기 모입니다.
     "확정"을 누르면 캘린더 제목이 [확정]으로 바뀌고, "거절"을 누르면
     캘린더에서 삭제되어 그 날짜가 다시 신청 가능해집니다.
3. admin.html은 검색엔진에 노출되지 않도록 `noindex` 설정이 되어 있지만,
   URL 자체를 외부에 공유하지 않도록 주의해 주세요. (비밀번호로 보호되지만,
   가장 안전한 방법은 URL도 알리지 않는 것입니다)
