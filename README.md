

```markdown
# 🎮 Tic Tac Toe - Play with Everyone!

**A place to play Tic Tac Toe with everyone.**

Real-time online multiplayer, smart AI opponents, leaderboards, trophies, and stunning visuals — all built with Flutter & Flame.

> **🚀 Coming soon to Google Play Store & App Store!**  
> The official version will be released by Gidmo1.  
> Please do **not** copy or distribute this project.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Flame](https://img.shields.io/badge/Flame-FF9800?style=for-the-badge)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-blue?style=for-the-badge)

## ✨ Features

### 🎯 Game Modes
- **Online Multiplayer (vs Friend)** — Shareable invite code/link, real-time moves synced via Firebase Realtime Database
- **Vs Computer** — Play against AI with multiple difficulty levels
- **Competition / Tournaments** — Compete for rankings
- **Quick Guest Play** — Jump in instantly without signing in

### 🏆 Social & Progression
- Google Sign-In + Firebase Authentication
- Custom player profiles & avatars (annah, david, piper, andrew, etc.)
- Global & friends Leaderboards
- Trophy system — Bronze I, Silver II, Gold III (with locked versions)
- Win/Loss tracking & statistics

### 🎨 Audio & Visuals
- 40+ hand-crafted assets (X/O sprites, confetti explosion, UI screens, backgrounds)
- Full sound system: tap sound, win, lose, button clicks, background music
- Smooth Flame-powered animations & particle effects (confetti on wins!)
- Beautiful polished UI with settings, profile editing, pause, etc.

### 🔗 Extras
- Share matches to WhatsApp
- Copy invite code
- Connectivity checks
- Cross-platform support (Android, iOS, Web, Windows, macOS, Linux)

## 🛠 Tech Stack

- **Frontend**: Flutter + Flame 1.12 (game engine)
- **Backend**: Firebase (Auth, Firestore, Realtime Database, Cloud Functions)
- **Audio**: flame_audio + audioplayers
- **Utilities**: google_sign_in, share_plus, app_links, connectivity_plus, shared_preferences, uuid, etc.

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (`>=3.8.1`)
- Firebase project (with Authentication, Firestore, Realtime Database enabled)

### Installation

```bash
git clone https://github.com/Gidmo1/tictactoe_game.git
cd tictactoe_game
flutter pub get
flutter run
```

### Firebase Setup (Important!)
1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Google Sign-In** in Authentication
3. Create Firestore Database and Realtime Database
4. Download your config files:
   - `google-services.json` → `android/app/`
   - `GoogleService-Info.plist` → `ios/Runner/`
5. Run `flutterfire configure` (or manually update `lib/firebase_options.dart`)
6. Review `firestore.rules` before going live

## 🎮 How to Play
1. Launch the app
2. Sign in with Google or play as Guest
3. Choose **Vs Friend** → generate or join a code  
   Or choose **Vs Computer**
4. Tap the board to place your mark — first to three in a row wins!

## 📸 Screenshots
(Add your gameplay screenshots here — welcome screen, vs friend lobby, board in action, trophies page, leaderboard, etc.)

## 🗺 Future Roadmap
- [ ] Random matchmaking queue
- [ ] Unbeatable Minimax AI
- [ ] Daily rewards & challenges
- [ ] Dark/Light theme toggle
- [ ] Ads & in-app purchases
- [ ] Publish to Google Play & App Store

## 📄 License

**All Rights Reserved** — Copyright © 2026 Gidmo1

This project is **proprietary**. You may view the code on GitHub, but you are **not allowed** to copy, modify, distribute, sell, or use any part of it (including assets, code, or design) without my written permission.

See the [LICENSE](LICENSE) file for full details.

Made with ❤️ by [Gidmo1](https://github.com/Gidmo1)
```

