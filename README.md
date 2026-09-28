# Honeybun 🐰

A little budget for two. Cloudflare Workers + D1, deployed from GitHub.

## Features
- Accounts, invite links, shared budget
- Password reset by email (Resend) and password change
- Edit any entry; undo deletes
- Custom splits: evenly, by percent, or a set amount owed
- Settle up with "Mark paid" and a payment history
- Bills & paydays that repeat weekly, every 2 weeks, or monthly, with "what's due before payday" on Home
- Private personal entries ("Only I can see this")
- Savings jar with add, take out, and a correctable history
- One-tap repeats: your five most common expenses sit on the Add screen and log with one tap
- Apple Pay auto-logging: an iPhone Shortcut automation posts each tap-to-pay purchase to Honeybun (no bank connection)
- Passkeys (Face ID / Touch ID / phone unlock) next to the password login
- Push notifications on installed devices: bills due, streak nudges, and shared expenses from your partner
- Undo right after adding an entry; budget rollover; search by amount and date range; light, dark, or auto appearance

## Database
The Worker creates and updates its own tables automatically. `schema.sql` is only a reference
(it's one line with no comments, so it can be pasted into the D1 console if you ever need it).

## Password reset emails
1. Create a free account at resend.com and add the domain `honeybun.me` (it can add the DNS records to Cloudflare for you).
2. Create an API key in Resend.
3. Cloudflare → Workers & Pages → honeybun → Settings → Variables and Secrets → Add →
   Type **Secret**, name `RESEND_API_KEY`, paste the key → Deploy.

Emails come from `hello@honeybun.me`. Change `MAIL_FROM` in `wrangler.jsonc` to use another address.

## Apple Pay auto-logging (iPhone Shortcuts)
Each person makes a key in Settings → Apple Pay auto-logging. The key is shown once and stored hashed.
A Shortcuts "Transaction" automation then calls:

    POST https://honeybun.me/api/log
    Authorization: Bearer hb_...
    Content-Type: application/json
    {"amount": "$84.00", "store": "Costco"}

Optional fields: `category` (home, groc, food, date, bills, subs, car, fun, pets, debt, other), `shared` (true/false),
`private` (true/false), `date` (YYYY-MM-DD). Form-encoded bodies work too. When category or split isn't given,
Honeybun reuses whatever you did the last time you logged that store, otherwise it guesses the category from the store name.
The response includes a `message` like "Logged $84.00 at Costco (Groceries, split) 🐰" that a Show Notification action can display.
The endpoint is rate-limited per IP and skips the same-origin check because it never reads the session cookie.

## Passkeys
WebAuthn without a library. The browser hands back the public key (`getPublicKey()`), the Worker verifies the challenge,
origin and RP ID hash, and on login verifies the ECDSA P-256 or RSA signature with WebCrypto. Passkeys are discoverable,
so the login button needs no email first. For local testing, wrangler dev rewrites Origin to the production host, so put
`DEV_ORIGIN=http://localhost:8787` in `.dev.vars`.

## Push notifications
Web Push with VAPID. Generate a P-256 key pair once, then:

    wrangler secret put VAPID_PRIVATE_KEY     # the private key as a JWK JSON string
    # VAPID_PUBLIC_KEY (raw, base64url) goes in wrangler.jsonc vars

Pushes carry no payload. The service worker asks `/api/push/latest` for the text, so nothing private goes through the
push service. Sent on: a partner's shared expense, bills due (9am local), and a streak nudge (7pm local, hourly cron).
On iPhone the app must be added to the Home Screen first.

## Local testing
    npm install
    npm run dev          # http://localhost:8787

## Security
PBKDF2-SHA256 passwords (100k iterations), hashed session tokens in HttpOnly/Secure/SameSite cookies,
hashed one-hour single-use reset tokens, same-origin JSON checks against CSRF, rate limits on login,
sign-up, reset, and joining, membership checks on every budget query, and a strict Content-Security-Policy.
