-- 修复 name 字段为 nullable（如果检查发现是 NOT NULL）
-- 在 Supabase Dashboard > SQL Editor 中执行

ALTER TABLE territories ALTER COLUMN name DROP NOT NULL;

-- 验证修复结果
SELECT
    column_name,
    is_nullable,
    CASE
        WHEN is_nullable = 'YES' THEN '✅ 修复成功！'
        ELSE '❌ 修复失败'
    END as status
FROM information_schema.columns
WHERE table_name = 'territories' AND column_name = 'name';
