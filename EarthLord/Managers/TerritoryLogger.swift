//
//  TerritoryLogger.swift
//  EarthLord
//
//  圈地功能日志管理器 - 用于真机调试时显示日志
//

import Foundation
import Combine  // @Published 需要这个框架

// MARK: - 日志类型枚举

/// 日志类型
enum LogType: String {
    case info = "INFO"
    case success = "SUCCESS"
    case warning = "WARNING"
    case error = "ERROR"
}

// MARK: - 日志条目

/// 单条日志记录
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: LogType
}

// MARK: - TerritoryLogger

/// 圈地功能日志管理器（单例 + ObservableObject）
/// 用于在 App 内显示调试日志，方便真机测试
@MainActor
final class TerritoryLogger: ObservableObject {

    // MARK: - 单例

    static let shared = TerritoryLogger()

    // MARK: - Published Properties

    /// 日志数组
    @Published var logs: [LogEntry] = []

    /// 格式化的日志文本（用于显示）
    @Published var logText: String = ""

    // MARK: - Private Properties

    /// 最大日志条数（防止内存溢出）
    private let maxLogCount = 200

    /// 日期格式化器（显示格式）
    private let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    /// 日期格式化器（导出格式）
    private let exportFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 添加日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - type: 日志类型（默认 info）
    func log(_ message: String, type: LogType = .info) {
        // 确保在主线程更新
        let entry = LogEntry(timestamp: Date(), message: message, type: type)

        // 添加新日志
        logs.append(entry)

        // 超出最大条数时，移除最旧的日志
        if logs.count > maxLogCount {
            logs.removeFirst(logs.count - maxLogCount)
        }

        // 更新格式化文本
        updateLogText()

        // 同时输出到控制台（方便连接 Xcode 时查看）
        print("📝 [圈地日志] [\(type.rawValue)] \(message)")
    }

    /// 清空所有日志
    func clear() {
        logs.removeAll()
        logText = ""
    }

    /// 导出日志为文本
    /// - Returns: 包含头信息的完整日志文本
    func export() -> String {
        var result = """
        === 圈地功能测试日志 ===
        导出时间: \(exportFormatter.string(from: Date()))
        日志条数: \(logs.count)

        """

        for entry in logs {
            let timestamp = exportFormatter.string(from: entry.timestamp)
            result += "[\(timestamp)] [\(entry.type.rawValue)] \(entry.message)\n"
        }

        return result
    }

    // MARK: - Private Methods

    /// 更新格式化的日志文本
    private func updateLogText() {
        var text = ""
        for entry in logs {
            let timestamp = displayFormatter.string(from: entry.timestamp)
            text += "[\(timestamp)] [\(entry.type.rawValue)] \(entry.message)\n"
        }
        logText = text
    }
}
