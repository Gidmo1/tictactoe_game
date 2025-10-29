import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:flame_audio/flame_audio.dart';
import 'package:tictactoe_game/privacy_options_screen.dart';
import 'package:tictactoe_game/profile_screen.dart';
import 'package:tictactoe_game/settings_screen.dart';
import 'package:tictactoe_game/vs_ai_board.dart';
import 'firebase.dart';
import 'board.dart';
import 'competition_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/user.dart' as app_user;
import 'service/invite_service.dart';
import 'invite_match_screen.dart';
import 'link_handler.dart';
import 'tournament_match_screen.dart';

// Lightweight router that runs a callback when routes change.
class ObservingRouter extends RouterComponent {
  final void Function(String routeName)? onRouteChanged;

  ObservingRouter({
    required String initialRoute,
    required Map<String, Route> routes,
    this.onRouteChanged,
  }) : super(initialRoute: initialRoute, routes: routes);

  @override
  void pushNamed(String name, {bool replace = false}) {
    try {
      onRouteChanged?.call(name);
    } catch (_) {}
    super.pushNamed(name, replace: replace);
  }

  @override
  Future<void> pop() async {
    return super.pop();
  }
}

class TicTacToeGame extends FlameGame
    with HasKeyboardHandlerComponents, TapCallbacks {
  String? pendingMatchId;
  bool pendingMatchIsTournament = false;
  late final RouterComponent router;
  String lastMessage = '';
  String loggedInUser = '';
  String? myPlayerSymbol;
  String currentRoute = 'menu';

  // music flag to prevent duplicate starts or stops
  bool _isMenuMusicPlaying = false;
  bool pendingTournamentJoinView = false;
  bool pendingTournamentAutoSearch = false;

  // it's gonna call these from components
  Future<void> playMenuMusic() async => _playMenuMusic();
  Future<void> stopMenuMusic() async => _stopMenuMusic();

  // Internal helpers
  Future<void> _playMenuMusic() async {
    if (!SettingsScreen.gameSoundOn) return;
    if (_isMenuMusicPlaying) return;
    try {
      await FlameAudio.bgm.stop();
    } catch (_) {}
    try {
      await FlameAudio.bgm.play('background_music.mp3', volume: 0.7);
      _isMenuMusicPlaying = true;
    } catch (e) {
      debugPrint('Error starting menu music: $e');
      _isMenuMusicPlaying = false;
    }
  }

  Future<void> _stopMenuMusic() async {
    if (!_isMenuMusicPlaying) {
      // nothing to stop
      return;
    }
    try {
      await FlameAudio.bgm.stop();
    } catch (e) {
      debugPrint('Error stopping menu music: $e');
    }
    _isMenuMusicPlaying = false;
  }

  void handleRouteChange(String routeName) {
    currentRoute = routeName;
    _handleMusicForRoute(routeName);
    debugPrint(
      'handleRouteChange: route=$routeName pendingTournamentAutoSearch=$pendingTournamentAutoSearch ts=${DateTime.now().toIso8601String()}',
    );
    // If the Competition screen requested an immediate tournament search,
    // trigger matchmaking on any TournamentMatchScreen instance found.
    if (routeName == 'tournament' && pendingTournamentAutoSearch) {
      try {
        // Clear the request immediately so it doesn't cause error repeatedly.
        pendingTournamentAutoSearch = false;
        // Find TournamentMatchScreen components and call their start method.
        final comps = children.whereType<Component>().where(
          (c) => c.runtimeType.toString() == 'TournamentMatchScreen',
        );
        final compList = comps.toList();
        debugPrint(
          'handleRouteChange: found ${compList.length} TournamentMatchScreen components to trigger',
        );
        for (final comp in compList) {
          try {
            debugPrint(
              'handleRouteChange: calling startMatchmaking on component ts=${DateTime.now().toIso8601String()}',
            );
            (comp as dynamic).startMatchmaking();
          } catch (err) {
            debugPrint('handleRouteChange: startMatchmaking call failed: $err');
          }
        }
        debugPrint('handleRouteChange: startMatchmaking calls dispatched');
      } catch (_) {}
    }
  }

  // Open a specific match
  void openMatchWithId(String matchId, {bool isCreator = true}) {
    pendingMatchId = matchId;
    pendingMatchIsTournament = false;
    myPlayerSymbol = isCreator ? 'X' : 'O';

    // stop menu music as soon as we leave menu
    _stopMenuMusic();

    if (router.children.isNotEmpty) {
      if (router.canPop()) router.pop();
    }

    router.pushNamed('invite');
  }

  // Join a match directly
  void joinMatch(String matchId) {
    lastMessage = 'Joining match $matchId...';
    pendingMatchId = matchId;
    pendingMatchIsTournament = false;
    myPlayerSymbol = 'O';

    _stopMenuMusic();
    router.pushNamed('invite');
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await Firebaseinit().initFirebase();
    await LinkHandler.initialize(this);

    // Listen for invites
    InviteService.listenForInvites((matchId) {
      openMatchWithId(matchId, isCreator: false);
    });

    // Handle cold-start invite
    final initialMatch = await InviteService.getInitialInvite();
    if (initialMatch != null) {
      openMatchWithId(initialMatch, isCreator: false);
    }

    // Load sound prefs
    final prefs = await SharedPreferences.getInstance();
    SettingsScreen.buttonSoundOn = prefs.getBool('buttonSoundOn') ?? true;
    SettingsScreen.gameSoundOn = prefs.getBool('gameSoundOn') ?? true;

    // Router setup
    router = ObservingRouter(
      initialRoute: 'menu',
      routes: {
        'menu': Route(() => MainMenuScreen()),
        'invite': Route(() {
          if (pendingMatchId == null || myPlayerSymbol == null) {
            return MainMenuScreen();
          }
          return TicTacToeInviteScreen(matchId: pendingMatchId!);
        }),
        'profile': Route(() => ProfileScreen()),
        'tictactoe': Route(() => TicTacToeBoard()),
        'settings': Route(() => SettingsScreen()),
        'vsai': Route(() {
          final fbUser = FirebaseAuth.instance.currentUser;
          if (fbUser == null) return TicTacToeVsAI();

          final user = app_user.User(
            id: fbUser.uid,
            userName: fbUser.displayName ?? "Anonymous",
            providerId: fbUser.providerData.isNotEmpty
                ? fbUser.providerData[0].providerId
                : "firebase",
            providerName: fbUser.providerData.isNotEmpty
                ? fbUser.providerData[0].providerId
                : "firebase",
          );

          return TicTacToeVsAI(loggedInUser: user);
        }),
        'competition': Route(() => CompetitionScreen()),
        'privacy': Route(() => PrivacyOptionsScreen()),
        'tournament': Route(() => TournamentMatchScreen()),
      },
      onRouteChanged: (name) => handleRouteChange(name),
    );

    add(router);

    // preload common assets that the Competition screen and matchmaking UI
    try {
      await images.load('leaderboard_background.png');
      await images.load('loading.png');
      await images.load('background.png');
      await images.load('retry.png');
      await images.load('cancel.png');
      // Record a prefs flag indicating preload succeeded (informational).
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('assets_preloaded_v1', true);
      } catch (_) {}
    } catch (e) {
      print('Preload assets failed: $e');
    }

    // Ensure music state matches menu on startup
    _handleMusicForRoute('menu');
  }

  // Central music control for routes
  void _handleMusicForRoute(String routeName) {
    final shouldPlay = (routeName == 'menu' || routeName == 'profile');
    if (!SettingsScreen.gameSoundOn) {
      // ensure music is stopped if sound disabled
      _stopMenuMusic();
      return;
    }

    if (shouldPlay) {
      _playMenuMusic();
    }
  }
}

// Main menu screen
class MainMenuScreen extends Component with HasGameReference<TicTacToeGame> {
  TextComponent? scoreDisplay;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? scoreListener;
  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final background = SpriteComponent()
      ..sprite = await game.loadSprite('background.png')
      ..size = game.size
      ..position = Vector2.zero()
      ..priority = 0;
    add(background);

    // Title
    add(
      TextComponent(
        text: '& ',
        position: Vector2(200, 150),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 40,
            color: Color.fromARGB(255, 255, 255, 255),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    // X and O sprites
    final xSprite = await game.loadSprite('X.png');
    add(
      SpriteComponent(
        sprite: xSprite,
        size: Vector2(50, 50),
        position: Vector2(150, 150),
        anchor: Anchor.center,
      ),
    );

    final oSprite = await game.loadSprite('O.png');
    add(
      SpriteComponent(
        sprite: oSprite,
        size: Vector2(50, 50),
        position: Vector2(240, 150),
        anchor: Anchor.center,
      ),
    );

    // Profile avatar
    final profileSprite = await game.loadSprite('profile.png');
    add(
      ProfileAvatar(
        sprite: profileSprite,
        size: Vector2(60, 60),
        position: Vector2(50, 60),
        onTap: () => game.router.pushNamed('profile'),
      ),
    );

    // Play buttons
    final playSprite = await game.loadSprite('play.png');
    add(
      _PressdownButton(
        sprite: playSprite,
        position: game.size / 2 + Vector2(0, -70),
        onPressed: () => game.router.pushNamed('tictactoe'),
      ),
    );

    final vsFriendSprite = await game.loadSprite('vsfriend.png');
    add(
      _PressdownButton(
        sprite: vsFriendSprite,
        position: game.size / 2,
        onPressed: () async {
          final matchId = 'match_${DateTime.now().millisecondsSinceEpoch}';
          final playerName =
              FirebaseAuth.instance.currentUser?.displayName ?? "Player";

          await InviteService().createInviteLink(playerName);
          await InviteService().shareViaWhatsApp(game.buildContext!, matchId);

          ScaffoldMessenger.of(game.buildContext!).showSnackBar(
            const SnackBar(
              content: Text("Invite sent! Waiting for your friend..."),
              duration: Duration(seconds: 2),
            ),
          );

          final g = game;
          g.openMatchWithId(matchId, isCreator: true);
        },
      ),
    );

    final vsComputerSprite = await game.loadSprite('vscomputer.png');
    add(
      _PressdownButton(
        sprite: vsComputerSprite,
        position: game.size / 2 + Vector2(0, 70),
        onPressed: () {
          final g = game;
          g.router.pushNamed('vsai');
        },
      ),
    );

    final competitionSprite = await game.loadSprite('competition.png');
    add(
      _PressdownButton(
        sprite: competitionSprite,
        position: game.size / 2 + Vector2(0, 140),
        onPressed: () async {
          // Allow guests to enter the Competition screen without forcing sign-in.
          // Guest join/sign-in flow is handled inside the CompetitionScreen.
          game.router.pushNamed('competition');
        },
      ),
    );
  }
}

class ProfileAvatar extends SpriteComponent with TapCallbacks {
  final VoidCallback onTap;

  ProfileAvatar({
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
    required this.onTap,
  }) : super(
         sprite: sprite,
         position: position,
         size: size,
         anchor: Anchor.center,
       );

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
    onTap();
  }
}

class _PressdownButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;

  _PressdownButton({
    required Sprite sprite,
    required Vector2 position,
    required this.onPressed,
    Vector2? size,
  }) : super(
         sprite: sprite,
         size: size ?? Vector2(200, 60),
         position: position,
         anchor: Anchor.center,
       );

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');

    add(
      SequenceEffect([
        ScaleEffect.to(Vector2(0.9, 0.9), EffectController(duration: 0.05)),
        ScaleEffect.to(
          Vector2(1.05, 1.05),
          EffectController(duration: 0.08, curve: Curves.easeOut),
        ),
        ScaleEffect.to(
          Vector2(1.0, 1.0),
          EffectController(duration: 0.05, curve: Curves.easeIn),
        ),
      ]),
    );

    Future.delayed(const Duration(milliseconds: 150), onPressed);
  }
}
