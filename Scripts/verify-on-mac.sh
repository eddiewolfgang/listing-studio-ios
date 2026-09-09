#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
xcodebuild -project ListingStudio.xcodeproj -scheme ListingStudio -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
printf '\nBuild finished. In Xcode select an installed iPhone simulator and choose Product > Test, then test on a physical iPhone.\n'
