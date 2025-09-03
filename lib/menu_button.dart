import 'package:flame/components.dart';
import 'package:flame/events.dart';

class MenuButton extends SpriteComponent with TapCallbacks {
  final void Function() onPressed;

  MenuButton({
    required Sprite sprite,
    required Vector2 position,
    required this.onPressed,
  }) : super(
         sprite: sprite,
         position: position,
         size: Vector2(200, 80),
         anchor: Anchor.center,
       );

  @override
  void onTapDown(TapDownEvent event) => onPressed();
}
