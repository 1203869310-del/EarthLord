-- Day 18 数据库自检脚本
-- 在 Supabase Dashboard > SQL Editor 中执行

-- 1. 检查 PostGIS 扩展
SELECT extname, extversion
FROM pg_extension
WHERE extname = 'postgis';

-- 2. 检查 territories 表结构
SELECT
    column_name,
    data_type,
    udt_name,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'territories'
ORDER BY ordinal_position;

-- 3. 检查 RLS 状态
SELECT
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'territories';

-- 4. 检查 RLS 策略
SELECT
    policyname,
    cmd,
    qual
FROM pg_policies
WHERE tablename = 'territories';

-- 5. 特别检查 name 字段是否 nullable
SELECT
    column_name,
    is_nullable,
    CASE
        WHEN is_nullable = 'YES' THEN '✅ nullable - 正确'
        ELSE '❌ NOT NULL - 需要修复!'
    END as status
FROM information_schema.columns
WHERE table_name = 'territories' AND column_name = 'name';
