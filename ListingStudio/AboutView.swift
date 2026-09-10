import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    private func configuredURL(_ key: String) -> URL? {
        guard let text = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              let url = URL(string: text), url.scheme == "https", url.host != nil else { return nil }
        return url
    }
    var body: some View {
        NavigationStack {
            List {
                Section("Listing Studio") {
                    Text("Prepare item descriptions and photos, organize your drafts, and track sales.")
                    Text("Independent listing organizer. Not affiliated with or endorsed by Meta or Facebook. Facebook publishing is manual.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Your data") {
                    Text("Listings and selected photos are stored in this app on your iPhone. There is no app account, analytics, advertising or tracking. If you choose AI generation and confirm sharing, up to three photos and your item details are uploaded through our service to Google Gemini.")
                    Text("Google may use free-tier AI inputs and outputs to improve its products. AI is optional; review generated drafts before using them. Your family access code is saved in this phone’s Keychain. Use Forget saved access code to remove it.")
                    Text("Your device backup may include this app’s data, depending on your Apple backup settings. This app does not synchronize listings between devices or with the web app.")
                    Text("When you copy or share a listing, you choose which app receives that content. Opening Facebook or a support website uses that service’s own privacy practices.")
                    Text("To remove a listing and its saved photos, open it and choose Delete listing. Removing this app also removes its local data; backups are managed separately in your Apple settings.")
                }
                Section("Privacy and support") {
                    if let url = configuredURL("PrivacyPolicyURL") { Link("Privacy policy", destination: url) }
                    if let url = configuredURL("SupportURL") { Link("Get support", destination: url) }
                    Text("Version 1.0").foregroundStyle(.secondary)
                }
            }.navigationTitle("About")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
