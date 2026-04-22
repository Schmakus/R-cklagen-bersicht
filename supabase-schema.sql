-- Tabellen erstellen
-- Hinweis: Das Startdatum der Rate (start_datum) kann beim Insert explizit gesetzt werden.
-- Beispiel für ein Update einer Rate:
-- update raten set betrag = 100, start_datum = '2026-03-01' where id = '...';
create table posten (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null default auth.uid(),
  name text not null,
  ziel_betrag numeric(12,2) default 0,
  laufzeit_monate int default 1,
  created_at timestamptz default now(),
  typ text not null default 'ruecklage',
  kredit_betrag numeric(12,2),
  konto text not null default 'Rücklagen',
  archiviert boolean not null default false
);

create table raten (
  id uuid default gen_random_uuid() primary key,
  posten_id uuid references posten(id) on delete cascade,
  betrag numeric(12,2) not null,
  start_datum date not null default current_date
);

create table faelligkeiten (
  id uuid default gen_random_uuid() primary key,
  posten_id uuid references posten(id) on delete cascade,
  tag smallint not null check (tag between 1 and 31),
  monat smallint not null check (monat between 1 and 12),
  betrag numeric(12,2) not null
);

create table transaktionen (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null default auth.uid(),
  posten_id uuid references posten(id) on delete cascade,
  betrag numeric(12,2) not null,
  typ text check (typ in ('einzahlung', 'auszahlung')),
  datum date not null default current_date,
  notiz text
);

alter table posten enable row level security;
alter table raten enable row level security;
alter table faelligkeiten enable row level security;
alter table transaktionen enable row level security;

create policy "User can manage their own posten" on posten for all using (auth.uid() = user_id);
create policy "User can manage their own raten" on raten for all using (
  posten_id in (select id from posten where user_id = auth.uid())
);
create policy "User can manage their own faelligkeiten" on faelligkeiten for all using (
  posten_id in (select id from posten where user_id = auth.uid())
);
create policy "User can manage their own transaktionen" on transaktionen for all using (
  posten_id in (select id from posten where user_id = auth.uid())
);
-- Einzigartigkeit für "Allgemein" pro Nutzer erzwingen
ALTER TABLE posten ADD CONSTRAINT unique_user_allgemein UNIQUE (user_id, name);

-- Keep-alive table (accessed via service role, no RLS needed)
create table keep_alive (
  id uuid primary key default '00000000-0000-0000-0000-000000000001',
  pinged_at timestamptz not null default now()
);

-- Seed the single row that the GitHub Action will PATCH
insert into keep_alive (id, pinged_at)
values ('00000000-0000-0000-0000-000000000001', now())
on conflict (id) do nothing;