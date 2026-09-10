import SwiftUI
import PhotosUI
import UIKit
import Security

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
    @State private var aiConsent = false
    @State private var generating = false
    @State private var aiResult: AISuggestion?
    @State private var aiCode = ""
    @State private var aiTask: Task<Void, Never>?
    init(item: Listing) { original = item; _draft = State(initialValue: item) }
    private var changed: Bool { draft != original }
    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                photosSection
                aiSection
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
            .disabled(importing || generating)
            .navigationTitle(original.title.isEmpty ? "New listing" : "Edit listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if changed { discard = true } else { dismiss() } }.disabled(importing || generating) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do { try store.save(draft, newPhotos: newPhotos); dismiss() }
                        catch { message = error.localizedDescription }
                    }.bold().disabled(importing || generating)
                }
            }
            .interactiveDismissDisabled(changed || importing || generating)
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
            .confirmationDialog("Send photos to Google Gemini?", isPresented: $aiConsent, titleVisibility: .visible) {
                Button("Send photos & generate") { aiTask = Task { await generateDescription() } }
            } message: {
                Text("Your first three photos and item details will be sent through Listing Studio’s service to Google. Google may use free-tier inputs and outputs to improve its products. Avoid private or sensitive photos. You can review the result before applying it.")
            }
            .sheet(item: $aiResult) { suggestion in
                NavigationStack {
                    Form {
                        Section("Suggested title") { Text(suggestion.title) }
                        Section("Suggested description") { Text(suggestion.description).textSelection(.enabled) }
                        Section("Check before using") {
                            Text(suggestion.reviewNotes.isEmpty ? "Check every detail. AI can make mistakes." : suggestion.reviewNotes)
                            Text("Applying replaces your title and description. You can then edit them before saving.")
                        }
                    }
                    .navigationTitle("Review AI draft")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Discard") { aiResult = nil } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Use draft") { draft.title = suggestion.title; draft.text = suggestion.description; aiResult = nil }
                        }
                    }
                }
            }
            .onDisappear { aiTask?.cancel() }
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
    private var aiSection: some View {
        Section {
            if AIService.endpoint == nil {
                Text("AI setup is not finished for this build. You can still assemble a description from your item details.").foregroundStyle(.secondary)
            } else {
                SecureField("AI access code", text: $aiCode).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Save access code") {
                    do { try AIService.saveCode(aiCode); aiCode = ""; message = "AI access code saved on this phone." }
                    catch { message = error.localizedDescription }
                }.disabled(aiCode.isEmpty)
                Button("Forget saved access code", role: .destructive) { AIService.forgetCode(); message = "AI access code removed." }
                Button("Generate description from photos", systemImage: "sparkles") { aiConsent = true }
                    .disabled(draft.photos.isEmpty || generating)
                if generating { ProgressView("Writing your draft…") }
            }
        } header: { Text("AI photo description") } footer: {
            Text("Uses the first three photos. Your existing listing stays unchanged until you choose Use draft. Enter the family access code here, never your Google API key.")
        }
    }
    @MainActor private func generateDescription() async {
        generating = true
        defer { generating = false }
        do {
            var photos: [String] = []
            for name in draft.photos.prefix(3) {
                guard let image = photo(name) else { throw ListingError.message("A photo is missing. Remove it or add it again.") }
                let scale = min(1, 1000 / max(image.size.width, image.size.height))
                let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
                let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
                guard let bytes = resized.jpegData(compressionQuality: 0.75), bytes.count <= 1_050_000 else {
                    throw ListingError.message("Try a smaller photo.")
                }
                photos.append(bytes.base64EncodedString())
            }
            let result = try await AIService.generate(photos: photos, details: draft.assembledText)
            try Task.checkCancellation()
            aiResult = result
        } catch is CancellationError { }
        catch { if !Task.isCancelled { message = error.localizedDescription } }
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
            Button("Copy listing & open Marketplace", systemImage: "arrow.up.right.square") {
                let text = [draft.title, draft.text.isEmpty ? draft.assembledText : draft.text]
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .joined(separator: "\n\n")
                guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    message = "Add an item title before preparing your Facebook listing."
                    return
                }
                do { try store.save(draft, newPhotos: newPhotos) }
                catch { message = error.localizedDescription; return }
                UIPasteboard.general.setItems([["public.utf8-plain-text": text]], options: [.localOnly: true])
                guard let url = URL(string: "https://www.facebook.com/marketplace/create/item") else { return }
                openURL(url) { accepted in if !accepted { message = "Facebook could not be opened. Open the Facebook app and go to Marketplace." } }
            }
        } header: { Text("Prepare to publish") } footer: {
            Text("Copy listing & open Marketplace saves your draft and copies its text. In Facebook, paste the text, enter the title and price, select your photos, and publish. Photos are not uploaded automatically. Mark the listing Listed after you publish.")
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

// Kept in this target source file so the existing Xcode project includes it.
struct AISuggestion: Decodable, Identifiable {
    var id: String { title + description }
    let title: String
    let description: String
    let reviewNotes: String
}
enum AIService {
    static var endpoint: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "AIServiceURL") as? String,
              let url = URL(string: raw), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else { return nil }
        return url
    }
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "ListingStudio.AI", kSecAttrAccount as String: "family-access"]
    }
    static func forgetCode() { SecItemDelete(query as CFDictionary) }
    static func saveCode(_ code: String) throws {
        let clean = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 32, clean.count <= 128, clean.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else {
            throw ListingError.message("Enter the family access code provided during setup.")
        }
        let attributes: [String: Any] = [kSecValueData as String: Data(clean.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw ListingError.message("The access code could not be saved securely.") }
    }
    static func generate(photos: [String], details: String) async throws -> AISuggestion {
        guard let url = endpoint else { throw ListingError.message("AI service setup is incomplete.") }
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(lookup as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data, let code = String(data: data, encoding: .utf8) else {
            throw ListingError.message("Save your family AI access code first.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 55
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + code, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["photos": photos, "details": details, "consent": true])
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        let session = URLSession(configuration: configuration, delegate: NoAIRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ListingError.message("AI service did not respond.") }
        guard http.statusCode == 200 else {
            let messages = [401: "Check your saved AI access code.", 429: "Google’s free allowance or request limit has been reached. Try later or write the description manually.", 422: "AI could not describe these photos. Try different photos or enter details manually."]
            throw ListingError.message(messages[http.statusCode] ?? "AI is unavailable right now. Your listing is unchanged.")
        }
        let result = try JSONDecoder().decode(AISuggestion.self, from: bytes)
        guard !result.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !result.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              result.title.count <= 150, result.description.count <= 4000, result.reviewNotes.count <= 1000 else {
            throw ListingError.message("AI returned an invalid draft. Your listing is unchanged.")
        }
        return result
    }
}
final class NoAIRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
