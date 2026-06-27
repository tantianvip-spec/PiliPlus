import 'dart:ui';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/scheduler.dart';
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
  static MiniPlayerController get instance {
    if (!Get.isRegistered<MiniPlayerController>()) {
      Get.put(MiniPlayerController());
    }
    return Get.find<MiniPlayerController>();
  }

  /// Whether the mini-player is currently visible.
  final RxBool isVisible = false.obs;

  /// Position offset from bottom-right corner (dx = right inset, dy = bottom inset).
  final Rx<Offset> position = const Offset(16, 16).obs;

  /// Current size of the mini-player. Initialized on first show.
  final Rx<Size> size = Size.zero.obs;

  /// Set while the user is tapping the mini-player to expand it back to the
  /// video page. [VideoDetailPageV.didPopNext] reads this to skip playerInit().
  bool _returningFromMiniPlayer = false;
  bool get returningFromMiniPlayer => _returningFromMiniPlayer;
  void markReturningFromMiniPlayer() => _returningFromMiniPlayer = true;
  void clearReturningFromMiniPlayer() => _returningFromMiniPlayer = false;

  /// Set while the app is popping multiple routes at once (e.g. the minimize
  /// button uses Get.until to return to the root route). Intermediate video
  /// pages that briefly become visible must not hide the mini-player.
  bool _bulkPopping = false;
  bool get isBulkPopping => _bulkPopping;
  void setBulkPopping(bool value) {
    _bulkPopping = value;
    debugPrint('[MiniPlayer] setBulkPopping=$value');
  }

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
    SchedulerBinding.instance.addPostFrameCallback((_) {
      PlPlayerController.instance?.dispose();
    });
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

  /// Compute the default mini-player size for [screenSize] without mutating state.
  Size defaultSizeFor(Size screenSize, {double aspectRatio = 16 / 9}) {
    const double minWidth = 160.0;
    const double widthFactor = 0.45;
    const double maxHeightFactor = 0.55;
    double w = screenSize.width * widthFactor;
    double h = w / aspectRatio;
    final double maxH = screenSize.height * maxHeightFactor;
    if (h > maxH) {
      h = maxH;
      w = h * aspectRatio;
    }
    final double maxW = screenSize.width * 0.8;
    w = w.clamp(minWidth, maxW);
    h = w / aspectRatio;
    return Size(w, h);
  }

  /// Initialize size based on screen width on first show.
  void initSize(Size screenSize, {double aspectRatio = 16 / 9}) {
    if (size.value == Size.zero) {
      size.value = defaultSizeFor(screenSize, aspectRatio: aspectRatio);
    }
  }

  /// Reset size to default.
  void resetSize(Size screenSize, {double aspectRatio = 16 / 9}) {
    size.value = defaultSizeFor(screenSize, aspectRatio: aspectRatio);
  }

  /// Apply a preset size by [widthFactor] (relative to screen width) and keep
  /// the mini-player within screen bounds.
  void applyPreset(
    Size screenSize,
    double widthFactor, {
    double aspectRatio = 16 / 9,
  }) {
    final newSize = clampSize(
      Size(
        screenSize.width * widthFactor,
        screenSize.width * widthFactor / aspectRatio,
      ),
      screenSize,
      aspectRatio: aspectRatio,
    );
    size.value = newSize;
    position.value = clampPosition(position.value, newSize, screenSize);
  }

  /// Clamp position so the mini-player stays within screen bounds.
  Offset clampPosition(Offset pos, Size playerSize, Size screenSize) {
    return Offset(
      pos.dx.clamp(4.0, screenSize.width - playerSize.width - 4.0),
      pos.dy.clamp(4.0, screenSize.height - playerSize.height - 4.0),
    );
  }

  /// Clamp size within min/max bounds while preserving [aspectRatio].
  Size clampSize(
    Size newSize,
    Size screenSize, {
    double aspectRatio = 16 / 9,
  }) {
    const double minW = 120.0;
    final double maxW = screenSize.width * 0.85;
    final double maxH = screenSize.height * 0.65;

    double w = newSize.width.clamp(minW, maxW);
    double h = w / aspectRatio;

    if (h > maxH) {
      h = maxH;
      w = h * aspectRatio;
      if (w < minW) {
        w = minW;
        h = w / aspectRatio;
      }
    }

    return Size(w, h);
  }

}
