import SwiftUI

struct InventoryView: View {
    @EnvironmentObject private var store: ListingStore
    @State private var editing: Listing?
    @State private var showInfo = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        metric("Drafts", count: store.listings.filter { $0.status == "Draft" }.count)
                        Spacer()
                        metric("Listed", count: store.listings.filter { $0.status == "Listed" }.count)
                        Spacer()
                        metric("Sold", count: store.listings.filter { $0.status == "Sold" }.count)
                    }.padding(.vertical, 8)
                }
                if let error = store.loadError {
                    Section { Text(error).foregroundStyle(.red).accessibilityLabel("Storage error. \(error)") }
                }
                if store.listings.isEmpty && store.loadError == nil {
                    ContentUnavailableView {
                        Label("Your first sale starts here", systemImage: "tag")
                    } description: {
                        Text("Prepare your item details and photos, then publish the listing yourself on Facebook.")
                    } actions: {
                        Button("Add an item", systemImage: "plus") { editing = Listing() }.buttonStyle(.borderedProminent)
                    }.listRowBackground(Color.clear)
                }
                ForEach(store.listings) { item in
                    Button { editing = item } label: {
                        HStack(spacing: 14) {
                            Group {
                                if let name = item.photos.first, let photo = store.image(name) {
                                    Image(uiImage: photo).resizable().scaledToFill()
                                } else { Image(systemName: "camera").font(.title2).foregroundStyle(.secondary) }
                            }.frame(width: 64, height: 70).background(Color.secondary.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.title).font(.headline).foregroundStyle(.primary).lineLimit(2)
                                Text(item.formattedPrice).foregroundStyle(.secondary)
                                Text(item.status).font(.caption).bold().foregroundStyle(item.status == "Sold" ? Color.green : Color.blue)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 3)
                    }.disabled(store.loadError != nil)
                }
                Section {
                    Text("Saved on this iPhone. No account required. Listings do not sync with the web app or Facebook.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Listing Studio")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("About", systemImage: "info.circle") { showInfo = true } }
                ToolbarItem(placement: .topBarTrailing) { Button("New listing", systemImage: "plus") { editing = Listing() }.disabled(store.loadError != nil) }
            }
            .sheet(item: $editing) { item in ListingEditor(item: item) }
            .sheet(isPresented: $showInfo) { AboutView() }
        }
    }
    private func metric(_ title: String, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) { Text("\(count)").font(.title2.bold()); Text(title).font(.subheadline).foregroundStyle(.secondary) }
    }
}
