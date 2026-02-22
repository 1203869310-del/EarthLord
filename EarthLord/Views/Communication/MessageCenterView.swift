//
//  MessageCenterView.swift
//  EarthLord
//
//  消息聚合中心（Day 36）
//

import SwiftUI

struct MessageCenterView: View {
    @StateObject private var communicationManager = CommunicationManager.shared
    @ObservedObject private var authManager = AuthManager.shared

    @State private var isLoading = true
    @State private var selectedChannel: CommunicationChannel?
    @State private var showingChat = false
    @State private var showingOfficialChannel = false

    private var summaries: [CommunicationManager.ChannelSummary] {
        communicationManager.getChannelSummaries()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerView

                    if isLoading {
                        loadingView
                    } else if summaries.isEmpty {
                        emptyStateView
                    } else {
                        messageListView
                    }
                }
            }
            .onAppear { loadData() }
            .navigationDestination(isPresented: $showingChat) {
                if let channel = selectedChannel {
                    ChannelChatView(channel: channel)
                        .environmentObject(authManager)
                }
            }
            .navigationDestination(isPresented: $showingOfficialChannel) {
                if let channel = selectedChannel {
                    OfficialChannelDetailView(channel: channel)
                }
            }
        }
    }

    // MARK: - 标题栏

    private var headerView: some View {
        HStack {
            Text("消息中心")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            Button(action: { loadData() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18))
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 加载中

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
            Text("加载中...")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.top, 8)
            Spacer()
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
            Text("暂无消息")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text("订阅频道后，消息会显示在这里")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
        }
    }

    // MARK: - 消息列表

    private var messageListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(summaries) { summary in
                    Button(action: {
                        selectedChannel = summary.channel
                        if summary.channel.channelType == .official {
                            showingOfficialChannel = true
                        } else {
                            showingChat = true
                        }
                    }) {
                        MessageRowView(summary: summary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - 方法

    private func loadData() {
        isLoading = true
        Task {
            if let userId = authManager.currentUserId {
                await communicationManager.loadSubscribedChannels(userId: userId)
                await communicationManager.loadAllChannelLatestMessages()
            }
            isLoading = false
        }
    }
}
