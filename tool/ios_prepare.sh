#!/bin/bash
# Generates and configures ios/ for a build on macOS. Run from the repo root.
set -euo pipefail
target=15.0

flutter config --enable-swift-package-manager
flutter create --platforms=ios --org com.gymmane --project-name gymmane .
rm -f test/widget_test.dart
flutter pub get

sed -i '' -E "s/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;/IPHONEOS_DEPLOYMENT_TARGET = ${target};/g" ios/Runner.xcodeproj/project.pbxproj
if [ -f ios/Podfile ]; then
  sed -i '' -E "s/^#? *platform :ios.*/platform :ios, '${target}'/" ios/Podfile
  perl -pi -e "s/^(\s*)flutter_additional_ios_build_settings\(target\)\s*$/\$1flutter_additional_ios_build_settings(target)\n\$1target.build_configurations.each { |c| c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '${target}' }\n/" ios/Podfile
fi

# Flutter's framework package needs iOS 13; raise plugins that still declare less.
cache="${PUB_CACHE:-$HOME/.pub-cache}"
find "$cache/hosted" -name Package.swift \( -path '*/ios/*' -o -path '*/darwin/*' \) -print0 |
  xargs -0 perl -pi -e 's/\.iOS\(\s*"(?:[0-9]|1[0-2])(?:\.[0-9]+)*"\s*\)/.iOS("13.0")/; s/\.iOS\(\s*\.v(?:[0-9]|1[0-2])(?:_[0-9]+)?\s*\)/.iOS("13.0")/'

plist=ios/Runner/Info.plist
pb() { /usr/libexec/PlistBuddy -c "$1" "$plist"; }
set_key() { pb "Delete :$1" 2>/dev/null || true; pb "Add :$1 string $2"; }
set_key NSPhotoLibraryUsageDescription "GymMane uses your photos for progress pictures."
set_key NSPhotoLibraryAddUsageDescription "GymMane saves images you create to your photos."
set_key NSCameraUsageDescription "GymMane uses the camera for progress pictures and barcodes."
set_key NSMicrophoneUsageDescription "GymMane needs the microphone when you record video."
set_key CFBundleDisplayName "GymMane"

# The layouts are built for a portrait phone.
for key in UISupportedInterfaceOrientations 'UISupportedInterfaceOrientations~ipad'; do
  pb "Delete :$key" 2>/dev/null || true
  pb "Add :$key array"
  pb "Add :$key:0 string UIInterfaceOrientationPortrait"
done

dart run flutter_launcher_icons
