//
//  AuthManager.swift
//  EarthLord
//
//  Created by feixiang yang on 2025/12/27.
//

import Foundation
import Combine
import Supabase
import Auth

// MARK: - 认证管理器
/// 管理用户认证流程，包括注册、登录、找回密码
///
/// 认证模式说明：
/// - 注册：发验证码 → 验证（此时已登录但没密码）→ 强制设置密码 → 完成
/// - 登录：邮箱 + 密码（直接登录）
/// - 找回密码：发验证码 → 验证（此时已登录）→ 设置新密码 → 完成
///
/// 重要：verifyOTP 成功后用户就已登录，但注册流程必须强制设置密码才能进入主页！
@MainActor
final class AuthManager: ObservableObject {

    // MARK: - 单例
    static let shared = AuthManager()

    // MARK: - 发布属性

    /// 是否已完成认证（已登录且完成所有流程）
    @Published private(set) var isAuthenticated: Bool = false

    /// OTP验证后需要设置密码
    @Published private(set) var needsPasswordSetup: Bool = false

    /// 当前登录用户
    @Published private(set) var currentUser: User?

    /// 是否正在加载
    @Published private(set) var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    /// 验证码是否已发送
    @Published private(set) var otpSent: Bool = false

    /// 验证码是否已验证（等待设置密码）
    @Published private(set) var otpVerified: Bool = false

    // MARK: - 私有属性

    /// Supabase 客户端
    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    // MARK: - 初始化

    private init() {
        // 监听认证状态变化
        Task {
            await setupAuthStateListener()
        }
    }

    // MARK: - 认证状态监听

    /// 设置认证状态监听器
    /// 监听 Supabase 认证事件，处理登录、登出、会话过期等情况
    private func setupAuthStateListener() async {
        for await (event, session) in supabase.auth.authStateChanges {
            await handleAuthEvent(event, session: session)
        }
    }

    /// 处理认证事件
    private func handleAuthEvent(_ event: AuthChangeEvent, session: Session?) async {
        print("[AuthManager] 认证事件: \(event)")

        switch event {
        case .initialSession:
            // 初始会话检查（应用启动时）
            handleSessionChange(session)

        case .signedIn:
            // 用户登录成功
            handleSessionChange(session)

        case .signedOut:
            // 用户登出（主动登出或会话过期）
            print("[AuthManager] 用户已登出")
            resetState()

        case .tokenRefreshed:
            // Token 刷新成功
            if let session = session {
                currentUser = session.user
                print("[AuthManager] Token 已刷新")
            }

        case .userUpdated:
            // 用户信息更新
            if let session = session {
                currentUser = session.user
                print("[AuthManager] 用户信息已更新")
            }

        case .passwordRecovery:
            // 密码恢复流程
            needsPasswordSetup = true
            otpVerified = true
            print("[AuthManager] 进入密码恢复流程")

        case .userDeleted:
            // 用户被删除
            print("[AuthManager] 用户已被删除")
            resetState()

        case .mfaChallengeVerified:
            // MFA 验证成功
            print("[AuthManager] MFA 验证成功")

        @unknown default:
            print("[AuthManager] 未知事件: \(event)")
        }
    }

    /// 处理会话变化
    private func handleSessionChange(_ session: Session?) {
        if let session = session {
            currentUser = session.user
            // 注意：不在这里设置 isAuthenticated
            // isAuthenticated 由具体的登录方法（signIn, completeRegistration等）控制
            // 这样可以避免 OTP 验证后自动进入主页的问题
            print("[AuthManager] 会话已更新，用户: \(session.user.email ?? "unknown")")
        } else {
            // 会话为空，可能是过期或未登录
            print("[AuthManager] 会话为空，重置状态")
            resetState()
        }
    }

    // MARK: - 注册流程

    /// 发送注册验证码
    /// - Parameter email: 邮箱地址
    ///
    /// 调用 supabase.auth.signInWithOTP，shouldCreateUser 设为 true 允许创建新用户
    func sendRegisterOTP(email: String) async {
        guard !email.isEmpty else {
            errorMessage = "请输入邮箱地址"
            return
        }

        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            try await supabase.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true
            )
            otpSent = true
        } catch {
            errorMessage = handleAuthError(error)
        }

        isLoading = false
    }

    /// 验证注册验证码
    /// - Parameters:
    ///   - email: 邮箱地址
    ///   - code: 验证码
    ///
    /// 验证成功后用户已登录，但 isAuthenticated 保持 false，需要设置密码
    func verifyRegisterOTP(email: String, code: String) async {
        guard !code.isEmpty else {
            errorMessage = "请输入验证码"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            // 验证成功，用户已登录，但需要设置密码
            otpVerified = true
            needsPasswordSetup = true
            // 注意：isAuthenticated 保持 false，直到设置密码完成

            // 获取当前用户信息
            if let session = try? await supabase.auth.session {
                currentUser = session.user
            }
        } catch {
            errorMessage = handleAuthError(error)
        }

        isLoading = false
    }

    /// 完成注册（设置密码）
    /// - Parameter password: 密码
    ///
    /// 设置密码后，注册流程完成，isAuthenticated 设为 true
    func completeRegistration(password: String) async {
        guard !password.isEmpty else {
            errorMessage = "请输入密码"
            return
        }

        guard password.count >= 6 else {
            errorMessage = "密码至少需要6位"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.update(
                user: UserAttributes(password: password)
            )

            // 密码设置成功，完成注册
            needsPasswordSetup = false
            otpVerified = false
            otpSent = false
            isAuthenticated = true
        } catch {
            errorMessage = handleAuthError(error)
        }

        isLoading = false
    }

    // MARK: - 登录

    /// 邮箱密码登录
    /// - Parameters:
    ///   - email: 邮箱地址
    ///   - password: 密码
    func signIn(email: String, password: String) async {
        guard !email.isEmpty else {
            errorMessage = "请输入邮箱地址"
            return
        }

        guard !password.isEmpty else {
            errorMessage = "请输入密码"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            currentUser = session.user
            isAuthenticated = true
        } catch {
            errorMessage = handleAuthError(error)
        }

        isLoading = false
    }

    // MARK: - 找回密码流程

    /// 发送重置密码验证码
    /// - Parameter email: 邮箱地址
    ///
    /// 触发 Reset Password 邮件模板
    func sendResetOTP(email: String) async {
        guard !email.isEmpty else {
            errorMessage = "请输入邮箱地址"
            return
        }

        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            try await supabase.auth.resetPasswordForEmail(email)
            otpSent = true
        } catch {
            errorMessage = handleAuthError(error)
        }

        isLoading = false
    }

    /// 验证重置密码验证码
    /// - Parameters:
    ///   - email: 邮箱地址
    ///   - code: 验证码
    ///
    /// 注意：type 是 .recovery 不是 .email
    func verifyResetOTP(email: String, code: String) async {
        guard !code.isEmpty else {
            errorMessage = "请输入验证码"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery
            )

            // 验证成功，用户已登录，需要设置新密码
            otpVerified = true
            needsPasswordSetup = true

            // 获取当前用户信息
            if let session = try? await supabase.auth.session {
                currentUser = session.user
            }
        } catch {
            errorMessage = handleAuthError(error)
        }

        isLoading = false
    }

    /// 重置密码
    /// - Parameter newPassword: 新密码
    func resetPassword(newPassword: String) async {
        guard !newPassword.isEmpty else {
            errorMessage = "请输入新密码"
            return
        }

        guard newPassword.count >= 6 else {
            errorMessage = "密码至少需要6位"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.update(
                user: UserAttributes(password: newPassword)
            )

            // 密码重置成功
            needsPasswordSetup = false
            otpVerified = false
            otpSent = false
            isAuthenticated = true
        } catch {
            errorMessage = handleAuthError(error)
        }

        isLoading = false
    }

    // MARK: - 第三方登录（预留）

    /// Apple 登录
    /// - TODO: 实现 Apple Sign In
    func signInWithApple() async {
        // TODO: 实现 Apple Sign In
        // 1. 使用 AuthenticationServices 获取 Apple ID 凭证
        // 2. 调用 supabase.auth.signInWithIdToken(credentials:)
        errorMessage = "Apple 登录功能开发中"
    }

    /// Google 登录
    /// - TODO: 实现 Google Sign In
    func signInWithGoogle() async {
        // TODO: 实现 Google Sign In
        // 1. 使用 GoogleSignIn SDK 获取 ID Token
        // 2. 调用 supabase.auth.signInWithIdToken(credentials:)
        errorMessage = "Google 登录功能开发中"
    }

    // MARK: - 其他方法

    /// 登出
    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.signOut()
            resetState()
        } catch {
            errorMessage = handleAuthError(error)
        }

        isLoading = false
    }

    /// 检查当前会话状态
    ///
    /// 应用启动时调用，恢复登录状态
    func checkSession() async {
        isLoading = true

        do {
            let session = try await supabase.auth.session
            currentUser = session.user

            // 检查用户是否通过邮箱密码注册（有 email identity）
            // 只有完成了密码设置的用户才能自动登录
            let hasEmailProvider = session.user.appMetadata["provider"] as? String == "email"
            let hasIdentities = !(session.user.identities?.isEmpty ?? true)

            if hasEmailProvider && hasIdentities {
                // 有完整的邮箱密码账户，自动登录
                isAuthenticated = true
            } else {
                // 可能是 OTP 验证但未设置密码的用户，需要重新认证
                isAuthenticated = false
            }
        } catch {
            // 没有有效会话，保持未认证状态
            resetState()
        }

        isLoading = false
    }

    // MARK: - 辅助方法

    /// 重置所有状态
    private func resetState() {
        isAuthenticated = false
        needsPasswordSetup = false
        currentUser = nil
        otpSent = false
        otpVerified = false
        errorMessage = nil
    }

    /// 重置 OTP 相关状态（用于切换流程）
    func resetOTPState() {
        otpSent = false
        otpVerified = false
        needsPasswordSetup = false
        errorMessage = nil
    }

    /// 处理认证错误
    /// - Parameter error: 错误对象
    /// - Returns: 用户友好的错误信息
    private func handleAuthError(_ error: Error) -> String {
        let errorString = String(describing: error)

        // 常见错误处理
        if errorString.contains("Invalid login credentials") {
            return "邮箱或密码错误"
        } else if errorString.contains("Email not confirmed") {
            return "邮箱未验证，请先验证邮箱"
        } else if errorString.contains("User already registered") {
            return "该邮箱已注册，请直接登录"
        } else if errorString.contains("Invalid OTP") || errorString.contains("Token has expired") {
            return "验证码无效或已过期"
        } else if errorString.contains("Email rate limit exceeded") {
            return "发送验证码过于频繁，请稍后再试"
        } else if errorString.contains("Network") || errorString.contains("URLError") {
            return "网络连接失败，请检查网络"
        } else if errorString.contains("Password should be at least") {
            return "密码强度不够，请使用更复杂的密码"
        } else if errorString.contains("User not found") {
            return "用户不存在"
        } else {
            // 返回原始错误信息用于调试
            print("Auth Error: \(error)")
            return "操作失败：\(error.localizedDescription)"
        }
    }
}

// MARK: - 便捷扩展
extension AuthManager {
    /// 当前用户 ID
    var currentUserId: UUID? {
        currentUser?.id
    }

    /// 当前用户邮箱
    var currentUserEmail: String? {
        currentUser?.email
    }

    /// 是否正在进行注册/找回密码流程
    var isInOTPFlow: Bool {
        otpSent || otpVerified || needsPasswordSetup
    }
}
