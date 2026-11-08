import Foundation

/// 間取りの部屋。間取り図の位置（0〜1 に正規化した四角）もここで決める
enum Room: String, CaseIterable, Codable, Identifiable, Sendable {
    case veranda, bedroom, living, kitchen, storage, toilet, washroom, bath, hallway, entrance

    var id: String { rawValue }

    var name: String {
        switch self {
        case .veranda: "窓・ベランダ"
        case .bedroom: "寝室"
        case .living: "リビング"
        case .kitchen: "キッチン"
        case .storage: "収納"
        case .toilet: "トイレ"
        case .washroom: "洗面所"
        case .bath: "浴室"
        case .hallway: "廊下"
        case .entrance: "玄関"
        }
    }

    /// 間取り図の短い名前（狭い部屋に入る長さ）
    var shortName: String {
        switch self {
        case .veranda: "窓・ベランダ"
        case .washroom: "洗面"
        default: name
        }
    }

    /// 間取り図の中の位置（x, y, 幅, 高さ。0〜1）
    var frame: (x: Double, y: Double, w: Double, h: Double) {
        switch self {
        case .veranda: (0, 0, 1, 0.12)
        case .bedroom: (0, 0.12, 0.40, 0.40)
        case .living: (0.40, 0.12, 0.60, 0.50)
        case .storage: (0, 0.52, 0.18, 0.18)
        case .toilet: (0.18, 0.52, 0.22, 0.18)
        case .washroom: (0, 0.70, 0.20, 0.30)
        case .bath: (0.20, 0.70, 0.20, 0.30)
        case .hallway: (0.40, 0.62, 0.22, 0.20)
        case .entrance: (0.40, 0.82, 0.22, 0.18)
        case .kitchen: (0.62, 0.62, 0.38, 0.38)
        }
    }
}

/// 道具。手順の前に「これを用意」と並べる
enum Tool: String, CaseIterable, Codable, Sendable {
    case cloth, microfiber, sponge, melamine, toothbrush, vacuum, duster, gloves
    case baking, citric, sesqui, neutral, alcohol, chlorine, newspaper, squeegee, chopstick, bag

    var name: String {
        switch self {
        case .cloth: "雑巾"
        case .microfiber: "マイクロファイバー"
        case .sponge: "スポンジ"
        case .melamine: "メラミンスポンジ"
        case .toothbrush: "古い歯ブラシ"
        case .vacuum: "掃除機"
        case .duster: "ハンディモップ"
        case .gloves: "ゴム手袋"
        case .baking: "重曹"
        case .citric: "クエン酸"
        case .sesqui: "セスキ"
        case .neutral: "中性洗剤"
        case .alcohol: "アルコール"
        case .chlorine: "塩素系"
        case .newspaper: "新聞紙"
        case .squeegee: "スクイージー"
        case .chopstick: "割り箸"
        case .bag: "ゴミ袋"
        }
    }

    /// 混ぜると危ない道具（塩素系と酸性）
    static func hasDangerousMix(_ tools: [Tool]) -> Bool {
        tools.contains(.chlorine) && tools.contains(.citric)
    }
}

/// 場所の束。basic は無料、ほかは Pro
enum Pack: String, CaseIterable, Codable, Sendable, Identifiable {
    case basic, replace, season, custom

    var id: String { rawValue }
    var isFree: Bool { self == .basic }

    var title: String {
        switch self {
        case .basic: "家じゅうの小掃除"
        case .replace: "替えどき"
        case .season: "季節の手入れ"
        case .custom: "自分の場所"
        }
    }

    var summary: String {
        switch self {
        case .basic: "レンジフードから玄関のたたきまで、やり方つき"
        case .replace: "スポンジ・フィルター・歯ブラシなど、消耗品の替え時"
        case .season: "衣替え・加湿器・扇風機・網戸など、その季節だけの手入れ"
        case .custom: "自分の家だけの場所を足す"
        }
    }
}

/// 掃除する 1 か所（手で用意したデータ）
struct Spot: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let room: Room
    let name: String
    /// かかる時間の目安（分）
    let minutes: Int
    /// 間隔（日）。この日数がたつと曇りきる
    let interval: Int
    let tools: [Tool]
    let steps: [String]
    /// やるのに向いた月（空なら通年）
    let months: Set<Int>
    let pack: Pack
    /// 年末の大掃除で扱われる所（年末の進みに数える）
    let yearEnd: Bool
    /// 一言のこつ
    let tip: String

    init(_ id: String, _ room: Room, _ name: String, min minutes: Int, every interval: Int,
         _ tools: [Tool], _ steps: [String], months: Set<Int> = [], pack: Pack = .basic,
         yearEnd: Bool = false, tip: String = "") {
        self.id = id
        self.room = room
        self.name = name
        self.minutes = minutes
        self.interval = max(1, interval)
        self.tools = tools
        self.steps = steps
        self.months = months
        self.pack = pack
        self.yearEnd = yearEnd
        self.tip = tip
    }

    var isSeasonal: Bool { !months.isEmpty }

    func inSeason(month: Int) -> Bool { months.isEmpty || months.contains(month) }

    /// 間隔の言い方（「2 週間ごと」「3 か月ごと」）
    var intervalText: String { Spot.intervalText(interval) }

    static func intervalText(_ days: Int) -> String {
        switch days {
        case ..<7: "\(days) 日ごと"
        case 7..<28 where days % 7 == 0: "\(days / 7) 週間ごと"
        case 7..<28: "\(days) 日ごと"
        case 28..<360: "\(Int((Double(days) / 30).rounded())) か月ごと"
        default: "1 年ごと"
        }
    }
}
