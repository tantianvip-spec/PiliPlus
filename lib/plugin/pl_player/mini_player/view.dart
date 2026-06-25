import 'package:PiliPlus/common/widgets/progress_bar/audio_video_progress_bar.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/mini_player/controller.dart';
import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Floating mini-player overlay widget.
///
/// Renders a draggable, resizable video player with basic controls
/// that floats over other pages within the app.
class MiniPlayerWidget extends StatelessWidget {
  const MiniPlayerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = MiniPlayerController.instance;
    final screenSize = MediaQuery.sizeOf(context);

    return Obx(() {
      if (!ctrl.isVisible.value) return const SizedBox.shrink();

      final plCtr = PlPlayerController.instance;
      if (plCtr == null) return const SizedBox.shrink();

      // Initialize size on first show
      ctrl.initSize(screenSize);

      final offset = ctrl.position.value;
      final right = offset.dx;
      final bottom = offset.dy;
      final playerSize = ctrl.size.value;

      return Positioned(
        right: right,
        bottom: bottom,
        width: playerSize.width,
        height: playerSize.height,
        child: _MiniPlayerContent(
          screenSize: screenSize,
          ctrl: ctrl,
          plCtr: plCtr,
        ),
      );
    });
  }
}

class _MiniPlayerContent extends StatefulWidget {
  final Size screenSize;
  final MiniPlayerController ctrl;
  final PlPlayerController plCtr;

  const _MiniPlayerContent({
    required this.screenSize,
    required this.ctrl,
    required this.plCtr,
  });

  @override
  State<_MiniPlayerContent> createState() => _MiniPlayerContentState();
}

class _MiniPlayerContentState extends State<_MiniPlayerContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  // Track initial values for scale gesture
  Offset? _initialPosition;
  Size? _initialSize;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Unified gesture handler: single finger drags, two+ fingers pinch-zoom.
  void _onScaleStart(ScaleStartDetails details) {
    _initialPosition = widget.ctrl.position.value;
    _initialSize = widget.ctrl.size.value;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final ctrl = widget.ctrl;

    if (details.pointerCount >= 2) {
      // Pinch-to-zoom: resize the mini-player
      final currentSize = _initialSize ?? ctrl.size.value;
      final newSize = ctrl.clampSize(
        Size(
          currentSize.width * details.scale,
          currentSize.height * details.scale,
        ),
        widget.screenSize,
      );
      ctrl.updateSize(newSize);

      // Keep position in bounds after resize
      final pos = ctrl.position.value;
      ctrl.updatePosition(ctrl.clampPosition(pos, newSize, widget.screenSize));
    } else {
      // Single finger drag: move position
      final start = _initialPosition ?? ctrl.position.value;
      final playerSize = ctrl.size.value;
      ctrl.updatePosition(ctrl.clampPosition(
        Offset(
          start.dx - details.focalPointDelta.dx,
          start.dy - details.focalPointDelta.dy,
        ),
        playerSize,
        widget.screenSize,
      ));
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _initialPosition = null;
    _initialSize = null;
  }

  void _onTap() {
    final plCtr = widget.plCtr;
    final heroTag = _findHeroTag();
    widget.ctrl.hide();
    if (plCtr.bvid.isNotEmpty && heroTag != null) {
      Get.toNamed(
        '/videoV',
        arguments: {
          'bvid': plCtr.bvid,
          'cid': plCtr.cid,
          'heroTag': heroTag,
          'videoType': VideoType.ugc,
        },
      );
    } else {
      Get.toNamed('/videoV');
    }
  }

  String? _findHeroTag() {
    try {
      // Attempt to find a reasonable heroTag from current route arguments
      final args = Get.arguments;
      if (args is Map && args['heroTag'] != null) {
        return args['heroTag'] as String;
      }
    } catch (_) {}
    return 'mini_player_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    final plCtr = widget.plCtr;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: GestureDetector(
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video content
                if (plCtr.videoController != null)
                  SimpleVideo(
                    controller: plCtr.videoController!,
                    fill: Colors.black,
                  )
                else
                  Container(color: Colors.black),

                // Tap to expand overlay
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _onTap,
                    behavior: HitTestBehavior.translucent,
                  ),
                ),

                // Bottom control bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        // Play/Pause
                        _ControlButton(
                          icon: Obx(() {
                            final isPlaying =
                                plCtr.playerStatus.isPlaying;
                            return Icon(
                              isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 18,
                              color: Colors.white,
                            );
                          }),
                          onTap: () {
                            if (plCtr.playerStatus.isPlaying) {
                              plCtr.pause();
                            } else {
                              plCtr.play();
                            }
                          },
                        ),

                        // Progress
                        Expanded(
                          child: Obx(() {
                            final position = plCtr.positionSeconds.value;
                            final duration =
                                plCtr.duration.value.inSeconds;
                            return ProgressBar(
                              progress: Duration(seconds: position),
                              total: Duration(seconds: duration),
                              barHeight: 2.5,
                              baseBarColor: const Color(0x33FFFFFF),
                              progressBarColor: Colors.white,
                              bufferedBarColor: const Color(0x55FFFFFF),
                              thumbRadius: 0,
                              thumbColor: Colors.white,
                              thumbGlowColor: Colors.white,
                              thumbGlowRadius: 0,
                              onSeek: plCtr.seekTo,
                            );
                          }),
                        ),

                        // Close
                        _ControlButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          onTap: widget.ctrl.close,
                        ),
                      ],
                    ),
                  ),
                ),

                // Resize handle indicator at bottom-right corner
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.fit_screen_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 36,
      child: IconButton(
        onPressed: onTap,
        icon: icon,
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: Colors.white,
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
