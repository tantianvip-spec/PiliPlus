import 'package:PiliPlus/common/widgets/progress_bar/audio_video_progress_bar.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/mini_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/mini_player/gesture_math.dart';
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
  static const double _controlBarHeight = 40.0;

  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  // Drag tracking
  Offset? _dragStartPos;
  Offset? _dragPointerStart;
  bool _dragCommitted = false;

  // Pinch tracking
  final Map<int, Offset> _activePointers = {};
  double? _pinchStartDistance;
  Size? _pinchStartSize;

  @override
  void initState() {
    super.initState();
    widget.ctrl.initSize(widget.screenSize);
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

  /// Returns true if [globalPosition] is inside the bottom control bar.
  bool _isInControlBar(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return false;
    final local = box.globalToLocal(globalPosition);
    return local.dy > box.size.height - _controlBarHeight;
  }

  void _handlePointerLift() {
    _pinchStartDistance = null;
    _pinchStartSize = null;
    _dragCommitted = false;

    if (_activePointers.length == 1) {
      // Continue dragging with the remaining finger from its current position.
      final remaining = _activePointers.entries.first;
      _dragPointerStart = remaining.value;
      _dragStartPos = widget.ctrl.position.value;
    } else {
      _dragPointerStart = null;
      _dragStartPos = null;
    }
  }

  void _onTap() {
    final ctrl = widget.ctrl;
    final plCtr = widget.plCtr;
    debugPrint(
        '[MiniPlayer] _onTap start, bvid=${plCtr.bvid}, cid=${plCtr.cid}, isVisible=${ctrl.isVisible.value}');
    // Read bvid/cid BEFORE any dispose clears them.
    final bvid = plCtr.bvid;
    // cid is int? — provide a fallback so RxInt(args['cid']) doesn't crash
    final cid = plCtr.cid ?? 0;
    if (bvid == null || bvid.isEmpty || cid == 0) {
      debugPrint('[MiniPlayer] _onTap: invalid bvid/cid, hiding instead');
      ctrl.hide();
      return;
    }
    final aid = plCtr.aid;
    final videoType = plCtr.videoType;
    final epid = plCtr.epid;
    final seasonId = plCtr.seasonId;
    final pgcType = plCtr.pgcType;
    debugPrint(
        '[MiniPlayer] _onTap captured args: bvid=$bvid, cid=$cid, aid=$aid, videoType=$videoType, epid=$epid, seasonId=$seasonId, pgcType=$pgcType');
    // Notify the video page that it is being restored from the mini-player,
    // so didPopNext() skips playerInit() and just re-enables the video surface.
    // Hide mini-player — this removes its SimpleVideo from the widget tree at
    // the end of the current frame.
    ctrl
      ..markReturningFromMiniPlayer()
      ..hide();
    // Wait 1 frame (plus a small safety margin) for the mini-player's
    // SimpleVideo to be fully released, then either pop back to the existing
    // video page or open a fresh one if the video page is no longer in stack.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 50), () {
        debugPrint('[MiniPlayer] delayed callback firing');
        var foundVideoRoute = false;
        try {
          final nav = Get.key.currentState;
          if (nav != null) {
            nav.popUntil((route) {
              if (route.settings.name == '/videoV') {
                foundVideoRoute = true;
                return true;
              }
              // Stop at the root route so we never pop the whole stack away.
              if (route.isFirst) {
                return true;
              }
              return false;
            });
          }
        } catch (e, s) {
          debugPrint('[MiniPlayer] ERROR in popUntil: $e\n$s');
        }

        if (foundVideoRoute) {
          debugPrint('[MiniPlayer] popped back to existing /videoV route');
          return;
        }

        // No existing video page in the stack (e.g. the user minimized the
        // player with the in-page minimize button). Dispose the player safely
        // — no other SimpleVideo is bound to it — and open a fresh video page.
        ctrl.clearReturningFromMiniPlayer();
        debugPrint(
            '[MiniPlayer] no existing /videoV route; disposing player and opening fresh page');
        try {
          debugPrint('[MiniPlayer] calling plCtr.dispose()');
          plCtr.dispose();
          debugPrint('[MiniPlayer] plCtr.dispose() returned');
        } catch (e, s) {
          debugPrint('[MiniPlayer] ERROR in plCtr.dispose(): $e\n$s');
        }
        try {
          debugPrint('[MiniPlayer] calling Get.toNamed to /videoV');
          Get.toNamed(
            '/videoV',
            arguments: {
              'bvid': bvid,
              'cid': cid,
              if (aid != null) 'aid': aid,
              'heroTag': 'mini_player_${DateTime.now().millisecondsSinceEpoch}',
              'videoType': videoType,
              if (epid != null) 'epId': epid,
              if (seasonId != null) 'seasonId': seasonId,
              if (pgcType != null) 'pgcType': pgcType,
            },
          );
          debugPrint('[MiniPlayer] Get.toNamed returned');
        } catch (e, s) {
          debugPrint('[MiniPlayer] ERROR in Get.toNamed: $e\n$s');
        }
      });
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
              // Block pointer events from reaching the page behind the mini-player.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox.expand(),
                ),
              ),

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

              // Drag + pinch listener — raw pointer events, no gesture arena conflict
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (event) {
                    if (_activePointers.length >= 2) return;
                    if (_activePointers.length == 1) {
                      // Potential second pointer — ignore it if it starts in the control bar.
                      if (_isInControlBar(event.position)) {
                        return;
                      }
                    }
                    _activePointers[event.pointer] = event.position;
                    final ctrl = widget.ctrl;

                    if (_activePointers.length == 1) {
                      _dragStartPos = ctrl.position.value;
                      _dragPointerStart = event.position;
                      _dragCommitted = false;
                    } else if (_activePointers.length == 2) {
                      // Second finger: switch from drag to pinch only if both
                      // fingers are outside the bottom control bar.
                      final positions = _activePointers.values.toList();
                      if (_isInControlBar(positions[0]) ||
                          _isInControlBar(positions[1])) {
                        return;
                      }
                      _dragStartPos = null;
                      _dragPointerStart = null;
                      _dragCommitted = false;
                      _pinchStartDistance =
                          (positions[0] - positions[1]).distance;
                      _pinchStartSize = ctrl.size.value;
                    }
                  },
                  onPointerMove: (event) {
                    if (!_activePointers.containsKey(event.pointer)) {
                      return;
                    }
                    _activePointers[event.pointer] = event.position;
                    final ctrl = widget.ctrl;

                    if (_activePointers.length == 2 &&
                        _pinchStartDistance != null &&
                        _pinchStartSize != null) {
                      final newSize = computePinchSize(
                        pointers: _activePointers,
                        startDistance: _pinchStartDistance!,
                        startSize: _pinchStartSize!,
                        screenSize: widget.screenSize,
                      );
                      ctrl.updateSize(newSize);
                      ctrl.updatePosition(
                        ctrl.clampPosition(
                          ctrl.position.value,
                          newSize,
                          widget.screenSize,
                        ),
                      );
                    } else if (_activePointers.length == 1 &&
                        _dragStartPos != null &&
                        _dragPointerStart != null) {
                      if (!_dragCommitted) {
                        final distance =
                            (event.position - _dragPointerStart!).distance;
                        if (distance < kTouchSlop) {
                          return;
                        }
                        _dragCommitted = true;
                      }
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
                    _activePointers.remove(event.pointer);
                    _handlePointerLift();
                  },
                  onPointerCancel: (event) {
                    _activePointers.remove(event.pointer);
                    _handlePointerLift();
                  },
                ),
              ),

              // Bottom control bar (stacked LAST so it's on TOP)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: _controlBarHeight,
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
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
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
                        icon: const Icon(Icons.close_rounded,
                            size: 20, color: Colors.white),
                        onTap: widget.ctrl.close,
                      ),
                    ],
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
