import 'package:flutter/material.dart';
import 'package:tictactoe_game/service/local_db.dart';
import 'package:tictactoe_game/service/guest_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tictactoe_game/tictactoe.dart';
import 'package:flame/components.dart';
import 'dart:math' as math;
import 'package:tictactoe_game/profile_screen.dart';

// Manual overlay sizing helper. Set `kUseManualOverlaySize` to true and
// adjust `manualOverlaySize` to explicitly use Vector2(width, height).
// User requested larger visual height — enable manual override by default
// so you can edit the exact Vector2 below.
const bool kUseManualOverlaySize = true;
// Taller overlay to accommodate larger avatars in 2x2 grid
final Vector2 manualOverlaySize = Vector2(360, 500);

class EditProfileOverlay extends StatefulWidget {
  final TicTacToeGame game;
  final bool navigateToProfile;
  final bool showAvatars;
  const EditProfileOverlay({
    Key? key,
    required this.game,
    this.navigateToProfile = true,
    this.showAvatars = true,
  }) : super(key: key);

  @override
  State<EditProfileOverlay> createState() => _EditProfileOverlayState();
}

class _EditProfileOverlayState extends State<EditProfileOverlay> {
  final _controller = TextEditingController();
  String _selected = '';
  final avatars = ['annah', 'andrew', 'david', 'piper'];
  bool _busy = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chosen = prefs.getString('chosen_avatar') ?? '';
      setState(() {
        _selected = chosen;
        _controller.text = prefs.getString('playerName') ?? '';
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    // Validate avatar selection when avatars are shown
    if (widget.showAvatars && _selected.isEmpty) {
      setState(() => _notice = 'Please choose an avatar');
      // Clear notice after short delay so user sees it
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _notice = null);
      });
      return;
    }

    setState(() => _busy = true);
    try {
      final fbUser = fb.FirebaseAuth.instance.currentUser;
      final id = fbUser?.uid ?? await GuestService.getOrCreateGuestId();
      final displayName = _controller.text.trim();
      final avatarName = _selected;
      final avatarUrl = avatarName.isNotEmpty
          ? 'assets/images/$avatarName.png'
          : null;

      final db = LocalDb.instance;
      await db.init();
      await db.upsertPlayer(
        googleId: id,
        displayName: displayName.isNotEmpty ? displayName : null,
        avatarName: avatarName.isNotEmpty ? avatarName : null,
        avatarUrl: avatarUrl,
      );

      final prefs = await SharedPreferences.getInstance();
      debugPrint(
        'EditProfile: saving displayName="${displayName}" avatar="${avatarName}"',
      );
      // Persist the display name only if non-empty so we don't overwrite
      // an existing name with an empty value.
      if (displayName.isNotEmpty) {
        await prefs.setString('playerName', displayName);
        debugPrint(
          'EditProfile: persisted playerName="${displayName}" to SharedPreferences',
        );
      } else {
        debugPrint(
          'EditProfile: displayName empty — not persisting to SharedPreferences',
        );
      }
      if (avatarName.isNotEmpty)
        await prefs.setString('chosen_avatar', avatarName);

      // Ensure any existing ProfileScreen instances refresh from prefs so
      // the display name updates immediately whether or not we navigate.
      try {
        final profileComps = widget.game.children
            .whereType<ProfileScreen>()
            .toList();
        debugPrint(
          'EditProfile: found ${profileComps.length} ProfileScreen component(s) to refresh',
        );
        for (final pc in profileComps) {
          try {
            await pc.refreshFromPrefs();
            debugPrint(
              'EditProfile: refreshed a ProfileScreen instance from prefs',
            );
          } catch (e) {
            debugPrint('EditProfile: error refreshing ProfileScreen: $e');
          }
        }
      } catch (e) {
        debugPrint('EditProfile: error locating ProfileScreen components: $e');
      }

      // Update any ProfileAvatar components (menu) so the chosen avatar
      // appears immediately on the home screen without requiring a restart.
      try {
        final comps = widget.game.children.whereType<ProfileAvatar>();
        final compsList = comps.toList();
        for (final c in compsList) {
          try {
            Sprite? sprite;
            final candidates = [
              'assets/images/$avatarName.png',
              'images/$avatarName.png',
              '$avatarName.png',
            ];
            for (final key in candidates) {
              try {
                sprite = await widget.game.loadSprite(key);
                break;
              } catch (_) {}
            }
            if (sprite != null) {
              c.sprite = sprite;
              c.size = Vector2(60, 60);
              c.anchor = Anchor.center;
              try {
                c.paint = Paint()
                  ..color = const Color.fromRGBO(255, 255, 255, 1.0);
              } catch (_) {}
              try {
                c.priority = 1000000000000;
              } catch (_) {}
            }
          } catch (e) {
            debugPrint(
              'EditProfile: failed updating existing ProfileAvatar: $e',
            );
          }
        }
        // If no ProfileAvatar exists yet (user had no avatar shown on menu),
        // create and add one so the chosen avatar appears immediately.
        if (compsList.isEmpty && avatarName.isNotEmpty) {
          try {
            Sprite? sprite;
            final candidates = [
              'assets/images/$avatarName.png',
              'images/$avatarName.png',
              '$avatarName.png',
            ];
            for (final key in candidates) {
              try {
                sprite = await widget.game.loadSprite(key);
                break;
              } catch (_) {}
            }
            if (sprite != null) {
              final pa = ProfileAvatar(
                sprite: sprite,
                size: Vector2(60, 60),
                position: Vector2(50, 60),
                onTap: () => widget.game.router.pushNamed('profile'),
              );
              // Ensure avatar appears bold/opaque (avoid faded appearance)
              try {
                pa.paint = Paint()
                  ..color = const Color.fromRGBO(255, 255, 255, 1.0);
                pa.priority = 1000000000000;
              } catch (_) {}
              widget.game.add(pa);
              debugPrint(
                'EditProfile: added new ProfileAvatar for $avatarName',
              );
            } else {
              debugPrint(
                'EditProfile: could not load sprite for $avatarName to add ProfileAvatar',
              );
            }
          } catch (e) {
            debugPrint('EditProfile: exception adding ProfileAvatar: $e');
          }
        }
      } catch (e) {
        debugPrint('EditProfile: error updating/adding ProfileAvatar: $e');
      }

      // If requested, navigate to profile screen so user can view the claimed avatar.
      try {
        if (widget.navigateToProfile) {
          widget.game.router.pushNamed('profile');
        } else {
          // If we're editing inline (from the profile screen), notify the
          // ProfileScreen component to refresh from prefs so the new name
          // appears immediately without navigating.
          try {
            final comps = widget.game.children.whereType<ProfileScreen>();
            if (comps.isNotEmpty) {
              try {
                // Call the public refresh method if available.
                comps.first.refreshFromPrefs();
              } catch (_) {}
            }
          } catch (_) {}
        }
      } catch (_) {}

      // Remove overlay (support all overlay keys used to show this UI)
      widget.game.overlays.remove('edit_profile');
      widget.game.overlays.remove('edit_profile_inline');
      widget.game.overlays.remove('claim_avatar');
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overlaySize = manualOverlaySize;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Display name field ABOVE the overlay
          SizedBox(
            width: overlaySize.x * 0.84,
            height: 44,
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Display name',
                border: OutlineInputBorder(),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Overlay with avatars INSIDE
          SizedBox(
            width: overlaySize.x,
            height: overlaySize.y,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: AssetImage('assets/images/confirmation_overlay.png'),
                  fit: BoxFit.fill,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Congratulations message at the top
                  if (widget.showAvatars)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      child: Text(
                        'Congratulations! You\'ve unlocked\n4 new avatars. Choose one to continue.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.7),
                              offset: const Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Avatar grid
                  Expanded(
                    child: widget.showAvatars
                        ? LayoutBuilder(
                            builder: (ctx, constraints) {
                              final boxW = constraints.maxWidth;
                              final boxH = constraints.maxHeight;

                              // 2x2 grid positions - centered and spaced out
                              final positions = <Vector2>[
                                Vector2(boxW * 0.25, boxH * 0.30),
                                Vector2(boxW * 0.75, boxH * 0.30),
                                Vector2(boxW * 0.25, boxH * 0.70),
                                Vector2(boxW * 0.75, boxH * 0.70),
                              ];

                              // Larger avatars since overlay is dedicated to them
                              final avatarSize = Vector2(
                                boxW * 0.32,
                                boxW * 0.32,
                              );

                              final children = <Widget>[];
                              for (var i = 0; i < avatars.length; i++) {
                                final name = avatars[i];
                                final chosen = name == _selected;
                                final pos = positions[i];
                                children.add(
                                  Positioned(
                                    left: pos.x - (avatarSize.x / 2),
                                    top: pos.y - (avatarSize.y / 2),
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _selected = name),
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          border: chosen
                                              ? Border.all(
                                                  color: Colors.yellow,
                                                  width: 4,
                                                )
                                              : null,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          color: Colors.transparent,
                                        ),
                                        child: Image.asset(
                                          'assets/images/$name.png',
                                          width: avatarSize.x,
                                          height: avatarSize.y,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return Stack(children: children);
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Notice text (if any)
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                _notice!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),

          const SizedBox(height: 8),

          // Save button BELOW the overlay
          _busy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(),
                )
              : GestureDetector(
                  onTap: _save,
                  child: Image.asset(
                    'assets/images/save.png',
                    width: 140,
                    height: 48,
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, error, stack) => Container(
                      width: 140,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.save, color: Colors.black),
                          SizedBox(width: 8),
                          Text('Save', style: TextStyle(color: Colors.black)),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
