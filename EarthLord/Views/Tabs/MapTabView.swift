//
//  MapTabView.swift
//  EarthLord
//
//  地图页面 - 显示末世风格地图、用户位置和圈地功能
//

import SwiftUI
import MapKit

// MARK: - MapTabView

struct MapTabView: View {

    // MARK: - State

    /// 定位管理器（使用 EnvironmentObject 与其他页面共享）
    @EnvironmentObject var locationManager: LocationManager

    /// 领地管理器
    @StateObject private var territoryManager = TerritoryManager.shared

    /// 用户位置（从地图回传）
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @State private var hasLocatedUser = false

    /// 是否显示验证结果横幅
    @State private var showValidationBanner = false

    /// 追踪开始时间
    @State private var trackingStartTime: Date?

    /// 是否正在上传
    @State private var isUploading = false

    /// 上传成功提示
    @State private var showUploadSuccess = false

    /// 上传错误信息
    @State private var uploadError: String?

    /// 已加载的领地列表
    @State private var territories: [Territory] = []

    /// 碰撞警告信息
    @State private var collisionWarning: String?

    /// 是否正在检测碰撞
    @State private var isCheckingCollision = false

    /// 探索管理器
    @StateObject private var explorationManager = ExplorationManager.shared

    /// 背包管理器
    @StateObject private var inventoryManager = InventoryManager.shared

    /// 是否显示探索结果
    @State private var showExplorationResult = false

    /// 是否显示 POI 详情
    @State private var selectedPOI: POI?
    @State private var showPOIDetail = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // 底层：末世风格地图
            MapViewRepresentable(
                userLocation: $userLocation,
                hasLocatedUser: $hasLocatedUser,
                trackingPath: $locationManager.pathCoordinates,
                pathUpdateVersion: locationManager.pathUpdateVersion,
                isTracking: locationManager.isTracking,
                isPathClosed: locationManager.isPathClosed,
                territories: territories,
                currentUserId: AuthManager.shared.currentUserId?.uuidString,
                pois: explorationManager.pois,
                scavengablePOI: explorationManager.currentPOI,
                buildings: BuildingManager.shared.playerBuildings,
                buildingTemplates: BuildingManager.shared.buildingTemplates
            )
            .ignoresSafeArea()

            // 顶层：UI 覆盖层
            VStack {
                // 顶部状态栏
                topStatusBar

                // 碰撞警告横幅
                if let warning = collisionWarning {
                    collisionWarningBanner(warning)
                }

                // 分级预警横幅
                if locationManager.pathCollisionWarning != nil &&
                   locationManager.isTracking {
                    territoryWarningBanner
                }

                // 速度警告横幅
                if locationManager.speedWarning != nil {
                    speedWarningBanner
                }

                // 验证结果横幅（根据验证结果显示成功或失败）
                if showValidationBanner {
                    validationResultBanner
                }

                // 上传成功提示
                if showUploadSuccess {
                    uploadSuccessBanner
                }

                // 上传错误提示
                if let error = uploadError {
                    uploadErrorBanner(error)
                }

                // 探索状态栏（探索进行中时显示）
                if explorationManager.state == .active {
                    explorationStatusBar
                }

                Spacer()

                // 底部控制栏
                bottomControlBar
            }

            // 权限被拒绝时显示提示卡片
            if locationManager.isDenied {
                permissionDeniedCard
            }

            // 搜刮提示弹窗（底部弹出）
            if explorationManager.showPOIPopup, let poi = explorationManager.currentPOI {
                VStack {
                    Spacer()
                    ScavengePromptView(
                        poi: poi,
                        distance: explorationManager.distanceToPOI(poi),
                        onScavenge: {
                            explorationManager.scavengePOI()
                        },
                        onDismiss: {
                            explorationManager.dismissPOIPopup()
                        }
                    )
                }
                .transition(.move(edge: .bottom))
                .zIndex(100)
            }

            // 搜刮加载中
            if explorationManager.isScavenging {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()

                ScavengingLoadingView()
                    .zIndex(101)
            }

            // 搜刮结果弹窗
            if explorationManager.showScavengeResult, let result = explorationManager.scavengeResult {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        explorationManager.dismissScavengeResult()
                    }

                ScavengeResultView(
                    result: result,
                    onDismiss: {
                        explorationManager.dismissScavengeResult()
                    }
                )
                .zIndex(102)
            }
        }
        .onAppear {
            // 页面出现时请求定位权限
            if locationManager.isNotDetermined {
                locationManager.requestPermission()
            } else if locationManager.isAuthorized {
                locationManager.startUpdatingLocation()
            }

            // 设置 LocationManager 引用到 ExplorationManager
            explorationManager.setLocationManager(locationManager)

            // 如果探索状态卡在 completed 但结果弹窗未显示，自动重置
            if explorationManager.state == .completed && !showExplorationResult {
                print("⚠️ [探索] 检测到状态卡住，自动重置")
                explorationManager.reset()
            }

            // 加载已有领地
            Task {
                await loadTerritories()
            }

            // 加载物品定义（用于奖励生成）
            Task {
                await inventoryManager.loadItemDefinitions()
            }
        }
        // 监听闭环状态，闭环后根据验证结果显示横幅
        .onReceive(locationManager.$isPathClosed) { isClosed in
            if isClosed {
                // 闭环后延迟一点点，等待验证结果
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        showValidationBanner = true
                    }
                    // 3 秒后自动隐藏
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showValidationBanner = false
                        }
                    }
                }
            }
        }
        // 监听探索状态变化
        .onReceive(explorationManager.$state) { state in
            switch state {
            case .active:
                // 探索开始，在地图页面显示状态栏（不跳转）
                break
            case .completed:
                // 探索完成，显示结果界面
                showExplorationResult = true
            case .idle:
                // 空闲状态
                break
            }
        }
        // 探索结果界面（Sheet）
        .sheet(isPresented: $showExplorationResult) {
            // 关闭时重置探索状态
            explorationManager.reset()
        } content: {
            if let result = explorationManager.lastExplorationResult {
                ExplorationResultView(result: result)
            }
        }
    }

    // MARK: - Top Status Bar

    /// 顶部状态栏：显示坐标信息
    private var topStatusBar: some View {
        HStack {
            // 位置图标
            Image(systemName: "location.fill")
                .foregroundColor(ApocalypseTheme.primary)
                .font(.system(size: 14))

            // 坐标文字
            if let location = userLocation {
                Text(String(format: "%.4f, %.4f", location.latitude, location.longitude))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            } else {
                Text("定位中...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 末世日期标签（装饰）
            Text("Day 1")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(ApocalypseTheme.warning)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ApocalypseTheme.warning.opacity(0.2))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [
                    ApocalypseTheme.cardBackground.opacity(0.95),
                    ApocalypseTheme.cardBackground.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Exploration Status Bar

    /// 探索状态栏（探索进行中时显示在地图上方）
    private var explorationStatusBar: some View {
        HStack(spacing: 16) {
            // 探索中指示器
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("探索中")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.green)
            }

            // 分隔线
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 1, height: 20)

            // 距离
            HStack(spacing: 4) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 12))
                Text("\(Int(explorationManager.totalDistance))m")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
            }
            .foregroundColor(.white)

            // 时间
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                Text(formatDuration(explorationManager.duration))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
            }
            .foregroundColor(.white)

            // 奖励等级
            Text(explorationManager.currentTier.rawValue)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(tierColor(explorationManager.currentTier))
                .clipShape(Capsule())

            Spacer()

            // 结束探索按钮
            Button(action: {
                explorationManager.stopExploration()
            }) {
                Text("结束")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ApocalypseTheme.danger)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ApocalypseTheme.cardBackground.opacity(0.95)
        )
    }

    /// 格式化探索时长
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    /// 奖励等级颜色
    private func tierColor(_ tier: RewardTier) -> Color {
        switch tier {
        case .none: return .gray
        case .bronze: return .brown
        case .silver: return .gray
        case .gold: return .yellow
        case .diamond: return .cyan
        }
    }

    // MARK: - Bottom Control Bar

    /// 底部控制栏：定位按钮 + 圈地按钮 + 探索按钮 + 确认登记按钮
    private var bottomControlBar: some View {
        HStack(alignment: .bottom) {
            // 左侧：验证通过时显示「确认登记领地」按钮
            if locationManager.territoryValidationPassed {
                confirmTerritoryButton
                    .padding(.leading, 16)
                    .padding(.bottom, 30)
            }

            Spacer()

            HStack(spacing: 12) {
                // 探索按钮（点击后自动搜索附近 POI）
                explorationButton

                VStack(spacing: 12) {
                    // 定位按钮
                    locationButton

                    // 圈地按钮
                    trackingButton
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 30)
        }
    }

    // MARK: - Confirm Territory Button

    /// 确认登记领地按钮（仅在验证通过时显示）
    private var confirmTerritoryButton: some View {
        Button(action: {
            Task {
                await uploadCurrentTerritory()
            }
        }) {
            HStack(spacing: 8) {
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(isUploading ? "上传中..." : "确认登记领地")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.green)
            )
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .disabled(isUploading)
        .opacity(isUploading ? 0.7 : 1.0)
    }

    // MARK: - Location Button

    /// 定位按钮
    private var locationButton: some View {
        Button(action: {
            // 重新请求定位或居中到用户位置
            if locationManager.isAuthorized {
                locationManager.startUpdatingLocation()
                // 重置居中标志，下次位置更新时会自动居中
                hasLocatedUser = false
            } else if locationManager.isDenied {
                // 打开设置
                locationManager.openSettings()
            } else {
                locationManager.requestPermission()
            }
        }) {
            ZStack {
                // 背景圆
                Circle()
                    .fill(ApocalypseTheme.cardBackground)
                    .frame(width: 50, height: 50)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                // 定位图标
                Image(systemName: locationIcon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(locationIconColor)
            }
        }
    }

    /// 定位按钮图标
    private var locationIcon: String {
        if locationManager.isDenied {
            return "location.slash.fill"
        } else if hasLocatedUser {
            return "location.fill"
        } else {
            return "location"
        }
    }

    /// 定位按钮颜色
    private var locationIconColor: Color {
        if locationManager.isDenied {
            return ApocalypseTheme.danger
        } else if hasLocatedUser {
            return ApocalypseTheme.primary
        } else {
            return ApocalypseTheme.textSecondary
        }
    }

    // MARK: - Exploration Button

    /// 探索按钮
    private var explorationButton: some View {
        Button(action: {
            performExploration()
        }) {
            VStack(spacing: 6) {
                Image(systemName: "binoculars.fill")
                    .font(.system(size: 16, weight: .semibold))

                Text("探索")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(width: 70)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [ApocalypseTheme.primary, ApocalypseTheme.primary.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .disabled(explorationManager.state != .idle || !locationManager.isAuthorized)
        .opacity(explorationManager.state != .idle || !locationManager.isAuthorized ? 0.7 : 1.0)
    }

    /// 执行探索
    private func performExploration() {
        Task {
            // 确保物品定义已加载
            if inventoryManager.itemDefinitions.isEmpty {
                await inventoryManager.loadItemDefinitions()
            }

            // 然后开始探索
            explorationManager.startExploration()
            TerritoryLogger.shared.log("用户点击开始探索", type: .info)
        }
    }

    // MARK: - Tracking Button

    /// 圈地按钮
    private var trackingButton: some View {
        Button(action: {
            if locationManager.isTracking {
                // 停止追踪
                locationManager.stopPathTracking()
                trackingStartTime = nil
            } else {
                // 开始追踪前检测碰撞
                Task {
                    await checkCollisionAndStartTracking()
                }
            }
        }) {
            HStack(spacing: 8) {
                // 图标
                Image(systemName: locationManager.isTracking ? "stop.fill" : "flag.fill")
                    .font(.system(size: 14, weight: .semibold))

                // 文字
                if locationManager.isTracking {
                    Text("停止圈地")
                        .font(.system(size: 14, weight: .semibold))

                    // 显示当前点数
                    Text("\(locationManager.pathPointCount)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                } else {
                    Text("开始圈地")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(locationManager.isTracking ? ApocalypseTheme.danger : ApocalypseTheme.primary)
            )
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        // 未授权或正在检测碰撞时禁用按钮
        .disabled(!locationManager.isAuthorized || isCheckingCollision)
        .opacity(locationManager.isAuthorized && !isCheckingCollision ? 1.0 : 0.5)
    }

    // MARK: - Speed Warning Banner

    /// 速度警告横幅
    private var speedWarningBanner: some View {
        HStack {
            // 警告图标
            Image(systemName: locationManager.isTracking ? "exclamationmark.triangle.fill" : "xmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))

            // 警告文字
            Text(locationManager.speedWarning ?? "")
                .font(.system(size: 14, weight: .medium))

            Spacer()

            // 关闭按钮
            Button(action: {
                locationManager.speedWarning = nil
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            // 根据追踪状态选择背景色
            // 还在追踪：黄色警告；已停止：红色错误
            locationManager.isTracking ?
                ApocalypseTheme.warning :
                ApocalypseTheme.danger
        )
        .onAppear {
            // 3 秒后自动消失
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                locationManager.speedWarning = nil
            }
        }
    }

    // MARK: - Validation Result Banner

    /// 验证结果横幅（根据验证结果显示成功或失败）
    private var validationResultBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: locationManager.territoryValidationPassed
                  ? "checkmark.circle.fill"
                  : "xmark.circle.fill")
                .font(.body)

            if locationManager.territoryValidationPassed {
                Text("圈地成功！领地面积: \(String(format: "%.0f", locationManager.calculatedArea))m²")
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                Text(locationManager.territoryValidationError ?? "验证失败")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(locationManager.territoryValidationPassed ? Color.green : Color.red)
        .padding(.top, 50)
    }

    // MARK: - Permission Denied Card

    /// 权限被拒绝时的提示卡片
    private var permissionDeniedCard: some View {
        VStack(spacing: 16) {
            // 警告图标
            Image(systemName: "location.slash.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(ApocalypseTheme.warning)

            // 标题
            Text("无法获取位置")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 说明
            Text("您已拒绝定位权限，无法在地图上显示您的位置。请在设置中开启定位权限。")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            // 前往设置按钮
            Button(action: {
                locationManager.openSettings()
            }) {
                HStack {
                    Image(systemName: "gearshape.fill")
                    Text("前往设置")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.primary)
                .clipShape(Capsule())
            }
        }
        .padding(24)
        .background(ApocalypseTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 32)
    }

    // MARK: - Upload Success Banner

    /// 上传成功横幅
    private var uploadSuccessBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.body)

            Text("领地登记成功！")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.green)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// 上传错误横幅
    private func uploadErrorBanner(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .font(.body)

            Text(error)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.red)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Upload Method

    /// 上传当前领地到数据库
    private func uploadCurrentTerritory() async {
        // 再次检查验证状态
        guard locationManager.territoryValidationPassed else {
            uploadError = "领地验证未通过，无法上传"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                uploadError = nil
            }
            return
        }

        // 保存当前数据（因为上传成功后会重置）
        let coordinates = locationManager.pathCoordinates
        let area = locationManager.calculatedArea
        let startTime = trackingStartTime ?? Date()

        isUploading = true
        uploadError = nil

        do {
            try await territoryManager.uploadTerritory(
                coordinates: coordinates,
                area: area,
                startTime: startTime
            )

            // 上传成功
            withAnimation {
                showUploadSuccess = true
                showValidationBanner = false
            }

            // 上传成功后停止追踪（会重置所有状态）
            locationManager.stopPathTracking()
            trackingStartTime = nil

            // 刷新领地列表，显示新上传的领地
            await loadTerritories()

            // 3秒后隐藏成功提示
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showUploadSuccess = false
                }
            }

        } catch {
            // 上传失败
            uploadError = "上传失败: \(error.localizedDescription)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                uploadError = nil
            }
        }

        isUploading = false
    }

    /// 加载所有领地
    private func loadTerritories() async {
        do {
            territories = try await territoryManager.loadAllTerritories()
            TerritoryLogger.shared.log("加载了 \(territories.count) 个领地", type: .info)
        } catch {
            TerritoryLogger.shared.log("加载领地失败: \(error.localizedDescription)", type: .error)
        }
    }

    // MARK: - Collision Detection

    /// 检测碰撞并开始追踪
    private func checkCollisionAndStartTracking() async {
        // 检查是否有当前位置
        guard let currentLocation = userLocation else {
            collisionWarning = "无法获取当前位置"
            hideCollisionWarningAfterDelay()
            return
        }

        isCheckingCollision = true
        collisionWarning = nil

        TerritoryLogger.shared.log("开始检测起始点碰撞", type: .info)

        do {
            // 检测碰撞
            if let _ = try await territoryManager.checkStartPointCollision(startPoint: currentLocation) {
                // 碰撞了！
                collisionWarning = "起始点位于他人领地内，请移动到安全区域"
                TerritoryLogger.shared.log("碰撞检测: 起始点在他人领地内", type: .error)
                hideCollisionWarningAfterDelay()
            } else {
                // 安全，开始追踪
                TerritoryLogger.shared.log("碰撞检测: 起始点安全 ✓", type: .success)
                trackingStartTime = Date()
                locationManager.startPathTracking()
            }
        } catch {
            collisionWarning = "检测失败: \(error.localizedDescription)"
            TerritoryLogger.shared.log("碰撞检测失败: \(error.localizedDescription)", type: .error)
            hideCollisionWarningAfterDelay()
        }

        isCheckingCollision = false
    }

    /// 延迟隐藏碰撞警告
    private func hideCollisionWarningAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation {
                collisionWarning = nil
            }
        }
    }

    // MARK: - Collision Warning Banner

    /// 起始点碰撞警告横幅
    private func collisionWarningBanner(_ warning: String) -> some View {
        HStack(spacing: 12) {
            // 警告图标
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            // 警告文字
            Text(warning)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)

            Spacer()

            // 关闭按钮
            Button(action: {
                withAnimation {
                    collisionWarning = nil
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color.red
                .overlay(
                    LinearGradient(
                        colors: [Color.red.opacity(0.9), Color.red],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// 领地分级预警横幅（根据预警级别显示不同颜色）
    private var territoryWarningBanner: some View {
        HStack(spacing: 12) {
            // 根据级别显示不同图标
            Group {
                switch locationManager.currentWarningLevel {
                case .violation:
                    Image(systemName: "xmark.circle.fill")
                case .danger:
                    Image(systemName: "exclamationmark.triangle.fill")
                case .caution:
                    Image(systemName: "exclamationmark.circle.fill")
                case .safe:
                    Image(systemName: "checkmark.circle.fill")
                }
            }
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(.white)

            // 警告文字
            VStack(alignment: .leading, spacing: 2) {
                Text(locationManager.currentWarningLevel.displayName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)

                Text(locationManager.pathCollisionWarning ?? "")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }

            Spacer()

            // 只有非违规状态才显示关闭按钮
            if locationManager.currentWarningLevel != .violation {
                Button(action: {
                    withAnimation {
                        locationManager.pathCollisionWarning = nil
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(warningBannerColor)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            // 非违规状态5秒后自动消失
            if locationManager.currentWarningLevel != .violation {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    withAnimation {
                        locationManager.pathCollisionWarning = nil
                    }
                }
            }
        }
    }

    /// 根据预警级别返回对应颜色
    private var warningBannerColor: some View {
        Group {
            switch locationManager.currentWarningLevel {
            case .violation:
                Color.red.overlay(
                    LinearGradient(
                        colors: [Color.red.opacity(0.95), Color.red],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            case .danger:
                Color.orange.overlay(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.95), Color.orange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            case .caution:
                Color.yellow.opacity(0.9).overlay(
                    LinearGradient(
                        colors: [Color.yellow.opacity(0.85), Color.yellow.opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            case .safe:
                Color.green.opacity(0.9).overlay(
                    LinearGradient(
                        colors: [Color.green.opacity(0.85), Color.green.opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MapTabView()
        .environmentObject(LocationManager())
}
