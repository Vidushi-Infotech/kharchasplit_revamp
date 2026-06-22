<p align="center">
  <img src="assets/images/logo.png" alt="KharchaSplit Logo" width="120"/>
</p>

<h1 align="center">KharchaSplit</h1>

<p align="center">
  A cross-platform app for expense splitting that helps you track shared costs, settle debts, and maintain a balanced budget.
</p>

<!-- <p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-3.11+-0553B1?logo=dart" alt="Dart"/>
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-brightgreen" alt="Platforms"/>
  <img src="https://img.shields.io/badge/State-Riverpod-purple" alt="Riverpod"/>
  <img src="https://img.shields.io/badge/License-Proprietary-red" alt="License"/>
</p> -->

---

## About

Managing shared expenses shouldn't require spreadsheets, endless calculations, or awkward conversations.

**KharchaSplit** ("Kharcha" = खर्चा, Hindi for *expense*) is a modern cross-platform expense management application designed to simplify group spending. Whether you're planning a trip, sharing rent with roommates, organizing events, or splitting everyday expenses with friends, KharchaSplit automatically keeps track of who paid, who owes, and who should receive money.

---

## ✨ Features

| Feature                | Description                                                       |
| ---------------------- | ----------------------------------------------------------------- |
| 💰 Dashboard           | Real-time overview of balances, amounts owed, and recent activity |
| 👥 Groups              | Create and manage trip, household, event, or team expense groups  |
| 🤝 Friends             | Track individual balances and settlements                         |
| 🧾 Expense Management  | Add, split, edit, and review expenses with detailed breakdowns    |
| 📊 Reports & Analytics | Interactive charts and spending insights                          |
| 📄 PDF Export          | Generate and share expense reports                                |
| 🔐 Authentication      | Google Sign-In and Facebook Login                                 |
| 🌓 Material 3 Theming  | Light mode, dark mode, and system theme sync                      |
| 📡 Offline Support     | Hive-powered local storage and offline access                     |
| 📱 Responsive Design   | Optimized layouts for mobile, tablet, and web                     |

<!-- ---

## Architecture -->

---

## 📱 Supported Platforms

| Platform | Supported |
| -------- | --------- |
| Android  | ✅         |
| iOS      | ✅         |
| Web      | ✅         |

---

## 🛠️ Tech Stack

| Category         | Technology                            |
| ---------------- | ------------------------------------- |
| Framework        | Flutter 3.x                           |
| Language         | Dart 3.11+                            |
| State Management | flutter_riverpod                      |
| Navigation       | go_router                             |
| Networking       | dio                                   |
| Local Database   | hive, hive_flutter                    |
| Secure Storage   | flutter_secure_storage                |
| Authentication   | google_sign_in, flutter_facebook_auth |
| Charts           | fl_chart                              |
| PDF Generation   | pdf                                   |
| File Sharing     | share_plus                            |
| Contacts         | flutter_contacts                      |
| Connectivity     | connectivity_plus                     |

---

## Getting Started

### Prerequisites

- Flutter `>=3.x` (Dart SDK `^3.11.0`) — [Install](https://docs.flutter.dev/get-started/install)
- Android Studio or VS Code with Flutter & Dart plugins

### Setup

```bash
git clone https://github.com/Vidushi-Infotech/kharchasplit_revamp.git
cd kharchasplit_revamp

flutter pub get
dart run build_runner build --delete-conflicting-outputs

flutter run
```

### Running the App

```bash
flutter run -d android
flutter run -d ios
flutter run -d chrome
```

---

## Configuration

### Google Sign-In
1. Create an OAuth 2.0 client in [Google Cloud Console](https://console.cloud.google.com/)
2. Place `google-services.json` → `android/app/`
3. Place `GoogleService-Info.plist` → `ios/Runner/`

### Facebook Authentication
1. Register your app at [Meta for Developers](https://developers.facebook.com/)
2. Follow the [flutter_facebook_auth setup guide](https://facebook.meedu.app)
3. Add your App ID to `android/app/src/main/res/values/strings.xml` and `ios/Runner/Info.plist`

---

## 🤝 Contributing

We welcome improvements and contributions.

Before creating a pull request:

```
flutter analyze
flutter test
```

Please ensure code follows existing conventions and includes meaningful commit messages.

> For bug reports or feature requests, open an [issue](https://github.com/Vidushi-Infotech/kharchasplit_revamp/issues).

---

## License

Copyright ©  2024 [Vidushi Infotech](https://github.com/Vidushi-Infotech). 

This software is proprietary and confidential. Unauthorized copying, modification, distribution, or use is prohibited.
