import Foundation

extension RepositoryDetailDTO {
    var stargazerBand: String {
        switch stargazersCount {
        case 0: return Strings.zero
        case 1...10: return Strings.upTo10
        case 11...100: return Strings.upTo100
        case 101...1000: return Strings.upTo1K
        default: return Strings.over1K
        }
    }

    private enum Strings {
        static let zero = String(localized: "stargazerBand.zero")
        static let upTo10 = String(localized: "stargazerBand.1to10")
        static let upTo100 = String(localized: "stargazerBand.11to100")
        static let upTo1K = String(localized: "stargazerBand.101to1K")
        static let over1K = String(localized: "stargazerBand.over1K")
    }
}
