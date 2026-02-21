-- Day 33 频道系统
-- 表 1：communication_channels
CREATE TABLE IF NOT EXISTS public.communication_channels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    channel_type TEXT NOT NULL CHECK (channel_type IN ('official','public','walkie','camp','satellite')),
    channel_code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    member_count INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.communication_channels ENABLE ROW LEVEL SECURITY;

CREATE POLICY "channels_select" ON public.communication_channels
    FOR SELECT USING (is_active = true);

CREATE POLICY "channels_insert" ON public.communication_channels
    FOR INSERT WITH CHECK (creator_id = auth.uid());

CREATE POLICY "channels_update" ON public.communication_channels
    FOR UPDATE USING (creator_id = auth.uid());

CREATE POLICY "channels_delete" ON public.communication_channels
    FOR DELETE USING (creator_id = auth.uid());

CREATE INDEX idx_comm_channels_creator ON public.communication_channels(creator_id);
CREATE INDEX idx_comm_channels_type ON public.communication_channels(channel_type);

-- 表 2：channel_subscriptions
CREATE TABLE IF NOT EXISTS public.channel_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    channel_id UUID NOT NULL REFERENCES public.communication_channels(id) ON DELETE CASCADE,
    is_muted BOOLEAN NOT NULL DEFAULT false,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, channel_id)
);

ALTER TABLE public.channel_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "subs_select" ON public.channel_subscriptions
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "subs_insert" ON public.channel_subscriptions
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "subs_update" ON public.channel_subscriptions
    FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "subs_delete" ON public.channel_subscriptions
    FOR DELETE USING (user_id = auth.uid());

CREATE INDEX idx_channel_subs_user ON public.channel_subscriptions(user_id);
CREATE INDEX idx_channel_subs_channel ON public.channel_subscriptions(channel_id);

-- RPC：创建频道并自动订阅
CREATE OR REPLACE FUNCTION public.create_channel_with_subscription(
    p_creator_id UUID,
    p_channel_type TEXT,
    p_name TEXT,
    p_description TEXT DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_channel_id UUID;
    v_channel_code TEXT;
    v_random TEXT;
BEGIN
    v_random := substring(md5(random()::text) from 1 for 8);
    v_channel_code := CASE p_channel_type
        WHEN 'official'  THEN 'OFF-'  || upper(substring(v_random from 1 for 4))
        WHEN 'public'    THEN 'PUB-'  || upper(substring(v_random from 1 for 6))
        WHEN 'walkie'    THEN '438.'  || substring(v_random from 1 for 3) || ' MHz'
        WHEN 'camp'      THEN 'CAMP-' || upper(substring(v_random from 1 for 6))
        WHEN 'satellite' THEN 'SAT-'  || upper(substring(v_random from 1 for 6))
        ELSE 'CH-' || upper(v_random)
    END;

    INSERT INTO public.communication_channels
        (creator_id, channel_type, channel_code, name, description)
    VALUES
        (p_creator_id, p_channel_type, v_channel_code, p_name, p_description)
    RETURNING id INTO v_channel_id;

    INSERT INTO public.channel_subscriptions (user_id, channel_id)
    VALUES (p_creator_id, v_channel_id);

    RETURN v_channel_id;
END;
$$;
