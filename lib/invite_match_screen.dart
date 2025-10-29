import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:tictactoe_game/settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'service/competition_service.dart';

class TicTacToeInviteScreen extends Component {
  final String matchId;
  late List<String> board;
  bool gameOver = false;
  late String currentPlayer;
  late TextComponent messageText;

  final double cellWidth = 390 / 3;
  final double cellHeight = 321 / 3;
  final double boardX = 4;
  final double boardY = 318;

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );
  StreamSubscription<DocumentSnapshot>? matchSubscription;

  bool confettiRunning = false;
  final Random random = Random();
  final List<Component> confettiPieces = [];
  bool _addedReturnButton = false;

  TicTacToeInviteScreen({required this.matchId});

  @override
  Future<void> onLoad() async {
    board = List.filled(9, '');
    currentPlayer = 'X';

    final canvasSize = findGame()?.size ?? Vector2(360, 640);

    // Background
    final background = SpriteComponent()
      ..sprite = await Sprite.load('playscreen.png')
      ..size = canvasSize
      ..position = Vector2.zero();
    add(background);

    // Message text
    messageText = TextComponent(
      text: "Waiting for opponent...",
      position: Vector2(canvasSize.x / 2, boardY - 80),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 24,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(messageText);

    // Return button will be added conditionally after we inspect the match doc

    // Board cells
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        add(
          TicTacToeCellInvite(
            row: row,
            col: col,
            position: Vector2(
              boardX + col * cellWidth,
              boardY + row * cellHeight,
            ),
            size: Vector2(cellWidth, cellHeight),
            parentBoard: this,
          ),
        );
      }
    }

    // Firestore listener for match updates
    // Choose collection based on whether the pending match is a tournament
    final gameRef = findGame();
    final collectionName =
        (gameRef != null &&
            (gameRef as dynamic).pendingMatchIsTournament == true)
        ? 'tournamentMatches'
        : 'matches';

    matchSubscription = firestore
        .collection(collectionName)
        .doc(matchId)
        .snapshots()
        .listen((snapshot) {
          final data = snapshot.data();
          if (data == null) return;

          // Add return button only for non-tournament matches
          if (data['tournament'] != true && !_addedReturnButton) {
            add(
              _PressdownButton(
                imagePath: 'return.png',
                position: Vector2(40, 180),
                size: Vector2(60, 60),
                onPressed: leaveMatch,
              ),
            );
            _addedReturnButton = true;
          }

          final boardData1D = List<String>.from(data['board']);
          for (int i = 0; i < 9; i++) {
            if (board[i] != boardData1D[i]) {
              board[i] = boardData1D[i];
              final r = i ~/ 3;
              final c = i % 3;
              final cell = children.whereType<TicTacToeCellInvite>().firstWhere(
                (cell) => cell.row == r && cell.col == c,
              );
              if (board[i] != '') cell.mark(board[i]);
            }
          }

          currentPlayer = data['currentTurn'] ?? 'X';
          gameOver = data['gameOver'] ?? false;

          if (gameOver) {
            final fb.User? firebaseUser = fb.FirebaseAuth.instance.currentUser;
            final myUID = firebaseUser?.uid ?? '';

            messageText.text = data['winnerUID'] == ''
                ? "Draw!"
                : (data['winnerUID'] == myUID ? "You win!" : "You lose!");
            _startConfetti();

            // Server-side trigger will handle awarding XP and marking scores.
            // The client should not write score documents.
          } else {
            final fb.User? firebaseUser = fb.FirebaseAuth.instance.currentUser;
            final myUID = firebaseUser?.uid ?? '';
            messageText.text = currentPlayer == myUID
                ? "Your turn"
                : "Opponent's turn";
          }
        });

    // Create match via Cloud Function if it doesn’t exist yet
    final doc = await firestore.collection(collectionName).doc(matchId).get();
    if (!doc.exists) {
      try {
        final svc = CompetitionService();
        final user = await svc.waitForSignIn();
        if (user == null) return;
        final callable = functions.httpsCallable('createMatch');
        await callable.call({'matchId': matchId, 'playerId': user.uid});
      } catch (e) {
        debugPrint("Error creating match via Cloud Function: $e");
      }
    }
  }

  // Scoring for tournament matches is handled server-side; client must not
  // write scores.

  void handleTap(int row, int col) async {
    if (gameOver || board[row * 3 + col] != '') return;

    // Ensure user is signed in and token propagated before attempting move
    final svc = CompetitionService();
    final user = await svc.waitForSignIn();
    if (user == null) return;
    if (currentPlayer != user.uid) return; // only allow your turn

    final int cellIndex = row * 3 + col;

    try {
      final callable = functions.httpsCallable('makeMove');
      final result = await callable.call({
        'matchId': matchId,
        'playerId': user.uid,
        'cellIndex': cellIndex,
      });

      final data = result.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final updatedBoard = List<String>.from(data['board']);
        board = updatedBoard;
        currentPlayer = data['currentTurn'] ?? currentPlayer;

        // Update cell visuals
        for (int i = 0; i < 9; i++) {
          final r = i ~/ 3;
          final c = i % 3;
          final cellComponent = children
              .whereType<TicTacToeCellInvite>()
              .firstWhere((cell) => cell.row == r && cell.col == c);
          if (board[i] != '') cellComponent.mark(board[i]);
        }
      }
    } catch (e) {
      debugPrint('Error calling makeMove Cloud Function: $e');
    }
  }

  void leaveMatch() async {
    matchSubscription?.cancel();

    // Leave tournament queue if necessary
    try {
      final svc = CompetitionService();
      final user = await svc.waitForSignIn();
      if (user != null) {
        final matchDoc = await firestore
            .collection('matches')
            .doc(matchId)
            .get();
        final isTournament = matchDoc.data()?['tournament'] == true;
        final tournamentId = matchDoc.data()?['tournamentId'] as String?;
        if (isTournament && tournamentId != null) {
          final callable = functions.httpsCallable('leaveTournamentQueue');
          await callable.call({
            'playerId': user.uid,
            'tournamentId': tournamentId,
          });
        }
      }
    } catch (e) {
      debugPrint('Error leaving tournament queue: $e');
    }

    final flameGame = findGame();
    if (flameGame != null) {
      for (final component in List<Component>.from(flameGame.children)) {
        component.removeFromParent();
      }
    }
    final router = (flameGame as dynamic).router;
    router?.pushNamed('menu');
  }

  void _startConfetti() {
    if (confettiRunning) return;
    confettiRunning = true;

    final size = findGame()?.size ?? Vector2(360, 640);

    void spawnConfettiPiece() {
      if (!confettiRunning) return;
      final double confettiSize = 4 + random.nextDouble() * 6;
      final paint = Paint()
        ..color = Color.fromARGB(
          255,
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
        );
      final confetti = RectangleComponent(
        size: Vector2(confettiSize, confettiSize * 1.5),
        paint: paint,
        position: Vector2(random.nextDouble() * size.x, -10),
        anchor: Anchor.center,
      );

      confettiPieces.add(confetti);
      add(confetti);

      final fallDuration = 1.5 + random.nextDouble() * 1.5;
      confetti.add(
        MoveEffect.to(
          Vector2(confetti.x, size.y + 50),
          EffectController(duration: fallDuration, curve: Curves.linear),
          onComplete: () {
            confetti.removeFromParent();
            confettiPieces.remove(confetti);
          },
        ),
      );

      confetti.add(
        RotateEffect.by(
          random.nextDouble() * pi * 4,
          EffectController(duration: fallDuration, curve: Curves.linear),
        ),
      );

      Future.delayed(const Duration(milliseconds: 15), spawnConfettiPiece);
    }

    spawnConfettiPiece();
    Future.delayed(
      const Duration(milliseconds: 2500),
      () => confettiRunning = false,
    );
  }
}

// CELL COMPONENT
class TicTacToeCellInvite extends PositionComponent with TapCallbacks {
  final int row;
  final int col;
  SpriteComponent? markSprite;
  final TicTacToeInviteScreen parentBoard;

  TicTacToeCellInvite({
    required this.row,
    required this.col,
    required Vector2 position,
    required Vector2 size,
    required this.parentBoard,
  }) : super(position: position, size: size);

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('tap.wav');
    parentBoard.handleTap(row, col);
  }

  void mark(String symbol) async {
    markSprite?.removeFromParent();
    markSprite = SpriteComponent()
      ..sprite = await Sprite.load(symbol == 'X' ? 'X.png' : 'O.png')
      ..size = Vector2(70, 70)
      ..position = size / 2
      ..anchor = Anchor.center;
    add(markSprite!);
  }
}

// BUTTON COMPONENT
class _PressdownButton extends SpriteComponent with TapCallbacks {
  final VoidCallback onPressed;
  final String imagePath;

  _PressdownButton({
    required this.imagePath,
    required Vector2 position,
    required Vector2 size,
    required this.onPressed,
  }) : super(size: size, position: position, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load(imagePath);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (SettingsScreen.buttonSoundOn) FlameAudio.play('button.wav');
    _bounceEffect();
    Future.delayed(const Duration(milliseconds: 180), onPressed);
  }

  void _bounceEffect() {
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
  }
}

// UTILITY: Current Week ID
String getCurrentWeekId() {
  final now = DateTime.now();
  final year = now.year;
  final oneJan = DateTime(year, 1, 1);
  final days = now.difference(oneJan).inDays + 1;
  final week = ((days + oneJan.weekday) / 7).ceil();
  return '$year-W$week';
}
