# DeepRest Mobile (Flutter)

The **full DeepRest experience on your phone** — same accounts, same data, same
backend as the website (https://deeprest-app.dev078.workers.dev). WhatsApp-style
architecture: one brain (Cloudflare Workers + D1), many faces (web + mobile).

## What's inside

| Tab | Features |
| --- | --- |
| **Chats** | WhatsApp-dark chat list, unread badges, last message, online dots, AI Companions row |
| **Community** | Member directory, search, XP/streak, profile sheet, "Message" button |
| **Duo** | Invite code pairing, partner dashboard, end partnership |
| **Ranks** | Top 25 leaderboard + your position |
| **Dashboard** | Rank ring, today's usage (phone-synced), top apps, 7-day history, target editor |
| **SOS** (app bar) | Distress call to your Duo partner + "I'm here" replies that land in chat |
| **Profile** (app bar) | Name, About, avatar colour/emoji, password change, logout |
| **AI Companions** | Shepherd · Guide · Counselor (private, encrypted at rest) |

Presence: the app heartbeats `/api/presence` every 60 s → green "online" dots
everywhere (website too).

## Build the APK

```bash
flutter pub get
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

Requires Android SDK (Android Studio works). No API keys needed — the backend
URL is baked in.

## Architecture

```
lib/
├── main.dart              # app entry, dark theme, AuthGate (JWT in SharedPreferences)
├── core/
│   ├── api.dart           # single API client — every backend endpoint
│   ├── models.dart        # null-safe models for all API payloads
│   ├── heartbeat.dart     # presence heartbeat timer
│   └── ui.dart            # WhatsApp-dark palette + Avatar(online dot) widget
└── screens/
    ├── auth_screen.dart   # sign in / register
    ├── home_shell.dart    # bottom nav + global call overlay (polls /api/call)
    ├── chats_screen.dart  # conversation list (6 s poll)
    ├── chat_screen.dart   # bubbles, ticks, date pills, online header (3 s poll)
    ├── community_screen.dart
    ├── duo_screen.dart
    ├── sos_screen.dart
    ├── dashboard_screen.dart
    ├── leaderboard_screen.dart
    ├── profile_screen.dart
    └── ai_screen.dart
```

Polling = realtime-lite (same strategy as the website). Everything goes through
`core/api.dart` — the same JWT auth the web uses (`Authorization: Bearer`).
