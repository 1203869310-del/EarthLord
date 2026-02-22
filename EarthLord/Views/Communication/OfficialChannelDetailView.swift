//
//  OfficialChannelDetailView.swift
//  EarthLord
//
//  官方频道详情页（Day 36）
//

import SwiftUI

struct OfficialChannelDetailView: View {
    let channel: CommunicationChannel

    @StateObject private var communicationManager = CommunicationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: MessageCategory?
    @State private var isLoading = true

    private var messages: [ChannelMessage] {
        let all = communicationManager.getMessages(for: channel.id)
        if let category = selectedCategory {
            return all.filter { $0.category == category }
        }
        return all
    }

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                navigationBar
                categoryFilter
                messageListView
            }
        }
        .navigationBarHidden(true)
        .onAppear { loadMessages() }
    }

    // MARK: - 导航栏

    private var navigationBar: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "megaphone.fill")
                        .foregroundColor(.red)
                    Text(channel.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                Text("官方公告 · 全球覆盖")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 分类过滤器

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(
                    title: "全部",
                    icon: "list.bullet",
                    color: ApocalypseTheme.primary,
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }
                ForEach(MessageCategory.allCases, id: \.self) { cat in
                    CategoryChip(
                        title: cat.displayName,
                        icon: cat.iconName,
                        color: cat.color,
                        isSelected: selectedCategory == cat
                    ) {
                        selectedCategory = cat
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
    }

    // MARK: - 消息列表

    private var messageListView: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                    .padding(.top, 50)
            } else if messages.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        OfficialMessageBubble(message: message)
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
            Text(selectedCategory == nil ? "暂无公告" : "暂无\(selectedCategory!.displayName)")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Spacer()
        }
    }

    private func loadMessages() {
        isLoading = true
        Task {
            await communicationManager.loadChannelMessages(channelId: channel.id)
            isLoading = false
        }
    }
}

// MARK: - 分类标签组件

struct CategoryChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : color.opacity(0.15))
            .cornerRadius(16)
        }
    }
}

// MARK: - 官方消息气泡

struct OfficialMessageBubble: View {
    let message: ChannelMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let category = message.category {
                HStack(spacing: 4) {
                    Image(systemName: category.iconName)
                        .font(.system(size: 12))
                    Text(category.displayName)
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .foregroundColor(category.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(category.color.opacity(0.15))
                .cornerRadius(8)
            }

            Text(message.content)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(message.timeAgo)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(message.category?.color.opacity(0.3) ?? Color.clear, lineWidth: 1)
        )
    }
}
