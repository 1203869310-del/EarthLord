//
//  AuthView.swift
//  EarthLord
//
//  Created by feixiang yang on 2025/12/27.
//

import SwiftUI

// MARK: - 认证页面
struct AuthView: View {
    @StateObject private var authManager = AuthManager.shared

    // MARK: - 状态
    @State private var selectedTab: AuthTab = .login
    @State private var showForgotPassword = false

    // 登录表单
    @State private var loginEmail = ""
    @State private var loginPassword = ""

    // 注册表单
    @State private var registerEmail = ""
    @State private var registerOTP = ""
    @State private var registerPassword = ""
    @State private var registerConfirmPassword = ""

    // 忘记密码表单
    @State private var resetEmail = ""
    @State private var resetOTP = ""
    @State private var resetPassword = ""
    @State private var resetConfirmPassword = ""
    @State private var resetStep: Int = 1

    // 倒计时
    @State private var countdown: Int = 0
    @State private var countdownTimer: Timer?

    // Toast
    @State private var showToast = false
    @State private var toastMessage = ""

    enum AuthTab: String, CaseIterable {
        case login = "登录"
        case register = "注册"
    }

    var body: some View {
        ZStack {
            // 背景渐变
            backgroundGradient

            ScrollView {
                VStack(spacing: 32) {
                    // Logo 和标题
                    headerView

                    // Tab 切换
                    tabSelector

                    // 内容区域
                    contentView

                    // 分隔线
                    dividerView

                    // 第三方登录
                    socialLoginButtons
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
            }

            // 加载遮罩
            if authManager.isLoading {
                loadingOverlay
            }

            // Toast 提示
            if showToast {
                toastView
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordSheet
        }
        .onChange(of: authManager.errorMessage) { _, newValue in
            if let message = newValue {
                showToastMessage(message)
            }
        }
    }

    // MARK: - 背景渐变
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.05, green: 0.05, blue: 0.08),
                Color(red: 0.10, green: 0.08, blue: 0.15),
                Color(red: 0.08, green: 0.06, blue: 0.12)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - 头部
    private var headerView: some View {
        VStack(spacing: 16) {
            // Logo
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "globe.asia.australia.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }

            // 标题
            Text("地球新主")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)

            Text("征服世界，从脚下开始")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(.top, 20)
    }

    // MARK: - Tab 选择器
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(AuthTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                        // 切换时重置状态
                        authManager.resetOTPState()
                        resetFormFields()
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.headline)
                            .foregroundColor(selectedTab == tab ? .white : ApocalypseTheme.textSecondary)

                        Rectangle()
                            .fill(selectedTab == tab ? ApocalypseTheme.primary : Color.clear)
                            .frame(height: 3)
                            .cornerRadius(1.5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 内容区域
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .login:
            loginView
        case .register:
            registerView
        }
    }

    // MARK: - 登录视图
    private var loginView: some View {
        VStack(spacing: 20) {
            // 邮箱输入
            AuthTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $loginEmail,
                keyboardType: .emailAddress
            )

            // 密码输入
            AuthTextField(
                icon: "lock.fill",
                placeholder: "密码",
                text: $loginPassword,
                isSecure: true
            )

            // 登录按钮
            AuthButton(title: "登录") {
                Task {
                    await authManager.signIn(email: loginEmail, password: loginPassword)
                }
            }

            // 忘记密码
            Button {
                resetStep = 1
                resetEmail = ""
                resetOTP = ""
                resetPassword = ""
                resetConfirmPassword = ""
                authManager.resetOTPState()
                showForgotPassword = true
            } label: {
                Text("忘记密码？")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
    }

    // MARK: - 注册视图（三步流程）
    private var registerView: some View {
        VStack(spacing: 20) {
            // 步骤指示器
            stepIndicator

            // 根据状态显示不同步骤
            if authManager.needsPasswordSetup && authManager.otpVerified {
                // 第三步：设置密码
                registerStep3
            } else if authManager.otpSent && !authManager.otpVerified {
                // 第二步：输入验证码
                registerStep2
            } else {
                // 第一步：输入邮箱
                registerStep1
            }
        }
    }

    // MARK: - 步骤指示器
    private var stepIndicator: some View {
        HStack(spacing: 12) {
            ForEach(1...3, id: \.self) { step in
                HStack(spacing: 8) {
                    Circle()
                        .fill(currentStep >= step ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text("\(step)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )

                    if step < 3 {
                        Rectangle()
                            .fill(currentStep > step ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                            .frame(height: 2)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    private var currentStep: Int {
        if authManager.needsPasswordSetup && authManager.otpVerified {
            return 3
        } else if authManager.otpSent {
            return 2
        } else {
            return 1
        }
    }

    // MARK: - 注册第一步：邮箱
    private var registerStep1: some View {
        VStack(spacing: 20) {
            Text("输入您的邮箱")
                .font(.headline)
                .foregroundColor(.white)

            AuthTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $registerEmail,
                keyboardType: .emailAddress
            )

            AuthButton(title: "发送验证码") {
                Task {
                    await authManager.sendRegisterOTP(email: registerEmail)
                    if authManager.otpSent {
                        startCountdown()
                    }
                }
            }
        }
    }

    // MARK: - 注册第二步：验证码
    private var registerStep2: some View {
        VStack(spacing: 20) {
            Text("输入验证码")
                .font(.headline)
                .foregroundColor(.white)

            Text("验证码已发送至 \(registerEmail)")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 验证码输入
            OTPInputView(code: $registerOTP)

            // 验证按钮
            AuthButton(title: "验证") {
                Task {
                    await authManager.verifyRegisterOTP(email: registerEmail, code: registerOTP)
                }
            }

            // 重发验证码
            resendButton {
                Task {
                    await authManager.sendRegisterOTP(email: registerEmail)
                    if authManager.otpSent {
                        startCountdown()
                    }
                }
            }
        }
    }

    // MARK: - 注册第三步：设置密码
    private var registerStep3: some View {
        VStack(spacing: 20) {
            Text("设置登录密码")
                .font(.headline)
                .foregroundColor(.white)

            Text("请设置密码以完成注册")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            AuthTextField(
                icon: "lock.fill",
                placeholder: "密码（至少6位）",
                text: $registerPassword,
                isSecure: true
            )

            AuthTextField(
                icon: "lock.fill",
                placeholder: "确认密码",
                text: $registerConfirmPassword,
                isSecure: true
            )

            AuthButton(title: "完成注册") {
                if registerPassword != registerConfirmPassword {
                    showToastMessage("两次输入的密码不一致")
                    return
                }
                Task {
                    await authManager.completeRegistration(password: registerPassword)
                }
            }
        }
    }

    // MARK: - 重发验证码按钮
    private func resendButton(action: @escaping () -> Void) -> some View {
        Button {
            if countdown == 0 {
                action()
            }
        } label: {
            if countdown > 0 {
                Text("\(countdown)秒后可重发")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else {
                Text("重新发送验证码")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .disabled(countdown > 0)
    }

    // MARK: - 分隔线
    private var dividerView: some View {
        HStack {
            Rectangle()
                .fill(ApocalypseTheme.textMuted.opacity(0.3))
                .frame(height: 1)

            Text("或者使用以下方式登录")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
                .fixedSize()

            Rectangle()
                .fill(ApocalypseTheme.textMuted.opacity(0.3))
                .frame(height: 1)
        }
    }

    // MARK: - 第三方登录按钮
    private var socialLoginButtons: some View {
        VStack(spacing: 12) {
            // Apple 登录
            Button {
                showToastMessage("Apple 登录即将开放")
            } label: {
                HStack {
                    Image(systemName: "apple.logo")
                        .font(.title2)
                    Text("通过 Apple 登录")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }

            // Google 登录
            Button {
                showToastMessage("Google 登录即将开放")
            } label: {
                HStack {
                    Image(systemName: "g.circle.fill")
                        .font(.title2)
                    Text("通过 Google 登录")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - 加载遮罩
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                Text("请稍候...")
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - Toast 视图
    private var toastView: some View {
        VStack {
            Spacer()

            Text(toastMessage)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.danger.opacity(0.9))
                .cornerRadius(25)
                .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut, value: showToast)
    }

    // MARK: - 忘记密码弹窗
    private var forgotPasswordSheet: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 步骤指示
                        forgotPasswordStepIndicator

                        // 根据步骤显示内容
                        switch resetStep {
                        case 1:
                            forgotPasswordStep1
                        case 2:
                            forgotPasswordStep2
                        case 3:
                            forgotPasswordStep3
                        default:
                            EmptyView()
                        }
                    }
                    .padding(24)
                }

                if authManager.isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle("找回密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showForgotPassword = false
                        authManager.resetOTPState()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - 忘记密码步骤指示器
    private var forgotPasswordStepIndicator: some View {
        HStack(spacing: 12) {
            ForEach(1...3, id: \.self) { step in
                HStack(spacing: 8) {
                    Circle()
                        .fill(resetStep >= step ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text("\(step)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )

                    if step < 3 {
                        Rectangle()
                            .fill(resetStep > step ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                            .frame(height: 2)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 忘记密码第一步
    private var forgotPasswordStep1: some View {
        VStack(spacing: 20) {
            Text("输入注册邮箱")
                .font(.headline)
                .foregroundColor(.white)

            AuthTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $resetEmail,
                keyboardType: .emailAddress
            )

            AuthButton(title: "发送验证码") {
                Task {
                    await authManager.sendResetOTP(email: resetEmail)
                    if authManager.otpSent {
                        startCountdown()
                        resetStep = 2
                    }
                }
            }
        }
    }

    // MARK: - 忘记密码第二步
    private var forgotPasswordStep2: some View {
        VStack(spacing: 20) {
            Text("输入验证码")
                .font(.headline)
                .foregroundColor(.white)

            Text("验证码已发送至 \(resetEmail)")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            OTPInputView(code: $resetOTP)

            AuthButton(title: "验证") {
                Task {
                    await authManager.verifyResetOTP(email: resetEmail, code: resetOTP)
                    if authManager.otpVerified {
                        resetStep = 3
                    }
                }
            }

            resendButton {
                Task {
                    await authManager.sendResetOTP(email: resetEmail)
                    if authManager.otpSent {
                        startCountdown()
                    }
                }
            }
        }
    }

    // MARK: - 忘记密码第三步
    private var forgotPasswordStep3: some View {
        VStack(spacing: 20) {
            Text("设置新密码")
                .font(.headline)
                .foregroundColor(.white)

            AuthTextField(
                icon: "lock.fill",
                placeholder: "新密码（至少6位）",
                text: $resetPassword,
                isSecure: true
            )

            AuthTextField(
                icon: "lock.fill",
                placeholder: "确认新密码",
                text: $resetConfirmPassword,
                isSecure: true
            )

            AuthButton(title: "重置密码") {
                if resetPassword != resetConfirmPassword {
                    showToastMessage("两次输入的密码不一致")
                    return
                }
                Task {
                    await authManager.resetPassword(newPassword: resetPassword)
                    if authManager.isAuthenticated {
                        showForgotPassword = false
                    }
                }
            }
        }
    }

    // MARK: - 辅助方法

    private func startCountdown() {
        countdown = 60
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                countdownTimer?.invalidate()
            }
        }
    }

    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showToast = false
            }
        }
    }

    private func resetFormFields() {
        loginEmail = ""
        loginPassword = ""
        registerEmail = ""
        registerOTP = ""
        registerPassword = ""
        registerConfirmPassword = ""
        countdown = 0
        countdownTimer?.invalidate()
    }
}

// MARK: - 自定义输入框
struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    @State private var isPasswordVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 20)

            if isSecure && !isPasswordVisible {
                SecureField(placeholder, text: $text)
                    .foregroundColor(.white)
            } else {
                TextField(placeholder, text: $text)
                    .foregroundColor(.white)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if isSecure {
                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - 自定义按钮
struct AuthButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
        }
    }
}

// MARK: - OTP 输入视图
struct OTPInputView: View {
    @Binding var code: String
    @FocusState private var isFocused: Bool

    let codeLength = 6

    var body: some View {
        ZStack {
            // 隐藏的文本输入框
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .opacity(0)
                .onChange(of: code) { _, newValue in
                    // 限制长度
                    if newValue.count > codeLength {
                        code = String(newValue.prefix(codeLength))
                    }
                    // 只允许数字
                    code = code.filter { $0.isNumber }
                }

            // 显示的方框
            HStack(spacing: 10) {
                ForEach(0..<codeLength, id: \.self) { index in
                    let character = getCharacter(at: index)

                    Text(character)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 45, height: 55)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    index == code.count && isFocused
                                        ? ApocalypseTheme.primary
                                        : ApocalypseTheme.textMuted.opacity(0.3),
                                    lineWidth: index == code.count && isFocused ? 2 : 1
                                )
                        )
                }
            }
        }
        .onTapGesture {
            isFocused = true
        }
        .onAppear {
            isFocused = true
        }
    }

    private func getCharacter(at index: Int) -> String {
        if index < code.count {
            let stringIndex = code.index(code.startIndex, offsetBy: index)
            return String(code[stringIndex])
        }
        return ""
    }
}

// MARK: - 预览
#Preview {
    AuthView()
}
