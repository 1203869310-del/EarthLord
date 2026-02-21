-- Day 34 消息系统
-- 执行前提：communication_channels、channel_subscriptions 表已存在

-- 启用 PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- 消息表
CREATE TABLE IF NOT EXISTS public.channel_messages (
    message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel_id UUID NOT NULL REFERENCES public.communication_channels(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    sender_callsign TEXT,
    content TEXT NOT NULL,
    sender_location GEOGRAPHY(POINT, 4326),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.channel_messages ENABLE ROW LEVEL SECURITY;

-- RLS：订阅者可查看
CREATE POLICY "订阅者可以查看频道消息" ON public.channel_messages
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.channel_subscriptions
            WHERE channel_subscriptions.channel_id = channel_messages.channel_id
              AND channel_subscriptions.user_id = auth.uid()
        )
    );

-- RLS：订阅者可发送
CREATE POLICY "订阅者可以发送消息" ON public.channel_messages
    FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() = sender_id
        AND EXISTS (
            SELECT 1 FROM public.channel_subscriptions
            WHERE channel_subscriptions.channel_id = channel_messages.channel_id
              AND channel_subscriptions.user_id = auth.uid()
        )
    );

CREATE INDEX idx_messages_channel ON public.channel_messages(channel_id);
CREATE INDEX idx_messages_sender  ON public.channel_messages(sender_id);
CREATE INDEX idx_messages_created ON public.channel_messages(created_at DESC);

-- ⚠️ 必须：启用 Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE channel_messages;

-- RPC：发送消息
CREATE OR REPLACE FUNCTION send_channel_message(
    p_channel_id  UUID,
    p_content     TEXT,
    p_latitude    DOUBLE PRECISION DEFAULT NULL,
    p_longitude   DOUBLE PRECISION DEFAULT NULL,
    p_device_type TEXT DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_message_id UUID;
    v_sender_id  UUID;
    v_callsign   TEXT;
    v_location   GEOGRAPHY(POINT, 4326);
    v_metadata   JSONB;
BEGIN
    v_sender_id := auth.uid();

    IF NOT EXISTS (
        SELECT 1 FROM public.channel_subscriptions
        WHERE channel_id = p_channel_id AND user_id = v_sender_id
    ) THEN
        RAISE EXCEPTION '您未订阅此频道，无法发送消息';
    END IF;

    -- 查用户名（user_profiles 不存在时容错）
    BEGIN
        SELECT username INTO v_callsign
        FROM public.user_profiles
        WHERE user_id = v_sender_id;
    EXCEPTION
        WHEN undefined_table THEN v_callsign := NULL;
    END;
    IF v_callsign IS NULL THEN v_callsign := '匿名用户'; END IF;

    IF p_latitude IS NOT NULL AND p_longitude IS NOT NULL THEN
        v_location := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::GEOGRAPHY;
    END IF;

    v_metadata := jsonb_build_object('device_type', COALESCE(p_device_type, 'unknown'));

    INSERT INTO public.channel_messages
        (channel_id, sender_id, sender_callsign, content, sender_location, metadata)
    VALUES
        (p_channel_id, v_sender_id, v_callsign, p_content, v_location, v_metadata)
    RETURNING message_id INTO v_message_id;

    RETURN v_message_id;
END;
$$;
