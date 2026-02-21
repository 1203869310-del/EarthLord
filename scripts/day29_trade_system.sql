-- ============================================================
-- Day 29: 交易系统数据层
-- EarthLord — 玩家之间的异步挂单交易系统
-- 在 Supabase Dashboard → SQL Editor 中执行此文件
-- ============================================================

-- ============================================================
-- 1. 建表
-- ============================================================

-- trade_offers 挂单表
create table trade_offers (
  id                     uuid         primary key default gen_random_uuid(),
  owner_id               uuid         references auth.users(id) not null,
  owner_username         text         not null,
  offering_items         jsonb        not null,   -- [{"name":"木材","quantity":5}]
  requesting_items       jsonb        not null,
  status                 text         not null default 'active'
                                      check (status in ('active','completed','cancelled','expired')),
  message                text,
  created_at             timestamptz  not null default now(),
  expires_at             timestamptz  not null,
  completed_at           timestamptz,
  completed_by_user_id   uuid         references auth.users(id),
  completed_by_username  text
);

-- trade_history 历史表
create table trade_history (
  id               uuid         primary key default gen_random_uuid(),
  offer_id         uuid         references trade_offers(id) not null,
  seller_id        uuid         references auth.users(id) not null,
  seller_username  text         not null,
  buyer_id         uuid         references auth.users(id) not null,
  buyer_username   text         not null,
  items_exchanged  jsonb        not null,  -- {"offered":[...],"requested":[...]}
  completed_at     timestamptz  not null default now(),
  seller_rating    int          check (seller_rating between 1 and 5),
  buyer_rating     int          check (buyer_rating between 1 and 5),
  seller_comment   text,
  buyer_comment    text,
  seller_claimed   boolean      not null default false
);

-- ============================================================
-- 2. 索引
-- ============================================================

create index idx_trade_offers_owner_id   on trade_offers(owner_id);
create index idx_trade_offers_status     on trade_offers(status);
create index idx_trade_offers_expires_at on trade_offers(expires_at);
-- 部分索引：最常用的查询（活跃且未过期）
create index idx_trade_offers_active     on trade_offers(status, expires_at) where status = 'active';

create index idx_trade_history_seller_id on trade_history(seller_id);
create index idx_trade_history_buyer_id  on trade_history(buyer_id);
create index idx_trade_history_offer_id  on trade_history(offer_id);

-- ============================================================
-- 3. RLS — trade_offers
-- ============================================================

alter table trade_offers enable row level security;

-- 所有人可见活跃订单；自己可见全部自己的订单
create policy "活跃订单对所有人可见，自己的订单全可见"
  on trade_offers for select
  using (auth.uid() = owner_id OR (status = 'active' AND expires_at > now()));

-- 只能创建自己的订单
create policy "用户只能创建自己的订单"
  on trade_offers for insert
  with check (auth.uid() = owner_id);

-- 只能取消自己的活跃订单（with check 确保只能改为 cancelled）
create policy "用户只能取消自己的活跃订单"
  on trade_offers for update
  using (auth.uid() = owner_id AND status = 'active')
  with check (status = 'cancelled');

-- ============================================================
-- 4. RLS — trade_history
-- ============================================================

alter table trade_history enable row level security;

create policy "只有买卖双方可以查看交易记录"
  on trade_history for select
  using (auth.uid() = seller_id OR auth.uid() = buyer_id);

-- 卖家可更新自己的评价字段 + seller_claimed
create policy "卖家可以评价并认领物品"
  on trade_history for update
  using (auth.uid() = seller_id)
  with check (
    buyer_rating IS NOT DISTINCT FROM buyer_rating
    AND buyer_comment IS NOT DISTINCT FROM buyer_comment
  );

-- 买家只可更新自己的评价字段
create policy "买家可以评价"
  on trade_history for update
  using (auth.uid() = buyer_id)
  with check (
    seller_rating IS NOT DISTINCT FROM seller_rating
    AND seller_comment IS NOT DISTINCT FROM seller_comment
    AND seller_claimed IS NOT DISTINCT FROM seller_claimed
  );

-- ============================================================
-- 5. RPC 函数 — 原子接受（SECURITY DEFINER）
-- ============================================================

create or replace function accept_trade_offer(offer_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_offer         trade_offers%rowtype;
  v_buyer_id      uuid;
  v_buyer_email   text;
  v_history_id    uuid;
begin
  v_buyer_id := auth.uid();
  if v_buyer_id is null then
    return jsonb_build_object('success', false, 'error', 'unauthenticated');
  end if;

  select email into v_buyer_email from auth.users where id = v_buyer_id;

  -- 原子更新：一个 UPDATE 语句保证并发安全
  -- 两个买家同时接受，只有一个能命中 status='active' 的行
  update trade_offers set
    status                = 'completed',
    completed_at          = now(),
    completed_by_user_id  = v_buyer_id,
    completed_by_username = v_buyer_email
  where
    id         = offer_id
    AND status = 'active'
    AND expires_at > now()
    AND owner_id != v_buyer_id
  returning * into v_offer;

  if v_offer.id is null then
    return jsonb_build_object('success', false, 'error', 'offer_unavailable');
  end if;

  v_history_id := gen_random_uuid();
  insert into trade_history (
    id, offer_id, seller_id, seller_username,
    buyer_id, buyer_username, items_exchanged, completed_at, seller_claimed
  ) values (
    v_history_id, v_offer.id, v_offer.owner_id, v_offer.owner_username,
    v_buyer_id, v_buyer_email,
    jsonb_build_object('offered', v_offer.offering_items, 'requested', v_offer.requesting_items),
    now(), false
  );

  return jsonb_build_object(
    'success',           true,
    'history_id',        v_history_id::text,
    'offering_items',    v_offer.offering_items,   -- 买家获得
    'requesting_items',  v_offer.requesting_items,  -- 买家支付（卖家待领取）
    'seller_id',         v_offer.owner_id::text
  );
end;
$$;

-- ============================================================
-- 6. 验证查询（执行完上面的语句后运行此部分确认结果）
-- ============================================================

-- 确认两张表存在
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('trade_offers', 'trade_history');

-- 确认 7 个索引存在
select indexname, tablename
from pg_indexes
where schemaname = 'public'
  and indexname like 'idx_trade_%';

-- 确认 RLS 已开启
select tablename, rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in ('trade_offers', 'trade_history');

-- 确认 RPC 函数存在
select routine_name, routine_type
from information_schema.routines
where routine_schema = 'public'
  and routine_name = 'accept_trade_offer';
