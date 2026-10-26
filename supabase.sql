-- Pingpaar – Datenbank
-- Einmal komplett im Supabase SQL Editor ausführen (New query → einfügen → Run).

-- 1) Tabellen ------------------------------------------------------------

create table if not exists public.couples (
  id          uuid primary key default gen_random_uuid(),
  invite_code text unique not null,
  created_by  uuid references auth.users(id) on delete set null,
  created_at  timestamptz not null default now()
);

create table if not exists public.couple_members (
  couple_id uuid not null references public.couples(id) on delete cascade,
  user_id   uuid not null references auth.users(id) on delete cascade,
  slot      text not null check (slot in ('a','b')),
  joined_at timestamptz not null default now(),
  primary key (couple_id, user_id),
  unique (couple_id, slot),
  unique (user_id)
);

-- Alle gemeinsamen Daten eines Paares, ein Eintrag pro Bereich
-- (z. B. "spots", "wishes", "pet") und pro Bild ("img-…").
-- Einträge "priv:<Nutzer-ID>" (private Kalender) sieht nur dieser Nutzer.
create table if not exists public.couple_data (
  couple_id  uuid not null references public.couples(id) on delete cascade,
  key        text not null,
  value      jsonb,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  primary key (couple_id, key)
);

-- 2) Hilfsfunktion: Gehört der eingeloggte Nutzer zu diesem Paar? --------

create or replace function public.is_member(cid uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.couple_members m where m.couple_id = cid and m.user_id = auth.uid());
$$;

-- 3) Zugriffsregeln: Jeder sieht nur die Daten seines eigenen Paares -----

alter table public.couples        enable row level security;
alter table public.couple_members enable row level security;
alter table public.couple_data    enable row level security;

drop policy if exists "couples lesen" on public.couples;
create policy "couples lesen" on public.couples
  for select using (public.is_member(id));

drop policy if exists "mitglieder lesen" on public.couple_members;
create policy "mitglieder lesen" on public.couple_members
  for select using (public.is_member(couple_id));

drop policy if exists "daten lesen" on public.couple_data;
create policy "daten lesen" on public.couple_data
  for select using (public.is_member(couple_id) and (key not like 'priv:%' or key = 'priv:' || auth.uid()::text));

drop policy if exists "daten anlegen" on public.couple_data;
create policy "daten anlegen" on public.couple_data
  for insert with check (public.is_member(couple_id) and updated_by = auth.uid() and (key not like 'priv:%' or key = 'priv:' || auth.uid()::text));

drop policy if exists "daten ändern" on public.couple_data;
create policy "daten ändern" on public.couple_data
  for update using (public.is_member(couple_id) and (key not like 'priv:%' or key = 'priv:' || auth.uid()::text)) with check (public.is_member(couple_id) and updated_by = auth.uid() and (key not like 'priv:%' or key = 'priv:' || auth.uid()::text));

drop policy if exists "daten löschen" on public.couple_data;
create policy "daten löschen" on public.couple_data
  for delete using (public.is_member(couple_id) and (key not like 'priv:%' or key = 'priv:' || auth.uid()::text));

-- Paare und Mitgliedschaften werden nur über die Funktionen unten angelegt.

-- 4) Funktionen ----------------------------------------------------------

-- Neues Paar anlegen (der Nutzer wird Platz "a") und Einladungscode erzeugen
create or replace function public.create_couple()
returns table (couple_id uuid, invite_code text, slot text)
language plpgsql security definer set search_path = public
as $$
declare
  uid uuid := auth.uid();
  cid uuid;
  code text;
  alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  i int;
begin
  if uid is null then raise exception 'not_logged_in'; end if;
  if exists (select 1 from couple_members m where m.user_id = uid) then
    return query select m.couple_id, c.invite_code, m.slot from couple_members m join couples c on c.id = m.couple_id where m.user_id = uid;
    return;
  end if;
  loop
    code := '';
    for i in 1..6 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    code := substr(code, 1, 3) || '-' || substr(code, 4, 3);
    exit when not exists (select 1 from couples where couples.invite_code = code);
  end loop;
  insert into couples (invite_code, created_by) values (code, uid) returning id into cid;
  insert into couple_members (couple_id, user_id, slot) values (cid, uid, 'a');
  return query select cid, code, 'a'::text;
end;
$$;

-- Mit Einladungscode einem Paar beitreten (der Nutzer wird Platz "b").
-- Ein eigenes, noch leeres Paar wird dabei aufgelöst.
create or replace function public.join_couple(code text)
returns table (couple_id uuid, invite_code text, slot text)
language plpgsql security definer set search_path = public
as $$
declare
  uid uuid := auth.uid();
  target uuid;
  own uuid;
  clean text := upper(regexp_replace(coalesce(code, ''), '[^A-Za-z0-9]', '', 'g'));
begin
  if uid is null then raise exception 'not_logged_in'; end if;
  if length(clean) <> 6 then raise exception 'bad_code'; end if;
  select c.id into target from couples c where replace(c.invite_code, '-', '') = clean;
  if target is null then raise exception 'code_not_found'; end if;
  if exists (select 1 from couple_members m where m.couple_id = target and m.user_id = uid) then
    return query select target, c.invite_code, m.slot from couples c join couple_members m on m.couple_id = c.id and m.user_id = uid where c.id = target;
    return;
  end if;
  if (select count(*) from couple_members m where m.couple_id = target) >= 2 then raise exception 'couple_full'; end if;
  select m.couple_id into own from couple_members m where m.user_id = uid;
  if own is not null then
    delete from couple_members m where m.couple_id = own and m.user_id = uid;
    delete from couples c where c.id = own and not exists (select 1 from couple_members m where m.couple_id = own);
  end if;
  insert into couple_members (couple_id, user_id, slot)
    values (target, uid, case when exists (select 1 from couple_members m where m.couple_id = target and m.slot = 'a') then 'b' else 'a' end);
  return query select target, c.invite_code, m.slot from couples c join couple_members m on m.couple_id = c.id and m.user_id = uid where c.id = target;
end;
$$;

-- Verbindung trennen: Der Nutzer verlässt das Paar.
-- Ist danach niemand mehr drin, werden alle Daten des Paares gelöscht.
create or replace function public.leave_couple()
returns void
language plpgsql security definer set search_path = public
as $$
declare
  uid uuid := auth.uid();
  cid uuid;
begin
  select m.couple_id into cid from couple_members m where m.user_id = uid;
  if cid is null then return; end if;
  delete from couple_members m where m.couple_id = cid and m.user_id = uid;
  if not exists (select 1 from couple_members m where m.couple_id = cid) then
    delete from couples c where c.id = cid;
  end if;
end;
$$;

-- Konto komplett löschen (inkl. aller Daten, wenn man allein im Paar ist)
create or replace function public.delete_me()
returns void
language plpgsql security definer set search_path = public, auth
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then return; end if;
  perform public.leave_couple();
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.create_couple() from public, anon;
revoke all on function public.join_couple(text) from public, anon;
revoke all on function public.leave_couple() from public, anon;
revoke all on function public.delete_me() from public, anon;
grant execute on function public.create_couple() to authenticated;
grant execute on function public.join_couple(text) to authenticated;
grant execute on function public.leave_couple() to authenticated;
grant execute on function public.delete_me() to authenticated;

-- 5) Live-Updates: Änderungen des Partners sofort anzeigen ---------------

alter table public.couple_data replica identity full;
alter table public.couple_members replica identity full;
do $$
begin
  begin
    alter publication supabase_realtime add table public.couple_data;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.couple_members;
  exception when duplicate_object then null;
  end;
end $$;

-- 6) Rechte für eingeloggte Nutzer (die Zugriffsregeln oben gelten trotzdem)
grant usage on schema public to authenticated;
grant select on public.couples, public.couple_members to authenticated;
grant select, insert, update, delete on public.couple_data to authenticated;
