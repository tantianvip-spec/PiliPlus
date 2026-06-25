import 'dart:async';
import 'dart:ui';

import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:get/get.dart';

/// Controller for the in-app mini-player overlay.
///
/// Manages visibility, position, and routing logic for the floating
/// mini-player that appears when users navigate away from the video
/// detail page while a video is playing.
class MiniPlayerController extends GetxController {
  static MiniPlayerController get instance => Get.find<MiniPlayerController>();

  /// Whether the mini-player is currently visible.
  final RxBool isVisible = false.obs;

  /// Position offset from bottom-right corner (dx = right inset, dy = bottom inset).
  final Rx<Offset> position = const Offset(16, 16).obs;

  /// Current size of the mini-player. Initialized on first show.
  final Rx<Size> size = Size.zero.obs;

  StreamSubscription<String>? _routeSub;

  @override
  void onInit() {
    super.onInit();
    _routeSub = Get.routing.current.listen(_onRouteChanged);
  }

  @override
  void onClose() {
    _routeSub?.cancel();
    _routeSub = null;
    super.onClose();
  }

  void _onRouteChanged(String routeName) {
    if (_isVideoPage(routeName)) {
      if (isVisible.value) {
        hide();
      }
    } else {
      _checkAutoShow();
    }
  }

  bool _isVideoPage(String routeName) {
    return routeName == '/videoV' || routeName == '/liveRoom';
  }

  void _checkAutoShow() {
    if (isVisible.value) return;
    if (!PlPlayerController.instanceExists()) return;
    final ctr = PlPlayerController.instance;
    if (ctr == null) return;
    if (ctr.playerStatus.isPlaying || ctr.playerStatus.isPaused) {
      show();
    }
  }

  /// Show the mini-player overlay.
  void show() {
    final ctr = PlPlayerController.instance;
    if (ctr != null && ctr.isDesktopPip) return;
    isVisible.value = true;
  }

  /// Hide the mini-player overlay without stopping playback.
  void hide() {
    isVisible.value = false;
  }

  /// Close the mini-player and dispose the player.
  void close() {
    hide();
    PlPlayerController.instance?.dispose();
  }

  /// Update the drag position.
  void updatePosition(Offset pos) {
    position.value = pos;
  }

  /// Update the mini-player size.
  void updateSize(Size newSize) {
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
    final double minW = 120.0;
    final double maxW = screenSize.width * 0.5;
    final double minH = minW * 9 / 16;
    final double maxH = maxW * 9 / 16;
    final double w = newSize.width.clamp(minW, maxW);
    final double h = newSize.height.clamp(minH, maxH);
    return Size(w, h);
  }
}
