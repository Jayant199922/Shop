-- Run this entire script in Supabase > SQL Editor.
create extension if not exists pgcrypto;
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role text not null check (role in ('owner','worker')) default 'worker',
  created_at timestamptz not null default now()
);
create table if not exists public.daily_entries (
  id uuid primary key default gen_random_uuid(),
  business_date date not null default current_date,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  sbi numeric(14,2) not null default 0,
  mp_online numeric(14,2) not null default 0,
  fino numeric(14,2) not null default 0,
  cash numeric(14,2) not null default 0,
  total_balance numeric(14,2) not null default 0,
  sbi_tx text,
  mp_tx text,
  fino_tx text,
  remarks text,
  status text not null default 'submitted' check (status in ('submitted','correction_required','approved')),
  correction_note text,
  approved_by uuid references auth.users(id),
  approved_at timestamptz
);
create table if not exists public.entry_history (
  id bigint generated always as identity primary key,
  entry_id uuid not null references public.daily_entries(id) on delete cascade,
  changed_by uuid not null references auth.users(id),
  changed_at timestamptz not null default now(),
  old_status text,
  new_status text,
  change_note text
);
create or replace function public.is_owner() returns boolean language sql security definer set search_path=public as $$
  select exists(select 1 from public.profiles where id=auth.uid() and role='owner');
$$;
create or replace function public.guard_entry_update() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if public.is_owner() then
    if new.status='approved' then new.approved_by=auth.uid(); new.approved_at=coalesce(new.approved_at,now()); end if;
    new.updated_at=now(); return new;
  end if;
  if old.created_by <> auth.uid() then raise exception 'You can only edit your own entries'; end if;
  if old.status <> 'correction_required' then raise exception 'This entry is locked. Only entries requiring correction can be edited.'; end if;
  if new.status <> 'submitted' then raise exception 'Workers can only resubmit an entry'; end if;
  if new.created_by <> old.created_by or new.id <> old.id or new.approved_by is not null or new.approved_at is not null then raise exception 'Protected fields cannot be changed'; end if;
  new.correction_note=null; new.updated_at=now(); return new;
end; $$;
drop trigger if exists daily_entry_guard on public.daily_entries;
create trigger daily_entry_guard before update on public.daily_entries for each row execute function public.guard_entry_update();
create or replace function public.log_entry_history() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.entry_history(entry_id,changed_by,old_status,new_status,change_note)
  values(new.id,auth.uid(),case when tg_op='INSERT' then null else old.status end,new.status,new.correction_note);
  return new;
end; $$;
drop trigger if exists daily_entry_history on public.daily_entries;
create trigger daily_entry_history after insert or update on public.daily_entries for each row execute function public.log_entry_history();
alter table public.profiles enable row level security;
alter table public.daily_entries enable row level security;
alter table public.entry_history enable row level security;
drop policy if exists "read own profile or owner reads all" on public.profiles;
create policy "read own profile or owner reads all" on public.profiles for select using (id=auth.uid() or public.is_owner());
drop policy if exists "owner manages profiles" on public.profiles;
create policy "owner manages profiles" on public.profiles for all using (public.is_owner()) with check (public.is_owner());
drop policy if exists "workers create own entries" on public.daily_entries;
create policy "workers create own entries" on public.daily_entries for insert with check (created_by=auth.uid() and status='submitted' and approved_by is null and approved_at is null);
drop policy if exists "workers and owner read entries" on public.daily_entries;
create policy "workers and owner read entries" on public.daily_entries for select using (created_by=auth.uid() or public.is_owner());
drop policy if exists "owner or correction owner update" on public.daily_entries;
create policy "owner or correction owner update" on public.daily_entries for update using (public.is_owner() or (created_by=auth.uid() and status='correction_required')) with check (public.is_owner() or (created_by=auth.uid() and status='submitted'));
drop policy if exists "read own history or owner" on public.entry_history;
create policy "read own history or owner" on public.entry_history for select using (public.is_owner() or exists(select 1 from public.daily_entries d where d.id=entry_id and d.created_by=auth.uid()));
-- History rows are written only by the database trigger; do not grant direct client writes.
