-- ═══════════════════════════════════════════════════════════
-- HiM 게시판(board.html) — Supabase 스키마 (보안 강화판)
-- Supabase 프로젝트 → SQL Editor → 새 쿼리에 전체 붙여넣고 Run
-- 기존 스키마를 이미 실행한 적이 있어도 이 파일을 다시 실행하면
-- 안전하게 새 구조로 교체됩니다.
--
-- 이 버전이 이전 버전과 다른 점:
--  1) 관리자는 더 이상 "공유 비밀번호"가 아니라 Supabase Auth 실제 로그인(이메일+비밀번호)을 사용합니다.
--  2) 일반 방문자의 글 등록은 Cloudflare Turnstile(캡차) 인증을 통과해야만 저장됩니다.
--  3) 이미지 업로드는 5MB, jpg/png/webp/gif로 제한됩니다.
-- ═══════════════════════════════════════════════════════════

create extension if not exists pgcrypto;
create extension if not exists http;  -- Turnstile 서버 검증(siteverify 호출)에 사용

-- 1) 게시글 테이블
create table if not exists posts (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  name        text not null,
  category    text not null default '일반',
  title       text not null,
  content     text not null,
  youtube_url text,
  image_urls  text[] not null default '{}',
  is_notice   boolean not null default false,
  status      text not null default 'pending' check (status in ('pending','approved','rejected'))
);

-- 2) 관리자 목록 테이블 — Supabase Auth로 로그인한 사용자 중
--    이 테이블에 등록된 user_id만 관리자 권한을 가집니다.
create table if not exists admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade
);
alter table admin_users enable row level security;
-- 공개 정책 없음 = 클라이언트에서 직접 조회/수정 불가 (아래 보안 함수로만 접근)

-- 현재 로그인한 사용자가 관리자인지 확인하는 함수 (클라이언트에서 호출 가능)
create or replace function am_i_admin()
returns boolean as $$
begin
  return exists (select 1 from admin_users where user_id = auth.uid());
end;
$$ language plpgsql security definer stable;

-- 3) 일반 사용자가 테이블에 직접 INSERT 하더라도, 로그인한 관리자가 아니면
--    항상 "대기중" 상태 + 공지 아님으로 강제 저장되는 트리거
create or replace function force_pending_on_insert()
returns trigger as $$
begin
  if exists (select 1 from admin_users where user_id = auth.uid()) then
    return new; -- 관리자가 직접 작성 → 입력한 값 그대로 (즉시 게시/공지 고정 가능)
  end if;
  new.status := 'pending';
  new.is_notice := false;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists trg_force_pending on posts;
create trigger trg_force_pending
  before insert on posts
  for each row execute function force_pending_on_insert();

-- 4) RLS 활성화
alter table posts enable row level security;

-- ⚠ 정책 안에서 admin_users를 "직접" 서브쿼리로 참조하면 안 됩니다.
-- admin_users는 RLS가 켜져 있고 일반 로그인 사용자에게 조회 권한이 없어서,
-- 정책 평가 시점에 그 서브쿼리가 항상 빈 결과(= false)로 처리되어 버립니다.
-- 반드시 SECURITY DEFINER 함수인 am_i_admin()을 통해서 확인해야
-- 권한 우회가 정상적으로 적용됩니다.
drop policy if exists "public can read approved posts" on posts;
drop policy if exists "read approved or admin sees all" on posts;
create policy "read approved or admin sees all"
  on posts for select
  using (status = 'approved' or am_i_admin());

-- 직접 테이블 INSERT는 관리자만 가능 (관리자가 board.html에서 즉시 게시할 때 사용).
-- 일반 방문자는 아래 submit_post() 함수를 통해서만 글을 등록할 수 있습니다.
drop policy if exists "public can insert posts" on posts;
drop policy if exists "admin can insert posts" on posts;
create policy "admin can insert posts"
  on posts for insert
  with check (am_i_admin());

drop policy if exists "admin can update posts" on posts;
create policy "admin can update posts"
  on posts for update
  using (am_i_admin());

drop policy if exists "admin can delete posts" on posts;
create policy "admin can delete posts"
  on posts for delete
  using (am_i_admin());

-- 5) Cloudflare Turnstile(캡차) 서버 검증
--    ⚠ 아래 secret 값을 Cloudflare Turnstile 대시보드에서 발급받은
--    "Secret Key"로 교체한 뒤 이 스크립트를 실행하세요.
create or replace function verify_turnstile(token text)
returns boolean as $$
declare
  secret text := 'YOUR_TURNSTILE_SECRET_KEY';
  resp http_response;
  ok boolean;
begin
  if token is null or length(token) = 0 then
    return false;
  end if;
  select * into resp from http_post(
    'https://challenges.cloudflare.com/turnstile/v0/siteverify',
    'secret=' || secret || '&response=' || token,
    'application/x-www-form-urlencoded'
  );
  ok := (resp.content::jsonb ->> 'success')::boolean;
  return coalesce(ok, false);
exception when others then
  return false;
end;
$$ language plpgsql security definer;

-- 6) 일반 방문자의 글 등록 (캡차 통과 필수, 항상 "대기중"으로 저장됨)
create or replace function submit_post(
  p_name text, p_category text, p_title text, p_content text,
  p_youtube_url text, p_image_urls text[], p_turnstile_token text
)
returns posts as $$
declare
  result posts;
begin
  if trim(coalesce(p_name,'')) = '' or trim(coalesce(p_title,'')) = '' or trim(coalesce(p_content,'')) = '' then
    raise exception '이름/제목/내용을 모두 입력해 주세요';
  end if;
  if not verify_turnstile(p_turnstile_token) then
    raise exception '자동 등록 방지 확인에 실패했습니다. 새로고침 후 다시 시도해 주세요.';
  end if;
  insert into posts (name, category, title, content, youtube_url, image_urls)
  values (p_name, p_category, p_title, p_content, p_youtube_url, coalesce(p_image_urls, '{}'))
  returning * into result;
  return result;
end;
$$ language plpgsql security definer;

-- 7) 게시글 이미지용 Storage 버킷 (5MB, 이미지 형식 제한)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('board-images', 'board-images', true, 5242880, array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg','image/png','image/webp','image/gif'];

-- 누구나 board-images 버킷에 업로드 가능 (글 등록 전에 사진을 먼저 올려야 하므로).
-- 버킷 자체의 용량/형식 제한이 남용을 막아줍니다.
drop policy if exists "public can upload board images" on storage.objects;
create policy "public can upload board images"
  on storage.objects for insert
  with check (bucket_id = 'board-images');

-- 누구나 board-images 파일 읽기 가능 (공개 버킷)
drop policy if exists "public can read board images" on storage.objects;
create policy "public can read board images"
  on storage.objects for select
  using (bucket_id = 'board-images');

-- ═══════════════════════════════════════════════════════════
-- 8) 관리자 계정 등록 (이 스크립트 실행 후 아래 안내에 따라 별도로 진행)
--
-- 1. Supabase 대시보드 → Authentication → Users → "Add user"에서
--    관리자 이메일/비밀번호로 계정을 만듭니다. (Auto Confirm User 체크)
-- 2. 아래 쿼리의 이메일 부분을 방금 만든 계정 이메일로 바꿔서
--    SQL Editor에서 한 번 실행하면 관리자 권한이 부여됩니다.
--
--   insert into admin_users (user_id)
--   select id from auth.users where email = 'admin@example.com';
--
-- ═══════════════════════════════════════════════════════════
