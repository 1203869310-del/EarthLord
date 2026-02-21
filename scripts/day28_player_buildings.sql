-- Day 28 建造系统 - player_buildings 表
-- 在 Supabase Dashboard > SQL Editor 中执行

-- ============================================================
-- 1. 创建表
-- ============================================================

create table player_buildings (
  id                uuid         primary key default gen_random_uuid(),
  user_id           uuid         references auth.users(id) not null,
  territory_id      text         not null,
  template_id       text         not null,
  building_name     text         not null,
  status            text         default 'constructing'
                                 check (status in ('constructing', 'active')),
  level             int          default 1,
  location_lat      double precision,
  location_lon      double precision,
  build_started_at  timestamptz  default now(),
  build_completed_at timestamptz,
  created_at        timestamptz  default now(),
  updated_at        timestamptz  default now()
);

-- ============================================================
-- 2. 索引
-- ============================================================

create index idx_player_buildings_user_id
  on player_buildings(user_id);

create index idx_player_buildings_territory_id
  on player_buildings(territory_id);

-- ============================================================
-- 3. updated_at 自动更新触发器
-- ============================================================

create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger update_player_buildings_updated_at
  before update on player_buildings
  for each row execute procedure update_updated_at_column();

-- ============================================================
-- 4. 开启 RLS
-- ============================================================

alter table player_buildings enable row level security;

-- ============================================================
-- 5. RLS 策略
-- ============================================================

create policy "用户可以查看自己的建筑"
  on player_buildings for select
  using (auth.uid() = user_id);

create policy "用户可以创建自己的建筑"
  on player_buildings for insert
  with check (auth.uid() = user_id);

create policy "用户可以更新自己的建筑"
  on player_buildings for update
  using (auth.uid() = user_id);

create policy "用户可以删除自己的建筑"
  on player_buildings for delete
  using (auth.uid() = user_id);

-- ============================================================
-- 6. 验证（执行完上面的语句后运行此段确认结果）
-- ============================================================

-- 检查表结构
select
    column_name,
    data_type,
    is_nullable,
    column_default
from information_schema.columns
where table_name = 'player_buildings'
order by ordinal_position;

-- 检查 RLS 状态
select tablename, rowsecurity as rls_enabled
from pg_tables
where tablename = 'player_buildings';

-- 检查 RLS 策略
select policyname, cmd, qual
from pg_policies
where tablename = 'player_buildings';

-- 检查触发器
select trigger_name, event_manipulation, action_timing
from information_schema.triggers
where event_object_table = 'player_buildings';
