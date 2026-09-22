-- 001_screenbridge_schema.sql
--
-- Core schema for ScreenBridge. Matches what the mobile app already
-- expects: onboarding_screen.dart calls joinRoom(code) reading
-- room['id'] / room['code'] / room['expires_at'], and home_screen.dart
-- calls uploadScreenshot(imageFile, roomId).
--
-- No Supabase Auth here, by design (see screenbridge-concept.md --
-- "No full auth needed"): this is a private, single-user tool, and
-- the room code/id itself is the access control. Both tables are
-- readable/writable by anyone holding the anon key, which is fine
-- for a personal tool but would NOT be fine if this ever became
-- multi-tenant/public -- flagging that now so it isn't a surprise
-- later.

create extension if not exists pgcrypto;

create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);

create table if not exists public.screenshots (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  image_url text not null,
  -- Written by SupabaseService.uploadScreenshot() alongside image_url
  -- (the storage object's path, e.g. '<roomId>/<timestamp>.png') --
  -- lets a future cleanup job delete the storage object itself, not
  -- just the row, without having to parse it back out of image_url.
  storage_path text,
  created_at timestamptz not null default now()
);

-- Desktop will list/subscribe to a room's screenshots newest-first;
-- this is the index that query actually uses.
create index if not exists screenshots_room_id_created_at_idx
  on public.screenshots (room_id, created_at desc);

alter table public.rooms enable row level security;
alter table public.screenshots enable row level security;

-- Permissive on purpose (see note above). Mobile only ever reads
-- rooms (it never creates one -- see onboarding_screen.dart's own
-- comment, "Mobile never creates rooms"); the insert policy is here
-- for whatever creates rooms on the desktop side once that exists.
create policy "rooms_select_all" on public.rooms
  for select using (true);
create policy "rooms_insert_all" on public.rooms
  for insert with check (true);

create policy "screenshots_select_all" on public.screenshots
  for select using (true);
create policy "screenshots_insert_all" on public.screenshots
  for insert with check (true);

-- Storage bucket for the actual image bytes. Public so
-- getPublicUrl() on the mobile upload and any <img src> on desktop
-- both work without generating signed URLs.
insert into storage.buckets (id, name, public)
values ('screenshots', 'screenshots', true)
on conflict (id) do nothing;

create policy "screenshots_bucket_insert" on storage.objects
  for insert with check (bucket_id = 'screenshots');

create policy "screenshots_bucket_select" on storage.objects
  for select using (bucket_id = 'screenshots');

-- NOTE: no delete policy / cleanup job yet. screenbridge-concept.md's
-- rolling-buffer / 24-48h retention idea isn't implemented here --
-- ask if you want a scheduled Edge Function or a client-side
-- "delete anything older than N hours on load" added next.
