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

## Database
The Worker creates and updates its own tables automatically. `schema.sql` is only a reference
(it's one line with no comments, so it can be pasted into the D1 console if you ever need it).

## Password reset emails
1. Create a free account at resend.com and add the domain `honeybun.me` (it can add the DNS records to Cloudflare for you).
2. Create an API key in Resend.
3. Cloudflare → Workers & Pages → honeybun → Settings → Variables and Secrets → Add →
   Type **Secret**, name `RESEND_API_KEY`, paste the key → Deploy.

Emails come from `hello@honeybun.me`. Change `MAIL_FROM` in `wrangler.jsonc` to use another address.

## Local testing
    npm install
    npm run dev          # http://localhost:8787

## Security
PBKDF2-SHA256 passwords (100k iterations), hashed session tokens in HttpOnly/Secure/SameSite cookies,
hashed one-hour single-use reset tokens, same-origin JSON checks against CSRF, rate limits on login,
sign-up, reset, and joining, membership checks on every budget query, and a strict Content-Security-Policy.
