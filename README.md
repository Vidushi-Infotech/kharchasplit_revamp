<p align="center">
  <img src="frontend/assets/images/logo.png" width="120" alt="KharchaSplit Logo" />
</p>

<h1 align="center">KharchaSplit</h1>

<p align="center">
  <strong>Split expenses effortlessly with friends, family, and groups</strong>
</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.kharchasplit">
    <img src="https://img.shields.io/badge/Google_Play-414141?style=for-the-badge&logo=google-play&logoColor=white" alt="Play Store" />
  </a>
  <a href="https://apps.apple.com/in/app/kharchasplit/id6754237285">
    <img src="https://img.shields.io/badge/App_Store-0D96F6?style=for-the-badge&logo=app-store&logoColor=white" alt="App Store" />
  </a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-3.2.1-0D9D6F?style=flat-square" alt="Version" />
  <img src="https://img.shields.io/badge/flutter-3.x-02569B?style=flat-square&logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/node.js-express-339933?style=flat-square&logo=node.js" alt="Node.js" />
  <img src="https://img.shields.io/badge/PostgreSQL-4169E1?style=flat-square&logo=postgresql&logoColor=white" alt="PostgreSQL" />
  <img src="https://img.shields.io/badge/platform-iOS%20%7C%20Android%20%7C%20Web-lightgrey?style=flat-square" alt="Platform" />
</p>

---

## About

KharchaSplit is a modern, production-ready expense splitting app built for the Indian market. Create groups, add expenses, split them your way, and settle up — all with a clean, responsive interface that works across phones, tablets, and web.

---

## Features

### Expense Management
| Feature | Description |
|---------|-------------|
| **4 Split Types** | Equal, Exact (unequal), Percentage, and Shares |
| **Smart Breakdown** | Collapsible split breakdown with member search, select all/deselect |
| **Categories** | 9 predefined categories with icons (Food, Transport, Shopping, etc.) |
| **Receipt Attach** | Camera/gallery photo upload with circular crop |
| **Personal Expenses** | Track personal spending outside of groups |

### Groups
| Feature | Description |
|---------|-------------|
| **Create & Manage** | Name, emoji/photo cover, multi-currency support (INR, USD, etc.) |
| **Add Members** | From device contacts — registered users added instantly, others invited |
| **Invite System** | WhatsApp (WATI), Email (SMTP), Copy Link — no email required to add |
| **Placeholder Members** | Unregistered users appear with pending badge, auto-convert on signup |
| **Cover Photos** | Base64 image upload with emoji fallback |

### Settlements
| Feature | Description |
|---------|-------------|
| **Settle Up** | Select recipient, amount, payment method |
| **Settlement History** | Per-pair timeline in group detail |
| **Balance Computation** | Client-side algorithm mirrors backend (paisa-precise) |

### Profile & Auth
| Feature | Description |
|---------|-------------|
| **Phone + Password** | Registration with +91 normalization |
| **Password Reset** | Email OTP via SMTP, auto-login after reset |
| **Profile Setup Gate** | Forced name + email step before dashboard |
| **Camera + Gallery** | Profile photo with circular crop (pure Flutter) |
| **Cross-Device Sync** | Profile data syncs on cold start via server refresh |
| **Session Management** | View active sessions, sign out everywhere |

### Notifications
| Feature | Description |
|---------|-------------|
| **Push Notifications** | Firebase Cloud Messaging (iOS + Android) |
| **In-App Inbox** | Read/unread, mark all read, notification routing |
| **Deep Links** | Tap notification → navigate to correct screen |

### UX & Design
| Feature | Description |
|---------|-------------|
| **Responsive** | 3-breakpoint design: Mobile (<600px), Tablet (600-1100px), Desktop (>1100px) |
| **Dark Mode** | System, Light, Dark theme switching |
| **Pull-to-Refresh** | Available on 13 screens |
| **Skeleton Loaders** | Shimmer loading on all data screens |
| **Offline Banner** | Connectivity detection with auto-refresh on reconnect |
| **Haptic Feedback** | Touch feedback on key interactions |

---

## Tech Stack

<table>
<tr>
<td width="50%">

### Frontend
| Technology | Purpose |
|-----------|---------|
| **Flutter 3.x** | Cross-platform UI |
| **Riverpod 3.2** | State management (23+ providers) |
| **go_router 17.1** | Navigation (30 routes) |
| **Dio 5.3** | HTTP client with interceptors |
| **FlutterSecureStorage** | Encrypted token storage |
| **Firebase Messaging** | Push notifications |
| **crop_your_image** | Profile photo crop |

</td>
<td width="50%">

### Backend
| Technology | Purpose |
|-----------|---------|
| **Node.js + Express** | REST API server |
| **PostgreSQL** | Primary database |
| **JWT** | Access + Refresh token auth |
| **bcrypt** | Password hashing |
| **Nodemailer** | SMTP email invites |
| **WATI API** | WhatsApp Business invites |
| **Firebase Admin** | Push notification delivery |

</td>
</tr>
</table>

---

## Project Structure

```
kharchaSplit/
├── frontend/                    # Flutter app
│   ├── lib/
│   │   ├── core/               # Theme, routing, services, utils
│   │   ├── components/         # Reusable UI (avatar, cards, loaders)
│   │   ├── models/             # Data models (user, group, expense, etc.)
│   │   ├── data/               # Repository layer (API communication)
│   │   ├── modules/            # Feature modules
│   │   │   ├── auth/           # Login, register, profile setup
│   │   │   ├── dashboard/      # Home screen
│   │   │   ├── groups/         # Groups, group detail, contacts picker
│   │   │   ├── expenses/       # Add/edit expense, expense detail
│   │   │   ├── settlements/    # Settle up, settlement history
│   │   │   ├── personal_expenses/
│   │   │   ├── friends/        # Friends list, friend detail
│   │   │   ├── activity/       # Activity feed
│   │   │   ├── notifications/  # Push inbox
│   │   │   ├── profile/        # Profile, edit, security, settings
│   │   │   ├── reports/        # Spending analytics
│   │   │   └── onboarding/     # Welcome tour
│   │   ├── layouts/            # Shell navigation (mobile, tablet, web)
│   │   └── presentation/       # Splash screen
│   ├── ios/
│   ├── android/
│   └── web/
│
├── backend/                     # Node.js API
│   └── src/
│       ├── config/             # Database, Firebase
│       ├── controllers/        # Route handlers
│       ├── models/             # SQL queries
│       ├── services/           # Email, WATI, notifications
│       ├── middleware/         # Auth, validation
│       ├── routes/            # Express routes
│       └── server.js          # Entry point
│
└── Production_May25/           # Production deployment snapshot
```

---

## Getting Started

### Prerequisites
- Flutter SDK 3.11+
- Node.js 18+
- PostgreSQL 14+
- Firebase project (for push notifications)

### Frontend Setup
```bash
cd frontend
flutter pub get
flutter run
```

### Backend Setup
```bash
cd backend
npm install
cp .env.example .env   # Configure database, JWT, SMTP, WATI
npm run dev
```

### Environment Variables (Backend)
```env
# Server
NODE_ENV=development
PORT=3000

# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/kharchasplit

# Auth
JWT_SECRET=your-secret
JWT_REFRESH_SECRET=your-refresh-secret

# Email (SMTP)
SMTP_HOST=smtp.gmail.com
SMTP_USER=your-email
SMTP_PASSWORD=your-app-password

# WhatsApp (WATI)
WATI_API_URL=https://live-mt-server.wati.io/xxxxx
WATI_API_TOKEN=your-token

# Firebase
FIREBASE_CREDENTIALS=path/to/serviceAccount.json
```

---

## API Endpoints

### Auth
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/auth/register` | Register with phone + password |
| POST | `/api/v1/auth/login` | Login |
| POST | `/api/v1/auth/forgot-password` | Request password reset OTP |
| POST | `/api/v1/auth/reset-password` | Verify OTP + set new password |

### Users
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/users/:id` | Get user profile |
| PUT | `/api/v1/users/:id` | Update profile (name, email, photo) |
| POST | `/api/v1/users/check-registration` | Batch check phone registration |

### Groups
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/groups` | List user's groups |
| POST | `/api/v1/groups` | Create group |
| GET | `/api/v1/groups/:id` | Group detail with members + balances |
| PUT | `/api/v1/groups/:id` | Edit group |
| POST | `/api/v1/groups/:id/pending-members` | Add member (+ WhatsApp invite) |
| POST | `/api/v1/groups/:id/invite-email` | Send email invite |

### Expenses
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/expenses` | Create expense |
| GET | `/api/v1/expenses/:id` | Expense detail |
| PUT | `/api/v1/expenses/:id` | Edit expense |
| DELETE | `/api/v1/expenses/:id` | Delete expense |

### Settlements
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/settlements` | Create settlement |
| GET | `/api/v1/settlements/:groupId` | List settlements for group |

---

## Version History

| Version | Build | Date | Highlights |
|---------|-------|------|------------|
| **3.2.1** | 20 | May 2026 | Invite redesign, cross-device sync, field standardization, 77 QA tests |
| **3.2.0** | 19 | May 2026 | iOS fixes, profile persistence, avatar system, camera crop |
| **3.0.0** | 15 | May 2026 | Production deploy, cover photos, SMTP invites, password auth |
| **2.5.0** | 13 | Apr 2026 | Backend integration, JWT, FCM, WATI, push notifications |
| **2.0.0** | 10 | Mar 2026 | All screens, splits, settlements, responsive design |
| **1.0.0** | 5 | Mar 2026 | Foundation — models, components, shell, dashboard |

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter App (Dart)                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐ │
│  │  Screens  │  │ Widgets  │  │Providers │  │  Models  │ │
│  └────┬─────┘  └──────────┘  └────┬─────┘  └─────────┘ │
│       │                           │                      │
│  ┌────▼───────────────────────────▼─────┐               │
│  │         Repository Layer (Dio)        │               │
│  └────────────────┬─────────────────────┘               │
└───────────────────┼─────────────────────────────────────┘
                    │ HTTPS (JWT)
┌───────────────────▼─────────────────────────────────────┐
│               Node.js / Express API                      │
│  ┌──────────┐  ┌────────────┐  ┌──────────┐            │
│  │  Routes   │  │Controllers │  │ Services  │            │
│  └────┬─────┘  └─────┬──────┘  └────┬─────┘            │
│       │               │              │                   │
│  ┌────▼───────────────▼──────────────▼─────┐            │
│  │            Models (SQL Queries)           │            │
│  └────────────────┬─────────────────────────┘            │
└───────────────────┼─────────────────────────────────────┘
                    │
        ┌───────────▼───────────┐
        │     PostgreSQL DB      │
        │  Users, Groups, Expenses│
        │  Settlements, Activities│
        └────────────────────────┘
```

---

## Team

**Vidushi Infotech** — Design, Development & Deployment

---

<p align="center">
  <sub>Built with Flutter + Express + PostgreSQL</sub>
</p>
