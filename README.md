# Phildit

A personal, read-only Reddit reader for iOS (SwiftUI, iOS 17+). Uses Reddit's public JSON endpoints; no login.

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

    brew install xcodegen && xcodegen generate && open Phildit.xcodeproj

CI (`.github/workflows/ios.yml`) builds, runs tests on the simulator, and uploads an unsigned `.ipa` artifact for sideloading.
