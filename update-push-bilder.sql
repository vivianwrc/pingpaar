-- Pingpaar – Ergänzung: Benachrichtigungen + Bilder-Speicher
-- Einmal im Supabase SQL Editor ausführen (New query → einfügen → Run).
-- Ändert nichts an euren bisherigen Daten.

-- A) Geräte, die Benachrichtigungen bekommen möchten ----------------------

create table if not exists public.push_subs (
  endpoint   text primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  p256dh     text not null,
  auth       text not null,
  created_at timestamptz not null default now()
);
alter table public.push_subs enable row level security;
-- Keine direkten Zugriffe: nur über die Funktionen unten.

create or replace function public.save_push_sub(ep text, k text, a text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not_logged_in'; end if;
  delete from push_subs where endpoint = ep;
  insert into push_subs (endpoint, user_id, p256dh, auth) values (ep, auth.uid(), k, a);
end;
$$;

create or replace function public.delete_push_sub(ep text)
returns void
language sql security definer set search_path = public
as $$
  delete from push_subs where endpoint = ep and user_id = auth.uid();
$$;

-- Geräte des eigenen Partners (für die Benachrichtigungs-Funktion)
create or replace function public.partner_push_subs()
returns table (endpoint text, p256dh text, auth text)
language sql stable security definer set search_path = public
as $$
  select s.endpoint, s.p256dh, s.auth
  from couple_members me
  join couple_members p on p.couple_id = me.couple_id and p.user_id <> me.user_id
  join push_subs s on s.user_id = p.user_id
  where me.user_id = auth.uid();
$$;

-- Abgelaufenes Gerät des Partners entfernen
create or replace function public.drop_partner_push(ep text)
returns void
language sql security definer set search_path = public
as $$
  delete from push_subs s using couple_members me, couple_members p
  where me.user_id = auth.uid() and p.couple_id = me.couple_id and p.user_id <> me.user_id
    and s.user_id = p.user_id and s.endpoint = ep;
$$;

revoke all on function public.save_push_sub(text, text, text) from public, anon;
revoke all on function public.delete_push_sub(text) from public, anon;
revoke all on function public.partner_push_subs() from public, anon;
revoke all on function public.drop_partner_push(text) from public, anon;
grant execute on function public.save_push_sub(text, text, text) to authenticated;
grant execute on function public.delete_push_sub(text) to authenticated;
grant execute on function public.partner_push_subs() to authenticated;
grant execute on function public.drop_partner_push(text) to authenticated;

-- B) Bilder-Speicher: privater Ordner pro Paar ---------------------------

insert into storage.buckets (id, name, public)
values ('pingpaar', 'pingpaar', false)
on conflict (id) do nothing;

drop policy if exists "pingpaar bilder lesen" on storage.objects;
create policy "pingpaar bilder lesen" on storage.objects for select to authenticated
  using (bucket_id = 'pingpaar' and public.is_member(((storage.foldername(name))[1])::uuid));

drop policy if exists "pingpaar bilder hochladen" on storage.objects;
create policy "pingpaar bilder hochladen" on storage.objects for insert to authenticated
  with check (bucket_id = 'pingpaar' and public.is_member(((storage.foldername(name))[1])::uuid));

drop policy if exists "pingpaar bilder ersetzen" on storage.objects;
create policy "pingpaar bilder ersetzen" on storage.objects for update to authenticated
  using (bucket_id = 'pingpaar' and public.is_member(((storage.foldername(name))[1])::uuid));

drop policy if exists "pingpaar bilder löschen" on storage.objects;
create policy "pingpaar bilder löschen" on storage.objects for delete to authenticated
  using (bucket_id = 'pingpaar' and public.is_member(((storage.foldername(name))[1])::uuid));
