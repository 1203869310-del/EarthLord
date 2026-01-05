//
//  TerritoryTestView.swift
//  EarthLord
//
//  圈地功能测试界面 - 显示实时调试日志
//

import SwiftUI

// MARK: - TerritoryTestView

/// 圈地功能测试页面
/// ⚠️ 不要套 NavigationStack，因为它是从 TestMenuView 导航进来的
struct TerritoryTestView: View {

    // MARK: - Properties

    /// 定位管理器（监听追踪状态）
    @EnvironmentObject var locationManager: LocationManager

    /// 日志管理器（监听日志更新）
    @ObservedObject var logger = TerritoryLogger.shared

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 状态指示器
            statusIndicator

            // 日志显示区域
            logScrollView

            // 底部按钮栏
            bottomButtons
        }
        .background(ApocalypseTheme.background)
        .navigationTitle("圈地测试")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 状态指示器

    /// 顶部状态指示器
    private var statusIndicator: some View {
        HStack(spacing: 8) {
            // 状态圆点
            Circle()
                .fill(locationManager.isTracking ? Color.green : ApocalypseTheme.textMuted)
                .frame(width: 10, height: 10)

            // 状态文字
            Text(locationManager.isTracking ? "追踪中" : "未追踪")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(locationManager.isTracking ? Color.green : ApocalypseTheme.textSecondary)

            Spacer()

            // 路径点数（追踪时显示）
            if locationManager.isTracking {
                Text("\(locationManager.pathPointCount) 点")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ApocalypseTheme.primary.opacity(0.15))
                    .clipShape(Capsule())
            }

            // 闭环状态
            if locationManager.isPathClosed {
                Text("已闭环")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 日志滚动视图

    /// 日志显示区域
    private var logScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if logger.logs.isEmpty {
                        // 空状态提示
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(ApocalypseTheme.textMuted)

                            Text("暂无日志")
                                .font(.system(size: 14))
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            Text("开始圈地追踪后，日志将显示在这里")
                                .font(.system(size: 12))
                                .foregroundColor(ApocalypseTheme.textMuted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                    } else {
                        // 日志列表
                        ForEach(logger.logs) { entry in
                            logEntryView(entry)
                                .id(entry.id)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            // 日志更新时自动滚动到底部
            .onChange(of: logger.logText) { _, _ in
                if let lastEntry = logger.logs.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastEntry.id, anchor: .bottom)
                    }
                }
            }
        }
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
    }

    /// 单条日志视图
    private func logEntryView(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // 时间戳
            Text(formatTime(entry.timestamp))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textMuted)

            // 日志类型标签
            Text(" [\(entry.type.rawValue)] ")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(logTypeColor(entry.type))

            // 消息内容
            Text(entry.message)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(logTypeColor(entry.type))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }

    /// 格式化时间
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "[\(formatter.string(from: date))]"
    }

    /// 根据日志类型返回颜色
    private func logTypeColor(_ type: LogType) -> Color {
        switch type {
        case .info:
            return ApocalypseTheme.textSecondary
        case .success:
            return Color.green
        case .warning:
            return ApocalypseTheme.warning
        case .error:
            return ApocalypseTheme.danger
        }
    }

    // MARK: - 底部按钮

    /// 底部操作按钮栏
    private var bottomButtons: some View {
        HStack(spacing: 16) {
            // 清空日志按钮
            Button(action: {
                logger.clear()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                    Text("清空日志")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.danger)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(ApocalypseTheme.danger.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(logger.logs.isEmpty)
            .opacity(logger.logs.isEmpty ? 0.5 : 1.0)

            // 导出日志按钮
            ShareLink(item: logger.export()) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                    Text("导出日志")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(ApocalypseTheme.primary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(logger.logs.isEmpty)
            .opacity(logger.logs.isEmpty ? 0.5 : 1.0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TerritoryTestView()
            .environmentObject(LocationManager())
    }
}
