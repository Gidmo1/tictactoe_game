🎮 Tic Tac Toe - Play with Everyone!
A place to play Tic Tac Toe with everyone.
Real-time online multiplayer, smart AI opponents, leaderboards, trophies, and stunning visuals — all built with Flutter & Flame.
�
�
�
�
✨ Features
🎯 Game Modes
Online Multiplayer (vs Friend) — Shareable invite code/link, real-time moves synced via Firebase Realtime Database
Vs Computer — Play against AI with multiple difficulty levels
Competition / Tournaments — Compete for rankings
Quick Guest Play — Jump in instantly without signing in
🏆 Social & Progression
Google Sign-In + Firebase Authentication
Custom player profiles & avatars (annah, david, piper, andrew, etc.)
Global & friends Leaderboards
Trophy system — Bronze I, Silver II, Gold III (with locked versions)
Win/Loss tracking & statistics
🎨 Audio & Visuals
40+ hand-crafted assets (X/O sprites, confetti explosion, UI screens, backgrounds)
Full sound system: tap sound, win, lose, button clicks, background music
Smooth Flame-powered animations & particle effects (confetti on wins!)
Beautiful polished UI with settings, profile editing, pause, etc.
🔗 Extras
Share matches to WhatsApp
Copy invite code
Connectivity checks
Cross-platform support (Android, iOS, Web, Windows, macOS, Linux)
🛠 Tech Stack
Frontend: Flutter + Flame 1.12 (game engine)
Backend: Firebase (Auth, Firestore, Realtime Database, Cloud Functions)
Audio: flame_audio + audioplayers
Utilities: google_sign_in, share_plus, app_links, connectivity_plus, shared_preferences, uuid, etc.
🚀 Getting Started
Prerequisites
Flutter SDK (>=3.8.1)
Firebase project (with Authentication, Firestore, Realtime Database enabled)
Installation
# 1. Clone the repository
git clone https://github.com/Gidmo1/tictactoe_game.git
cd tictactoe_game

# 2. Install dependencies
flutter pub get

# 3. Run the game
flutter run
Firebase Setup (Important!)
Create a Firebase project at console.firebase.google.com
Enable Google Sign-In in Authentication
Create Firestore Database and Realtime Database
Download your config files:
google-services.json → android/app/
GoogleService-Info.plist → ios/Runner/
Run flutterfire configure (or manually update lib/firebase_options.dart)
Review firestore.rules before going live
🎮 How to Play
Launch the app
Sign in with Google or play as Guest
Choose Vs Friend → generate or join a code
Or choose Vs Computer
Tap the board to place your mark — first to three in a row wins!
📸 Screenshots
(Add your gameplay screenshots here — welcome screen, vs friend lobby, board in action, trophies page, leaderboard, etc.)
🗺 Future Roadmap
[ ] Random matchmaking queue
[ ] Unbeatable Minimax AI
[ ] Daily rewards & challenges
[ ] Dark/Light theme toggle
[ ] Ads & in-app purchases
[ ] Publish to Google Play & App Store
🤝 Contributing
Contributions, issues, and feature requests are welcome!
Feel free to fork the repo and submit a pull request.
📄 License
This project is currently private. All rights reserved.
Made by Gidmo1