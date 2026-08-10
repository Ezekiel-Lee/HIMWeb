# 게시판(사진 첨부) Supabase 연동 설정 가이드 — 보안 강화판

게시판(board.html)이 사진 업로드를 지원하며, Google Sheets/Apps Script 대신
**Supabase**(무료 관리형 DB + 파일 저장소)를 사용합니다. 관리자 인증은 공유
비밀번호가 아니라 **실제 로그인 계정(Supabase Auth)**을 사용하고, 일반 방문자의
글 등록에는 **Cloudflare Turnstile(캡차)**가 적용되어 자동 스팸을 막습니다.
교육 신청(캘린더 예약) 기능은 기존처럼 Google Apps Script를 그대로 사용하므로
건드릴 필요 없습니다.

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
- `posts` 테이블 + 사진 URL 배열 저장
- `admin_users`에 등록된 로그인 계정만 승인/거절/즉시게시 가능하도록 하는 보안 정책(RLS)
- 일반 방문자의 글 등록은 `submit_post()` 함수를 통해서만 가능하며, 이 함수가
  Turnstile 캡차를 서버에서 직접 검증한 뒤에만 저장 (실패 시 자동 차단)
- 사진 저장용 `board-images` 버킷 자동 생성 (5MB, jpg/png/webp/gif 제한)

## 5단계 — API 키 확인

1. 왼쪽 메뉴 **Project Settings**(톱니바퀴) → **API**
2. **Project URL** 복사 (예: `https://xxxxxxxx.supabase.co`)
3. **anon public** 키 복사 (긴 문자열, `service_role` 키는 절대 사용하지 마세요 —
   그건 서버 전용 비밀키입니다)

## 6단계 — 웹사이트 파일에 값 붙여넣기

**board.html**, **post.html**, **admin.html** 3개 파일 각각에서 아래 두 줄을 찾아
5단계에서 복사한 값으로 교체하세요. (3개 파일 모두 동일한 값)

```js
var SUPABASE_URL = 'YOUR_SUPABASE_PROJECT_URL';
var SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
```

그리고 **board.html**에서만 아래 한 줄을 찾아 3단계의 **Site Key**로 교체하세요.
(Secret Key가 아니라 Site Key입니다 — Site Key는 공개되어도 안전합니다)

```js
var TURNSTILE_SITE_KEY = 'YOUR_TURNSTILE_SITE_KEY';
```

## 7단계 — 확인

1. board.html에서 "✎ 글쓰기" → 캡차 체크 → 사진 1~2장 첨부해서 등록
   (캡차를 완료하지 않으면 등록되지 않습니다)
2. Supabase 대시보드 → **Table Editor** → `posts` 테이블에서 방금 쓴 글이
   `status = pending`으로 들어왔는지 확인
3. admin.html 접속 → 2단계에서 만든 **이메일/비밀번호로 로그인**
   → "승인 대기 게시글"에 방금 글이 사진과 함께 보이는지 확인 → "승인" 클릭
4. board.html로 돌아가 새로고침 → 글이 게시판에 표시되고, **클릭하면 새
   브라우저 탭으로 게시글 상세 페이지(post.html)가 열리는지** 확인
5. board.html에서도 "관리자이신가요?"를 눌러 같은 계정으로 로그인해 보면,
   글쓰기 시 승인 없이 바로 게시되고 "공지사항 고정" 옵션이 나타나는지 확인

## 보안 수준 요약

| 항목 | 이전 방식 | 지금 방식 |
|---|---|---|
| 관리자 인증 | 소스코드에 평문 비밀번호 노출 | Supabase Auth 실제 로그인 (비밀번호는 서버에만 저장, 소스에 없음) |
| 승인/거절/삭제 권한 | 누구나 비밀번호만 알면 API 직접 호출 가능 | 로그인한 관리자 계정만 가능하도록 DB 레벨(RLS)에서 강제 |
| 글 등록 스팸 | 제한 없음 | Turnstile 캡차를 서버에서 직접 검증, 실패 시 저장 자체가 차단됨 |
| 이미지 업로드 남용 | 제한 없음 | 파일당 5MB, 이미지 형식만 허용 |

**남아있는 한계 한 가지**: 교육 신청(캘린더) 승인 기능은 여전히 예전 방식대로
공유 비밀번호(Apps Script)를 사용합니다. 이 부분은 별도 시스템(Google Calendar)이라
이번 작업 범위에 포함하지 않았습니다. 필요하시면 이 부분도 같은 방식으로
강화해 드릴 수 있어요.
