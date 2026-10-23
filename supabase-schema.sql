-- =====================================================================
-- CardUP — schema bazei de date (Supabase / PostgreSQL)
-- Rulează tot fișierul o singură dată în Supabase → SQL Editor → Run.
-- =====================================================================

create schema if not exists private;

-- ---------------------------------------------------------------------
-- 1. Tabele
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  first_name  text not null default '',
  last_name   text not null default '',
  faculty     text not null default '',
  study_year  text not null default 'Anul I',
  card_no     text not null unique,
  theme       text not null default 'navy',
  interests   text[] not null default '{}',
  role        text not null default 'student' check (role in ('student','staff','admin')),
  created_at  timestamptz not null default now()
);

create table if not exists public.events (
  id          uuid primary key default gen_random_uuid(),
  title       text not null check (char_length(title) between 1 and 120),
  category    text not null,
  description text not null default '',
  points      int  not null check (points > 0 and points <= 1000),
  min_level   int  not null default 0 check (min_level between 0 and 3),
  event_date  date,
  place       text not null default '',
  image_path  text,
  active      boolean not null default true,
  created_by  uuid references public.profiles(id),
  created_at  timestamptz not null default now()
);

create table if not exists public.rewards (
  id          uuid primary key default gen_random_uuid(),
  title       text not null check (char_length(title) between 1 and 120),
  type        text not null check (type in ('Produse UPSC','Oportunități')),
  description text not null default '',
  cost        int  not null check (cost > 0 and cost <= 10000),
  min_level   int  not null default 0 check (min_level between 0 and 3),
  stock       int  not null default 0 check (stock >= 0),
  image_path  text,
  active      boolean not null default true,
  created_by  uuid references public.profiles(id),
  created_at  timestamptz not null default now()
);

-- Registrul: fiecare punct acordat și fiecare premiu ales sau ridicat
create table if not exists public.transactions (
  id          uuid primary key default gen_random_uuid(),
  student_id  uuid not null references public.profiles(id) on delete restrict,
  kind        text not null check (kind in ('earn','redeem')),
  event_id    uuid references public.events(id)  on delete set null,
  reward_id   uuid references public.rewards(id) on delete set null,
  title       text not null,                       -- denumirea la momentul operațiunii
  points      int  not null check (points > 0),
  code        text unique,                         -- codul de ridicare (doar la premii)
  status      text not null default 'done' check (status in ('done','pending','used','cancelled')),
  operator_id uuid references public.profiles(id), -- angajatul care a scanat
  created_at  timestamptz not null default now(),
  used_at     timestamptz
);
create unique index if not exists one_earn_per_event
  on public.transactions(student_id, event_id) where kind = 'earn';
create index if not exists tx_student_idx on public.transactions(student_id, created_at desc);
create index if not exists tx_created_idx on public.transactions(created_at desc);

-- ---------------------------------------------------------------------
-- 2. Funcții interne
-- ---------------------------------------------------------------------
create or replace function private.gen_card_no() returns text
language plpgsql as $$
declare c text;
begin
  loop
    c := 'UPSC-' || lpad((floor(random() * 1000000))::int::text, 6, '0');
    exit when not exists (select 1 from public.profiles where card_no = c);
  end loop;
  return c;
end $$;

create or replace function private.stats(p uuid)
returns table(earned int, spent int, reserved int, balance int, level int)
language sql stable as $$
  with s as (
    select
      coalesce(sum(points) filter (where kind = 'earn'), 0)::int                          as earned,
      coalesce(sum(points) filter (where kind = 'redeem' and status = 'used'), 0)::int    as spent,
      coalesce(sum(points) filter (where kind = 'redeem' and status = 'pending'), 0)::int as reserved
    from public.transactions where student_id = p
  )
  select earned, spent, reserved, earned - spent - reserved,
         case when earned >= 300 then 3 when earned >= 150 then 2 when earned >= 50 then 1 else 0 end
  from s;
$$;

create or replace function public.is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role in ('staff','admin'));
$$;

-- Profil creat automat la înregistrare
create or replace function private.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, first_name, last_name, faculty, study_year, card_no)
  values (
    new.id,
    left(coalesce(new.raw_user_meta_data->>'first_name', ''), 60),
    left(coalesce(new.raw_user_meta_data->>'last_name', ''), 60),
    left(coalesce(new.raw_user_meta_data->>'faculty', ''), 100),
    left(coalesce(new.raw_user_meta_data->>'study_year', 'Anul I'), 20),
    private.gen_card_no()
  );
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- ---------------------------------------------------------------------
-- 3. Operațiuni (singura cale de a modifica punctele)
-- ---------------------------------------------------------------------

-- Studentul alege un premiu: punctele se rezervă, stocul scade, primește un cod
create or replace function public.reserve_reward(p_reward uuid)
returns public.transactions
language plpgsql security definer set search_path = public as $$
declare r public.rewards; st record; t public.transactions; c text;
begin
  if auth.uid() is null then raise exception 'Trebuie să fii autentificat.'; end if;
  perform 1 from public.profiles where id = auth.uid() for update;
  select * into r from public.rewards where id = p_reward and active for update;
  if not found then raise exception 'Premiul nu mai este disponibil.'; end if;
  if r.stock <= 0 then raise exception 'Stocul acestui premiu este epuizat.'; end if;
  select * into st from private.stats(auth.uid());
  if st.level < r.min_level then raise exception 'Premiul se deblochează la un nivel mai mare.'; end if;
  if st.balance < r.cost then raise exception 'Nu ai suficiente puncte pentru acest premiu.'; end if;
  loop
    c := 'R-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
    exit when not exists (select 1 from public.transactions where code = c);
  end loop;
  update public.rewards set stock = stock - 1 where id = r.id;
  insert into public.transactions (student_id, kind, reward_id, title, points, code, status)
  values (auth.uid(), 'redeem', r.id, r.title, r.cost, c, 'pending')
  returning * into t;
  return t;
end $$;

-- Anularea unui cod neridicat: punctele și stocul revin
create or replace function public.cancel_reservation(p_tx uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare t public.transactions;
begin
  select * into t from public.transactions where id = p_tx and kind = 'redeem' for update;
  if not found then raise exception 'Codul nu există.'; end if;
  if t.student_id <> auth.uid() and not public.is_staff() then raise exception 'Acces interzis.'; end if;
  if t.status <> 'pending' then raise exception 'Doar codurile neridicate pot fi anulate.'; end if;
  update public.transactions set status = 'cancelled', used_at = now(),
         operator_id = case when public.is_staff() and t.student_id <> auth.uid() then auth.uid() else null end
   where id = p_tx;
  if t.reward_id is not null then update public.rewards set stock = stock + 1 where id = t.reward_id; end if;
end $$;

-- Angajatul scanează un cod de ridicare
create or replace function public.lookup_code(p_code text)
returns json
language plpgsql stable security definer set search_path = public as $$
declare j json;
begin
  if not public.is_staff() then raise exception 'Acces interzis.'; end if;
  select json_build_object(
    'id', t.id, 'code', t.code, 'status', t.status, 'title', t.title, 'points', t.points,
    'created_at', t.created_at, 'used_at', t.used_at,
    'operator', nullif(trim(coalesce(o.first_name,'') || ' ' || coalesce(o.last_name,'')), ''),
    'image_path', r.image_path, 'stock', r.stock,
    'student', json_build_object('id', p.id, 'first_name', p.first_name, 'last_name', p.last_name,
                                 'card_no', p.card_no, 'faculty', p.faculty, 'study_year', p.study_year),
    'balance', (select balance from private.stats(p.id))
  ) into j
  from public.transactions t
  join public.profiles p on p.id = t.student_id
  left join public.rewards r on r.id = t.reward_id
  left join public.profiles o on o.id = t.operator_id
  where t.code = upper(trim(p_code)) and t.kind = 'redeem';
  return j;
end $$;

-- Angajatul confirmă predarea: punctele se retrag definitiv
create or replace function public.confirm_redeem(p_code text)
returns public.transactions
language plpgsql security definer set search_path = public as $$
declare t public.transactions;
begin
  if not public.is_staff() then raise exception 'Acces interzis.'; end if;
  update public.transactions
     set status = 'used', used_at = now(), operator_id = auth.uid()
   where code = upper(trim(p_code)) and kind = 'redeem' and status = 'pending'
  returning * into t;
  if not found then raise exception 'Codul nu există sau a fost deja folosit.'; end if;
  return t;
end $$;

-- Angajatul scanează cardul unui student
create or replace function public.lookup_card(p_card text)
returns json
language plpgsql stable security definer set search_path = public as $$
declare j json;
begin
  if not public.is_staff() then raise exception 'Acces interzis.'; end if;
  select json_build_object(
    'student', json_build_object('id', p.id, 'first_name', p.first_name, 'last_name', p.last_name,
                                 'card_no', p.card_no, 'faculty', p.faculty, 'study_year', p.study_year),
    'earned', s.earned, 'balance', s.balance, 'level', s.level,
    'events_done', coalesce((select json_agg(event_id) from public.transactions
                             where student_id = p.id and kind = 'earn' and event_id is not null), '[]'::json)
  ) into j
  from public.profiles p, private.stats(p.id) s
  where p.card_no = upper(trim(p_card));
  return j;
end $$;

-- Angajatul acordă punctele pentru un eveniment
create or replace function public.award_points(p_card text, p_event uuid)
returns public.transactions
language plpgsql security definer set search_path = public as $$
declare sid uuid; e public.events; t public.transactions;
begin
  if not public.is_staff() then raise exception 'Acces interzis.'; end if;
  select id into sid from public.profiles where card_no = upper(trim(p_card));
  if sid is null then raise exception 'Cardul nu există.'; end if;
  select * into e from public.events where id = p_event and active;
  if not found then raise exception 'Evenimentul nu există sau este arhivat.'; end if;
  begin
    insert into public.transactions (student_id, kind, event_id, title, points, status, operator_id)
    values (sid, 'earn', e.id, e.title, e.points, 'done', auth.uid())
    returning * into t;
  exception when unique_violation then
    raise exception 'Studentul a primit deja punctele pentru acest eveniment.';
  end;
  return t;
end $$;

-- Doar administratorul schimbă rolurile
create or replace function public.set_role(p_user uuid, p_role text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Doar administratorii pot schimba rolurile.';
  end if;
  if p_role not in ('student','staff','admin') then raise exception 'Rol invalid.'; end if;
  if p_user = auth.uid() and p_role <> 'admin' then
    raise exception 'Nu îți poți retrage singur rolul de administrator.';
  end if;
  update public.profiles set role = p_role where id = p_user;
end $$;

-- ---------------------------------------------------------------------
-- 4. Vizualizări (respectă drepturile celui care citește)
-- ---------------------------------------------------------------------
create or replace view public.student_overview with (security_invoker = true) as
select p.id, p.first_name, p.last_name, p.card_no, p.faculty, p.study_year, p.role, p.created_at,
  coalesce(sum(t.points) filter (where t.kind = 'earn'), 0)::int                            as earned,
  coalesce(sum(t.points) filter (where t.kind = 'redeem' and t.status = 'used'), 0)::int    as spent,
  coalesce(sum(t.points) filter (where t.kind = 'redeem' and t.status = 'pending'), 0)::int as reserved,
  count(t.id) filter (where t.kind = 'redeem' and t.status = 'used')::int                   as rewards_taken
from public.profiles p
left join public.transactions t on t.student_id = p.id
group by p.id;

create or replace view public.registry with (security_invoker = true) as
select t.id, t.created_at, t.used_at, t.kind, t.status, t.title, t.points, t.code,
       t.event_id, t.reward_id, t.student_id,
       p.first_name, p.last_name, p.card_no, p.faculty, p.study_year,
       nullif(trim(coalesce(o.first_name,'') || ' ' || coalesce(o.last_name,'')), '') as operator
from public.transactions t
join public.profiles p on p.id = t.student_id
left join public.profiles o on o.id = t.operator_id;

-- ---------------------------------------------------------------------
-- 5. Securitate (Row Level Security)
-- ---------------------------------------------------------------------
alter table public.profiles     enable row level security;
alter table public.events       enable row level security;
alter table public.rewards      enable row level security;
alter table public.transactions enable row level security;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_staff());
drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists events_select on public.events;
create policy events_select on public.events for select to authenticated
  using (active or public.is_staff());
drop policy if exists events_write on public.events;
create policy events_write on public.events for all to authenticated
  using (public.is_staff()) with check (public.is_staff());

drop policy if exists rewards_select on public.rewards;
create policy rewards_select on public.rewards for select to authenticated
  using (active or public.is_staff());
drop policy if exists rewards_write on public.rewards;
create policy rewards_write on public.rewards for all to authenticated
  using (public.is_staff()) with check (public.is_staff());

drop policy if exists tx_select on public.transactions;
create policy tx_select on public.transactions for select to authenticated
  using (student_id = auth.uid() or public.is_staff());
-- Nicio politică de insert/update/delete: punctele se schimbă doar prin funcțiile de mai sus.

-- Vizitatorii neautentificați nu văd nimic
revoke all on public.profiles, public.events, public.rewards, public.transactions,
              public.student_overview, public.registry from anon;

-- Studentul își poate edita doar aceste câmpuri (nu rolul și nici numărul cardului)
revoke update on public.profiles from authenticated;
grant update (first_name, last_name, faculty, study_year, theme, interests) on public.profiles to authenticated;
revoke insert, delete on public.profiles from authenticated;
revoke insert, update, delete on public.transactions from authenticated;

-- Funcții: cine le poate apela
revoke execute on all functions in schema private from public, anon, authenticated;
-- Serviciul de autentificare trebuie să poată rula declanșatorul care creează profilul
grant usage on schema private to supabase_auth_admin;
grant execute on function private.handle_new_user() to supabase_auth_admin;
revoke execute on function public.is_staff(), public.reserve_reward(uuid), public.cancel_reservation(uuid),
  public.lookup_code(text), public.confirm_redeem(text), public.lookup_card(text),
  public.award_points(text, uuid), public.set_role(uuid, text) from public, anon;
grant execute on function public.is_staff(), public.reserve_reward(uuid), public.cancel_reservation(uuid),
  public.lookup_code(text), public.confirm_redeem(text), public.lookup_card(text),
  public.award_points(text, uuid), public.set_role(uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- 6. Fotografii (Storage)
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('media', 'media', true)
on conflict (id) do nothing;

drop policy if exists media_staff_insert on storage.objects;
create policy media_staff_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'media' and public.is_staff());
drop policy if exists media_staff_update on storage.objects;
create policy media_staff_update on storage.objects for update to authenticated
  using (bucket_id = 'media' and public.is_staff());
drop policy if exists media_staff_delete on storage.objects;
create policy media_staff_delete on storage.objects for delete to authenticated
  using (bucket_id = 'media' and public.is_staff());

-- ---------------------------------------------------------------------
-- 7. Actualizări în timp real (studentul vede imediat punctele scanate)
-- ---------------------------------------------------------------------
do $$
begin
  alter publication supabase_realtime add table public.transactions;
exception when duplicate_object then null;
end $$;
