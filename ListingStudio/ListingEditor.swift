import SwiftUI
import PhotosUI
import UIKit

struct SharePayload: Identifiable { let id = UUID(); let items: [Any] }
struct ListingEditor: View {
    @EnvironmentObject private var store: ListingStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var draft: Listing
    private let original: Listing
    @State private var newPhotos: [String: Data] = [:]
    @State private var selected: [PhotosPickerItem] = []
    @State private var importing = false
    @State private var message: String?
    @State private var discard = false
    @State private var replaceDescription = false
    @State private var deleting = false
    @State private var share: SharePayload?
    init(item: Listing) { original = item; _draft = State(initialValue: item) }
    private var changed: Bool { draft != original }
    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                photosSection
                descriptionSection
                handoffSection
                Section {
                    Picker("Status", selection: $draft.status) { ForEach(Listing.statuses, id: \.self) { Text($0) } }
                    Text("Set Listed after you publish on Facebook. Update Sold yourself after a sale.").font(.footnote).foregroundStyle(.secondary)
                }
                if store.listings.contains(where: { $0.id == draft.id }) {
                    Section { Button("Delete listing", role: .destructive) { deleting = true } }
                }
            }
            .disabled(importing)
            .navigationTitle(original.title.isEmpty ? "New listing" : "Edit listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if changed { discard = true } else { dismiss() } }.disabled(importing) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do { try store.save(draft, newPhotos: newPhotos); dismiss() }
                        catch { message = error.localizedDescription }
                    }.bold().disabled(importing)
                }
            }
            .interactiveDismissDisabled(changed || importing)
            .overlay { if importing { ProgressView("Importing photos…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) } }
            .alert("Listing Studio", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
            .confirmationDialog("Discard unsaved changes?", isPresented: $discard, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
            }
            .confirmationDialog("Replace the current description with your item details?", isPresented: $replaceDescription, titleVisibility: .visible) {
                Button("Replace description") { draft.text = draft.assembledText }
            }
            .confirmationDialog("Delete this listing and its saved photos?", isPresented: $deleting, titleVisibility: .visible) {
                Button("Delete listing", role: .destructive) {
                    do { try store.delete(draft); dismiss() } catch { message = error.localizedDescription }
                }
            }
            .sheet(item: $share) { payload in ActivitySheet(items: payload.items) }
            .onChange(of: selected) { _, items in
                guard !items.isEmpty else { return }
                importing = true
                Task { await importPhotos(items) }
            }
        }
    }
    private var detailsSection: some View {
        Section("Item details") {
            TextField("Item title", text: $draft.title)
            TextField("Asking price in USD", text: $draft.price).keyboardType(.decimalPad)
            Picker("Condition", selection: $draft.condition) { ForEach(Listing.conditions, id: \.self) { Text($0) } }
            TextField("Pickup town or neighborhood", text: $draft.location)
            TextField("Model, accessories, wear and any issues", text: $draft.details, axis: .vertical).lineLimit(3...8)
            Toggle("Firm price", isOn: $draft.firmPrice)
        }
    }
    private var photosSection: some View {
        Section {
            ForEach(Array(draft.photos.enumerated()), id: \.element) { offset, name in
                HStack {
                    if let image = photo(name) {
                        Image(uiImage: image).resizable().scaledToFit().frame(width: 90, height: 84).accessibilityLabel("Photo \(offset + 1)")
                    } else { Label("Missing photo", systemImage: "photo.badge.exclamationmark").font(.caption) }
                    Text(offset == 0 ? "Cover photo" : "Photo \(offset + 1)").font(.subheadline)
                    Spacer()
                    Menu {
                        if offset > 0 { Button("Move earlier", systemImage: "arrow.up") { draft.photos.swapAt(offset, offset - 1) } }
                        if offset < draft.photos.count - 1 { Button("Move later", systemImage: "arrow.down") { draft.photos.swapAt(offset, offset + 1) } }
                        Button(role: .destructive) { draft.photos.removeAll { $0 == name }; newPhotos.removeValue(forKey: name) } label: { Label("Remove photo", systemImage: "trash") }
                    } label: { Image(systemName: "ellipsis.circle").padding(8) }.accessibilityLabel("Options for photo \(offset + 1)")
                }
            }
            if draft.photos.count < 10 {
                PhotosPicker(selection: $selected, maxSelectionCount: 10 - draft.photos.count, matching: .images) { Label("Add photos", systemImage: "photo.badge.plus") }
            }
        } header: { Text("Photos · \(draft.photos.count)/10") } footer: {
            Text("The first photo is your cover. Use the photo menu to reorder. Selected photos are copied into the app when you save; your originals are unchanged.")
        }
    }
    private var descriptionSection: some View {
        Section {
            Button("Assemble from item details", systemImage: "text.badge.plus") {
                do {
                    try draft.validate()
                    if draft.text.isEmpty { draft.text = draft.assembledText } else { replaceDescription = true }
                } catch { message = error.localizedDescription }
            }
            TextEditor(text: $draft.text).frame(minHeight: 190).accessibilityLabel("Listing description")
        } header: { Text("Description") } footer: { Text("Formats the facts you entered. Review and edit the wording before sharing.") }
    }
    private var handoffSection: some View {
        Section {
            Button("Copy title", systemImage: "doc.on.doc") { copy(draft.title) }
            Button("Copy description", systemImage: "doc.on.doc") { copy(draft.text) }
            Button("Share text and photos…", systemImage: "square.and.arrow.up") {
                var items: [Any] = []
                let text = [draft.title, draft.text].filter { !$0.isEmpty }.joined(separator: "\n\n")
                if !text.isEmpty { items.append(text) }
                for name in draft.photos { if let image = photo(name) { items.append(image) } }
                if items.isEmpty { message = "Add text or photos first." } else { share = SharePayload(items: items) }
            }
            Button("Open Facebook Marketplace", systemImage: "arrow.up.right.square") {
                guard let url = URL(string: "https://www.facebook.com/marketplace/create/item") else { return }
                openURL(url) { accepted in if !accepted { message = "Facebook could not be opened. Open the Facebook app and go to Marketplace." } }
            }
        } header: { Text("Prepare to publish") } footer: {
            Text("Paste your text and select photos in Facebook, then review and publish there. The share sheet does not guarantee Marketplace posting. This app does not publish automatically or update Facebook listings.")
        }
    }
    private func photo(_ name: String) -> UIImage? {
        if let bytes = newPhotos[name] { return UIImage(data: bytes) }
        return store.image(name)
    }
    private func copy(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { message = "Add text first."; return }
        UIPasteboard.general.setItems([["public.utf8-plain-text": text]], options: [.localOnly: true])
        message = "Copied. Paste it into your Facebook listing."
    }
    @MainActor private func importPhotos(_ items: [PhotosPickerItem]) async {
        defer { selected = []; importing = false }
        var failures = 0
        for item in items.prefix(max(0, 10 - draft.photos.count)) {
            do {
                guard let bytes = try await item.loadTransferable(type: Data.self) else { throw ListingError.message("Photo unavailable.") }
                let prepared = try await Task.detached(priority: .userInitiated) { try ListingStore.preparedPhoto(bytes) }.value
                let name = UUID().uuidString + ".jpg"
                newPhotos[name] = prepared
                draft.photos.append(name)
            } catch { failures += 1 }
        }
        if failures > 0 { message = "\(failures) photo(s) could not be imported. Try a smaller image under 35 MB, or download the original from iCloud Photos first. Your other photos are still here." }
    }
}
struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
