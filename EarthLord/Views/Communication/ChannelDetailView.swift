//
//  ChannelDetailView.swift
//  EarthLord
//

import SwiftUI
import Supabase

struct ChannelDetailView: View {
    let channel: CommunicationChannel
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var showDeleteConfirm = false
    @State private var isLoading = false
    @State private var showChat = false

    private var isCreator: Bool {
        authManager.currentUserId == channel.creatorId
    }

    private var isSubscribed: Bool {
        communicationManager.isSubscribed(channelId: channel.id)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {

                    // 频道头像
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(ApocalypseTheme.primary.opacity(0.15))
                                .frame(width: 80, height: 80)
                            Image(systemName: channel.channelType.iconName)
                                .font(.system(size: 36))
                                .foregroundColor(ApocalypseTheme.primary)
                        }
                        Text(channel.name)
                            .font(.title2).fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .multilineTextAlignment(.center)

                        // 频道码
                        Text(channel.channelCode)
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(ApocalypseTheme.primary.opacity(0.12))
                            .cornerRadius(8)

                        // 已订阅标签
                        if isSubscribed {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("已订阅")
                            }
                            .font(.caption)
                            .foregroundColor(.green)
                        }
                    }
                    .padding(.top, 8)

                    // 描述
                    if let desc = channel.description, !desc.isEmpty {
                        Text(desc)
                            .font(.body)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // 信息卡
                    VStack(spacing: 0) {
                        infoRow(label: "频道类型", value: channel.channelType.displayName)
                        Divider().background(ApocalypseTheme.textSecondary.opacity(0.2))
                        infoRow(label: "通讯范围", value: channel.channelType.rangeText)
                        Divider().background(ApocalypseTheme.textSecondary.opacity(0.2))
                        infoRow(label: "成员数量", value: "\(channel.memberCount) 人")
                        Divider().background(ApocalypseTheme.textSecondary.opacity(0.2))
                        infoRow(
                            label: "创建时间",
                            value: channel.createdAt.formatted(date: .abbreviated, time: .omitted)
                        )
                    }
                    .background(ApocalypseTheme.textSecondary.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // 操作按钮
                    VStack(spacing: 12) {
                        if isCreator {
                            // 创建者：删除按钮
                            Button {
                                showDeleteConfirm = true
                            } label: {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.white)
                                            .scaleEffect(0.8)
                                    }
                                    Image(systemName: "trash")
                                    Text("删除频道")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.85))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(isLoading)
                        } else {
                            // 非创建者：订阅/取消订阅
                            if isSubscribed {
                                Button {
                                    showChat = true
                                } label: {
                                    Label("进入频道", systemImage: "bubble.left.and.bubble.right.fill")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(ApocalypseTheme.primary)
                                        .foregroundColor(.black)
                                        .fontWeight(.semibold)
                                        .cornerRadius(12)
                                }

                                Button {
                                    Task { await unsubscribe() }
                                } label: {
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .progressViewStyle(.circular)
                                                .tint(ApocalypseTheme.textPrimary)
                                                .scaleEffect(0.8)
                                        }
                                        Image(systemName: "minus.circle")
                                        Text("取消订阅")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(ApocalypseTheme.textSecondary.opacity(0.15))
                                    .foregroundColor(ApocalypseTheme.textPrimary)
                                    .cornerRadius(12)
                                }
                                .disabled(isLoading)
                            } else {
                                Button {
                                    Task { await subscribe() }
                                } label: {
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .progressViewStyle(.circular)
                                                .tint(.black)
                                                .scaleEffect(0.8)
                                        }
                                        Image(systemName: "plus.circle")
                                        Text("订阅频道")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(ApocalypseTheme.primary)
                                    .foregroundColor(.black)
                                    .cornerRadius(12)
                                }
                                .disabled(isLoading)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 24)
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle("频道详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .alert("删除频道", isPresented: $showDeleteConfirm) {
                Button("取消", role: .cancel) {}
                Button("确认删除", role: .destructive) {
                    Task { await deleteChannel() }
                }
            } message: {
                Text("频道删除后无法恢复，所有订阅者将失去该频道。")
            }
            .sheet(isPresented: $showChat) {
                ChannelChatView(channel: channel)
                    .environmentObject(authManager)
            }
        }
    }

    // MARK: - 信息行

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 操作

    private func subscribe() async {
        guard let uid = authManager.currentUserId else { return }
        isLoading = true
        await communicationManager.subscribeToChannel(userId: uid, channelId: channel.id)
        isLoading = false
    }

    private func unsubscribe() async {
        guard let uid = authManager.currentUserId else { return }
        isLoading = true
        await communicationManager.unsubscribeFromChannel(userId: uid, channelId: channel.id)
        isLoading = false
    }

    private func deleteChannel() async {
        guard let uid = authManager.currentUserId else { return }
        isLoading = true
        await communicationManager.deleteChannel(channelId: channel.id, userId: uid)
        isLoading = false
        dismiss()
    }
}

#Preview {
    ChannelDetailView(channel: CommunicationChannel(
        id: UUID(),
        creatorId: UUID(),
        channelType: .public_,
        channelCode: "PUB-ABC123",
        name: "废土广播站",
        description: "废土世界的公共频道，欢迎所有幸存者加入。",
        isActive: true,
        memberCount: 42,
        createdAt: Date(),
        updatedAt: Date()
    ))
    .environmentObject(AuthManager.shared)
}
