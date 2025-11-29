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
import 'firebase.dart';
import 'board.dart';
import 'competition_screen.dart';
import 'service/score_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'service/invite_service.dart';
import 'friend_invite_screen.dart';
import 'invite_match_screen.dart';
import 'invite_options_screen.dart';
import 'generate_code_screen.dart';
import 'join_match_screen.dart';
import 'link_handler.dart';
import 'service/auth_service.dart';
import 'tournament_match_screen.dart';

import 'vs_ai_board.dart';

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
  // Nullable fields for server-created AI matches removed.
  late final RouterComponent router;
  String lastMessage = '';
  String loggedInUser = '';
  String? myPlayerSymbol;
  String currentRoute = 'menu';
  // Temporary callback set when showing the auth gate so the Flutter
  // overlay can notify game code when the user successfully signs in.
  void Function()? pendingAuthOnSignedIn;

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
    // Remove transient overlays on route change to avoid leftover dialogs.
    // Debug-log routing changes to help diagnose overlay/black-screen issues.
    try {
      debugPrint(
        'handleRouteChange: route=$routeName pendingMatchId=$pendingMatchId myPlayerSymbol=${myPlayerSymbol ?? 'null'}',
      );
    } catch (_) {}
    try {
      overlays.remove('code_input');
      overlays.remove('message');
      overlays.remove('confirmation');
    } catch (_) {}
    _handleMusicForRoute(routeName);
    // Show a quick Flutter overlay to avoid a black screen when entering
    // the Competition route. It will be removed by the CompetitionScreen
    // itself once the Flame background sprite is ready.
    try {
      if (routeName == 'competition') {
        overlays.add('competition_fallback');
      } else {
        overlays.remove('competition_fallback');
      }
    } catch (_) {}
    // If navigating to invite with a pending match, add the lobby once invite UI is ready.
    if (routeName == 'invite' &&
        pendingMatchId != null &&
        !pendingMatchIsTournament) {
      // Poll for Invite screen and add FriendLobbyComponent when ready.
      Future<void> tryAddLobby(int retries) async {
        final hasInvite =
            (router.children.whereType<FriendInviteScreen>().isNotEmpty ||
            router.children.whereType<FriendInviteComponent>().isNotEmpty ||
            // fallback: in case invite was added directly to the game
            children.whereType<FriendInviteScreen>().isNotEmpty ||
            children.whereType<FriendInviteComponent>().isNotEmpty);
        if (hasInvite) {
          children.whereType<FriendLobbyComponent>().forEach(
            (c) => c.removeFromParent(),
          );
          add(FriendLobbyComponent(matchId: pendingMatchId!));
          return;
        }
        if (retries <= 0) {
          // timed out — add lobby anyway to avoid leaving user waiting
          children.whereType<FriendLobbyComponent>().forEach(
            (c) => c.removeFromParent(),
          );
          add(FriendLobbyComponent(matchId: pendingMatchId!));
          return;
        }
        await Future.delayed(const Duration(milliseconds: 60));
        return tryAddLobby(retries - 1);
      }

      tryAddLobby(10);
    }
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
    // Manage the profile avatar so it only appears on the home/menu route.
    try {
      if (routeName != 'menu') {
        try {
          children.whereType<ProfileAvatar>().forEach(
            (c) => c.removeFromParent(),
          );
        } catch (_) {}
        try {
          for (final r in router.children) {
            r.children.whereType<ProfileAvatar>().forEach(
              (c) => c.removeFromParent(),
            );
          }
        } catch (_) {}
      } else {
        // Ensure a ProfileAvatar exists on the menu. Run async so we don't
        // block route handling.
        () async {
          try {
            final prefs = await SharedPreferences.getInstance();
            final chosen = prefs.getString('chosen_avatar') ?? '';
            if (chosen.isEmpty) return;
            // If a ProfileAvatar already exists anywhere, do nothing.
            final existing = <ProfileAvatar>[];
            try {
              existing.addAll(children.whereType<ProfileAvatar>());
            } catch (_) {}
            if (existing.isNotEmpty) return;
            Sprite? spr;
            final candidates = [
              'assets/images/$chosen.png',
              'images/$chosen.png',
              '$chosen.png',
            ];
            for (final key in candidates) {
              try {
                spr = await loadSprite(key);
                break;
              } catch (_) {}
            }
            if (spr == null) return;
            final pa = ProfileAvatar(
              sprite: spr,
              size: Vector2(60, 60),
              position: Vector2(50, 60),
              onTap: () => router.pushNamed('profile'),
            );
            try {
              pa.paint = Paint()
                ..color = const Color.fromRGBO(255, 255, 255, 1.0);
            } catch (_) {}
            try {
              pa.priority = 1000000000000;
            } catch (_) {}
            add(pa);
          } catch (_) {}
        }();
      }
    } catch (_) {}
  }

  // Allow external callers to set invite input on the active FriendInviteComponent.
  void setInviteInput(String txt) {
    final comps = <FriendInviteComponent>[];
    comps.addAll(children.whereType<FriendInviteComponent>());
    // also check router children for route-wrapped invite screen
    for (final c in router.children) {
      if (c is FriendInviteScreen) {
        comps.addAll(c.children.whereType<FriendInviteComponent>());
      }
    }
    for (final comp in comps) {
      try {
        comp.input = txt;
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

    // Ensure we're on the invite route before showing the lobby so the
    // dialog appears on the invite screen rather than over the home/menu.
    try {
      if (currentRoute != 'invite') {
        router.pushReplacementNamed('invite');
      }
    } catch (_) {}

    // Defer adding FriendLobbyComponent until invite route is active.
  }

  // Join a match directly
  void joinMatch(String matchId) {
    lastMessage = 'Joining match $matchId...';
    pendingMatchId = matchId;
    pendingMatchIsTournament = false;
    myPlayerSymbol = 'O';

    _stopMenuMusic();
    // Defer adding FriendLobbyComponent until invite route is active.
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Competition screen manages its own loading UI to avoid black screens.
    await Firebaseinit().initFirebase();
    // Ensure we have an authenticated user for Firestore rules that
    // require auth. Prefer existing sign-in; otherwise try anonymous.
    try {
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser == null) {
        debugPrint('No Firebase user - anonymous sign-in disabled for now');
        // DISABLED: Anonymous sign-in was interfering with provider sign-in flow
        // try {
        //   await FirebaseAuth.instance.signInAnonymously();
        //   debugPrint(
        //     'Anonymous sign-in succeeded: ${FirebaseAuth.instance.currentUser?.uid}',
        //   );
        // } catch (e) {
        //   debugPrint('Anonymous sign-in failed: $e');
        // }
      } else {
        debugPrint('Already signed in uid=${fbUser.uid}');
      }
    } catch (e) {
      debugPrint('Error checking/signing Firebase user: $e');
    }
    try {
      final current = FirebaseAuth.instance.currentUser;
      if (current == null) {
        debugPrint('No current user - anonymous sign-in disabled');
        // DISABLED: Anonymous sign-in was interfering with provider sign-in flow
        // try {
        //   await FirebaseAuth.instance.signInAnonymously();
        //   debugPrint('Signed in anonymously for Firestore access');
        // } catch (e) {
        //   debugPrint('Anonymous sign-in failed: $e');
        // }
      }
    } catch (e) {
      debugPrint('Auth check failed: $e');
    }
    await LinkHandler.initialize(this);

    // Upload locally cached guest scores to server (best-effort).
    // NOTE: anonymous sign-in is disabled by default. Only attempt
    // uploading cached guest scores if there is an authenticated user.
    try {
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser != null && !fbUser.isAnonymous) {
        await ScoreService().uploadAllGuestCaches();
      } else {
        debugPrint(
          'Skipping uploadAllGuestCaches: no authenticated user present (guest scores will remain local).',
        );
      }
    } catch (e) {
      debugPrint('Failed to upload cached guest scores at startup: $e');
    }

    // Auth helper for flame so that sign in flow will work well
    try {
      // Attach auth helper for platform sign-in integrations (no social SDKs attached).
      (this as dynamic).authHelper = AuthHelper();
    } catch (_) {}

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
            return FriendInviteScreen();
          }
          return TicTacToeInviteScreen(matchId: pendingMatchId!);
        }),
        'invite_options': Route(() => InviteOptionsScreen()),
        'invite_generate': Route(() => GenerateCodeScreen()),
        'invite_join': Route(() => JoinMatchScreen()),
        'profile': Route(() => ProfileScreen()),
        'tictactoe': Route(() => TicTacToeBoard()),
        'vsai': Route(() => TicTacToeVsAI()),
        'settings': Route(() => SettingsScreen()),
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
      await images.load('playscreen.png');
      await images.load('loading.png');
      await images.load('background.png');
      await images.load('retry.png');
      // Record a prefs flag indicating preload succeeded
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
    /*final profileSprite = await game.loadSprite('profile.png');
    add(
      ProfileAvatar(
        sprite: profileSprite,
        size: Vector2(60, 60),
        position: Vector2(50, 60),
        onTap: () => game.router.pushNamed('profile'),
      ),
    );*/

    final settingsSprite = await game.loadSprite('settings.png');
    add(
      SettingsImage(
        sprite: settingsSprite,
        size: Vector2(30, 30),
        position: Vector2(340, 60),
        onTap: () => game.router.pushNamed('settings'),
      ),
    );

    // Test button removed - avatar-claim overlay is shown automatically
    // after the player's first completed match via the Home button handler.

    // Profile avatar: prefer the chosen avatar (if any) and make it tappable
    try {
      final prefs = await SharedPreferences.getInstance();
      final chosen = prefs.getString('chosen_avatar') ?? '';
      // If the player hasn't chosen an avatar yet, don't show any avatar on
      // the home screen. The avatar will be offered after their first match.
      final showAvatar = chosen.isNotEmpty;
      Sprite? profileSprite;
      if (showAvatar && chosen.isNotEmpty) {
        // Try a few common asset keys so sprite loading is robust across
        // different `pubspec.yaml` asset declarations.
        final candidates = [
          'assets/images/$chosen.png',
          'images/$chosen.png',
          '$chosen.png',
        ];
        for (final key in candidates) {
          try {
            profileSprite = await game.loadSprite(key);
            break;
          } catch (_) {}
        }
      }
      if (profileSprite != null) {
        final pa = ProfileAvatar(
          sprite: profileSprite,
          size: Vector2(60, 60),
          position: Vector2(50, 60),
          onTap: () => game.router.pushNamed('profile'),
        );
        try {
          pa.paint = Paint()..color = const Color.fromRGBO(255, 255, 255, 1.0);
        } catch (_) {}
        try {
          pa.priority = 1000000000000;
        } catch (_) {}
        add(pa);
      }
    } catch (_) {}

    // Play buttons
    /*final playSprite = await game.loadSprite('play.png');
    add(
      _PressdownButton(
        sprite: playSprite,
        position: game.size / 2 + Vector2(0, -70),
        onPressed: () => game.router.pushNamed('tictactoe'),
      ),
    );*/

    final vsFriendSprite = await game.loadSprite('vsfriend.png');
    add(
      _PressdownButton(
        sprite: vsFriendSprite,
        position: game.size / 2,
        onPressed: () async {
          // Navigate to the invite options screen
          final g = game;
          try {
            g.overlays.remove('code_input');
            g.overlays.remove('message');
          } catch (_) {}
          g.router.pushNamed('invite_options');
        },
      ),
    );

    final vsComputerSprite = await game.loadSprite('vscomputer.png');
    add(
      _PressdownButton(
        sprite: vsComputerSprite,
        position: game.size / 2 + Vector2(0, 60),
        onPressed: () async {
          final g = game;
          try {
            g.overlays.remove('code_input');
            g.overlays.remove('message');
          } catch (_) {}
          g.router.pushNamed('vsai');
        },
      ),
    );

    final competitionSprite = await game.loadSprite('competition.png');
    add(
      _PressdownButton(
        sprite: competitionSprite,
        position: game.size / 2 + Vector2(0, 120),
        onPressed: () async {
          // Allow guests to enter the Competition screen without forcing sign-in.
          // Guest join/sign-in flow is handled inside the CompetitionScreen.
          game.router.pushNamed('competition');
        },
      ),
    );

    // Avatar claim overlay is now shown after the first completed game
    // (handled by `EndMatchOverlay`). Removing the previous behavior that
    // added the avatar overlay on first visit to avoid showing it on the
    // home/menu screen before the player has played any games.
  }
}

class SettingsImage extends SpriteComponent with TapCallbacks {
  final VoidCallback onTap;
  SettingsImage({
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
         size: size ?? Vector2(220, 50),
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
