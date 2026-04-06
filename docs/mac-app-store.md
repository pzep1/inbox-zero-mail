# Mac App Store Lane

This repo already uses the macOS app sandbox in the direct-download build. The
Mac App Store lane needs one additional split: App Store builds cannot ship
Sparkle or any direct-update mechanism.

## What is prepared here

- `Config/InboxZeroMail-AppStore.xcconfig`
  App Store-specific overrides, including `APP_STORE` compilation.
- `Config/InboxZeroMail-AppStore-Info.plist`
  A plist variant with Sparkle keys removed.
- `InboxZeroMail/AppStoreUpdateSupport.swift`
  A no-op updater shim so App Store builds compile without the Sparkle-backed
  `AppUpdates` package.
- `InboxZeroMail/InboxZeroMailApp.swift`
  `InboxZeroMail/MailAppCommands.swift`
  These now import `AppUpdates` only for non-App-Store builds and hide the
  "Check for Updates…" command for App Store builds.

## Remaining manual Xcode steps

These still need to be done in Xcode because they change target membership and
signing identities:

1. Duplicate the `InboxZeroMail` app target into an App Store target, for
   example `InboxZeroMailAppStore`.
2. Point the new target at:
   - `Config/InboxZeroMail-AppStore.xcconfig`
   - `Config/InboxZeroMail-AppStore-Info.plist`
3. Remove the `AppUpdates` package product from the App Store target’s linked
   frameworks / package dependencies.
4. Keep sandbox entitlements on and tighten them further if review requires it.
5. Give the App Store target its own bundle identifier.
6. Create a matching App Store Connect app record.
7. Archive the App Store target with:
   - signing style: App Store
   - certificate/profile: Mac App Distribution
8. Upload the archive to App Store Connect and complete metadata/review.

## Expected result

- Direct-download target:
  Developer ID signing, Sparkle, GitHub Releases, appcast updates.
- App Store target:
  no Sparkle, no direct-update UI, App Store-managed updates only.
