# Phildit – project notes

Personal, read-only-ish Reddit reader for iOS (SwiftUI, iOS 17+, iPhone only). No third-party dependencies.

## Layout
- `project.yml` – XcodeGen spec; `Phildit.xcodeproj` is generated and git-ignored (`brew install xcodegen && xcodegen generate`).
- `Phildit/` – app sources: `RedditClient` (API calls; uses oauth.reddit.com + bearer token when logged in, www.reddit.com public JSON otherwise), `AuthManager` (OAuth2 installed-app flow, `ASWebAuthenticationSession`, redirect `phildit://oauth`, refresh token in Keychain), `Models`, `FeedViewModel`, `Views`, `Keychain`, `Assets.xcassets` (placeholder icon).
- `PhilditTests/` – decoding tests (comment listings with "more" stubs, token response, subscriptions).
- `.github/workflows/ios.yml` – every push: build + test on simulator, uploads unsigned `.ipa` artifact.
- `.github/workflows/testflight.yml` – manual or `v*` tag: archive, cloud-signed, upload to TestFlight.

## State (as of last session)
- CI green on the simulator build/test and unsigned IPA. The login flow and TestFlight workflow have NOT been run against real credentials.
- Login needs a Reddit "installed app" client ID (reddit.com/prefs/apps, redirect URI `phildit://oauth`), entered in the in-app Account screen. Reddit now gates new API apps behind approval, so this may need a request first.
- TestFlight needs: App Store Connect app record for `com.philkellner.phildit`, and repo secrets `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (API key, Admin role). Never commit these.
- The earlier static web reader was removed from philkellner.github.io.

## Ideas / not done
Saved subreddits, inline video, "load more replies" for comments, voting/posting (needs more OAuth scopes), real app icon, CI caching.

## Local build
    xcodegen generate
    xcodebuild test -project Phildit.xcodeproj -scheme Phildit -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
