# Honeybun for iPhone

A native iOS shell (Capacitor) around https://honeybun.me, the same way the Windows app works: the website
updates itself, so most changes never need a new App Store build. Native pieces live in `ios/App/App`:

- `BiometricLock.swift`: Face ID / passcode lock (honeybun.me shows the switch in Settings inside this app only).
- `MainViewController.swift`: registers the plugins.
- `HoneybunNative.swift`: gives the widget and Siri this phone's own token (made by honeybun.me after you sign in).
- `HoneybunIntents.swift`: Siri shortcuts ("log an expense", "how much is left").
- `HoneybunWidget/`: home-screen and lock-screen widgets (they fetch /api/app/summary themselves).
- `Shared/`: code used by both the app and the widget.
- `App.entitlements`: Push Notifications and the App Group `group.me.honeybun.app`.

`scripts/setup_native.rb` adds those to the Xcode project (widget target, entitlements). It is already applied in this repo and is safe to run again.

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

## Before the App Store

1. Apple Developer account ($99/year), then create the app record (bundle id `me.honeybun.app`).
2. Apple wants more than a website in a frame. This app has a Face ID lock; add home-screen widgets,
   real push notifications (Push Notifications capability) and Siri shortcuts before submitting.
3. Paid upgrades inside the app must use Apple In-App Purchase (StoreKit), not Stripe.
4. Privacy details: the app collects email and budget entries. Add a privacy policy URL (honeybun.me/privacy) and an account-deletion option (Settings already has one).
