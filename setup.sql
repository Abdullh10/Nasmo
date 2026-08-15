-- ============================================================
--  Nasmo — إعداد قاعدة بيانات Supabase من الصفر
--  نفّذ هذا الملف كاملاً مرة واحدة في SQL Editor داخل Supabase
--  (Database > SQL Editor > New query > الصق الكود > Run)
-- ============================================================

-- ── 1. حذف الجداول القديمة (إن وُجدت) ──────────────────────
drop table if exists visit_schedules  cascade;
drop table if exists students         cascade;
drop table if exists practice_shares  cascade;
drop table if exists plc_goals        cascade;
drop table if exists tasks            cascade;
drop table if exists indicator_status cascade;
drop table if exists notifications    cascade;
drop table if exists submissions      cascade;
drop table if exists app_settings     cascade;
drop table if exists site_settings    cascade;
drop table if exists profiles         cascade;
drop table if exists communities      cascade;

-- ── 2. حذف الدوال المساعدة القديمة (إن وُجدت) ──────────────
drop function if exists my_role();
drop function if exists my_school();

-- ── 3. إنشاء الجداول ─────────────────────────────────────────

-- المجتمعات المهنية
create table communities (
  id           uuid primary key default gen_random_uuid(),
  school       text not null,
  name         text not null,
  meeting_day  text,
  meeting_time text,
  created_at   timestamptz default now()
);

-- حسابات المستخدمين (id يطابق auth.users.id تلقائيًا)
create table profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  username     text unique not null,
  full_name    text not null,
  role         text not null check (role in ('coordinator','principal','teacher','admin')),
  school       text not null,
  community_id uuid references communities(id),
  specialty    text,
  phone        text,
  email        text,
  created_at   timestamptz default now()
);

-- الإشعارات
create table notifications (
  id          uuid primary key default gen_random_uuid(),
  school      text not null,
  sender_id   uuid references profiles(id),
  sender_name text,
  target_type text not null check (target_type in ('school','community','user')),
  target_id   uuid,
  type        text not null default 'general' check (type in ('meeting','submission','demo','general')),
  title       text not null,
  body        text,
  due_date    date,
  read_by     jsonb default '[]'::jsonb,
  created_at  timestamptz default now()
);

-- النماذج المُدخَلة
create table submissions (
  id                  uuid primary key default gen_random_uuid(),
  form_type           text not null,
  school              text not null,
  created_by          uuid references profiles(id),
  created_by_name     text,
  payload             jsonb not null,
  status              text not null default 'draft',
  preparer_signature  text,
  principal_signature text,
  principal_comment   text,
  principal_rating    int check (principal_rating between 0 and 100),
  principal_note      text,
  submitted_at        timestamptz,
  approved_at         timestamptz,
  created_at          timestamptz default now(),
  updated_at          timestamptz default now()
);

-- المهام
create table tasks (
  id                     uuid primary key default gen_random_uuid(),
  school                 text not null,
  community_id           uuid references communities(id),
  created_by             uuid references profiles(id),
  created_by_name        text,
  assigned_to            uuid references profiles(id),
  assigned_to_name       text,
  title                  text not null,
  description            text,
  due_date               date,
  status                 text not null default 'pending' check (status in ('pending','done')),
  teacher_notes          text,
  evidence_files         jsonb default '[]'::jsonb,
  completed_at           timestamptz,
  principal_status       text check (principal_status in ('approved','returned')),
  principal_rating       int check (principal_rating between 0 and 100),
  principal_note         text,
  principal_reviewed_at  timestamptz,
  coordinator_status     text check (coordinator_status in ('returned')),
  coordinator_note       text,
  coordinator_reviewed_at timestamptz,
  created_at             timestamptz default now()
);

-- إعدادات المدرسة
create table app_settings (
  school            text primary key,
  semester_start    date,
  current_semester  text default '2'
);

-- حالة مؤشرات البرنامج
create table indicator_status (
  id           uuid primary key default gen_random_uuid(),
  school       text not null,
  indicator_id text not null,
  done         boolean default false,
  done_by      text,
  done_at      timestamptz,
  unique (school, indicator_id)
);

-- إعدادات الموقع العامة
create table site_settings (
  id               text primary key default 'global',
  program_title    text,
  program_subtitle text,
  academic_year    text
);

-- خطط التحسين الفصلية
create table plc_goals (
  id                    uuid primary key default gen_random_uuid(),
  school                text not null,
  community_id          uuid references communities(id),
  semester              text not null,
  title                 text not null,
  measure_unit          text,
  baseline_value        numeric,
  target_value          numeric,
  current_value         numeric,
  due_date              date,
  status                text not null default 'active' check (status in ('active','achieved','missed')),
  category              text not null default 'academic' check (category in ('academic','teacherSupport','knowledgeSharing')),
  created_by            uuid references profiles(id),
  created_by_name       text,
  principal_status      text check (principal_status in ('approved','returned')),
  principal_rating      int check (principal_rating between 0 and 100),
  principal_note        text,
  principal_reviewed_at timestamptz,
  assigned_member_ids   jsonb default '[]'::jsonb,
  evidence_files        jsonb default '[]'::jsonb,
  created_at            timestamptz default now(),
  updated_at            timestamptz default now()
);

-- بنك تبادل الخبرات
create table practice_shares (
  id                    uuid primary key default gen_random_uuid(),
  school                text not null,
  community_id          uuid references communities(id),
  created_by            uuid references profiles(id),
  created_by_name       text,
  category              text not null default 'teacherSupport' check (category in ('academic','teacherSupport','knowledgeSharing')),
  title                 text not null,
  description           text,
  attachment_note       text,
  attachments           jsonb default '[]'::jsonb,
  status                text not null default 'pending' check (status in ('pending','approved','returned')),
  principal_rating      int check (principal_rating between 0 and 100),
  principal_note        text,
  principal_reviewed_at timestamptz,
  created_at            timestamptz default now(),
  updated_at            timestamptz default now()
);

-- بيانات الطلاب
create table students (
  id                  uuid primary key default gen_random_uuid(),
  school              text not null,
  created_by          uuid references profiles(id),
  created_by_name     text,
  full_name           text not null,
  grade               text,
  section             text,
  national_id         text,
  notes               text,
  assigned_teacher_ids jsonb default '[]'::jsonb,
  created_at          timestamptz default now()
);

-- جداول الزيارات التبادلية
create table visit_schedules (
  id              uuid primary key default gen_random_uuid(),
  school          text not null,
  community_id    uuid references communities(id),
  created_by      uuid references profiles(id),
  created_by_name text,
  status          text not null default 'sent' check (status in ('sent')),
  rows            jsonb default '[]'::jsonb,
  created_at      timestamptz default now()
);

-- ── 4. الدوال المساعدة (تقرأ دور/مدرسة المستخدم الحالي) ──────
create or replace function my_role()
returns text language sql security definer stable as $$
  select role from profiles where id = auth.uid()
$$;

create or replace function my_school()
returns text language sql security definer stable as $$
  select school from profiles where id = auth.uid()
$$;

-- ── 5. تفعيل Row Level Security على جميع الجداول ─────────────
alter table profiles         enable row level security;
alter table communities      enable row level security;
alter table notifications    enable row level security;
alter table submissions      enable row level security;
alter table tasks            enable row level security;
alter table app_settings     enable row level security;
alter table indicator_status enable row level security;
alter table site_settings    enable row level security;
alter table plc_goals        enable row level security;
alter table practice_shares  enable row level security;
alter table students         enable row level security;
alter table visit_schedules  enable row level security;

-- ── 6. سياسات الأمان (RLS Policies) ──────────────────────────

-- profiles
create policy "profiles_select" on profiles
  for select using ( id = auth.uid() or my_role() = 'admin' or school = my_school() );

-- فقط مدير النظام يستطيع إضافة مستخدمين جدد
-- (حساب admin الأول يُضاف يدوياً عبر SQL Editor — انظر الخطوة 7 أدناه)
create policy "profiles_insert" on profiles
  for insert with check ( my_role() = 'admin' );

create policy "profiles_update" on profiles
  for update using (
    id = auth.uid() or my_role() = 'admin'
    or (my_role() = 'coordinator' and role = 'teacher' and school = my_school())
  ) with check (
    id = auth.uid() or my_role() = 'admin'
    or (my_role() = 'coordinator' and role = 'teacher' and school = my_school())
  );

create policy "profiles_delete" on profiles
  for delete using ( my_role() = 'admin' );

-- communities
create policy "communities_select" on communities
  for select using ( school = my_school() or my_role() = 'admin' );
create policy "communities_write" on communities
  for all using ( my_role() = 'admin' ) with check ( my_role() = 'admin' );

-- notifications
create policy "notifications_select" on notifications
  for select using ( school = my_school() or my_role() = 'admin' );
create policy "notifications_insert" on notifications
  for insert with check ( school = my_school() or my_role() = 'admin' );
create policy "notifications_update" on notifications
  for update using ( school = my_school() or my_role() = 'admin' )
  with check ( school = my_school() or my_role() = 'admin' );

-- submissions
create policy "submissions_all" on submissions
  for all using ( school = my_school() or my_role() = 'admin' )
  with check ( school = my_school() or my_role() = 'admin' );

-- tasks
create policy "tasks_all" on tasks
  for all using ( school = my_school() or my_role() = 'admin' )
  with check ( school = my_school() or my_role() = 'admin' );

-- app_settings
create policy "app_settings_all" on app_settings
  for all using ( school = my_school() or my_role() = 'admin' )
  with check ( school = my_school() or my_role() = 'admin' );

-- indicator_status
create policy "indicator_status_all" on indicator_status
  for all using ( school = my_school() or my_role() = 'admin' )
  with check ( school = my_school() or my_role() = 'admin' );

-- site_settings
create policy "site_settings_select" on site_settings
  for select using ( true );
create policy "site_settings_write" on site_settings
  for all using ( my_role() = 'admin' ) with check ( my_role() = 'admin' );

-- plc_goals
create policy "plc_goals_all" on plc_goals
  for all using ( school = my_school() or my_role() = 'admin' )
  with check ( school = my_school() or my_role() = 'admin' );

-- practice_shares
create policy "practice_shares_all" on practice_shares
  for all using ( school = my_school() or my_role() = 'admin' )
  with check ( school = my_school() or my_role() = 'admin' );

-- students
create policy "students_all" on students
  for all using ( school = my_school() or my_role() = 'admin' )
  with check ( school = my_school() or my_role() = 'admin' );

-- visit_schedules
create policy "visit_schedules_all" on visit_schedules
  for all using ( school = my_school() or my_role() = 'admin' )
  with check ( school = my_school() or my_role() = 'admin' );

-- ── 7. إنشاء حساب مدير النظام (admin) ──────────────────────
--
--  الخطوات (بعد تشغيل كل ما فوق):
--
--  أ) اذهب إلى: Authentication > Users > Add user
--     البريد الإلكتروني : admin@nasmo.local
--     كلمة المرور       : اختر كلمة مرور قوية (أو 1234 للتجربة)
--     ✅ فعّل "Auto Confirm User"
--     ثم اضغط "Create User" وانسخ الـ UUID الذي يظهر.
--
--  ب) عُد إلى SQL Editor وشغّل الأمر التالي بعد تبديل <UUID-هنا>:
--
-- insert into profiles (id, username, full_name, role, school)
-- values (
--   '<UUID-هنا>',
--   'admin',
--   'مدير نظام المنصة',
--   'admin',
--   'المدرسة'
-- );
--
-- ============================================================
