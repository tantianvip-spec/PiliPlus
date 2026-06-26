import 'package:PiliPlus/common/widgets/progress_bar/audio_video_progress_bar.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/mini_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Floating mini-player overlay widget.
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

  // Drag tracking
  Offset? _dragStartPos;
  Offset? _dragPointerStart;

  // Resize tracking
  Offset? _resizePointerStart;
  Size? _resizeStartSize;

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

  void _onTap() {
    final ctrl = widget.ctrl;
    ctrl.markTapToExpand();
    ctrl.hide();
    // Wait one frame for the mini-player's SimpleVideo to be fully
    // removed from the widget tree before navigating back. Without
    // this delay, popUntil triggers didPopNext which eventually
    // re-creates PLVideoPlayer/SimpleVideo on the video page — but
    // the mini-player's SimpleVideo is still in the tree because
    // Flutter hasn't rebuilt yet. Two SimpleVideo widgets bound to
    // the same VideoController at once causes a media-kit crash.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.key.currentState?.popUntil((route) => route.settings.name == '/videoV');
    });
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

              // Tap-to-expand (GestureDetector catches taps on video area)
              // Must be BELOW controls in Stack order so buttons work
              Positioned.fill(
                child: GestureDetector(
                  onTap: _onTap,
                  behavior: HitTestBehavior.translucent,
                ),
              ),

              // Drag listener — raw pointer events, no gesture arena conflict
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (event) {
                    _dragStartPos = widget.ctrl.position.value;
                    _dragPointerStart = event.position;
                  },
                  onPointerMove: (event) {
                    if (_dragStartPos != null && _dragPointerStart != null) {
                      final ctrl = widget.ctrl;
                      final delta = event.position - _dragPointerStart!;
                      final newPos = ctrl.clampPosition(
                        Offset(
                          _dragStartPos!.dx - delta.dx,
                          _dragStartPos!.dy - delta.dy,
                        ),
                        ctrl.size.value,
                        widget.screenSize,
                      );
                      ctrl.updatePosition(newPos);
                    }
                  },
                  onPointerUp: (event) {
                    _dragStartPos = null;
                    _dragPointerStart = null;
                  },
                  onPointerCancel: (event) {
                    _dragStartPos = null;
                    _dragPointerStart = null;
                  },
                ),
              ),

              // Bottom control bar (stacked LAST so it's on TOP)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 40,
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
                      _ControlButton(
                        icon: Obx(() {
                          final isPlaying = plCtr.playerStatus.isPlaying;
                          return Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 20,
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
                      Expanded(
                        child: Obx(() {
                          final position = plCtr.positionSeconds.value;
                          final duration = plCtr.duration.value.inSeconds;
                          return ProgressBar(
                            progress: Duration(seconds: position),
                            total: Duration(seconds: duration),
                            barHeight: 3,
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
                      _ControlButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white),
                        onTap: widget.ctrl.close,
                      ),
                    ],
                  ),
                ),
              ),

              // Resize handle — positioned ABOVE the control bar
              // Uses Listener (raw pointer events) instead of GestureDetector
              // to avoid gesture arena conflict with SimpleVideo.
              Positioned(
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.only(right: 2, bottom: 42),
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (event) {
                      _resizePointerStart = event.position;
                      _resizeStartSize = widget.ctrl.size.value;
                    },
                    onPointerMove: (event) {
                      if (_resizePointerStart == null || _resizeStartSize == null) return;
                      final ctrl = widget.ctrl;
                      final delta = event.position - _resizePointerStart!;
                      final newWidth = (_resizeStartSize!.width + delta.dx)
                          .clamp(120.0, widget.screenSize.width * 0.85);
                      final aspect = _resizeStartSize!.width / _resizeStartSize!.height;
                      ctrl.updateSize(Size(newWidth, newWidth / aspect));
                    },
                    onPointerUp: (_) {
                      _resizePointerStart = null;
                      _resizeStartSize = null;
                    },
                    onPointerCancel: (_) {
                      _resizePointerStart = null;
                      _resizeStartSize = null;
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.fit_screen_rounded,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
      width: 44,
      height: 40,
      child: IconButton(
        onPressed: onTap,
        icon: icon,
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: Colors.white,
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
    );
  }
}
