import Foundation

/// A CEFR level, from A1 (beginner) to C2 (mastery).
public enum CEFRLevel: String, Codable, CaseIterable, Comparable, Sendable {
    case a1 = "A1", a2 = "A2", b1 = "B1", b2 = "B2", c1 = "C1", c2 = "C2"

    /// The broad band: "A", "B" or "C".
    public var band: String { String(rawValue.prefix(1)) }

    public var rank: Int { Self.allCases.firstIndex(of: self)! }

    public static func < (lhs: CEFRLevel, rhs: CEFRLevel) -> Bool { lhs.rank < rhs.rank }

    /// Rough IELTS band this vocabulary level supports.
    public var ieltsHint: String {
        switch self {
        case .a1, .a2: "Band 3–4"
        case .b1: "Band 4.5–5.5"
        case .b2: "Band 5.5–6.5"
        case .c1: "Band 7–8"
        case .c2: "Band 8.5–9"
        }
    }
}
