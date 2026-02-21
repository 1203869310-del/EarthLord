//
//  MockExplorationData.swift
//  EarthLord
//
//  探索模块的测试假数据
//

import Foundation
import CoreLocation
import MapKit

// MARK: - POI 兴趣点数据模型

/// 兴趣点类型
enum POIType: String, CaseIterable {
    case hospital = "医院"
    case supermarket = "超市"
    case factory = "工厂"
    case pharmacy = "药店"
    case gasStation = "加油站"

    var iconName: String {
        switch self {
        case .hospital: return "cross.case.fill"
        case .supermarket: return "cart.fill"
        case .factory: return "building.2.fill"
        case .pharmacy: return "pills.fill"
        case .gasStation: return "fuelpump.fill"
        }
    }

    var color: String {
        switch self {
        case .hospital: return "red"
        case .supermarket: return "green"
        case .factory: return "gray"
        case .pharmacy: return "purple"
        case .gasStation: return "orange"
        }
    }

    /// POI 类型对应的奖励等级（影响物品数量和稀有度）
    var rewardTier: RewardTier {
        switch self {
        case .hospital: return .gold      // 医院物资丰富
        case .pharmacy: return .silver    // 药店物资适中
        case .supermarket: return .silver // 超市物资适中
        case .gasStation: return .bronze  // 加油站物资较少
        case .factory: return .gold       // 工厂可能有珍稀材料
        }
    }
}

/// POI 状态
enum POIStatus {
    case discovered      // 已发现
    case undiscovered    // 未发现
    case looted          // 已搜刮
}

/// 物资状态
enum ResourceStatus {
    case available       // 有物资
    case depleted        // 已清空
    case unknown         // 未知（未发现时）
}

/// 危险等级
enum DangerLevel: Int, CaseIterable {
    case safe = 0       // 安全
    case low = 1        // 低危
    case medium = 2     // 中危
    case high = 3       // 高危
    case extreme = 4    // 极危

    var displayName: String {
        switch self {
        case .safe: return "安全"
        case .low: return "低危"
        case .medium: return "中危"
        case .high: return "高危"
        case .extreme: return "极危"
        }
    }

    var color: String {
        switch self {
        case .safe: return "green"
        case .low: return "yellow"
        case .medium: return "orange"
        case .high: return "red"
        case .extreme: return "purple"
        }
    }

    /// 稀有度权重分布
    var rarityWeights: RarityWeights {
        switch self {
        case .safe, .low:
            return RarityWeights(common: 0.70, uncommon: 0.25, rare: 0.05, epic: 0, legendary: 0)
        case .medium:
            return RarityWeights(common: 0.50, uncommon: 0.30, rare: 0.15, epic: 0.05, legendary: 0)
        case .high:
            return RarityWeights(common: 0, uncommon: 0.40, rare: 0.35, epic: 0.20, legendary: 0.05)
        case .extreme:
            return RarityWeights(common: 0, uncommon: 0, rare: 0.30, epic: 0.40, legendary: 0.30)
        }
    }
}

/// 稀有度权重结构
struct RarityWeights {
    let common: Double
    let uncommon: Double
    let rare: Double
    let epic: Double
    let legendary: Double

    /// 转换为字典（用于 AI 请求）
    var toDictionary: [String: Double] {
        [
            "common": common,
            "uncommon": uncommon,
            "rare": rare,
            "epic": epic,
            "legendary": legendary
        ]
    }
}

/// 兴趣点模型
struct POI: Identifiable, Equatable {
    let id: UUID
    let name: String
    let type: POIType
    let coordinate: CLLocationCoordinate2D
    var status: POIStatus
    var resourceStatus: ResourceStatus
    let dangerLevel: DangerLevel
    let source: String  // "地图数据" 或 "手动添加"

    /// 关联的 MapKit 地图项（可选，仅从 MapKit 搜索得到的 POI 有此属性）
    var mapItem: MKMapItem?

    /// 上次搜刮时间（用于冷却计算）
    var lastScavengedAt: Date?

    /// 搜刮冷却时间（秒），默认 1 小时
    static let scavengeCooldown: TimeInterval = 3600

    /// 是否可以搜刮（未在冷却中）
    var canScavenge: Bool {
        guard resourceStatus != .depleted else { return false }
        guard let lastTime = lastScavengedAt else { return true }
        return Date().timeIntervalSince(lastTime) >= POI.scavengeCooldown
    }

    /// 剩余冷却时间（秒）
    var remainingCooldown: TimeInterval {
        guard let lastTime = lastScavengedAt else { return 0 }
        let elapsed = Date().timeIntervalSince(lastTime)
        return max(0, POI.scavengeCooldown - elapsed)
    }

    /// 格式化的剩余冷却时间
    var formattedCooldown: String {
        let remaining = remainingCooldown
        if remaining <= 0 { return "" }
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Initializers

    init(
        id: UUID = UUID(),
        name: String,
        type: POIType,
        coordinate: CLLocationCoordinate2D,
        status: POIStatus,
        resourceStatus: ResourceStatus,
        dangerLevel: DangerLevel,
        source: String,
        mapItem: MKMapItem? = nil,
        lastScavengedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.coordinate = coordinate
        self.status = status
        self.resourceStatus = resourceStatus
        self.dangerLevel = dangerLevel
        self.source = source
        self.mapItem = mapItem
        self.lastScavengedAt = lastScavengedAt
    }

    // MARK: - Equatable

    static func == (lhs: POI, rhs: POI) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 背包物品数据模型

/// 物品分类
enum ItemCategory: String, CaseIterable {
    case food = "食物"
    case water = "水"
    case material = "材料"
    case tool = "工具"
    case medical = "医疗"

    var iconName: String {
        switch self {
        case .food: return "fork.knife"
        case .water: return "drop.fill"
        case .material: return "hammer.fill"
        case .tool: return "wrench.fill"
        case .medical: return "cross.fill"
        }
    }

    var color: String {
        switch self {
        case .food: return "orange"
        case .water: return "blue"
        case .material: return "brown"
        case .tool: return "gray"
        case .medical: return "red"
        }
    }
}

/// 稀有度
enum Rarity: String, CaseIterable, Codable {
    case common = "普通"
    case uncommon = "优秀"
    case rare = "稀有"
    case epic = "史诗"
    case legendary = "传奇"

    var color: String {
        switch self {
        case .common: return "gray"
        case .uncommon: return "green"
        case .rare: return "blue"
        case .epic: return "purple"
        case .legendary: return "orange"
        }
    }

    /// 从 API 返回的字符串初始化
    static func from(apiString: String) -> Rarity {
        switch apiString.lowercased() {
        case "common": return .common
        case "uncommon": return .uncommon
        case "rare": return .rare
        case "epic": return .epic
        case "legendary": return .legendary
        default: return .common
        }
    }
}

/// 物品品质（部分物品没有品质）
enum Quality: String {
    case damaged = "破损"
    case normal = "普通"
    case good = "良好"
    case perfect = "完美"
}

/// 背包物品模型
struct BackpackItem: Identifiable {
    let id = UUID()
    let name: String
    let category: ItemCategory
    var quantity: Int        // 可变数量
    let weight: Double       // 单个物品重量（kg）
    let volume: Double       // 单个物品体积（L）
    let rarity: Rarity
    let quality: Quality?    // 部分物品没有品质
    let story: String?       // 背景故事（AI 生成时有值）

    /// 标准初始化器
    init(name: String, category: ItemCategory, quantity: Int, weight: Double, volume: Double, rarity: Rarity, quality: Quality?) {
        self.name = name
        self.category = category
        self.quantity = quantity
        self.weight = weight
        self.volume = volume
        self.rarity = rarity
        self.quality = quality
        self.story = nil
    }

    /// 带故事的初始化器
    init(name: String, category: ItemCategory, quantity: Int, weight: Double, volume: Double, rarity: Rarity, quality: Quality?, story: String?) {
        self.name = name
        self.category = category
        self.quantity = quantity
        self.weight = weight
        self.volume = volume
        self.rarity = rarity
        self.quality = quality
        self.story = story
    }

    /// 是否有背景故事
    var hasStory: Bool {
        story != nil && !(story?.isEmpty ?? true)
    }
}

// MARK: - 奖励等级

/// 奖励等级枚举
enum RewardTier: String {
    case none = "无奖励"
    case bronze = "铜级"
    case silver = "银级"
    case gold = "金级"
    case diamond = "钻石级"

    /// 根据行走距离判断奖励等级
    static func tier(for distance: Double) -> RewardTier {
        switch distance {
        case 0..<200:
            return .none
        case 200..<500:
            return .bronze
        case 500..<1000:
            return .silver
        case 1000..<2000:
            return .gold
        default:
            return .diamond
        }
    }

    /// 奖励物品数量
    var itemCount: Int {
        switch self {
        case .none: return 0
        case .bronze: return 1
        case .silver: return 2
        case .gold: return 3
        case .diamond: return 5
        }
    }

    /// 稀有度抽取概率分布
    /// - Returns: (普通概率, 稀有概率, 史诗概率)
    var rarityWeights: (common: Double, rare: Double, epic: Double) {
        switch self {
        case .none:
            return (0, 0, 0)
        case .bronze:
            return (90, 10, 0)      // 铜级：90%普通，10%稀有
        case .silver:
            return (70, 25, 5)      // 银级：70%普通，25%稀有，5%史诗
        case .gold:
            return (50, 35, 15)     // 金级：50%普通，35%稀有，15%史诗
        case .diamond:
            return (30, 40, 30)     // 钻石级：30%普通，40%稀有，30%史诗
        }
    }

    /// 等级颜色
    var color: String {
        switch self {
        case .none: return "gray"
        case .bronze: return "brown"
        case .silver: return "gray"
        case .gold: return "yellow"
        case .diamond: return "cyan"
        }
    }

    /// 等级图标
    var iconName: String {
        switch self {
        case .none: return "xmark.circle"
        case .bronze: return "medal"
        case .silver: return "medal.fill"
        case .gold: return "crown"
        case .diamond: return "crown.fill"
        }
    }
}

// MARK: - 探索结果数据模型

/// 探索结果模型
struct ExplorationResult {
    let distance: ExplorationStat      // 行走距离
    let area: ExplorationStat          // 探索面积
    let duration: Int                  // 探索时长（分钟）
    let rewardTier: RewardTier         // 奖励等级
    let rewards: [RewardItem]          // 获得的物品
}

/// 统计数据模型（本次/累计/排名）
struct ExplorationStat {
    let current: Double     // 本次数值
    let total: Double       // 累计数值
    let rank: Int           // 排名
}

/// 奖励物品模型
struct RewardItem: Identifiable {
    let id = UUID()
    let name: String
    let quantity: Int
    let iconName: String
    let category: ItemCategory
    let rarity: Rarity           // 物品稀有度
    let story: String?           // 背景故事（AI 生成时有值）
    let isAIGenerated: Bool      // 是否 AI 生成

    /// 标准初始化器（本地生成）
    init(name: String, quantity: Int, iconName: String, category: ItemCategory, rarity: Rarity) {
        self.name = name
        self.quantity = quantity
        self.iconName = iconName
        self.category = category
        self.rarity = rarity
        self.story = nil
        self.isAIGenerated = false
    }

    /// AI 生成初始化器
    init(name: String, quantity: Int, iconName: String, category: ItemCategory, rarity: Rarity, story: String?, isAIGenerated: Bool) {
        self.name = name
        self.quantity = quantity
        self.iconName = iconName
        self.category = category
        self.rarity = rarity
        self.story = story
        self.isAIGenerated = isAIGenerated
    }
}

/// 搜刮结果
struct ScavengeResult {
    let poi: POI               // 搜刮的 POI
    let rewards: [RewardItem]  // 获得的奖励
    let timestamp: Date        // 搜刮时间

    /// 格式化时间
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }
}

// MARK: - 假数据集合

struct MockExplorationData {

    // MARK: - 可用物品池（用于随机奖励）

    /// 物品模板（包含名称、分类、稀有度）
    private struct ItemTemplate {
        let name: String
        let category: ItemCategory
        let rarity: Rarity
    }

    /// 所有可用的物品模板（按稀有度分类）
    private static let availableItems: [ItemTemplate] = [
        // 普通物品（common）
        ItemTemplate(name: "矿泉水", category: .water, rarity: .common),
        ItemTemplate(name: "面包", category: .food, rarity: .common),
        ItemTemplate(name: "绷带", category: .medical, rarity: .common),
        ItemTemplate(name: "木材", category: .material, rarity: .common),
        ItemTemplate(name: "石头", category: .material, rarity: .common),
        ItemTemplate(name: "绳子", category: .tool, rarity: .common),

        // 稀有物品（rare）
        ItemTemplate(name: "罐头食品", category: .food, rarity: .rare),
        ItemTemplate(name: "能量棒", category: .food, rarity: .rare),
        ItemTemplate(name: "废金属", category: .material, rarity: .rare),
        ItemTemplate(name: "手电筒", category: .tool, rarity: .rare),

        // 史诗物品（epic）
        ItemTemplate(name: "药品", category: .medical, rarity: .epic),
        ItemTemplate(name: "高级医疗包", category: .medical, rarity: .epic),
        ItemTemplate(name: "钢材", category: .material, rarity: .epic)
    ]

    /// 根据行走距离生成探索结果
    /// - Parameters:
    ///   - distance: 行走距离（米）
    ///   - area: 探索面积（平方米）
    ///   - duration: 探索时长（分钟）
    ///   - totalDistance: 累计距离
    ///   - totalArea: 累计面积
    /// - Returns: 探索结果
    static func generateExplorationResult(
        distance: Double,
        area: Double = 50000,
        duration: Int = 30,
        totalDistance: Double = 15000,
        totalArea: Double = 250000
    ) -> ExplorationResult {
        // 判断奖励等级
        let tier = RewardTier.tier(for: distance)

        // 生成随机奖励物品（基于稀有度概率）
        var rewards: [RewardItem] = []
        let itemCount = tier.itemCount

        // 获取稀有度权重
        let weights = tier.rarityWeights

        // 随机抽取物品
        for _ in 0..<itemCount {
            // 根据概率决定稀有度
            let rarity = randomRarity(commonWeight: weights.common,
                                     rareWeight: weights.rare,
                                     epicWeight: weights.epic)

            // 从对应稀有度的物品池中随机选择
            let itemsOfRarity = availableItems.filter { $0.rarity == rarity }

            if let randomItem = itemsOfRarity.randomElement() {
                let quantity = Int.random(in: 1...5)
                let reward = RewardItem(
                    name: randomItem.name,
                    quantity: quantity,
                    iconName: randomItem.category.iconName,
                    category: randomItem.category,
                    rarity: randomItem.rarity
                )
                rewards.append(reward)
            }
        }

        return ExplorationResult(
            distance: ExplorationStat(
                current: distance,
                total: totalDistance + distance,
                rank: Int.random(in: 30...60)
            ),
            area: ExplorationStat(
                current: area,
                total: totalArea + area,
                rank: Int.random(in: 30...60)
            ),
            duration: duration,
            rewardTier: tier,
            rewards: rewards
        )
    }

    /// 根据权重随机选择稀有度
    /// - Parameters:
    ///   - commonWeight: 普通物品权重
    ///   - rareWeight: 稀有物品权重
    ///   - epicWeight: 史诗物品权重
    /// - Returns: 随机选中的稀有度
    private static func randomRarity(commonWeight: Double,
                                    rareWeight: Double,
                                    epicWeight: Double) -> Rarity {
        let totalWeight = commonWeight + rareWeight + epicWeight
        let randomValue = Double.random(in: 0..<totalWeight)

        if randomValue < commonWeight {
            return .common
        } else if randomValue < commonWeight + rareWeight {
            return .rare
        } else {
            return .epic
        }
    }

    // MARK: - POI 列表（5个不同状态的兴趣点）

    static let pois: [POI] = [
        POI(
            name: "废弃超市",
            type: .supermarket,
            coordinate: CLLocationCoordinate2D(latitude: 22.5401, longitude: 114.0601),
            status: .discovered,
            resourceStatus: .available,
            dangerLevel: .safe,
            source: "地图数据"
        ),
        POI(
            name: "医院废墟",
            type: .hospital,
            coordinate: CLLocationCoordinate2D(latitude: 22.5405, longitude: 114.0595),
            status: .discovered,
            resourceStatus: .depleted,
            dangerLevel: .medium,
            source: "地图数据"
        ),
        POI(
            name: "加油站",
            type: .gasStation,
            coordinate: CLLocationCoordinate2D(latitude: 22.5410, longitude: 114.0605),
            status: .undiscovered,
            resourceStatus: .unknown,
            dangerLevel: .low,
            source: "地图数据"
        ),
        POI(
            name: "药店废墟",
            type: .pharmacy,
            coordinate: CLLocationCoordinate2D(latitude: 22.5398, longitude: 114.0608),
            status: .discovered,
            resourceStatus: .available,
            dangerLevel: .low,
            source: "手动添加"
        ),
        POI(
            name: "工厂废墟",
            type: .factory,
            coordinate: CLLocationCoordinate2D(latitude: 22.5415, longitude: 114.0598),
            status: .undiscovered,
            resourceStatus: .unknown,
            dangerLevel: .high,
            source: "地图数据"
        )
    ]

    // MARK: - 背包物品（8种不同类型）

    static let backpackItems: [BackpackItem] = [
        BackpackItem(
            name: "矿泉水",
            category: .water,
            quantity: 5,
            weight: 0.5,
            volume: 0.5,
            rarity: .common,
            quality: nil
        ),
        BackpackItem(
            name: "罐头食品",
            category: .food,
            quantity: 8,
            weight: 0.3,
            volume: 0.2,
            rarity: .common,
            quality: .normal
        ),
        BackpackItem(
            name: "绷带",
            category: .medical,
            quantity: 12,
            weight: 0.05,
            volume: 0.05,
            rarity: .common,
            quality: nil
        ),
        BackpackItem(
            name: "药品",
            category: .medical,
            quantity: 3,
            weight: 0.1,
            volume: 0.08,
            rarity: .rare,
            quality: .good
        ),
        BackpackItem(
            name: "木材",
            category: .material,
            quantity: 15,
            weight: 2.0,
            volume: 3.0,
            rarity: .common,
            quality: .normal
        ),
        BackpackItem(
            name: "废金属",
            category: .material,
            quantity: 10,
            weight: 1.5,
            volume: 1.0,
            rarity: .uncommon,
            quality: nil
        ),
        BackpackItem(
            name: "手电筒",
            category: .tool,
            quantity: 1,
            weight: 0.4,
            volume: 0.3,
            rarity: .uncommon,
            quality: .perfect
        ),
        BackpackItem(
            name: "绳子",
            category: .tool,
            quantity: 2,
            weight: 0.8,
            volume: 0.5,
            rarity: .common,
            quality: .damaged
        )
    ]

    // MARK: - 探索结果示例

    static let explorationResult = ExplorationResult(
        distance: ExplorationStat(
            current: 2500,    // 本次行走2500米
            total: 15000,     // 累计15000米
            rank: 42          // 排名42
        ),
        area: ExplorationStat(
            current: 50000,   // 本次探索5万平方米
            total: 250000,    // 累计25万平方米
            rank: 38          // 排名38
        ),
        duration: 30,         // 探索时长30分钟
        rewardTier: .diamond, // 钻石级（2500米）
        rewards: [
            RewardItem(
                name: "木材",
                quantity: 5,
                iconName: "hammer.fill",
                category: .material,
                rarity: .common
            ),
            RewardItem(
                name: "矿泉水",
                quantity: 3,
                iconName: "drop.fill",
                category: .water,
                rarity: .common
            ),
            RewardItem(
                name: "罐头食品",
                quantity: 2,
                iconName: "fork.knife",
                category: .food,
                rarity: .rare
            ),
            RewardItem(
                name: "药品",
                quantity: 1,
                iconName: "cross.fill",
                category: .medical,
                rarity: .epic
            ),
            RewardItem(
                name: "手电筒",
                quantity: 2,
                iconName: "wrench.fill",
                category: .tool,
                rarity: .rare
            )
        ]
    )
}
