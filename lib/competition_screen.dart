import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

// Return button
class _ReturnButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;

  _ReturnButton({
    required Sprite sprite,
    required Vector2 position,
    required this.onPressed,
  }) : super(
         sprite: sprite,
         position: position,
         size: Vector2(50, 50),
         anchor: Anchor.center,
       );

  @override
  void onTapDown(TapDownEvent event) {
    add(ScaleEffect.to(Vector2(0.9, 0.9), EffectController(duration: 0.05)));
    Future.delayed(const Duration(milliseconds: 120), onPressed);
  }
}

// Button that bounces like an arcade button
class _ArcadeButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;

  _ArcadeButton({
    required Sprite sprite,
    required Vector2 position,
    Vector2? size,
    required this.onPressed,
  }) : super(
         sprite: sprite,
         position: position,
         size: size ?? Vector2(200, 60),
         anchor: Anchor.center,
       );

  @override
  void onTapDown(TapDownEvent event) {
    // Bounce effect
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

// Leaderboard Card
class LeaderboardCardComponent extends PositionComponent {
  final int rank;
  final String name;
  final int score;
  final Color cardColor;
  final Color textColor;
  final Color? medalColor;
  final double width;
  final double height;

  LeaderboardCardComponent({
    required this.rank,
    required this.name,
    required this.score,
    required Vector2 position,
    required this.cardColor,
    required this.textColor,
    this.medalColor,
    required this.width,
    required this.height,
  }) : super(
         position: position,
         size: Vector2(width, height),
         anchor: Anchor.topLeft,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Card background
    add(RectangleComponent(size: size, paint: Paint()..color = cardColor));

    // Trophy and medal
    if (medalColor != null) {
      final trophySize = 28.0;
      add(
        SpriteComponent(
          sprite: await Sprite.load(
            rank == 1
                ? 'trophy_gold.png'
                : rank == 2
                ? 'trophy_silver.png'
                : 'trophy_bronze.png',
          ),
          size: Vector2(trophySize, trophySize),
          position: Vector2(16, size.y / 2 - trophySize / 2),
        ),
      );
    }

    // Rank number
    add(
      TextComponent(
        text: '$rank',
        position: Vector2(60, size.y / 2),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: medalColor ?? const Color.fromARGB(255, 255, 255, 255),
          ),
        ),
      ),
    );

    // Circle avatar
    add(
      CircleComponent(
        radius: 20,
        position: Vector2(110, size.y / 2),
        anchor: Anchor.center,
        paint: Paint()..color = Colors.blueGrey,
      ),
    );

    // Player name
    add(
      TextComponent(
        text: name,
        position: Vector2(145, size.y / 2),
        anchor: Anchor.centerLeft,
        textRenderer: TextPaint(
          style: TextStyle(
            fontSize: 18,
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    // Score
    add(
      TextComponent(
        text: '$score XP',
        position: Vector2(width - 16, size.y / 2),
        anchor: Anchor.centerRight,
        textRenderer: TextPaint(
          style: TextStyle(
            fontSize: 18,
            color: const Color.fromARGB(255, 225, 180, 0),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _ScrollableLeaderboardContainer extends PositionComponent
    with DragCallbacks {
  final List<Map<String, dynamic>> entries;
  final double width;
  final double height;
  final double y;
  double scrollOffset = 0;
  double scrollVelocity = 0;
  final double cardHeight = 70;
  List<LeaderboardCardComponent> cardComponents = [];

  _ScrollableLeaderboardContainer({
    required this.entries,
    required this.width,
    required this.height,
    required this.y,
  }) : super(position: Vector2(0, y), size: Vector2(width, height));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _buildInitialCards();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (scrollVelocity.abs() > 0.1) {
      scrollOffset += scrollVelocity * dt;
      scrollVelocity *= 0.92;
      final maxScroll = (entries.length * cardHeight - height).clamp(
        0,
        double.infinity,
      );
      scrollOffset = scrollOffset.clamp(0, maxScroll).toDouble();
      _updateCardPositions();
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    scrollOffset -= event.localDelta.y;
    scrollVelocity = -event.localDelta.y * 10;
    final maxScroll = (entries.length * cardHeight - height).clamp(
      0,
      double.infinity,
    );
    scrollOffset = scrollOffset.clamp(0, maxScroll).toDouble();
    _updateCardPositions();
  }

  void _buildInitialCards() {
    removeAll(children);
    cardComponents.clear();
    for (int i = 0; i < entries.length; i++) {
      final rank = i + 1;
      final name = entries[i]['name'] ?? 'Player';
      final score = entries[i]['score'] is int
          ? entries[i]['score'] as int
          : int.tryParse(entries[i]['score'].toString()) ?? 0;

      final Color cardColor = rank <= 3
          ? const Color.fromARGB(255, 74, 104, 67)
          : i % 2 == 0
          ? const Color.fromARGB(255, 74, 104, 67)
          : const Color.fromARGB(255, 74, 104, 67);

      final card = LeaderboardCardComponent(
        rank: rank,
        name: name,
        score: score,
        position: Vector2(0, i * cardHeight),
        cardColor: cardColor,
        textColor: const Color.fromARGB(255, 255, 255, 255),
        medalColor: rank <= 3
            ? rank == 1
                  ? Colors.yellow.shade700
                  : rank == 2
                  ? Colors.grey
                  : const Color(0xFFCD7F32)
            : null,
        width: width,
        height: cardHeight - 6,
      );

      cardComponents.add(card);
      add(card);
    }
    _updateCardPositions();
  }

  void _updateCardPositions() {
    for (int i = 0; i < cardComponents.length; i++) {
      final card = cardComponents[i];
      card.position = Vector2(0, i * cardHeight - scrollOffset);
    }
  }
}

// Competition Screen
class CompetitionScreen extends Component with HasGameReference {
  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Background
    final bg = SpriteComponent()
      ..sprite = await game.loadSprite('leaderboard_background.png')
      ..size = game.size
      ..position = Vector2.zero();
    add(bg);

    final goldSprite = await Sprite.load('Gold III_locked.png');
    add(
      SpriteComponent(
        sprite: goldSprite,
        size: Vector2(120, 120),
        position: Vector2(300, 80),
        anchor: Anchor.center,
      ),
    );

    final silverSprite = await Sprite.load('Silver II_locked.png');
    add(
      SpriteComponent(
        sprite: silverSprite,
        size: Vector2(110, 110),
        position: Vector2(180, 90),
        anchor: Anchor.center,
      ),
    );

    final bronzeSprite = await Sprite.load('Bronze I.png');
    add(
      SpriteComponent(
        sprite: bronzeSprite,
        size: Vector2(120, 120),
        position: Vector2(60, 120),
        anchor: Anchor.center,
      ),
    );

    // Scrollable leaderboard
    final leaderboardStartY = 120.0;
    final leaderboardHeight = game.size.y - leaderboardStartY - 180.0;
    add(
      _ScrollableLeaderboardContainer(
        entries: dummyEntries,
        width: game.size.x,
        height: leaderboardHeight,
        y: leaderboardStartY + 40,
      ),
    );

    // Return button
    final returnSprite = await game.loadSprite('return.png');
    add(
      _ReturnButton(
        sprite: returnSprite,
        position: Vector2(24, 60),
        onPressed: () {
          final flameGame = findGame();
          if (flameGame != null) {
            final router = (flameGame as dynamic).router;
            router?.pushNamed('menu');
          }
        },
      ),
    );

    // Join Tournament button
    final joinSprite = await game.loadSprite('joinatournament.png');
    final buttonWidth = 220.0;
    final buttonHeight = 56.0;
    final buttonSpacing = 16.0;
    final bottomStartY = game.size.y - buttonHeight * 2 - buttonSpacing - 30;

    // Join Tournament button
    add(
      _ArcadeButton(
        sprite: joinSprite,
        position: Vector2(game.size.x / 2, bottomStartY + buttonHeight / 2),
        size: Vector2(buttonWidth, buttonHeight),
        onPressed: () {
          //To route to tournament screen
          final flameGame = findGame();
          if (flameGame != null) {
            final router = (flameGame as dynamic).router;
            router?.pushNamed('lobby');
          }
        },
      ),
    );
  }
}

// Ai players on the leaderboard incase there is not an human player available on the leaderboard
final List<Map<String, dynamic>> dummyEntries = [
  {'name': 'Alice', 'score': 1200},
  {'name': 'Bob', 'score': 1100},
  {'name': 'Charlie', 'score': 1050},
  {'name': 'Diana', 'score': 1000},
  {'name': 'Eve', 'score': 950},
  /*{'name': 'Frank', 'score': 900},
  {'name': 'Grace', 'score': 850},
  {'name': 'Heidi', 'score': 800},
  {'name': 'Ivan', 'score': 750},
  {'name': 'Judy', 'score': 700},
  {'name': 'Mallory', 'score': 650},
  {'name': 'Niaj', 'score': 600},
  {'name': 'Olivia', 'score': 550},
  {'name': 'Peggy', 'score': 500},
  {'name': 'Sybil', 'score': 450},*/
];
