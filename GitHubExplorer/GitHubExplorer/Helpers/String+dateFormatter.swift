import Foundation

extension String {
    
    var dateFormatted: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: self) {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
        return self
    }
}
