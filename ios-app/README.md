# Honeybun for iPhone

Honeybun launches into native SwiftUI authentication and budgeting screens in
`ios/App/HoneybunSwiftUI`. The Capacitor website remains an optional Classic fallback.
Native changes require a new app build; a website update does not update native screens.

The project also includes Face ID/passcode locking, StoreKit consumable tips, Siri
shortcuts, widgets, push notification integration and shared app-group storage.
`scripts/setup_native.rb` registers the native sources and widget target in Xcode.
Backend and Apple service configuration must be verified separately from source presence.

## Build it (needs a Mac with Xcode)

```
cd ios-app
npm install
npx cap sync ios
cd ios/App && pod install
open App.xcworkspace
```

In Xcode: pick your team under Signing & Capabilities, choose a device, press Run.

## Push notifications (Apple)

1. In your Apple Developer account, create an **APNs Auth Key** (Keys, then "Apple Push Notifications service") and download the `.p8` file.
2. Turn on Push Notifications and App Groups (`group.me.honeybun.app`) for the app id `me.honeybun.app` and for `me.honeybun.app.widget` (App Groups only).
3. Give the Worker the key (from `ios-app/`'s parent folder):
   ```
   npx wrangler secret put APNS_KEY      # paste the whole .p8 text
   npx wrangler secret put APNS_KEY_ID   # the 10-character key id
   npx wrangler secret put APNS_TEAM_ID  # your 10-character team id
   ```
   Optional: `APNS_ENV` = `sandbox` while testing from Xcode. Without these secrets, iPhone push is simply off.

## TestFlight from GitHub (no Mac needed)

Once you have an Apple Developer account, GitHub's Mac servers can build, sign and upload the app for you.

1. App Store Connect: create the app (bundle id `me.honeybun.app`).
2. App Store Connect, Users and Access, Integrations, **App Store Connect API**: create a key with the **Admin** role. Download the `.p8` (you only get it once) and note the **Key ID** and **Issuer ID**.
3. On GitHub, Settings, Secrets and variables, Actions, add four secrets:
   - `APPLE_TEAM_ID`: your 10-character team id (developer.apple.com, Membership)
   - `ASC_KEY_ID`: the key id
   - `ASC_ISSUER_ID`: the issuer id
   - `ASC_KEY_P8`: the full text of the `.p8` file, including the BEGIN and END lines
4. After validating and committing the intended release candidate, select its branch in GitHub Actions, **iPhone app (TestFlight)**, **Run workflow**. This workflow signs and uploads immediately; it is not a signing-only check. Wait for Apple processing and verify the build in App Store Connect before installing it through TestFlight on a physical iPhone.

Each run gets a new build number automatically.

## Honeybun 1.0 release gates

- Freeze features and preserve the native UI. Run the existing backend, Swift,
  project, simulator UI and Release archive checks on the selected candidate.
- Verify production backend alignment, authentication, email, APNs and Sign in
  with Apple configuration. Local tests do not prove production service readiness.
- Confirm signing for `me.honeybun.app` and `me.honeybun.app.widget`, including
  `group.me.honeybun.app`, associated domains, Sign in with Apple and production APNs.
- The optional tip jar uses three consumable StoreKit products:
  `me.honeybun.app.tip.small`, `.medium` and `.large`. Verify their App Store Connect
  configuration and submission status, and test purchases in TestFlight.
- Test the final TestFlight build on supported physical devices. Record launch,
  typical use, registration, login, account deletion and the tip flow on a physical
  device running the latest OS, as Apple requested. Simulator footage is insufficient.
- Supply working review credentials, actual-app screenshots and all six requested
  review disclosures. Add the same information to App Review Notes and the response.
- Complete accurate privacy and age-rating questionnaires. Verify the age rating
  against the minimum age in the Terms; do not blindly answer None to every question.

Uploading, deployment and App Review submission require explicit release authorization.
