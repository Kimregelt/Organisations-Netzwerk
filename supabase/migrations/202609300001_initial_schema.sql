create extension if not exists pgcrypto;

create type public.unit_type as enum ('dezernat','sachgebiet','geschaeftsbereich','externe_organisationseinheit');
create type public.task_source as enum ('GVP','Veranstaltung');
create type public.event_status as enum ('draft','active','closed','archived');
create type public.relation_type as enum ('fachliche_verbindung');

create table public.datasets (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  effective_date date,
  source_file text,
  source_reference text,
  active boolean not null default true,
  imported_at timestamptz not null default now(),
  unique (name, effective_date)
);

create table public.organization_units (
  id uuid primary key default gen_random_uuid(),
  dataset_id uuid references public.datasets(id) on delete restrict,
  external_id text,
  unit_type public.unit_type not null,
  name text not null,
  short_name text,
  internal boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (dataset_id, external_id)
);

create table public.topics (
  id uuid primary key default gen_random_uuid(),
  dataset_id uuid not null references public.datasets(id) on delete restrict,
  external_id text not null,
  department_no text not null,
  oz text not null,
  original_name text not null,
  display_name text not null,
  source text not null default 'GVP',
  pointer_raw text,
  pdf_page integer,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (dataset_id, external_id),
  unique (dataset_id, department_no, oz)
);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  dataset_id uuid references public.datasets(id) on delete restrict,
  external_id text,
  source public.task_source not null,
  department_id uuid not null references public.organization_units(id) on delete restrict,
  subject_area_id uuid not null references public.organization_units(id) on delete restrict,
  topic_id uuid references public.topics(id) on delete set null,
  oz text,
  original_name text not null,
  display_name text not null,
  pointer_raw text,
  pdf_page integer,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint tasks_gvp_origin_ck check (
    (source = 'GVP' and dataset_id is not null and external_id is not null and oz is not null)
    or
    (source = 'Veranstaltung' and external_id is null and oz is null)
  ),
  unique (dataset_id, external_id)
);

create table public.hierarchy_edges (
  id uuid primary key default gen_random_uuid(),
  dataset_id uuid not null references public.datasets(id) on delete restrict,
  source_external_id text not null,
  target_external_id text not null,
  source_kind text not null check (source_kind in ('organization_unit','topic','task')),
  target_kind text not null check (target_kind in ('organization_unit','topic','task')),
  provenance text not null default 'GVP',
  note text,
  created_at timestamptz not null default now(),
  unique (dataset_id, source_external_id, target_external_id)
);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  event_date date,
  status public.event_status not null default 'draft',
  public_slug text not null unique,
  created_at timestamptz not null default now()
);

create table public.capture_sessions (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete restrict,
  auth_user_id uuid not null,
  department_id uuid not null references public.organization_units(id) on delete restrict,
  subject_area_id uuid not null references public.organization_units(id) on delete restrict,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (event_id, auth_user_id)
);

create table public.professional_relations (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete restrict,
  capture_session_id uuid not null references public.capture_sessions(id) on delete restrict,
  source_task_id uuid not null references public.tasks(id) on delete restrict,
  target_kind text not null check (target_kind in ('task','organization_unit')),
  target_task_id uuid references public.tasks(id) on delete restrict,
  target_organization_unit_id uuid references public.organization_units(id) on delete restrict,
  relation_type public.relation_type not null default 'fachliche_verbindung',
  directed boolean not null default false,
  strength smallint check (strength between 1 and 5),
  comment text,
  created_at timestamptz not null default now(),
  constraint professional_relation_target_ck check (
    (target_kind='task' and target_task_id is not null and target_organization_unit_id is null)
    or
    (target_kind='organization_unit' and target_task_id is null and target_organization_unit_id is not null)
  )
);

create index tasks_department_idx on public.tasks(department_id);
create index tasks_subject_area_idx on public.tasks(subject_area_id);
create index tasks_topic_idx on public.tasks(topic_id);
create index topics_dataset_oz_idx on public.topics(dataset_id, department_no, oz);
create index hierarchy_edges_dataset_idx on public.hierarchy_edges(dataset_id);
create index professional_relations_event_idx on public.professional_relations(event_id);
create index professional_relations_source_idx on public.professional_relations(source_task_id);
create index professional_relations_target_task_idx on public.professional_relations(target_task_id);
create index capture_sessions_auth_idx on public.capture_sessions(auth_user_id);

alter table public.datasets enable row level security;
alter table public.organization_units enable row level security;
alter table public.topics enable row level security;
alter table public.tasks enable row level security;
alter table public.hierarchy_edges enable row level security;
alter table public.events enable row level security;
alter table public.capture_sessions enable row level security;
alter table public.professional_relations enable row level security;

revoke all on all tables in schema public from anon, authenticated;
grant select on public.datasets, public.organization_units, public.topics, public.tasks, public.hierarchy_edges, public.events to authenticated;
grant insert on public.tasks, public.capture_sessions, public.professional_relations to authenticated;
grant select, update on public.capture_sessions to authenticated;
grant select on public.professional_relations to authenticated;

create policy datasets_read on public.datasets for select to authenticated using (true);
create policy units_read on public.organization_units for select to authenticated using (true);
create policy topics_read on public.topics for select to authenticated using (true);
create policy hierarchy_read on public.hierarchy_edges for select to authenticated using (true);
create policy events_read on public.events for select to authenticated using (status in ('active','closed'));
create policy tasks_read on public.tasks for select to authenticated using (true);
create policy tasks_event_insert on public.tasks for insert to authenticated with check (source='Veranstaltung' and dataset_id is null and external_id is null and oz is null);

create policy sessions_read_own on public.capture_sessions for select to authenticated using (auth.uid() = auth_user_id);
create policy sessions_insert_own on public.capture_sessions for insert to authenticated with check (auth.uid() = auth_user_id);
create policy sessions_update_own on public.capture_sessions for update to authenticated using (auth.uid() = auth_user_id) with check (auth.uid() = auth_user_id);

create policy relations_read on public.professional_relations for select to authenticated using (true);
create policy relations_insert_own_session on public.professional_relations for insert to authenticated with check (
  exists (
    select 1 from public.capture_sessions s
    where s.id = capture_session_id and s.auth_user_id = auth.uid() and s.event_id = event_id
  )
);
