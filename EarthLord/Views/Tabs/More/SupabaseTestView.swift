//
//  SupabaseTestView.swift
//  EarthLord
//
//  Created by feixiang yang on 2025/12/27.
//

import SwiftUI
import Supabase

// MARK: - Supabase 管理器（线程安全）
@MainActor
final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://qadoexkslcefeioxhlwk.supabase.co")!,
            supabaseKey: "sb_publishable_XD_UyW0tHeC_k3Bj5c7RNA_c3CGytWS"
        )
    }
}

struct SupabaseTestView: View {
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var logMessages: [String] = []
    @State private var isTesting: Bool = false

    enum ConnectionStatus {
        case idle
        case testing
        case success
        case failure
    }

    var body: some View {
        VStack(spacing: 24) {
            // 状态图标
            statusIconView

            // 调试日志
            logView

            // 测试按钮
            testButton
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ApocalypseTheme.background)
        .navigationTitle("Supabase 连接测试")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 状态图标
    private var statusIconView: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusBackgroundColor)
                    .frame(width: 80, height: 80)

                Image(systemName: statusIconName)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(statusText)
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .multilineTextAlignment(.center)
        }
    }

    private var statusIconName: String {
        switch connectionStatus {
        case .idle:
            return "questionmark"
        case .testing:
            return "arrow.triangle.2.circlepath"
        case .success:
            return "checkmark"
        case .failure:
            return "exclamationmark"
        }
    }

    private var statusBackgroundColor: Color {
        switch connectionStatus {
        case .idle:
            return ApocalypseTheme.textMuted
        case .testing:
            return ApocalypseTheme.info
        case .success:
            return ApocalypseTheme.success
        case .failure:
            return ApocalypseTheme.danger
        }
    }

    private var statusText: String {
        switch connectionStatus {
        case .idle:
            return "点击下方按钮测试连接"
        case .testing:
            return "正在测试连接..."
        case .success:
            return "连接成功（服务器已响应）"
        case .failure:
            return "连接失败"
        }
    }

    // MARK: - 日志视图
    private var logView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("调试日志")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                if !logMessages.isEmpty {
                    Button("清除") {
                        logMessages.removeAll()
                    }
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(logMessages.enumerated()), id: \.offset) { index, message in
                            Text(message)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(logTextColor(for: message))
                                .id(index)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: logMessages.count) { _, _ in
                    if let lastIndex = logMessages.indices.last {
                        withAnimation {
                            proxy.scrollTo(lastIndex, anchor: .bottom)
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func logTextColor(for message: String) -> Color {
        if message.contains("[成功]") {
            return ApocalypseTheme.success
        } else if message.contains("[失败]") || message.contains("[错误]") {
            return ApocalypseTheme.danger
        } else if message.contains("[信息]") {
            return ApocalypseTheme.info
        } else {
            return ApocalypseTheme.textSecondary
        }
    }

    // MARK: - 测试按钮
    private var testButton: some View {
        Button(action: testConnection) {
            HStack(spacing: 8) {
                if isTesting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "network")
                }

                Text(isTesting ? "测试中..." : "测试连接")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isTesting ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isTesting)
    }

    // MARK: - 测试逻辑
    private func testConnection() {
        isTesting = true
        connectionStatus = .testing

        addLog("[信息] 开始测试 Supabase 连接...")
        addLog("[信息] URL: https://qadoexkslcefeioxhlwk.supabase.co")

        Task {
            do {
                // 故意查询一个不存在的表来测试连接
                addLog("[信息] 正在发送测试请求...")
                let _: [EmptyRow] = try await SupabaseManager.shared.client
                    .from("non_existent_table")
                    .select()
                    .execute()
                    .value

                // 如果没有抛出错误，说明表存在（不太可能）
                addLog("[成功] 连接成功，表存在（意外情况）")
                connectionStatus = .success
                isTesting = false
            } catch {
                handleConnectionError(error)
                isTesting = false
            }
        }
    }

    private func handleConnectionError(_ error: Error) {
        let errorString = String(describing: error)
        addLog("[信息] 收到服务器响应")
        addLog("[信息] 错误详情: \(errorString)")

        // 判断错误类型
        if errorString.contains("PGRST") || errorString.contains("Could not find the table") {
            // PostgreSQL REST API 错误，说明连接成功
            addLog("[成功] 连接成功（服务器已响应）")
            addLog("[信息] 服务器返回预期的表不存在错误")
            connectionStatus = .success
        } else if errorString.contains("relation") && errorString.contains("does not exist") {
            // 表不存在错误，说明连接成功
            addLog("[成功] 连接成功（服务器已响应）")
            addLog("[信息] 服务器返回关系不存在错误")
            connectionStatus = .success
        } else if errorString.contains("hostname") ||
                  errorString.contains("URL") ||
                  errorString.contains("NSURLErrorDomain") ||
                  errorString.contains("Could not connect") {
            // 网络或 URL 错误
            addLog("[失败] 连接失败：URL 错误或无网络")
            addLog("[错误] 请检查网络连接和 Supabase URL")
            connectionStatus = .failure
        } else {
            // 其他错误
            addLog("[失败] 发生未知错误")
            addLog("[错误] \(error.localizedDescription)")
            connectionStatus = .failure
        }
    }

    private func addLog(_ message: String) {
        let timestamp = Self.formatLogTime(Date())
        logMessages.append("[\(timestamp)] \(message)")
    }
}

// MARK: - 辅助类型
private struct EmptyRow: Decodable, Sendable {}

extension SupabaseTestView {
    nonisolated static func formatLogTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        SupabaseTestView()
    }
}
