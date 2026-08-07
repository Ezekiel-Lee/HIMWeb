-- ═══════════════════════════════════════════════════════════
-- HiM 게시판(board.html) — Supabase 스키마
-- Supabase 프로젝트 → SQL Editor → 새 쿼리에 전체 붙여넣고 Run
-- (한 번만 실행하면 됩니다)
-- ═══════════════════════════════════════════════════════════

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

-- 일반 사용자가 테이블에 직접 INSERT 하더라도 항상 "대기중" 상태로만
-- 들어가도록 강제하는 트리거 (승인/공지 고정은 반드시 아래 관리자 함수로만 가능)
create or replace function force_pending_on_insert()
returns trigger as $$
begin
  new.status := 'pending';
  new.is_notice := false;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_force_pending on posts;
create trigger trg_force_pending
  before insert on posts
  for each row execute function force_pending_on_insert();

-- 2) RLS 활성화
alter table posts enable row level security;

-- 누구나 "승인됨" 게시글만 조회 가능
drop policy if exists "public can read approved posts" on posts;
create policy "public can read approved posts"
  on posts for select
  using (status = 'approved');

-- 누구나 새 글을 등록 가능 (트리거가 강제로 pending 처리)
drop policy if exists "public can insert posts" on posts;
create policy "public can insert posts"
  on posts for insert
  with check (true);

-- 직접 UPDATE/DELETE 는 막아둠 (관리자 전용 함수로만 처리)

-- 3) 관리자 비밀번호 확인 + 승인/거절/즉시게시용 함수
--    ⚠ 'Genesis11' 부분을 board.html / admin.html 과 동일한 값으로 바꿔서 실행하세요.
create or replace function admin_check_password(pw text)
returns boolean as $$
begin
  return pw = 'Genesis11';
end;
$$ language plpgsql security definer;

-- 대기중인 글 목록 (관리자 전용, 비밀번호 필요)
create or replace function admin_list_pending(pw text)
returns setof posts as $$
begin
  if not admin_check_password(pw) then
    raise exception '비밀번호가 올바르지 않습니다';
  end if;
  return query select * from posts where status = 'pending' order by created_at desc;
end;
$$ language plpgsql security definer;

create or replace function admin_approve_post(post_id uuid, pw text)
returns void as $$
begin
  if not admin_check_password(pw) then
    raise exception '비밀번호가 올바르지 않습니다';
  end if;
  update posts set status = 'approved' where id = post_id;
end;
$$ language plpgsql security definer;

create or replace function admin_reject_post(post_id uuid, pw text)
returns void as $$
begin
  if not admin_check_password(pw) then
    raise exception '비밀번호가 올바르지 않습니다';
  end if;
  delete from posts where id = post_id;
end;
$$ language plpgsql security definer;

-- 관리자가 직접 작성 시 즉시 게시(+ 공지 고정 가능)
create or replace function admin_create_post(
  p_name text, p_category text, p_title text, p_content text,
  p_youtube_url text, p_image_urls text[], p_is_notice boolean, pw text
)
returns posts as $$
declare
  result posts;
begin
  if not admin_check_password(pw) then
    raise exception '비밀번호가 올바르지 않습니다';
  end if;
  insert into posts (name, category, title, content, youtube_url, image_urls, is_notice, status)
  values (p_name, p_category, p_title, p_content, p_youtube_url, coalesce(p_image_urls, '{}'), p_is_notice, 'approved')
  returning * into result;
  return result;
end;
$$ language plpgsql security definer;

-- 4) 게시글 이미지용 Storage 버킷
insert into storage.buckets (id, name, public)
values ('board-images', 'board-images', true)
on conflict (id) do nothing;

-- 누구나 board-images 버킷에 업로드 가능 (게시판 특성상 승인 전 이미지도 미리 올려야 함)
drop policy if exists "public can upload board images" on storage.objects;
create policy "public can upload board images"
  on storage.objects for insert
  with check (bucket_id = 'board-images');

-- 누구나 board-images 파일 읽기 가능 (공개 버킷)
drop policy if exists "public can read board images" on storage.objects;
create policy "public can read board images"
  on storage.objects for select
  using (bucket_id = 'board-images');