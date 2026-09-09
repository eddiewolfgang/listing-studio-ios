# App Store release checklist

Status: native source prepared; not compiled or submitted. Checked against Apple documentation on September 9, 2026. Recheck requirements at the actual submission date.

## Apple and owner setup

- Enroll in the Apple Developer Program (currently USD $99 per membership year). The account owner handles identity checks, agreements and payment. No purchase or enrollment has been performed.
- Decide individual versus organization enrollment and the seller identity to appear on the store.
- Confirm the final name; “Listing Studio” is a working name only.
- Create/register a unique bundle identifier and App Store Connect app record.
- Decide release pricing and countries. There are no purchases or payment SDKs in this source.
- Use Xcode 26 or later with an iOS 26 SDK or later under Apple’s current upload requirement.

## Native validation — must run on a Mac and iPhone

- Build Debug in an installed iPhone simulator; fix any compile/API issues discovered.
- Run the included XCTest suite using Product > Test. These tests have not been run here.
- Test on a physical iPhone: create, edit, save, force-quit, reopen, delete.
- Confirm missing storage/corrupt index cannot silently erase prior listings.
- Import local JPEG, PNG and HEIC photos plus a photo stored in iCloud; check orientation, photo order, removal, failed import, cancellation and the 10-photo limit.
- Test VoiceOver, large accessibility text, dark/light appearance and the smallest supported iPhone layout.
- Test copy/paste, share sheet dismissal and supported share destinations. Opening Facebook must remain a manual handoff with no false success message.
- Verify the app functions offline except downloading cloud photos or opening external services.
- Verify deletion of a saved listing removes its unreferenced photo files.
- Check device performance with a realistic number of photo-heavy listings. UI and local IO performance have not been measured here.
- Verify policy/support links work in About and contain the final owner contact details.
- Capture real screenshots from the tested build in the dimensions currently requested by App Store Connect. No screenshots are included because a simulator has not run.

## Privacy and store metadata

- Publish the final privacy policy and support page at public HTTPS URLs. Fill the Info.plist URLs. Do not use the owner-private web app as the public support page.
- Review the privacy manifest and privacy-label responses against the final binary, SDKs and actual support practices. Local-only processing in this source does not send inventory to a developer server, but final disclosures remain the publisher’s responsibility.
- The source does not request broad photo-library access or use tracking, analytics or login. The system picker grants access to selected photos.
- Complete Apple’s current age-rating questionnaire based on the shipped features; do not guess an age rating from this checklist.
- Provide copyright, review contact details, app description, keywords, screenshots and support/policy links.
- Verify encryption/export-compliance answers for the final binary. Current code has no custom cryptography or network client; the plist currently sets ITSAppUsesNonExemptEncryption to false.

## Upload and review

- Set your Team and registered bundle identifier, then archive a Release build in Xcode.
- Validate/upload through Xcode Organizer to your App Store Connect account.
- Distribute a TestFlight beta and complete real-device checks before submitting.
- Select the tested build in App Store Connect, complete metadata and submit for App Review.
- Address Apple’s feedback. Native features do not guarantee approval under minimum-functionality or other guidelines.
- Choose the release timing in App Store Connect. This package makes no live store changes.

## Official references

- Enrollment and annual fee: https://developer.apple.com/programs/enroll/
- Upload requirements: https://developer.apple.com/news/upcoming-requirements/
- Submission overview: https://developer.apple.com/app-store/submitting/
- Review guidelines, including 4.2 and 5.1.1: https://developer.apple.com/app-store/review/guidelines/
- App review preparation: https://developer.apple.com/distribute/app-review/
- Privacy disclosures: https://developer.apple.com/app-store/app-privacy-details/

## Not part of this version

Automatic Facebook publication, Facebook account connection, buyer messaging, web-app synchronization, app-owned user accounts, payments, subscriptions and cloud inventory storage.
