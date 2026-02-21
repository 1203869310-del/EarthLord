//
//  ChannelCenterView.swift
//  EarthLord
//

import SwiftUI
import Supabase

struct ChannelCenterView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var selectedTab = 0
    @State private var showCreateSheet = false
    @State private var selectedChannel: CommunicationChannel?
    @State private var searchText = ""

    var filteredChannels: [CommunicationChannel] {
        if searchText.isEmpty {
            return communicationManager.channels
        }
        return communicationManager.channels.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.channelCode.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack {
                Text("频道")
                    .font(.title2).fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Spacer()
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            // Tab 栏
            HStack(spacing: 0) {
                tabButton(title: "我的频道", index: 0)
                tabButton(title: "发现频道", index: 1)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.3))

            // 内容区
            if selectedTab == 0 {
                myChannelsView
            } else {
                discoverChannelsView
            }
        }
        .background(ApocalypseTheme.background)
        .onAppear {
            Task {
                await communicationManager.loadPublicChannels()
                if let uid = authManager.currentUserId {
                    await communicationManager.loadSubscribedChannels(userId: uid)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateChannelSheet()
                .environmentObject(authManager)
        }
        .sheet(item: $selectedChannel) { channel in
            ChannelDetailView(channel: channel)
                .environmentObject(authManager)
        }
    }

    // MARK: - 我的频道 Tab

    @ViewBuilder
    private var myChannelsView: some View {
        if communicationManager.subscribedChannels.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 48))
                    .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.4))
                Text("暂无订阅频道")
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Text("去「发现频道」订阅感兴趣的频道")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(communicationManager.subscribedChannels) { subscribed in
                        channelRow(channel: subscribed.channel, isSubscribed: true)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - 发现频道 Tab

    @ViewBuilder
    private var discoverChannelsView: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(ApocalypseTheme.textSecondary)
                TextField("搜索频道名称或频道码", text: $searchText)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
            .padding(10)
            .background(ApocalypseTheme.textSecondary.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if filteredChannels.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.4))
                    Text(searchText.isEmpty ? "暂无可用频道" : "未找到匹配频道")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredChannels) { channel in
                            channelRow(
                                channel: channel,
                                isSubscribed: communicationManager.isSubscribed(channelId: channel.id)
                            )
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - 频道行

    private func channelRow(channel: CommunicationChannel, isSubscribed: Bool) -> some View {
        Button {
            selectedChannel = channel
        } label: {
            HStack(spacing: 12) {
                // 频道图标
                ZStack {
                    Circle()
                        .fill(ApocalypseTheme.primary.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: channel.channelType.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(ApocalypseTheme.primary)
                }

                // 频道信息
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(channel.name)
                            .font(.body).fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Spacer()
                        if isSubscribed {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    HStack(spacing: 6) {
                        Text(channel.channelCode)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ApocalypseTheme.primary.opacity(0.1))
                            .cornerRadius(4)
                        Text("\(channel.memberCount) 成员")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(ApocalypseTheme.background)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab 按钮

    private func tabButton(title: String, index: Int) -> some View {
        Button {
            selectedTab = index
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(selectedTab == index ? .semibold : .regular)
                    .foregroundColor(
                        selectedTab == index ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary
                    )
                Rectangle()
                    .fill(selectedTab == index ? ApocalypseTheme.primary : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ChannelCenterView()
        .environmentObject(AuthManager.shared)
}
