//
//  CommunicationManager.swift
//  EarthLord
//
//  通讯系统管理器 - 处理通讯设备的加载、解锁和切换
//

import Foundation
import Combine
import Supabase

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

    // MARK: - 私有属性

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

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
}
