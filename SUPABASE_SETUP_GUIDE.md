# 게시판(사진 첨부) Supabase 연동 설정 가이드

게시판(board.html)이 이제 사진 업로드를 지원합니다. Google Sheets/Apps Script 대신
**Supabase**(무료 관리형 DB + 파일 저장소)를 사용합니다. 서버를 직접 운영할 필요는
없고, 아래 단계만 따라 하면 됩니다. 교육 신청(캘린더 예약) 기능은 기존처럼
Google Apps Script를 그대로 사용하므로 건드릴 필요 없습니다.

## 1단계 — Supabase 프로젝트 생성

1. https://supabase.com 접속 → 회원가입/로그인 (GitHub 계정으로 가능)
2. "New project" 클릭
3. 프로젝트 이름: 예) `him-board`
4. 데이터베이스 비밀번호를 설정하고 저장 (나중에 필요할 수 있으니 메모)
5. Region은 가장 가까운 지역(예: Southeast Asia / Sydney) 선택 → "Create new project"
   (1~2분 정도 초기화 시간이 걸립니다)

## 2단계 — 데이터베이스 스키마 실행

1. 왼쪽 메뉴에서 **SQL Editor** 클릭 → "New query"
2. 함께 전달한 `supabase-schema.sql` 파일을 열어 **전체 내용을 복사**해서 붙여넣기
3. 스크립트 안의 `'Genesis11'` 부분(2군데)을 board.html / admin.html에서 쓰는
   관리자 비밀번호와 동일한 값으로 바꾸고 싶다면 지금 수정하세요. (그대로 두면
   기본값 `Genesis11`이 사용됩니다)
4. 우측 하단 **Run** 클릭 → "Success" 메시지 확인

이 스크립트가 자동으로 해주는 일:
- `posts` 테이블 생성 (게시글 + 사진 URL 배열 저장)
- 일반 사용자는 항상 "승인 대기" 상태로만 글이 등록되도록 보안 처리
- 관리자 승인/거절/즉시게시 함수 생성
- 사진을 저장할 `board-images` Storage 버킷 자동 생성 + 공개 읽기/업로드 권한 설정

## 3단계 — API 키 확인

1. 왼쪽 메뉴 **Project Settings**(톱니바퀴) → **API**
2. **Project URL** 복사 (예: `https://xxxxxxxx.supabase.co`)
3. **anon public** 키 복사 (긴 문자열, `service_role` 키는 절대 사용하지 마세요 —
   그건 서버 전용 비밀키입니다)

## 4단계 — 웹사이트 파일에 붙여넣기

아래 **3개 파일**에서 각각 두 줄을 찾아 방금 복사한 값으로 교체하세요.
(모두 동일한 값을 넣어야 합니다)

- `board.html`
- `post.html`
- `admin.html`

```js
var SUPABASE_URL = 'YOUR_SUPABASE_PROJECT_URL';
var SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
```

↓

```js
var SUPABASE_URL = 'https://xxxxxxxx.supabase.co';
var SUPABASE_ANON_KEY = '여기에_anon_public_키';
```

## 5단계 — 확인

1. board.html을 열어 "✎ 글쓰기" → 사진 1~2장 첨부해서 등록
2. Supabase 대시보드 → **Table Editor** → `posts` 테이블에서 방금 쓴 글이
   `status = pending`으로 들어왔는지 확인
3. `Storage` → `board-images` 버킷에 사진 파일이 업로드되었는지 확인
4. admin.html에 접속해 관리자 비밀번호로 로그인 → "승인 대기 게시글"에 방금
   글이 사진과 함께 보이는지 확인 → "승인" 클릭
5. board.html로 돌아가 새로고침 → 글이 게시판에 표시되고, **클릭하면 새
   브라우저 탭으로 게시글 상세 페이지(post.html)가 열리는지** 확인

## 참고 — 보안 수준

기존 방식과 동일하게, 관리자 비밀번호는 페이지 소스에 그대로 노출되는 방식입니다
(작은 선교단체 게시판 규모에 맞춘 간단한 방식). 승인/거절/즉시게시는 반드시
Supabase SQL 함수 안에서 비밀번호를 확인한 뒤에만 실행되므로, 방문자가 직접
DB를 조작해 글을 강제로 승인시킬 수는 없습니다. 더 강한 보안이 필요해지면
(예: 로그인 시스템 도입) 알려주시면 업그레이드해 드릴 수 있습니다.