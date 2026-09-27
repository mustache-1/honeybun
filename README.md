# Honeybun 🐰

A little budget for two. Runs on Cloudflare Workers + D1, deployed from GitHub.

## Setup (one time)

1. **GitHub** – create a *private* repo called `honeybun` and upload everything in this folder.
2. **Database** – Cloudflare dashboard → Storage & Databases → D1 → Create → name it `honeybun`. Copy its **Database ID**.
3. **Connect the ID** – on GitHub, edit `wrangler.jsonc` and replace `PASTE-YOUR-DATABASE-ID-HERE` with that ID. Commit.
4. **Create the tables** – in D1, open `honeybun` → Console, paste all of `schema.sql`, run it.
5. **Deploy** – Cloudflare → Workers & Pages → Create → Import a repository → pick `honeybun`. Keep the deploy command `npx wrangler deploy`.
6. **Domain** – honeybun.me must be in your Cloudflare account; `wrangler.jsonc` attaches it automatically.

After that, every commit to `main` deploys automatically.

## Local testing (optional)

    npm install
    npm run db:init:local
    npm run dev          # http://localhost:8787

## Security notes

- Passwords: PBKDF2-SHA256, 100k iterations, random salt.
- Sessions: random 256-bit token in an HttpOnly, Secure, SameSite=Lax `__Host-` cookie; only its SHA-256 hash is stored.
- CSRF: non-GET requests must be JSON from the same origin.
- Login, sign-up, and join attempts are rate-limited.
- Every budget query checks membership.
- Content-Security-Policy and other headers in `public/_headers`.
