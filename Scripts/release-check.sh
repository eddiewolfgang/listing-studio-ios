#!/bin/sh
set -eu
[ "${CONFIGURATION:-Debug}" = "Release" ] || exit 0
case "${PRODUCT_BUNDLE_IDENTIFIER:-}" in
  ""|com.example.*) echo 'error: Set your registered bundle identifier before archiving.'; exit 1;;
esac
for key in PrivacyPolicyURL SupportURL; do
  value=$(/usr/libexec/PlistBuddy -c "Print :$key" "$SRCROOT/ListingStudio/Info.plist")
  case "$value" in
    https://*) ;;
    *) echo "error: Set a real public HTTPS $key in ListingStudio/Info.plist before archiving."; exit 1;;
  esac
done
