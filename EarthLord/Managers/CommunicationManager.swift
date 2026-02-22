//
//  CommunicationManager.swift
//  EarthLord
//
//  通讯系统管理器 - 处理通讯设备的加载、解锁和切换
//

import Foundation
import Combine
import Supabase
import CoreLocation

// MARK: - 通讯管理器

@MainActor
final class CommunicationManager: ObservableObject {

    // MARK: - 单例

    static let shared = CommunicationManager()

    // MARK: - 发布属性

    @Published private(set) var devices: [CommunicationDevice] = []
    @Published private(set) var currentDevice: CommunicationDevice?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    @Published private(set) var channels: [CommunicationChannel] = []
    @Published private(set) var subscribedChannels: [SubscribedChannel] = []
    @Published private(set) var mySubscriptions: [ChannelSubscription] = []
    @Published var channelMessages: [UUID: [ChannelMessage]] = [:]
    @Published var isSendingMessage = false
    @Published var subscribedChannelIds: Set<UUID> = []

    // MARK: - 私有属性

    private var supabase: SupabaseClient { SupabaseManager.shared.client }
    private var realtimeChannel: RealtimeChannelV2?
    private var messageSubscriptionTask: Task<Void, Never>?

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = formatter.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "无法解析日期字符串: \(string)"
            )
        }
        return d
    }

    // MARK: - 初始化

    private init() {}

    // MARK: - 加载设备列表

    /// 加载当前用户的通讯设备；若无记录则自动初始化
    func loadDevices(userId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await supabase
                .from("communication_devices")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
            devices = try decoder.decode([CommunicationDevice].self, from: response.data)
            currentDevice = devices.first(where: { $0.isCurrent })
            if devices.isEmpty {
                await initializeDevices(userId: userId)
            }
            print("[CommunicationManager] ✅ 加载设备: \(devices.count) 条，当前设备: \(currentDevice?.deviceType.displayName ?? "无")")
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
            print("[CommunicationManager] ❌ 加载设备失败: \(error)")
        }
        isLoading = false
    }

    // MARK: - 初始化设备（新用户）

    /// 调用 RPC 为新用户插入 4 条默认设备记录
    func initializeDevices(userId: UUID) async {
        do {
            try await supabase
                .rpc("initialize_user_devices",
                     params: ["p_user_id": AnyJSON.string(userId.uuidString)])
                .execute()
            print("[CommunicationManager] ✅ 初始化设备完成")
            // 重新加载
            await loadDevices(userId: userId)
        } catch {
            errorMessage = "初始化设备失败: \(error.localizedDescription)"
            print("[CommunicationManager] ❌ 初始化设备失败: \(error)")
        }
    }

    // MARK: - 切换当前设备

    /// 切换激活的通讯设备（通过 RPC 原子操作）
    func switchDevice(userId: UUID, deviceType: DeviceType) async {
        do {
            try await supabase
                .rpc("switch_current_device", params: [
                    "p_user_id":     AnyJSON.string(userId.uuidString),
                    "p_device_type": AnyJSON.string(deviceType.rawValue)
                ])
                .execute()

            // 更新本地状态
            for i in devices.indices {
                devices[i].isCurrent = (devices[i].deviceType == deviceType)
            }
            currentDevice = devices.first(where: { $0.isCurrent })
            print("[CommunicationManager] ✅ 切换设备: \(deviceType.displayName)")
        } catch {
            errorMessage = "切换失败: \(error.localizedDescription)"
            print("[CommunicationManager] ❌ 切换设备失败: \(error)")
        }
    }

    // MARK: - 解锁设备

    /// 解锁指定类型的通讯设备
    func unlockDevice(userId: UUID, deviceType: DeviceType) async {
        do {
            let updateData: [String: AnyJSON] = [
                "is_unlocked": .bool(true),
                "updated_at":  .string(Date().ISO8601Format())
            ]
            try await supabase
                .from("communication_devices")
                .update(updateData)
                .eq("user_id",     value: userId.uuidString)
                .eq("device_type", value: deviceType.rawValue)
                .execute()

            // 更新本地状态
            if let idx = devices.firstIndex(where: { $0.deviceType == deviceType }) {
                devices[idx].isUnlocked = true
            }
            print("[CommunicationManager] ✅ 解锁设备: \(deviceType.displayName)")
        } catch {
            errorMessage = "解锁失败: \(error.localizedDescription)"
            print("[CommunicationManager] ❌ 解锁设备失败: \(error)")
        }
    }

    // MARK: - 便捷计算属性

    /// 当前设备类型（未设置时回退到对讲机）
    func getCurrentDeviceType() -> DeviceType {
        currentDevice?.deviceType ?? .walkieTalkie
    }

    /// 当前设备是否支持发送消息
    func canSendMessage() -> Bool {
        getCurrentDeviceType().canSend
    }

    /// 当前设备的通讯范围（千米），nil 表示无限制或仅接收
    func getCurrentRange() -> Double? {
        getCurrentDeviceType().range
    }

    /// 指定类型的设备是否已解锁
    func isDeviceUnlocked(_ deviceType: DeviceType) -> Bool {
        devices.first(where: { $0.deviceType == deviceType })?.isUnlocked ?? false
    }

    // MARK: - 频道方法

    /// 加载所有活跃公共频道
    func loadPublicChannels() async {
        do {
            let response = try await supabase
                .from("communication_channels")
                .select()
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
            channels = try decoder.decode([CommunicationChannel].self, from: response.data)
            print("[CommunicationManager] ✅ 加载频道: \(channels.count) 条")
        } catch {
            errorMessage = "加载频道失败: \(error.localizedDescription)"
            print("[CommunicationManager] ❌ 加载频道失败: \(error)")
        }
    }

    /// 加载当前用户已订阅的频道
    func loadSubscribedChannels(userId: UUID) async {
        do {
            // 先查订阅记录
            let subResponse = try await supabase
                .from("channel_subscriptions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
            let subs = try decoder.decode([ChannelSubscription].self, from: subResponse.data)
            mySubscriptions = subs

            guard !subs.isEmpty else {
                subscribedChannels = []
                return
            }

            // 提取 channel IDs 并查频道
            let channelIds = subs.map { $0.channelId.uuidString }
            let chResponse = try await supabase
                .from("communication_channels")
                .select()
                .in("id", values: channelIds)
                .execute()
            let chs = try decoder.decode([CommunicationChannel].self, from: chResponse.data)

            // 组合
            subscribedChannels = subs.compactMap { sub in
                guard let ch = chs.first(where: { $0.id == sub.channelId }) else { return nil }
                return SubscribedChannel(channel: ch, subscription: sub)
            }
            print("[CommunicationManager] ✅ 订阅频道: \(subscribedChannels.count) 条")
        } catch {
            errorMessage = "加载订阅失败: \(error.localizedDescription)"
            print("[CommunicationManager] ❌ 加载订阅失败: \(error)")
        }
    }

    /// 创建频道（通过 RPC）
    func createChannel(userId: UUID, type: ChannelType, name: String, description: String?) async {
        do {
            var params: [String: AnyJSON] = [
                "p_creator_id":   .string(userId.uuidString),
                "p_channel_type": .string(type.rawValue),
                "p_name":         .string(name)
            ]
            if let desc = description, !desc.isEmpty {
                params["p_description"] = .string(desc)
            }
            try await supabase
                .rpc("create_channel_with_subscription", params: params)
                .execute()
            // 刷新两个列表
            await loadPublicChannels()
            await loadSubscribedChannels(userId: userId)
            print("[CommunicationManager] ✅ 创建频道: \(name)")
        } catch {
            errorMessage = "创建频道失败: \(error.localizedDescription)"
            print("[CommunicationManager] ❌ 创建频道失败: \(error)")
        }
    }

    /// 订阅频道
    func subscribeToChannel(userId: UUID, channelId: UUID) async {
        do {
            let insertData: [String: AnyJSON] = [
                "user_id":    .string(userId.uuidString),
                "channel_id": .string(channelId.uuidString)
            ]
            try await supabase
                .from("channel_subscriptions")
                .insert(insertData)
                .execute()
            await loadSubscribedChannels(userId: userId)
            print("[CommunicationManager] ✅ 订阅频道: \(channelId)")
        } catch {
            errorMessage = "订阅失败: \(error.localizedDescription)"
            print("[CommunicationManager] ❌ 订阅失败: \(error)")
        }
    }

    /// 取消订阅频道
    func unsubscribeFromChannel(userId: UUID, channelId: UUID) async {
        do {
            try await supabase
                .from("channel_subscriptions")
                .delete()
                .eq("user_id",    value: userId.uuidString)
                .eq("channel_id", value: channelId.uuidString)
                .execute()
            await loadSubscribedChannels(userId: userId)
            print("[CommunicationManager] ✅ 取消订阅: \(channelId)")
        } catch {
            errorMessage = "取消订阅失败: \(error.localizedDescription)"
            print("[CommunicationManager] ❌ 取消订阅失败: \(error)")
        }
    }

    /// 是否已订阅指定频道
    func isSubscribed(channelId: UUID) -> Bool {
        mySubscriptions.contains(where: { $0.channelId == channelId })
    }

    /// 删除频道（仅创建者）
    func deleteChannel(channelId: UUID, userId: UUID) async {
        do {
            try await supabase
                .from("communication_channels")
                .delete()
                .eq("id", value: channelId.uuidString)
                .execute()
            await loadPublicChannels()
            await loadSubscribedChannels(userId: userId)
            print("[CommunicationManager] ✅ 删除频道: \(channelId)")
        } catch {
            errorMessage = "删除频道失败: \(error.localizedDescription)"
            print("[CommunicationManager] ❌ 删除频道失败: \(error)")
        }
    }

    // MARK: - 消息方法

    /// 加载频道历史消息（最近50条，升序）
    func loadChannelMessages(channelId: UUID) async {
        do {
            let response = try await supabase
                .from("channel_messages")
                .select()
                .eq("channel_id", value: channelId.uuidString)
                .order("created_at", ascending: true)
                .limit(50)
                .execute()
            let messages = try decoder.decode([ChannelMessage].self, from: response.data)
            channelMessages[channelId] = messages
            print("[CommunicationManager] ✅ 加载消息: \(messages.count) 条")
        } catch {
            print("[CommunicationManager] ❌ 加载消息失败: \(error)")
        }
    }

    /// 通过 RPC 发送消息
    @discardableResult
    func sendChannelMessage(channelId: UUID, content: String, deviceType: String? = nil,
                            latitude: Double? = nil, longitude: Double? = nil) async -> Bool {
        isSendingMessage = true
        defer { isSendingMessage = false }
        do {
            var params: [String: AnyJSON] = [
                "p_channel_id": .string(channelId.uuidString),
                "p_content":    .string(content)
            ]
            if let dt = deviceType {
                params["p_device_type"] = .string(dt)
            }
            if let lat = latitude  { params["p_latitude"]  = .double(lat) }
            if let lon = longitude { params["p_longitude"] = .double(lon) }
            try await supabase
                .rpc("send_channel_message", params: params)
                .execute()
            print("[CommunicationManager] ✅ 发送消息成功")
            return true
        } catch {
            print("[CommunicationManager] ❌ 发送消息失败: \(error)")
            return false
        }
    }

    /// 启动 Realtime 订阅（监听 channel_messages 表的 INSERT 事件）
    func startRealtimeSubscription() {
        let rt = supabase.realtimeV2.channel("channel_messages_realtime")
        realtimeChannel = rt

        messageSubscriptionTask = Task { [weak self] in
            guard let self else { return }
            let insertions = await rt.postgresChange(InsertAction.self, table: "channel_messages")
            await rt.subscribe()
            for await insert in insertions {
                await self.handleNewMessage(insertion: insert)
            }
        }
        print("[CommunicationManager] ✅ 启动 Realtime 订阅")
    }

    /// 停止 Realtime 订阅
    func stopRealtimeSubscription() {
        messageSubscriptionTask?.cancel()
        messageSubscriptionTask = nil
        Task {
            await realtimeChannel?.unsubscribe()
            realtimeChannel = nil
        }
        print("[CommunicationManager] ✅ 停止 Realtime 订阅")
    }

    /// 处理收到的新消息
    func handleNewMessage(insertion: InsertAction) async {
        do {
            let dec = JSONDecoder()
            let message = try insertion.decodeRecord(as: ChannelMessage.self, decoder: dec)
            guard subscribedChannelIds.contains(message.channelId) else { return }

            // ✅ Day 35 新增：距离过滤
            let channelType = subscribedChannels
                .first(where: { $0.channel.id == message.channelId })?.channel.channelType
            if let ct = channelType, !shouldReceiveMessage(message, channelType: ct) { return }

            var msgs = channelMessages[message.channelId] ?? []
            if !msgs.contains(where: { $0.id == message.id }) {
                msgs.append(message)
                channelMessages[message.channelId] = msgs
            }
            print("[CommunicationManager] ✅ 收到新消息: \(message.content)")
        } catch {
            print("[CommunicationManager] ❌ 解析新消息失败: \(error)")
        }
    }

    /// 注册对某个频道的消息监听
    func subscribeToChannelMessages(channelId: UUID) {
        subscribedChannelIds.insert(channelId)
        if realtimeChannel == nil {
            startRealtimeSubscription()
        }
    }

    /// 取消对某个频道的消息监听
    func unsubscribeFromChannelMessages(channelId: UUID) {
        subscribedChannelIds.remove(channelId)
        channelMessages.removeValue(forKey: channelId)
        if subscribedChannelIds.isEmpty {
            stopRealtimeSubscription()
        }
    }

    /// 获取指定频道的消息列表
    func getMessages(for channelId: UUID) -> [ChannelMessage] {
        channelMessages[channelId] ?? []
    }

    // MARK: - 官方频道

    /// 官方频道固定 UUID
    static let officialChannelId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    /// 检查是否是官方频道
    func isOfficialChannel(_ channelId: UUID) -> Bool {
        channelId == CommunicationManager.officialChannelId
    }

    /// 确保用户已订阅官方频道（强制订阅）
    func ensureOfficialChannelSubscribed(userId: UUID) async {
        let officialId = CommunicationManager.officialChannelId
        if subscribedChannels.contains(where: { $0.channel.id == officialId }) {
            print("✅ [官方频道] 已订阅")
            return
        }
        do {
            let insertData: [String: AnyJSON] = [
                "user_id":    .string(userId.uuidString),
                "channel_id": .string(officialId.uuidString)
            ]
            try await supabase
                .from("channel_subscriptions")
                .insert(insertData)
                .execute()
            await loadSubscribedChannels(userId: userId)
            print("✅ [官方频道] 已自动订阅")
        } catch {
            // 可能已订阅，不视为错误
            print("⚠️ [官方频道] 订阅失败（可能已订阅）: \(error)")
        }
    }

    // MARK: - 消息聚合

    /// 频道摘要（用于消息聚合页）
    struct ChannelSummary: Identifiable {
        let channel: CommunicationChannel
        let lastMessage: ChannelMessage?
        let unreadCount: Int
        var id: UUID { channel.id }
    }

    /// 获取所有订阅频道的摘要（官方频道置顶，其余按最新消息时间排序）
    func getChannelSummaries() -> [ChannelSummary] {
        subscribedChannels.map { subscribedChannel in
            let messages = channelMessages[subscribedChannel.channel.id] ?? []
            return ChannelSummary(
                channel: subscribedChannel.channel,
                lastMessage: messages.last,
                unreadCount: 0
            )
        }.sorted { a, b in
            if a.channel.channelType == .official && b.channel.channelType != .official { return true }
            if a.channel.channelType != .official && b.channel.channelType == .official { return false }
            let t1 = a.lastMessage?.createdAt ?? a.channel.createdAt
            let t2 = b.lastMessage?.createdAt ?? b.channel.createdAt
            return t1 > t2
        }
    }

    /// 加载所有订阅频道的最新 1 条消息（用于消息聚合页预览）
    func loadAllChannelLatestMessages() async {
        for subscribedChannel in subscribedChannels {
            let channelId = subscribedChannel.channel.id
            do {
                let response = try await supabase
                    .from("channel_messages")
                    .select()
                    .eq("channel_id", value: channelId.uuidString)
                    .order("created_at", ascending: false)
                    .limit(1)
                    .execute()
                let messages = try decoder.decode([ChannelMessage].self, from: response.data)
                if let last = messages.first {
                    if channelMessages[channelId] == nil {
                        channelMessages[channelId] = [last]
                    } else if !channelMessages[channelId]!.contains(where: { $0.id == last.id }) {
                        channelMessages[channelId]?.insert(last, at: 0)
                    }
                }
            } catch {
                print("❌ [消息聚合] 加载频道 \(channelId) 最新消息失败: \(error)")
            }
        }
    }

    // MARK: - 距离过滤

    /// 判断是否应接收该消息（保守策略：信息不完整时显示）
    func shouldReceiveMessage(_ message: ChannelMessage, channelType: ChannelType) -> Bool {
        // 营地频道（私有）不限制距离
        if channelType == .camp {
            return true
        }

        guard let myDevice = currentDevice?.deviceType else {
            print("⚠️ [距离过滤] 无法获取当前设备，保守显示"); return true
        }
        // 收音机接收方：无限制
        if myDevice == .radio { print("📻 [距离过滤] 收音机用户，接收所有消息"); return true }

        guard let senderDevice = message.senderDeviceType else {
            print("⚠️ [距离过滤] 消息缺少设备类型，保守显示"); return true
        }
        if senderDevice == .radio { print("🚫 [距离过滤] 收音机不能发送消息"); return false }

        guard let senderLocation = message.senderLocation else {
            print("⚠️ [距离过滤] 消息缺少位置信息，保守显示"); return true
        }
        guard let myLocation = getCurrentLocation() else {
            print("⚠️ [距离过滤] 无法获取当前位置，保守显示"); return true
        }

        let distance = calculateDistance(
            from: CLLocationCoordinate2D(latitude: myLocation.latitude, longitude: myLocation.longitude),
            to:   CLLocationCoordinate2D(latitude: senderLocation.latitude, longitude: senderLocation.longitude)
        )
        let canReceive = canReceiveMessage(senderDevice: senderDevice, myDevice: myDevice, distance: distance)
        print(canReceive
            ? "✅ [距离过滤] 通过: 发送者=\(senderDevice.rawValue), 我=\(myDevice.rawValue), 距离=\(String(format: "%.2f", distance))km"
            : "🚫 [距离过滤] 丢弃: 发送者=\(senderDevice.rawValue), 我=\(myDevice.rawValue), 距离=\(String(format: "%.2f", distance))km")
        return canReceive
    }

    /// 设备矩阵：(发送者, 接收者) → 最大距离(km)
    private func canReceiveMessage(senderDevice: DeviceType, myDevice: DeviceType, distance: Double) -> Bool {
        if myDevice == .radio  { return true  }
        if senderDevice == .radio { return false }
        switch (senderDevice, myDevice) {
        case (.walkieTalkie, .walkieTalkie): return distance <= 3.0
        case (.walkieTalkie, .campRadio):   return distance <= 30.0
        case (.walkieTalkie, .satellite):   return distance <= 100.0
        case (.campRadio,   .walkieTalkie): return distance <= 30.0
        case (.campRadio,   .campRadio):    return distance <= 30.0
        case (.campRadio,   .satellite):    return distance <= 100.0
        case (.satellite,   .walkieTalkie): return distance <= 100.0
        case (.satellite,   .campRadio):    return distance <= 100.0
        case (.satellite,   .satellite):    return distance <= 100.0
        default: return false
        }
    }

    /// Haversine 距离计算（公里）
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: from.latitude, longitude: from.longitude)
            .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude)) / 1000.0
    }

    /// 当前用户位置（真实 GPS）
    private func getCurrentLocation() -> LocationPoint? {
        guard let coord = LocationManager.shared.userLocation else { return nil }
        return LocationPoint(latitude: coord.latitude, longitude: coord.longitude)
    }
}
