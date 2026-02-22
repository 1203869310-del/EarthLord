//
//  CreateChannelSheet.swift
//  EarthLord
//

import SwiftUI
import Supabase

struct CreateChannelSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var channelType: ChannelType = .public_
    @State private var channelName = ""
    @State private var channelDescription = ""
    @State private var isCreating = false

    private var canCreate: Bool {
        let trimmed = channelName.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 2 && trimmed.count <= 50 && !isCreating
    }

    // 可创建的类型（排除官方频道）
    private let creatableTypes: [ChannelType] = [.public_, .walkie, .camp, .satellite]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // 类型选择
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("频道类型")
                        VStack(spacing: 8) {
                            ForEach(creatableTypes, id: \.self) { type in
                                typeButton(type)
                            }
                        }
                    }

                    // 频道名称
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("频道名称")
                        TextField("2-50 个字符", text: $channelName)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .padding(12)
                            .background(ApocalypseTheme.textSecondary.opacity(0.1))
                            .cornerRadius(10)
                        HStack {
                            Spacer()
                            Text("\(channelName.count)/50")
                                .font(.caption)
                                .foregroundColor(
                                    channelName.count > 50
                                    ? .red
                                    : ApocalypseTheme.textSecondary
                                )
                        }
                    }

                    // 频道描述（可选）
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("频道描述（可选）")
                        TextField("简短描述频道用途…", text: $channelDescription, axis: .vertical)
                            .lineLimit(3...6)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .padding(12)
                            .background(ApocalypseTheme.textSecondary.opacity(0.1))
                            .cornerRadius(10)
                    }

                    // 提示：频道码自动生成
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(ApocalypseTheme.primary)
                        Text("频道码将在创建后自动生成")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .padding(12)
                    .background(ApocalypseTheme.primary.opacity(0.08))
                    .cornerRadius(10)

                    // 创建按钮
                    Button {
                        Task { await createChannel() }
                    } label: {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.black)
                                    .scaleEffect(0.8)
                            }
                            Text(isCreating ? "创建中…" : "创建频道")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canCreate ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary.opacity(0.3))
                        .foregroundColor(canCreate ? .black : ApocalypseTheme.textSecondary)
                        .cornerRadius(12)
                    }
                    .disabled(!canCreate)
                }
                .padding()
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle("创建频道")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - 类型选择按钮

    private func typeButton(_ type: ChannelType) -> some View {
        Button {
            channelType = type
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            channelType == type
                            ? ApocalypseTheme.primary.opacity(0.2)
                            : ApocalypseTheme.textSecondary.opacity(0.1)
                        )
                        .frame(width: 40, height: 40)
                    Image(systemName: type.iconName)
                        .foregroundColor(
                            channelType == type
                            ? ApocalypseTheme.primary
                            : ApocalypseTheme.textSecondary
                        )
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.body).fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                Spacer()
                if channelType == type {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .padding(12)
            .background(
                channelType == type
                ? ApocalypseTheme.primary.opacity(0.08)
                : ApocalypseTheme.textSecondary.opacity(0.05)
            )
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        channelType == type ? ApocalypseTheme.primary : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 分区标题

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline).fontWeight(.semibold)
            .foregroundColor(ApocalypseTheme.textSecondary)
    }

    // MARK: - 创建逻辑

    private func createChannel() async {
        guard let uid = authManager.currentUserId else { return }
        isCreating = true
        let desc = channelDescription.trimmingCharacters(in: .whitespaces)
        await communicationManager.createChannel(
            userId: uid,
            type: channelType,
            name: channelName.trimmingCharacters(in: .whitespaces),
            description: desc.isEmpty ? nil : desc
        )
        isCreating = false
        if communicationManager.errorMessage == nil {
            dismiss()
        }
    }
}

#Preview {
    CreateChannelSheet()
        .environmentObject(AuthManager.shared)
}
