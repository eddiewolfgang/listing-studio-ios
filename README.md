# Listing Studio — native iPhone project

Prepared for Eddie, September 9, 2026. “Listing Studio” is a working name; name and trademark availability have not been checked.

## What this is

A native SwiftUI iPhone app project implementing the personal listing workflow. It is source code, not a signed IPA, TestFlight build, or approved App Store app. No Apple account has been connected, no membership has been purchased, and nothing has been submitted to Apple.

Features implemented:
- Create and edit item title, USD price, condition, pickup area, notes and description.
- Assemble descriptions from the supplied facts, with manual editing; this is formatting, not generative AI.
- Import up to 10 photos with the native photo picker; downsample images, reorder them and choose a cover.
- Save listings and selected photos on the current iPhone with protected, atomic file writes.
- Track Draft, Listed and Sold manually; delete listings and their saved photos.
- Copy title or description and use the iOS share sheet for text/photos.
- Open Facebook Marketplace for manual listing creation.
- Native accessibility labels, system text sizing and automatic system appearance.

This version deliberately has no login or backend. Each installation has its own private local inventory. It does NOT connect to Eddie’s private website, migrate its existing listings, synchronize between devices, or automatically publish to Facebook. Device backups may contain app data according to the user’s Apple backup settings. Deleting the app removes its local records. The website remains private and unchanged.

## Open and build

1. Use a Mac with the current App Store-accepted Xcode version. Apple currently requires Xcode 26 or later and the iOS 26 SDK or later for uploads. The app’s deployment target is iOS 17; SDK and minimum OS version are different settings.
2. Unzip this package and open `ListingStudio.xcodeproj`.
3. Select the `ListingStudio` scheme and an installed iPhone simulator. Build and run with Product > Run.
4. Run Product > Test. The included XCTest target covers price/description validation, saved-listing/photo round trips, deletion, and protection against overwriting an unreadable index.
5. For a physical iPhone, select your developer Team under Signing & Capabilities and use a unique bundle identifier for the app and tests.

Alternatively, run `./Scripts/verify-on-mac.sh` for a simulator build. This script has not been executed here because this environment has no Xcode or Apple SDKs.

## Required before archiving

- Choose the final app name and confirm its availability in App Store Connect.
- Register your bundle identifier; replace `com.example.ListingStudio` in the app target and choose your signing team. Update the test target’s identifier too.
- Publish your actual privacy policy and support page at public HTTPS URLs with your support contact details.
- Set `PrivacyPolicyURL` and `SupportURL` in `ListingStudio/Info.plist` to those live pages. About then shows both links.
- Review the included draft privacy text against the shipped binary and any later integrations.
- Run the simulator tests and physical-device checklist in `Submission/Submission-checklist.md`.

The Release build phase rejects the example app bundle identifier and missing HTTPS privacy/support URLs. It checks configuration presence only; you must verify that the URLs work, belong to you, and contain the final required information.

## Submission

Use your Apple Developer membership, App Store Connect record, Xcode signing/archive upload, and TestFlight before App Review. See the submission folder for draft store copy, review notes, and remaining steps. Apple decides whether the app meets its review guidelines; native implementation is not a guarantee of acceptance.

## Validation performed here

- Xcode project object-reference graph and scheme XML checked.
- Info and privacy plists, asset-catalog JSON and opaque 1024 × 1024 icon checked.
- Shell script syntax checked.
- Source and required project paths checked; ZIP integrity verified.

NOT performed here: Swift compilation/type checking, XCTest execution, simulator launch, physical-iPhone testing, UI screenshots, signing, archiving or uploading. Treat this as an uncompiled first implementation until those steps pass. Do not label it release-ready.

## Structure

- `ListingStudio/`: native SwiftUI screens, model, protected local persistence, plist and assets.
- `ListingStudioTests/`: XCTest source.
- `ListingStudio.xcodeproj/`: app/test targets and shared scheme.
- `Scripts/`: Mac build helper and archive configuration checks.
- `Submission/`: editable App Store copy, privacy draft and release checklist.

There are no API keys, third-party SDKs, package dependencies, ads, analytics, in-app purchases or Facebook credentials.
