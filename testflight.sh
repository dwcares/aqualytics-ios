#!/bin/bash
set -e

echo "==> Generating Xcode project..."
xcodegen generate

echo "==> Archiving..."
xcodebuild -project CulliganApp.xcodeproj \
  -scheme CulliganApp \
  -sdk iphoneos \
  -configuration Release \
  -allowProvisioningUpdates \
  archive \
  -archivePath build/CulliganApp.xcarchive \
  -quiet

echo "==> Exporting IPA..."
xcodebuild -exportArchive \
  -archivePath build/CulliganApp.xcarchive \
  -exportPath build/ \
  -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates \
  -quiet

echo "==> Done! Check App Store Connect for your build."
