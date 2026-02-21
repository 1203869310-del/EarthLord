-- Day 32-A 通讯系统迁移
-- Migration: 20260221_communication_devices.sql

-- =============================================
-- Migration 1: 创建表 + RLS
-- =============================================

-- 通讯设备表
CREATE TABLE IF NOT EXISTS public.communication_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_type TEXT NOT NULL CHECK (device_type IN ('radio', 'walkie_talkie', 'camp_radio', 'satellite')),
    device_level INT NOT NULL DEFAULT 1,
    is_unlocked BOOLEAN NOT NULL DEFAULT false,
    is_current BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, device_type)
);

ALTER TABLE public.communication_devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "用户可以查看自己的设备" ON public.communication_devices
    FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "用户可以添加自己的设备" ON public.communication_devices
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY "用户可以更新自己的设备" ON public.communication_devices
    FOR UPDATE TO authenticated USING (auth.uid() = user_id);

CREATE INDEX idx_communication_devices_user_id ON public.communication_devices(user_id);

-- =============================================
-- Migration 2: 数据库函数
-- =============================================

-- 初始化用户设备（新用户首次加载时调用）
CREATE OR REPLACE FUNCTION initialize_user_devices(p_user_id UUID)
RETURNS void AS $$
BEGIN
    INSERT INTO public.communication_devices (user_id, device_type, is_unlocked, is_current)
    VALUES
        (p_user_id, 'radio',         true,  false),
        (p_user_id, 'walkie_talkie', true,  true),
        (p_user_id, 'camp_radio',    false, false),
        (p_user_id, 'satellite',     false, false)
    ON CONFLICT (user_id, device_type) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 切换当前设备（原子操作：先全清，再设置）
CREATE OR REPLACE FUNCTION switch_current_device(p_user_id UUID, p_device_type TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.communication_devices
        WHERE user_id = p_user_id
          AND device_type = p_device_type
          AND is_unlocked = true
    ) THEN
        RAISE EXCEPTION '设备未解锁';
    END IF;

    UPDATE public.communication_devices SET is_current = false WHERE user_id = p_user_id;
    UPDATE public.communication_devices SET is_current = true
        WHERE user_id = p_user_id AND device_type = p_device_type;

    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
