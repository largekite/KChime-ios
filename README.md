# KChime

AI-powered reply assistant for iOS — keyboard extension, share extension, and a Node.js backend.

---

## Mono-repo layout

```
kchime-ios/                          ← git root
├── KChime/                          iOS main app (SwiftUI, iOS 17+)
│   ├── App/                         KChimeApp.swift, AppState.swift
│   ├── Auth/                        Sign in with Apple service + button
│   ├── Models/                      ToneProfile, ContactEntity extensions
│   ├── Onboarding/                  OnboardingFlowView and steps
│   ├── Tabs/                        Home, SavedReplies, Contacts, Settings
│   ├── Paywall/                     PaywallView (StoreKit 2 + RevenueCat)
│   ├── Persistence/                 CoreData stack (encrypted contact notes)
│   └── Resources/                   Info.plist, entitlements, assets
├── KChimeKeyboard/                  Custom keyboard extension
├── KChimeShare/                     Share extension
├── KChimeTests/                     XCTest unit tests
├── Shared/                          Code shared by all three targets
│   ├── Constants/AppConstants.swift App Group ID, API base URL, keys
│   ├── Crypto/EncryptionService.swift AES-GCM via CryptoKit + Keychain
│   └── Networking/KChimeAPIClient.swift URLSession API client
├── backend/                         Node.js + TypeScript API
│   ├── src/
│   │   ├── app.ts                   Hono app factory (Vercel / Lambda)
│   │   ├── index.ts                 Local dev server entry point
│   │   ├── types/api.ts             Shared request/response types
│   │   ├── lib/
│   │   │   ├── ai/                  OpenAI provider + Anthropic fallback
│   │   │   ├── auth/                Apple token verification, JWT middleware
│   │   │   ├── db/                  Vercel Postgres client + migrations
│   │   │   ├── payments/            RevenueCat webhook + entitlement check
│   │   │   └── rate-limit/          In-memory rate limiter
│   │   └── routes/
│   │       ├── auth.ts              POST /api/auth/apple
│   │       ├── reply.ts             POST /api/mobile/reply
│   │       ├── usage.ts             GET  /api/mobile/usage
│   │       ├── account.ts           DELETE /api/mobile/account
│   │       └── webhooks/
│   │           └── revenuecat.ts    POST /api/webhooks/revenuecat
│   ├── package.json
│   ├── tsconfig.json
│   └── vercel.json
├── .github/workflows/
│   ├── ios.yml                      iOS build + test (macOS-14 runner)
│   └── backend.yml                  Typecheck, lint, test, Vercel deploy
├── .env.example                     All required environment variables
├── project.yml                      XcodeGen project spec
└── README.md
```

---

## Architecture decisions

| Concern | Choice | Rationale |
|---------|--------|-----------|
| iOS framework | SwiftUI + Swift 6 | Strict concurrency, modern lifecycle |
| Keyboard/Share | App Extensions | Share App Group for IPC + UserDefaults |
| Local storage | CoreData + AES-GCM | Encrypted contact notes; Keychain-held key |
| Auth | Sign in with Apple | App Store required, privacy-first |
| Payments | RevenueCat SDK (iOS) + webhook | Cross-platform, battle-tested receipt validation |
| Backend | Hono on Vercel | Edge-compatible, zero cold-start overhead |
| Database | Vercel Postgres (Neon) | Serverless-native, free tier available |
| AI primary | OpenAI gpt-4o-mini | Fast, cheap, good quality |
| AI fallback | Anthropic claude-haiku | Automatic fallback if OpenAI errors |
| Rate limiting | In-memory + DB daily cap | Per-IP burst + per-user/device daily |

---

## Prerequisites

### iOS
- macOS 14+ with Xcode 16
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Apple Developer account (free or paid) — needed for extensions

### Backend
- Node.js 20+
- A Vercel account (free tier works)
- Vercel Postgres database (created in Vercel Dashboard)

---

## Local development

### 1. Clone and set up

```bash
git clone https://github.com/your-org/kchime-ios.git
cd kchime-ios
```

### 2. iOS app

```bash
# Generate the Xcode project from project.yml
xcodegen generate

# Open in Xcode
open KChime.xcodeproj
```

In Xcode:
- Set your **Team** in the Signing & Capabilities tab for all three targets.
- Replace `group.com.kchime.shared` with your own App Group ID (must match across targets).
- Run on a real device or simulator (keyboard extensions require a device for full testing).

### 3. Backend

```bash
cd backend

# Install dependencies
npm install

# Copy environment template
cp ../.env.example .env
# Edit .env and fill in your secrets

# Run local dev server (port 3000, hot reload)
npm run dev
```

Update `AppConstants.apiBaseURL` in [Shared/Constants/AppConstants.swift](Shared/Constants/AppConstants.swift) to `http://localhost:3000` for local testing.

### 4. Database migrations

The first time the backend boots (or call the helper directly):

```bash
# One-off migration — creates tables in Vercel Postgres
node -e "import('./dist/lib/db/client.js').then(m => m.runMigrations())"
```

---

## Environment variables

See [.env.example](.env.example) for the full list with descriptions.

**Required for any environment:**

| Variable | Description |
|----------|-------------|
| `JWT_SECRET` | ≥32-char random string for signing session JWTs |
| `APPLE_CLIENT_ID` | iOS bundle ID (`com.kchime.app`) |
| `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` | At least one AI provider |
| `POSTGRES_URL` | Vercel Postgres connection string |
| `REVENUECAT_API_KEY` | RevenueCat server-side API key |
| `REVENUECAT_WEBHOOK_SECRET` | Shared secret configured in RC Dashboard |

**Vercel GitHub Secrets** (for CI deploy):

| Secret | Where to find |
|--------|---------------|
| `VERCEL_TOKEN` | Vercel → Account Settings → Tokens |
| `VERCEL_ORG_ID` | Vercel → Settings → General → Team ID |
| `VERCEL_PROJECT_ID` | Vercel → Project → Settings → General |

---

## Package dependencies

### iOS (SPM via project.yml)

| Package | Version | Used by |
|---------|---------|---------|
| [KeychainSwift](https://github.com/evgenyneu/keychain-swift) | ≥20.0.0 | All targets — auth token, encryption key |
| [RevenueCat/purchases-ios](https://github.com/RevenueCat/purchases-ios) | ≥5.0.0 | Main app — subscription management |

### Backend (npm)

| Package | Role |
|---------|------|
| `hono` | HTTP framework (Vercel Edge / Node compatible) |
| `openai` | OpenAI API client |
| `@anthropic-ai/sdk` | Anthropic fallback provider |
| `jose` | JWT sign/verify + Apple JWKS remote fetch |
| `@vercel/postgres` | Serverless Postgres client |
| `zod` | Runtime request validation |

---

## CI checks

### iOS (`ios.yml`)
- Triggers on changes to any iOS source or `project.yml`
- `xcodegen generate` → `xcodebuild build` → `xcodebuild test`
- No code signing (simulator build only)

### Backend (`backend.yml`)
- Triggers on changes under `backend/`
- TypeScript typecheck → ESLint → Vitest
- On PR: deploys a Vercel preview URL
- On merge to `main`: deploys to production

---

## RevenueCat setup

1. Create a RevenueCat project and add the iOS app.
2. Add the `RevenueCat` SPM package (already in `project.yml`).
3. Set the **Webhook URL** in RC Dashboard → Integrations → Webhooks:
   `https://kchime.vercel.app/api/webhooks/revenuecat`
4. Copy the webhook authorization secret to `REVENUECAT_WEBHOOK_SECRET`.
5. Configure the `pro` entitlement and `com.kchime.app.pro.monthly` product in RC.

---

## Sign in with Apple setup

1. In Apple Developer Portal → Certificates, Identifiers & Profiles → Identifiers:
   - Enable **Sign in with Apple** capability for `com.kchime.app`.
2. The entitlements file already includes `com.apple.developer.applesignin`.
3. Set `APPLE_CLIENT_ID=com.kchime.app` and `APPLE_TEAM_ID=<your-10-char-team-id>` in the backend.

---

## Security notes

- Contact notes are encrypted at rest using **AES-256-GCM** (CryptoKit). The symmetric key lives in Keychain with `.accessibleWhenUnlockedThisDeviceOnly`.
- Session JWTs are signed with HS256. Rotate `JWT_SECRET` to invalidate all sessions.
- The keyboard extension has `RequestsOpenAccess = false` — no network access by default. Flip this only if you add direct-from-keyboard AI calls and update the privacy disclosure.
- All API routes that touch user data require a valid session JWT or are scoped to an anonymous device ID (no PII).
