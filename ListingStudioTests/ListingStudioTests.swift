import XCTest
import UIKit
@testable import ListingStudio

@MainActor final class ListingStudioTests: XCTestCase {
    func testValidationAndDescription() throws {
        var item = Listing()
        XCTAssertThrowsError(try item.validate())
        item.title = "Camera lens"; item.price = "125.50"; item.details = "Scratch on barrel. Includes case."
        try item.validate()
        XCTAssertTrue(item.assembledText.contains(item.details))
        item.price = "-10"; XCTAssertThrowsError(try item.validate())
        item.price = "1.999"; XCTAssertThrowsError(try item.validate())
        item.price = ""; XCTAssertFalse(item.assembledText.contains("Asking"))
    }
    func testSaveReloadAndDeletePhoto() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ListingStore(root: root)
        var item = Listing(); item.title = "Headphones"
        let name = UUID().uuidString + ".jpg"; item.photos = [name]
        let image = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { ctx in
            UIColor.blue.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        try store.save(item, newPhotos: [name: try XCTUnwrap(image.jpegData(compressionQuality: 0.8))])
        let reloaded = ListingStore(root: root)
        XCTAssertEqual(reloaded.listings.first?.title, "Headphones")
        XCTAssertNotNil(reloaded.image(name))
        try reloaded.delete(item)
        XCTAssertTrue(ListingStore(root: root).listings.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: try XCTUnwrap(reloaded.photoURL(name)).path))
    }
    func testUnreadableIndexCannotBeOverwritten() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let index = root.appendingPathComponent("listings.json")
        let damaged = Data("not valid json".utf8); try damaged.write(to: index)
        let store = ListingStore(root: root)
        XCTAssertNotNil(store.loadError)
        var item = Listing(); item.title = "Do not overwrite"
        XCTAssertThrowsError(try store.save(item))
        XCTAssertEqual(try Data(contentsOf: index), damaged)
    }
}
