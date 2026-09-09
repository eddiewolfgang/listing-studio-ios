import Foundation
import Combine
import UIKit
import ImageIO

@MainActor
final class ListingStore: ObservableObject {
    @Published private(set) var listings: [Listing] = []
    @Published private(set) var loadError: String?
    private let root: URL
    private var index: URL { root.appendingPathComponent("listings.json") }
    private var images: URL { root.appendingPathComponent("Photos", isDirectory: true) }
    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ListingStudio", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: index.path) {
                let decoded = try JSONDecoder().decode([Listing].self, from: Data(contentsOf: index))
                guard Set(decoded.map(\.id)).count == decoded.count else { throw ListingError.message("Duplicate listing IDs.") }
                for listing in decoded { try listing.validate() }
                listings = decoded.sorted { $0.updated > $1.updated }
            }
        } catch {
            loadError = "Your saved listings could not be opened. To protect them, saving is disabled. Reopen the app after unlocking your phone. If this continues, contact support before reinstalling."
        }
    }
    func photoURL(_ name: String) -> URL? {
        guard Listing.safePhotoName(name) else { return nil }
        return images.appendingPathComponent(name)
    }
    func image(_ name: String) -> UIImage? {
        guard let url = photoURL(name) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
    func save(_ item: Listing, newPhotos: [String: Data] = [:]) throws {
        guard loadError == nil else { throw ListingError.message("Saving is disabled because existing listings could not be opened.") }
        var item = item
        item.title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        item.updated = Date()
        try item.validate()
        var written: [URL] = []
        do {
            for name in item.photos {
                guard let url = photoURL(name) else { throw ListingError.message("Invalid photo name.") }
                if !FileManager.default.fileExists(atPath: url.path) {
                    guard let bytes = newPhotos[name] else { throw ListingError.message("A photo is missing. Remove it or select it again.") }
                    try bytes.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                    written.append(url)
                }
            }
            var next = listings.filter { $0.id != item.id }
            next.insert(item, at: 0)
            try persist(next)
            let oldPhotos = Set(listings.flatMap(\.photos))
            listings = next
            removeUnused(oldPhotos)
        } catch {
            for url in written { try? FileManager.default.removeItem(at: url) }
            throw error
        }
    }
    func delete(_ item: Listing) throws {
        guard loadError == nil else { throw ListingError.message("Changes are disabled until saved listings can be opened.") }
        let next = listings.filter { $0.id != item.id }
        try persist(next)
        listings = next
        removeUnused(Set(item.photos))
    }
    private func persist(_ items: [Listing]) throws {
        let data = try JSONEncoder().encode(items)
        try data.write(to: index, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    private func removeUnused(_ candidates: Set<String>) {
        let used = Set(listings.flatMap(\.photos))
        for name in candidates.subtracting(used) {
            if let url = photoURL(name) { try? FileManager.default.removeItem(at: url) }
        }
    }
    // Downsampling bounds decoding memory; re-encoding does not retain original EXIF location metadata.
    nonisolated static func preparedPhoto(_ bytes: Data) throws -> Data {
        guard bytes.count <= 35 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(bytes as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1800
              ] as CFDictionary),
              let output = UIImage(cgImage: cg).jpegData(compressionQuality: 0.85) else {
            throw ListingError.message("That photo could not be imported. Try a smaller image under 35 MB.")
        }
        return output
    }
}
