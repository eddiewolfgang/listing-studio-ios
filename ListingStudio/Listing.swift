import Foundation

struct Listing: Identifiable, Codable, Equatable {
    var id = UUID()
    var title = ""
    var price = ""
    var condition = "Good"
    var location = ""
    var details = ""
    var text = ""
    var firmPrice = false
    var status = "Draft"
    var photos: [String] = []
    var updated = Date()

    static let conditions = ["New", "Like new", "Good", "Fair", "For parts"]
    static let statuses = ["Draft", "Listed", "Sold"]
    var formattedPrice: String {
        guard !price.isEmpty, let amount = Decimal(string: price, locale: Locale(identifier: "en_US_POSIX")) else { return "Price not set" }
        return amount.formatted(.currency(code: "USD"))
    }
    var assembledText: String {
        [title.trimmingCharacters(in: .whitespacesAndNewlines),
         "Condition: \(condition).", details.trimmingCharacters(in: .whitespacesAndNewlines),
         price.isEmpty ? "" : "Asking \(formattedPrice). \(firmPrice ? "Firm price." : "Open to offers.")",
         location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "Pickup in \(location)."]
            .filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
    func validate() throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ListingError.message("Add an item title.") }
        guard title.count <= 150, details.count <= 6000, text.count <= 10000, location.count <= 150 else { throw ListingError.message("Please shorten the title, location or description.") }
        guard price.isEmpty || (price.count <= 15 && price.range(of: #"^\d+(\.\d{1,2})?$"#, options: .regularExpression) != nil) else { throw ListingError.message("Enter a price such as 125 or 125.50, without a dollar sign.") }
        guard Self.conditions.contains(condition), Self.statuses.contains(status), photos.count <= 10,
              Set(photos).count == photos.count, photos.allSatisfy({ Self.safePhotoName($0) }) else { throw ListingError.message("This listing contains invalid data.") }
    }
    static func safePhotoName(_ name: String) -> Bool {
        guard name.hasSuffix(".jpg") else { return false }
        return UUID(uuidString: String(name.dropLast(4))) != nil
    }
}
enum ListingError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
