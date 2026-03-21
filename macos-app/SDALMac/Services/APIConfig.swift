import Foundation

enum APIConfig {
    static let baseURL = "https://sdalsosyal.mywire.org"

    static func url(_ path: String) -> URL {
        URL(string: "\(baseURL)\(path)")!
    }

    static func url(_ path: String, query: [String: String]) -> URL {
        var components = URLComponents(string: "\(baseURL)\(path)")!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return components.url!
    }
}

extension DateFormatter {
    static func relativeString(from dateString: String) -> String {
        let formatters: [ISO8601DateFormatter] = {
            let f1 = ISO8601DateFormatter()
            f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let f2 = ISO8601DateFormatter()
            f2.formatOptions = [.withInternetDateTime]
            return [f1, f2]
        }()

        let simpleFormatter: Foundation.DateFormatter = {
            let f = Foundation.DateFormatter()
            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            return f
        }()

        var date: Date?
        for fmt in formatters {
            if let d = fmt.date(from: dateString) {
                date = d
                break
            }
        }
        if date == nil {
            date = simpleFormatter.date(from: dateString)
        }
        guard let parsedDate = date else { return dateString }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: parsedDate, relativeTo: Date())
    }
}
