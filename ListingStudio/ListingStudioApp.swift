import SwiftUI

@main
struct ListingStudioApp: App {
    @StateObject private var store = ListingStore()
    var body: some Scene {
        WindowGroup { InventoryView().environmentObject(store).tint(Color(red: 0.15, green: 0.37, blue: 0.63)) }
    }
}
