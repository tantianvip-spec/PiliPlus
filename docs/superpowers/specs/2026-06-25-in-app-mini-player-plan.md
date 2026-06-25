# Implementation Plan: In-App Mini Player

> Based on design spec: `docs/superpowers/specs/2026-06-25-in-app-mini-player-design.md`

## Overview

Add an in-app floating mini-player to PiliPlus. When users navigate away from the video detail page while a video is playing, the video shrinks to a draggable floating window that persists across pages within the app.

**Key insight**: `PlPlayerController` is already a singleton — the mini-player reuses its `VideoController` rather than creating a second player instance.

## Files to Create

### 1. `lib/plugin/pl_player/mini_player/controller.dart` — MiniPlayerController

A `GetxController` managing mini-player visibility and position.

```dart
class MiniPlayerController extends GetxController {
  static MiniPlayerController get instance => Get.find();
  
  final RxBool isVisible = false.obs;
  final Rx<Offset> position = const Offset(16, 16).obs; // right, bottom
  
  void show() => isVisible.value = true;
  void hide() => isVisible.value = false;
  void updatePosition(Offset pos) => position.value = pos;
  void close() { hide(); PlPlayerController.instance?.dispose(); }
}
```

**Key behaviors:**
- Route listening: watch `Get.routing` to auto-show when leaving `/videoV`/`/liveRoom`
- Auto-hide when returning to `/videoV`/`/liveRoom`
- Safe area aware — clamp position within visible bounds

### 2. `lib/plugin/pl_player/mini_player/view.dart` — MiniPlayerWidget

A `StatelessWidget` (or `GetView<MiniPlayerController>`) rendered as a floating overlay.

**Structure:**
```
Obx(
  AnimatedSlide + FadeTransition (entry/exit)
    Positioned (from controller.position)
      GestureDetector (drag)
        ClipRRect (radius: 12)
          Stack
            SimpleVideo(controller: plPlayerController.videoController!)
            GestureDetector (tap → navigate back)
            Positioned.bottom (control bar overlay)
              Row: [PlayPause, ProgressBar, CloseButton]
```

**Dimensions:**
- Width: 35% of screen width, min 120px
- Height: auto (16:9 ratio based on video aspect)
- Default position: bottom-right, 16px inset

**Controls:**
- Play/Pause: `IconButton` calling `plPlayer.play()`/`plPlayer.pause()`
- Progress: `ProgressBar` (thin, no thumb thumb), reads from `plPlayerController`
- Close: `IconButton` → `MiniPlayerController.instance.close()`
- Tap video area: `Get.toNamed('/videoV', arguments: {...})` or `Get.back()` to return

## Files to Modify

### 3. `lib/pages/main/view.dart` — Integrate mini-player into MainApp

In `_MainAppState`:
- `initState()`: `Get.put(MiniPlayerController())`
- `build()`: Wrap existing child in `Stack`, overlay `MiniPlayerWidget`

```dart
// Before return, wrap:
child = Stack(
  children: [
    child, // original Scaffold
    Obx(() => Get.find<MiniPlayerController>().isVisible.value
        ? const MiniPlayerWidget()
        : const SizedBox.shrink()),
  ],
);
```

### 4. `lib/pages/video/view.dart` — Trigger mini-player on leave

In `_VideoDetailPageVState.didPushNext()`:
```dart
final plCtr = videoDetailController.plPlayerController;
if (plCtr.playerStatus.isPlaying) {
  MiniPlayerController.instance.show();
}
```

### 5. `lib/plugin/pl_player/view/view.dart` — Add minimize button

In the bottom control bar, add a new `BottomControlType.minimize` entry (or add the button directly):

- Add `Icons.picture_in_picture_alt` button to `userSpecifyItemRight`
- On tap: `MiniPlayerController.instance.show(); Get.back();`

Alternatively, add the button to `HeaderControl` if it fits better in the top bar.

## Build Sequence

| Step | File | Description |
|------|------|-------------|
| 1 | `mini_player/controller.dart` | Create MiniPlayerController with route listening |
| 2 | `mini_player/view.dart` | Create MiniPlayerWidget with controls and drag |
| 3 | `main/view.dart` | Register controller, overlay widget in Stack |
| 4 | `video/view.dart` | Auto-trigger on route leave |
| 5 | `pl_player/view/view.dart` | Add minimize button to controls |
| 6 | Test | Verify on mobile, verify edge cases |

## Edge Cases & Risks

- **Route listener registration**: Must register in `MiniPlayerController.onInit()` and cancel in `onClose()`
- **Player already disposed**: Check `PlPlayerController.instanceExists()` before accessing
- **Quick back-and-forth**: Use `EasyThrottle` or debounce to prevent flicker
- **Desktop PiP conflict**: Mini-player should not show when desktop PiP is active (`plCtr.isDesktopPip`)
- **System PiP on Android**: Mini-player should not overlap with system PiP mode
- **Position out of bounds**: Clamp drag position to screen insets using `MediaQuery.viewInsetsOf(context)`
