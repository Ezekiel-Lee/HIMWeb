# HiM 웹사이트 — Supabase 연동 설정 가이드

게시판(사진 포함)과 교육 신청(캘린더 예약)이 모두 Google Sheets/Apps Script/
Google Calendar 대신 **Supabase**(무료 관리형 DB + 파일 저장소) 하나로 통합되었습니다.
더 이상 Google 계정에 의존하지 않아서, 이전에 겪었던 "Apps Script 배포가
서비스 약관 위반으로 막히는" 문제에서 완전히 벗어났습니다.

관리자 인증은 공유 비밀번호가 아니라 **실제 로그인 계정(Supabase Auth)**을 사용하고,
일반 방문자의 글 등록·교육 신청에는 **Cloudflare Turnstile(캡차)**가 적용되어
자동 스팸을 막습니다.

## 1단계 — Supabase 프로젝트 생성

1. https://supabase.com 접속 → 회원가입/로그인 (GitHub 계정으로 가능)
2. "New project" 클릭
3. 프로젝트 이름: 예) `him-board`
4. 데이터베이스 비밀번호를 설정하고 저장 (나중에 필요할 수 있으니 메모)
5. Region은 가장 가까운 지역(예: Southeast Asia / Sydney) 선택 → "Create new project"
   (1~2분 정도 초기화 시간이 걸립니다)

## 2단계 — 관리자 로그인 계정 만들기

1. 왼쪽 메뉴 **Authentication** → **Users** → **Add user** → **Create new user**
2. 관리자로 쓸 이메일/비밀번호 입력, **"Auto Confirm User"** 체크 후 생성
   (이메일 인증 절차 없이 바로 로그인 가능하게 하기 위함)
3. 방금 만든 계정이 목록에 뜨면 완료. 이 이메일/비밀번호가 앞으로
   admin.html과 board.html의 "관리자 로그인"에 사용됩니다.

## 3단계 — Cloudflare Turnstile(캡차) 키 발급

1. https://dash.cloudflare.com/?to=/:account/turnstile 접속 (Cloudflare 계정 필요, 무료)
2. **Add site** 클릭 → 사이트 이름 아무거나 입력 → 도메인에 실제 웹사이트 주소 입력
   (예: `yourdomain.com`, 로컬 테스트도 하려면 `localhost`도 추가 가능)
3. Widget Mode는 **Managed**(기본값) 선택 → 생성
4. **Site Key**와 **Secret Key** 두 개를 복사해 둡니다. (다음 단계에서 사용)

## 4단계 — 데이터베이스 스키마 실행

1. Supabase 프로젝트 → 왼쪽 메뉴 **SQL Editor** → "New query"
2. 함께 전달한 `supabase-schema.sql` 파일을 열어 **전체 내용을 복사**해서 붙여넣기
3. 스크립트 안의 `'YOUR_TURNSTILE_SECRET_KEY'` 부분을 3단계에서 복사한
   **Secret Key**로 교체
4. 우측 하단 **Run** 클릭 → "Success" 확인
5. 스크립트 맨 아래 안내대로, 아래 쿼리의 이메일을 2단계에서 만든 관리자
   이메일로 바꿔서 **한 번 더 실행**하세요 (관리자 권한 부여):
   ```sql
   insert into admin_users (user_id)
   select id from auth.users where email = 'admin@example.com';
   ```

이 스크립트가 자동으로 해주는 일:
- `posts` 테이블 + 사진 URL 배열 저장 (게시판)
- `bookings` 테이블 (교육 신청 — 시작일/종료일, 신청자 정보, 승인 상태)
- `admin_users`에 등록된 로그인 계정만 승인/거절/삭제가 가능하도록 하는 보안 정책(RLS)
- 일반 방문자의 글 등록·교육 신청은 각각 `submit_post()` / `request_booking()` 함수를
  통해서만 가능하며, 두 함수 모두 Turnstile 캡차를 서버에서 직접 검증한 뒤에만 저장
  (실패 시 자동 차단), `request_booking()`은 날짜 중복도 서버에서 재확인합니다
- 사진 저장용 `board-images` 버킷 자동 생성 (5MB, jpg/png/webp/gif 제한)
- `posts`에 `drive_folder_url` 컬럼 — 글쓰기 폼에서 "Google Drive 폴더 링크"를 선택으로
  입력하면, 게시글 상세 페이지(post.html)에 해당 Drive 폴더가 그대로 임베드되어 보입니다.
  사진 업로드와 별개로 쓸 수 있는 옵션이며, **폴더가 "링크가 있는 모든 사용자에게 공개"로
  공유되어 있어야** 방문자에게 보입니다.

**⚠ 이미 이전 버전의 스키마를 실행한 적이 있다면**, 이 파일을 다시 통째로 실행해도
안전합니다 (기존 정책/함수를 안전하게 교체합니다). `posts` 테이블 데이터는 유지됩니다.

## 5단계 — API 키 확인

1. 왼쪽 메뉴 **Project Settings**(톱니바퀴) → **API**
2. **Project URL** 복사 (예: `https://xxxxxxxx.supabase.co`)
3. **anon public** 키 복사 (긴 문자열, `service_role` 키는 절대 사용하지 마세요 —
   그건 서버 전용 비밀키입니다)

## 6단계 — 웹사이트 파일에 값 붙여넣기

**board.html, post.html, admin.html, media.html, support.html, about.html** —
6개 파일 각각에서 아래 두 줄을 찾아 5단계에서 복사한 값으로 교체하세요.
(6개 파일 모두 동일한 값)

```js
var SUPABASE_URL = 'YOUR_SUPABASE_PROJECT_URL';
var SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
```

그리고 **board.html, support.html** 두 파일에서 아래 한 줄을 찾아 3단계의
**Site Key**로 교체하세요. (Secret Key가 아니라 Site Key입니다 — 공개되어도 안전합니다)

```js
var TURNSTILE_SITE_KEY = 'YOUR_TURNSTILE_SITE_KEY';
```

## 7단계 — 확인

**게시판**
1. board.html에서 "✎ 글쓰기" → 캡차 체크 → 사진 1~2장 첨부해서 등록
2. admin.html에서 관리자 계정으로 로그인 → "승인 대기 게시글"에서 승인
3. board.html에서 글 클릭 → 새 탭으로 post.html 열리는지 확인
4. media.html에 YouTube 링크를 넣은 글이 보이는지 확인

**교육 신청(캘린더)**
1. support.html에서 날짜 선택 → 캡차 체크 → 신청
2. admin.html의 **"예약 현황" 달력**과 **"승인 대기 교육 신청"** 목록에 방금 신청이
   보이는지 확인 → "확정" 클릭
3. support.html/about.html 달력에 확정된 날짜가 반영되는지 확인

## 보안 수준 요약

| 항목 | 이전 방식 | 지금 방식 |
|---|---|---|
| 관리자 인증 | 소스코드에 평문 비밀번호 노출 | Supabase Auth 실제 로그인 (비밀번호는 서버에만 저장) |
| 승인/거절/삭제 권한 | 누구나 비밀번호만 알면 API 직접 호출 가능 | 로그인한 관리자 계정만 가능하도록 DB 레벨(RLS)에서 강제 |
| 글/신청 스팸 | 제한 없음 | Turnstile 캡차를 서버에서 직접 검증, 실패 시 저장 자체가 차단됨 |
| 이미지 업로드 남용 | 제한 없음 | 파일당 5MB, 이미지 형식만 허용 |
| 인프라 리스크 | 개인 Google 계정에 의존 (계정 정지/어뷰징 감지 시 전체 마비) | Supabase 단일 백엔드, Google 계정과 무관 |

## 더 이상 필요 없는 파일

아래 파일들은 이제 사용하지 않습니다. 확인 기간을 두고 문제없으면 삭제하셔도 됩니다.
- `CALENDAR_SETUP_GUIDE.md` (Google Calendar/Apps Script 설정 가이드 — 파일 상단에 "사용 안 함" 표시해 두었습니다)
- `calendar-booking.gs.txt` (Apps Script 코드)
