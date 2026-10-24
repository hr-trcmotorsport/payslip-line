-- รันใน Supabase → SQL Editor ครั้งเดียว

create table if not exists employees (
  emp_code          text primary key,
  line_user_id      text unique not null,
  national_id_hash  text not null,
  pdf_password_enc  text not null,
  active            boolean not null default true,
  registered_at     timestamptz not null default now()
);

create table if not exists registrations (
  id               bigint generated always as identity primary key,
  line_user_id     text not null,
  emp_code         text not null,
  national_id_enc  text,
  display_name     text,
  status           text not null default 'pending',  -- pending | approved | rejected
  created_at       timestamptz not null default now()
);

create table if not exists payslips (
  period       text not null,           -- YYYY-MM
  emp_code     text not null,
  raw_path     text not null,
  uploaded_at  timestamptz not null default now(),
  primary key (period, emp_code)
);

create table if not exists send_log (
  period    text not null,
  emp_code  text not null,
  status    text not null,              -- ok | error
  error     text,
  sent_at   timestamptz not null default now(),
  primary key (period, emp_code)
);

create table if not exists push_log (
  id            bigint generated always as identity primary key,
  ts            timestamptz not null default now(),
  kind          text,
  line_user_id  text
);

-- ปิดการเข้าถึงจากภายนอก (ใช้ service key ฝั่งเซิร์ฟเวอร์เท่านั้น)
alter table employees      enable row level security;
alter table registrations  enable row level security;
alter table payslips       enable row level security;
alter table send_log       enable row level security;
alter table push_log       enable row level security;

-- bucket เก็บไฟล์สลีป (private)
insert into storage.buckets (id, name, public)
values ('payslips', 'payslips', false)
on conflict (id) do nothing;
