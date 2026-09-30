# Honeybun for iPhone

A native iOS shell (Capacitor) around https://honeybun.me, the same way the Windows app works: the website
updates itself, so most changes never need a new App Store build. Native pieces live in `ios/App/App`:

- `BiometricLock.swift`: Face ID / passcode lock (honeybun.me shows the switch in Settings inside this app only).
- `MainViewController.swift`: registers that plugin.

## Build it (needs a Mac with Xcode)

```
cd ios-app
npm install
npx cap sync ios
cd ios/App && pod install
open App.xcworkspace
```

In Xcode: pick your team under Signing & Capabilities, choose a device, press Run.

## Before the App Store

1. Apple Developer account ($99/year), then create the app record (bundle id `me.honeybun.app`).
2. Apple wants more than a website in a frame. This app has a Face ID lock; add home-screen widgets,
   real push notifications (Push Notifications capability) and Siri shortcuts before submitting.
3. Paid upgrades inside the app must use Apple In-App Purchase (StoreKit), not Stripe.
4. Privacy details: the app collects email and budget entries. Add a privacy policy URL (honeybun.me/privacy) and an account-deletion option (Settings already has one).
