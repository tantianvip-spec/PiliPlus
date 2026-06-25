import 'dart:ui';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:get/get.dart';

/// Controller for the in-app mini-player overlay.
///
/// Manages visibility, position, and sizing logic for the floating
/// mini-player that appears when users navigate away from the video
/// detail page while a video is playing.
///
/// Triggered either automatically (on navigate away while playing)
/// or manually (via the minimize button in player controls).
/// Auto-hide is handled by the video page's RouteAware lifecycle.
class MiniPlayerController extends GetxController {
  static MiniPlayerController get instance => Get.find<MiniPlayerController>();

  /// Whether the mini-player is currently visible.
  final RxBool isVisible = false.obs;

  /// Position offset from bottom-right corner (dx = right inset, dy = bottom inset).
  final Rx<Offset> position = const Offset(16, 16).obs;

  /// Current size of the mini-player. Initialized on first show.
  final Rx<Size> size = Size.zero.obs;

  // ---- Tap-to-expand flag ----
  //
  // Decouples "did we come from mini-player?" detection from isVisible.
  // _onTap in the mini-player view sets this to true BEFORE hide() and
  // popUntil(). didPopNext on the video page reads this flag and clears
  // it, which lets it correctly skip playerInit even if hide() already
  // ran. Without this flag, the check depended on isVisible timing,
  // which was unreliable when hide() ran before popUntil().
  bool _tapToExpandTriggered = false;
  bool get tapToExpandTriggered => _tapToExpandTriggered;
  void markTapToExpand() => _tapToExpandTriggered = true;
  void clearTapToExpand() => _tapToExpandTriggered = false;

  /// Show the mini-player overlay.
  void show() {
    final ctr = PlPlayerController.instance;
    if (ctr != null && ctr.isDesktopPip) return;
    debugPrint('[MiniPlayer] show() called, wasVisible=${isVisible.value}');
    isVisible.value = true;
  }

  /// Hide the mini-player overlay without stopping playback.
  void hide() {
    debugPrint('[MiniPlayer] hide() called, wasVisible=${isVisible.value}');
    isVisible.value = false;
  }

  /// Close the mini-player and dispose the player.
  void close() {
    debugPrint('[MiniPlayer] close() called');
    hide();
    PlPlayerController.instance?.dispose();
  }

  /// Update the drag position.
  void updatePosition(Offset pos) {
    debugPrint('[MiniPlayer] updatePosition($pos)');
    position.value = pos;
  }

  /// Update the mini-player size.
  void updateSize(Size newSize) {
    debugPrint('[MiniPlayer] updateSize($newSize)');
    size.value = newSize;
  }

  /// Initialize size based on screen width on first show.
  void initSize(Size screenSize) {
    if (size.value == Size.zero) {
      final double w = (screenSize.width * 0.35).clamp(120.0, screenSize.width * 0.5);
      size.value = Size(w, w * 9 / 16);
    }
  }

  /// Reset size to default.
  void resetSize(Size screenSize) {
    final double w = (screenSize.width * 0.35).clamp(120.0, screenSize.width * 0.5);
    size.value = Size(w, w * 9 / 16);
  }

  /// Clamp position so the mini-player stays within screen bounds.
  Offset clampPosition(Offset pos, Size playerSize, Size screenSize) {
    return Offset(
      pos.dx.clamp(4.0, screenSize.width - playerSize.width - 4.0),
      pos.dy.clamp(4.0, screenSize.height - playerSize.height - 4.0),
    );
  }

  /// Clamp size within min/max bounds.
  Size clampSize(Size newSize, Size screenSize) {
    const double minW = 120.0;
    final double maxW = screenSize.width * 0.85;
    const double minH = minW * 9 / 16;
    final double maxH = maxW * 9 / 16;
    final double w = newSize.width.clamp(minW, maxW);
    final double h = newSize.height.clamp(minH, maxH);
    return Size(w, h);
  }
}
