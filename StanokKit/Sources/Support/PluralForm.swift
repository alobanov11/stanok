import Foundation

enum PluralForm {

    static func of(_ count: Int, _ one: String, _ few: String, _ many: String) -> String {
        let tens = count % 100
        guard tens < 11 || tens > 14 else { return many }

        switch count % 10 {
        case 1: return one
        case 2...4: return few
        default: return many
        }
    }
}
