# Phildit

A personal, read-only Reddit reader for iOS (SwiftUI, iOS 17+). Uses Reddit's public JSON endpoints; no login.

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

    brew install xcodegen && xcodegen generate && open Phildit.xcodeproj

CI (`.github/workflows/ios.yml`) builds, runs tests on the simulator, and uploads an unsigned `.ipa` artifact for sideloading.

## TestFlight

Run the "TestFlight" workflow (or push a `v*` tag). Required repo secrets: `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (contents of the App Store Connect API key, Admin role). The app record `com.philkellner.phildit` must exist in App Store Connect.
