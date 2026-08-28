import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:flame_audio/flame_audio.dart';
import 'package:tictactoe_game/privacy_options_screen.dart';
import 'package:tictactoe_game/profile_screen.dart';
import 'package:tictactoe_game/settings_screen.dart';
import 'package:tictactoe_game/components/button.dart';
import 'components/auth_gate_component.dart';
import 'package:tictactoe_game/game_themes/theme.dart';
import 'package:tictactoe_game/game_themes/theme_store.dart';
import 'package:tictactoe_game/game_themes/theme_picker.dart';
import 'board.dart';
import 'competition_screen.dart';
import 'service/score_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'service/invite_service.dart';
import 'friend_invite_screen.dart';
import 'invite_match_screen.dart';
import 'generate_code_screen.dart';
import 'join_match_screen.dart';
import 'link_handler.dart';
import 'service/auth_service.dart';
import 'tournament_match_screen.dart';

import 'vs_ai_board.dart';
import 'vs_computer_setup_screen.dart';
import 'vs_computer_match_config.dart';

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
  bool routerReady = false;
  String lastMessage = '';
  String loggedInUser = '';
  String? myPlayerSymbol;
  String? pendingInviteCode;
  String currentRoute = 'menu';
  VsComputerMatchConfig? vsComputerConfig;

  Future<bool> requireSignedInForOnlineAction() async {
    if (Supabase.instance.client.auth.currentUser != null) {
      return true;
    }

    try {
      final gate = AuthGateComponent(
        onSignedIn: () {
          debugPrint('Online action resumed after sign-in.');
        },
      );
      gate.priority = 1006000000000;
      add(gate);
    } catch (_) {
      try {
        overlays.add('auth_gate');
      } catch (_) {}
    }

    return false;
  }

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
    if (routeName == 'profile') {
      Future<void>(() async {
        for (var attempt = 0; attempt < 5; attempt++) {
          await Future.delayed(const Duration(milliseconds: 80));
          await refreshActiveProfile();
        }
      });
    }
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

  void openSettings({required String returnRoute}) {
    router.pushNamed('settings_$returnRoute');
  }

  Future<void> refreshActiveProfile() async {
    final profiles = <ProfileScreen>[];
    for (final route in router.children) {
      profiles.addAll(route.children.whereType<ProfileScreen>());
    }
    for (final profile in profiles) {
      await profile.refreshFromSupabase();
    }
  }

  void startVsComputer(VsComputerMatchConfig config) {
    vsComputerConfig = config;
    router.pushReplacement(
      Route(() => TicTacToeVsAI(config: config)),
      name: 'vsai_active',
    );
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
    // Supabase is initialized in main.dart before the game starts.
    // Ensure we have an authenticated user for Firestore rules that
    // require auth. Prefer existing sign-in; otherwise try anonymous.
    try {
      final authUser = Supabase.instance.client.auth.currentUser;
      if (authUser == null) {
        debugPrint('No Supabase user - anonymous sign-in disabled for now');
        // Anonymous sign-in remains disabled to preserve provider flow.
      } else {
        debugPrint('Already signed in uid=${authUser.id}');
      }
    } catch (e) {
      debugPrint('Error checking Supabase user: $e');
    }
    try {
      final current = Supabase.instance.client.auth.currentUser;
      if (current == null) {
        debugPrint('No current user - anonymous sign-in disabled');
        // Anonymous sign-in remains disabled to preserve provider flow.
      }
    } catch (e) {
      debugPrint('Auth check failed: $e');
    }
    await LinkHandler.initialize(this);

    // Upload locally cached guest scores to server (best-effort).
    // NOTE: anonymous sign-in is disabled by default. Only attempt
    // uploading cached guest scores if there is an authenticated user.
    try {
      final authUser = Supabase.instance.client.auth.currentUser;
      if (authUser != null) {
        await ScoreService().markAccountAsKnown(authUser.id);
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
        // Use the active Supabase invite hub for the VS FRIEND entry point.
        'invite_options': Route(() => FriendInviteScreen()),
        'invite_generate': Route(() => GenerateCodeScreen()),
        'invite_join': Route(() => JoinMatchScreen()),
        'profile': Route(() => ProfileScreen()),
        'tictactoe': Route(() => TicTacToeBoard()),
        'vsai_setup': Route(() => VsComputerSetupScreen()),
        'vsai': Route(() => TicTacToeVsAI(config: vsComputerConfig)),
        'settings': Route(() => SettingsScreen(returnRoute: 'menu')),
        'settings_menu': Route(() => SettingsScreen(returnRoute: 'menu')),
        'settings_tictactoe': Route(
          () => SettingsScreen(returnRoute: 'tictactoe'),
        ),
        'settings_vsai': Route(() => SettingsScreen(returnRoute: 'vsai')),
        'settings_vsai_active': Route(
          () => SettingsScreen(returnRoute: 'vsai_active'),
        ),
        'competition': Route(() => CompetitionScreen()),
        'privacy': Route(() => PrivacyOptionsScreen()),
        'tournament': Route(() => TournamentMatchScreen()),
        'themes': Route(() => ThemePickerScreen()),
      },
      onRouteChanged: (name) => handleRouteChange(name),
    );

    add(router);
    routerReady = true;

    // preload common assets that the Competition screen and matchmaking UI
    try {
      await images.load('leaderboard_background.png');
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
  GameTheme get theme => ThemeStore.current;

  // Theme-reactive components that need rebuilding on theme change
  RectangleComponent? _bgRect;
  final List<Component> _themedChildren = [];
  int _themeBuildGeneration = 0;
  String? _builtThemeId;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _buildThemedComponents(++_themeBuildGeneration);
  }

  @override
  void onMount() {
    super.onMount();
    ThemeStore.addListener(_onThemeChanged);
    if (_builtThemeId != null && _builtThemeId != theme.id) {
      _onThemeChanged();
    }
  }

  @override
  void onRemove() {
    ThemeStore.removeListener(_onThemeChanged);
    super.onRemove();
  }

  void _onThemeChanged() {
    final generation = ++_themeBuildGeneration;
    for (final child in _themedChildren) {
      child.removeFromParent();
    }
    _themedChildren.clear();
    _bgRect?.removeFromParent();
    _bgRect = null;
    _buildThemedComponents(generation);
  }

  Future<void> _buildThemedComponents([int? generation]) async {
    final t = theme;
    _builtThemeId = t.id;

    _bgRect = RectangleComponent(
      size: game.size,
      position: Vector2.zero(),
      priority: 0,
      paint: Paint()..color = t.boardBackground,
    );
    add(_bgRect!);

    // Title
    final title = TextComponent(
      text: '& ',
      position: Vector2(200, 150),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          fontSize: 40,
          color: t.contrastColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(title);
    _themedChildren.add(title);

    // X and O sprites
    final xSprite = SpriteComponent(
      sprite: await t.symbolSprite('X', 50, pixelRatio: 4),
      size: Vector2(50, 50),
      position: Vector2(150, 150),
      anchor: Anchor.center,
    );
    if (generation != null && generation != _themeBuildGeneration) return;
    add(xSprite);
    _themedChildren.add(xSprite);

    final oSprite = SpriteComponent(
      sprite: await t.symbolSprite('O', 50, pixelRatio: 4),
      size: Vector2(50, 50),
      position: Vector2(240, 150),
      anchor: Anchor.center,
    );
    if (generation != null && generation != _themeBuildGeneration) return;
    add(oSprite);
    _themedChildren.add(oSprite);

    // Settings gear icon (using sprite) - NOT themed, keep as-is
    final settingsBtn = SettingsIconButton(
      position: Vector2(340, 60),
      size: Vector2(36, 36),
      onPressed: () => game.openSettings(returnRoute: 'menu'),
    );
    add(settingsBtn);
    _themedChildren.add(settingsBtn);

    // Profile avatar: prefer the chosen avatar (if any) and make it tappable
    try {
      final prefs = await SharedPreferences.getInstance();
      final chosen = prefs.getString('chosen_avatar') ?? '';
      Sprite? profileSprite;
      final candidates = chosen.isNotEmpty
          ? ['assets/images/$chosen.png', 'images/$chosen.png', '$chosen.png']
          : ['profile.png', 'images/profile.png', 'assets/images/profile.png'];
      for (final key in candidates) {
        try {
          profileSprite = await game.loadSprite(key);
          break;
        } catch (_) {}
      }
      if (profileSprite != null) {
        if (generation != null && generation != _themeBuildGeneration) return;
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
        _themedChildren.add(pa);
      }
    } catch (_) {}

    // Play buttons (themed)
    final btnFriend = ButtonComponent(
      label: 'VS FRIEND',
      position: game.size / 2,
      size: Vector2(220, 50),
      theme: t,
      onPressed: () async {
        final g = game;
        try {
          g.overlays.remove('code_input');
          g.overlays.remove('message');
        } catch (_) {}
        g.router.pushNamed('invite_options');
      },
    );
    add(btnFriend);
    _themedChildren.add(btnFriend);

    final btnAI = ButtonComponent(
      label: 'VS COMPUTER',
      position: game.size / 2 + Vector2(0, 60),
      size: Vector2(220, 50),
      theme: t,
      onPressed: () async {
        final g = game;
        try {
          g.overlays.remove('code_input');
          g.overlays.remove('message');
        } catch (_) {}
        g.router.pushNamed('vsai_setup');
      },
    );
    add(btnAI);
    _themedChildren.add(btnAI);

    final btnComp = ButtonComponent(
      label: 'COMPETITION',
      position: game.size / 2 + Vector2(0, 120),
      size: Vector2(220, 50),
      theme: t,
      onPressed: () async {
        game.router.pushNamed('competition');
      },
    );
    add(btnComp);
    _themedChildren.add(btnComp);
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
