//
//  CallsignSettingsSheet.swift
//  EarthLord
//
//  呼号设置弹窗（Day 36）
//

import SwiftUI
import Supabase

struct CallsignSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authManager = AuthManager.shared

    @State private var callsign: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false

    private var isValid: Bool {
        let t = callsign.trimmingCharacters(in: .whitespaces)
        return t.count >= 3 && t.count <= 20
    }

    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    infoSection
                    inputSection

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    saveButton
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("呼号设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
        .onAppear { loadCurrentCallsign() }
        .alert("保存成功", isPresented: $showingSuccess) {
            Button("确定") { dismiss() }
        } message: {
            Text("您的呼号已更新为：\(callsign)")
        }
    }

    // MARK: - 说明区

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(ApocalypseTheme.primary)
                Text("什么是呼号？")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Text("呼号是您在电波中的身份标识，其他幸存者会通过呼号识别您。就像真实电台中的 \"CQ CQ，这里是 BJ-Alpha-001\"。")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("推荐格式：")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                HStack(spacing: 8) {
                    ForEach(["BJ-Alpha-001", "SH-Beta-42", "Survivor-X"], id: \.self) { example in
                        Text(example)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ApocalypseTheme.primary.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 输入区

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("您的呼号")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)

            TextField("输入呼号（3-20字符）", text: $callsign)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(14)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(10)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isValid ? ApocalypseTheme.primary : Color.gray, lineWidth: 1)
                )
                .autocapitalization(.allCharacters)
                .disableAutocorrection(true)

            Text("仅支持字母、数字和连字符（-）")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 保存按钮

    private var saveButton: some View {
        Button(action: saveCallsign) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Text("保存呼号")
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(isValid ? ApocalypseTheme.primary : Color.gray)
        .foregroundColor(.white)
        .cornerRadius(10)
        .disabled(!isValid || isLoading)
    }

    // MARK: - 方法

    private func loadCurrentCallsign() {
        guard let userId = authManager.currentUserId else { return }
        Task {
            do {
                let response = try await SupabaseManager.shared.client
                    .from("user_profiles")
                    .select("callsign")
                    .eq("user_id", value: userId.uuidString)
                    .limit(1)
                    .execute()

                struct ProfileRow: Decodable { let callsign: String? }
                let rows = try JSONDecoder().decode([ProfileRow].self, from: response.data)
                if let saved = rows.first?.callsign {
                    callsign = saved
                }
            } catch {
                // 未设置呼号视为正常，不报错
            }
        }
    }

    private func saveCallsign() {
        guard isValid else { return }

        let pattern = "^[A-Za-z0-9-]+$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              regex.firstMatch(in: callsign, range: NSRange(callsign.startIndex..., in: callsign)) != nil else {
            errorMessage = "呼号只能包含字母、数字和连字符"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                guard let userId = authManager.currentUserId else {
                    throw NSError(domain: "", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
                }

                let upsertData: [String: AnyJSON] = [
                    "user_id":  .string(userId.uuidString),
                    "callsign": .string(callsign)
                ]
                try await SupabaseManager.shared.client
                    .from("user_profiles")
                    .upsert(upsertData, onConflict: "user_id")
                    .execute()

                isLoading = false
                showingSuccess = true
            } catch {
                isLoading = false
                errorMessage = "保存失败：\(error.localizedDescription)"
            }
        }
    }
}
