-- ============================================================
-- Day 36: 官方频道 + 用户资料表（呼号）
-- ============================================================

-- ============================================================
-- 1. 插入官方频道（固定 UUID）
-- ============================================================

-- 官方频道没有创建者，先将 creator_id 改为可空
ALTER TABLE public.communication_channels
    ALTER COLUMN creator_id DROP NOT NULL;

-- 先检查是否已存在
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM communication_channels
        WHERE id = '00000000-0000-0000-0000-000000000000'
    ) THEN
        INSERT INTO communication_channels (
            id,
            channel_type,
            name,
            channel_code,
            description,
            is_active,
            created_at
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            'official',
            '官方频道',
            'OFF-MAIN',
            '地球领主官方公告频道，发布生存指南、游戏资讯、任务和紧急广播。',
            true,
            now()
        );
        RAISE NOTICE '✅ 官方频道已创建';
    ELSE
        RAISE NOTICE '⚠️ 官方频道已存在，跳过';
    END IF;
END $$;

-- 验证
SELECT id, name, channel_type, channel_code
FROM communication_channels
WHERE channel_type = 'official';

-- ============================================================
-- 2. 创建 user_profiles 表（存储呼号）
-- ============================================================

CREATE TABLE IF NOT EXISTS public.user_profiles (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
    callsign    TEXT,
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now()
);

-- 启用 RLS
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- RLS 策略
CREATE POLICY "Users can view own profile"
    ON public.user_profiles FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update own profile"
    ON public.user_profiles FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own profile"
    ON public.user_profiles FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 更新时间触发器
CREATE OR REPLACE FUNCTION update_user_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_user_profiles_updated_at ON public.user_profiles;

CREATE TRIGGER trigger_update_user_profiles_updated_at
    BEFORE UPDATE ON public.user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_user_profiles_updated_at();

-- 验证
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'user_profiles'
ORDER BY ordinal_position;
