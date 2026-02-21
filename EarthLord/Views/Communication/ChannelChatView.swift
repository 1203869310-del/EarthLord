//
//  ChannelChatView.swift
//  EarthLord
//

import SwiftUI
import CoreLocation

struct ChannelChatView: View {
    let channel: CommunicationChannel
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var messageText = ""
    @State private var scrollProxy: ScrollViewProxy?

    private var messages: [ChannelMessage] {
        communicationManager.getMessages(for: channel.id)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // 消息列表
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if messages.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .font(.system(size: 40))
                                        .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.4))
                                    Text("暂无消息，发送第一条吧")
                                        .font(.subheadline)
                                        .foregroundColor(ApocalypseTheme.textSecondary)
                                }
                                .padding(.top, 60)
                            } else {
                                ForEach(messages) { message in
                                    MessageBubbleView(
                                        message: message,
                                        isOwn: message.senderId == authManager.currentUserId
                                    )
                                    .id(message.id)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: messages.count) { _ in
                        if let last = messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear { scrollProxy = proxy }
                }

                Divider()
                    .background(ApocalypseTheme.textSecondary.opacity(0.2))

                // 输入区
                if communicationManager.canSendMessage() {
                    HStack(spacing: 8) {
                        TextField("输入消息...", text: $messageText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(ApocalypseTheme.textSecondary.opacity(0.1))
                            .cornerRadius(20)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Button {
                            Task { await sendMessage() }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(
                                    messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? ApocalypseTheme.textSecondary.opacity(0.4)
                                    : ApocalypseTheme.primary
                                )
                        }
                        .disabled(
                            messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || communicationManager.isSendingMessage
                        )
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ApocalypseTheme.background)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "radio")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Text("收音机模式：只能收听，无法发送消息")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ApocalypseTheme.background)
                }
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle(channel.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .onAppear {
                Task {
                    await communicationManager.loadChannelMessages(channelId: channel.id)
                    communicationManager.subscribeToChannelMessages(channelId: channel.id)
                }
            }
            .onDisappear {
                communicationManager.unsubscribeFromChannelMessages(channelId: channel.id)
            }
        }
    }

    private func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messageText = ""
        let deviceType = communicationManager.getCurrentDeviceType().rawValue
        let coord = LocationManager.shared.userLocation
        await communicationManager.sendChannelMessage(
            channelId: channel.id,
            content: text,
            deviceType: deviceType,
            latitude: coord?.latitude,
            longitude: coord?.longitude
        )
    }
}

// MARK: - 消息气泡

private struct MessageBubbleView: View {
    let message: ChannelMessage
    let isOwn: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if isOwn { Spacer(minLength: 60) }

            VStack(alignment: isOwn ? .trailing : .leading, spacing: 4) {
                if !isOwn, let callsign = message.senderCallsign {
                    Text(callsign)
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 4)
                }

                Text(message.content)
                    .font(.body)
                    .foregroundColor(isOwn ? .black : ApocalypseTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        isOwn
                        ? ApocalypseTheme.primary
                        : ApocalypseTheme.textSecondary.opacity(0.15)
                    )
                    .cornerRadius(16)

                HStack(spacing: 4) {
                    Image(systemName: deviceIconName(for: message.deviceType))
                        .font(.system(size: 10))
                        .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.6))
                    Text(message.timeAgo)
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.6))
                }
                .padding(.horizontal, 4)
            }

            if !isOwn { Spacer(minLength: 60) }
        }
    }

    private func deviceIconName(for deviceType: String?) -> String {
        switch deviceType {
        case "radio":        return "radio"
        case "walkie_talkie": return "phone.badge.waveform"
        case "camp_radio":   return "antenna.radiowaves.left.and.right"
        case "satellite":    return "antenna.radiowaves.left.and.right.circle"
        default:             return "iphone"
        }
    }
}

#Preview {
    ChannelChatView(channel: CommunicationChannel(
        id: UUID(),
        creatorId: UUID(),
        channelType: .public_,
        channelCode: "PUB-ABC123",
        name: "废土广播站",
        description: "废土世界的公共频道",
        isActive: true,
        memberCount: 42,
        createdAt: Date(),
        updatedAt: Date()
    ))
    .environmentObject(AuthManager.shared)
}
