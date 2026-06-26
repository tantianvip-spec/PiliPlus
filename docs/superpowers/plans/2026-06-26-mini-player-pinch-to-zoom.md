> I'm using the writing-plans skill to create the implementation plan.

# Mini-Player Pinch-to-Zoom Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the mini-player's resize icon with a two-finger pinch-to-zoom gesture that keeps the 16:9 aspect ratio and existing size limits.

**Architecture:** A small pure helper computes the new size from two active pointer positions; the existing full-area `Listener` in `mini_player/view.dart` is extended to track active pointers and delegate to either drag (1 pointer) or pinch (2 pointers). The bottom-right resize handle widget is removed entirely.

**Tech Stack:** Flutter, Dart, `media_kit_video`, `get`.

---

### File map

- `lib/plugin/pl_player/mini_player/gesture_math.dart` — NEW pure helper for pinch size math.
- `test/plugin/pl_player/mini_player/gesture_math_test.dart` — NEW unit tests for the helper.
- `lib/plugin/pl_player/mini_player/view.dart` — MODIFY to replace resize icon/handle with pinch handling.

---

### Task 1: Write the failing unit test

**Files:**
- Create: `test/plugin/pl_player/mini_player/gesture_math_test.dart`

- [ ] **Step 1: Create test file**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/plugin/pl_player/mini_player/gesture_math.dart';

void main() {
  const screenSize = Size(800, 600);
  const startSize = Size(200, 112.5);

  test('no scale returns start size', () {
    final pointers = <int, Offset>{
      1: const Offset(100, 100),
      2: const Offset(200, 100),
    };
    expect(
      computePinchSize(
        pointers: pointers,
        startDistance: 100,
        startSize: startSize,
        screenSize: screenSize,
      ),
      startSize,
    );
  });

  test('pinch out increases size', () {
    final pointers = <int, Offset>{
      1: const Offset(50, 100),
      2: const Offset(250, 100),
    };
    expect(
      computePinchSize(
        pointers: pointers,
        startDistance: 100,
        startSize: startSize,
        screenSize: screenSize,
      ),
      const Size(400, 225),
    );
  });

  test('pinch in clamps to minimum width', () {
    final pointers = <int, Offset>{
      1: const Offset(190, 100),
      2: const Offset(200, 100),
    };
    expect(
      computePinchSize(
        pointers: pointers,
        startDistance: 100,
        startSize: startSize,
        screenSize: screenSize,
      ),
      const Size(120, 67.5),
    );
  });

  test('pinch out clamps to maximum width', () {
    final pointers = <int, Offset>{
      1: const Offset(0, 100),
      2: const Offset(800, 100),
    };
    expect(
      computePinchSize(
        pointers: pointers,
        startDistance: 100,
        startSize: startSize,
        screenSize: screenSize,
      ),
      const Size(680, 382.5),
    );
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

Run:
```bash
flutter test test/plugin/pl_player/mini_player/gesture_math_test.dart
```

Expected: FAIL with import/target not found errors (`computePinchSize` does not exist).

---

### Task 2: Implement the pinch-size helper

**Files:**
- Create: `lib/plugin/pl_player/mini_player/gesture_math.dart`

- [ ] **Step 1: Create helper file**

```dart
import 'package:flutter/material.dart';

/// Compute the new mini-player size from a two-finger pinch gesture.
///
/// [pointers] must contain exactly two active pointers. [startDistance] is
/// the distance between those two pointers when pinch started. [startSize]
/// is the mini-player size at that moment. [screenSize] is used to clamp
/// the width to `[120, screenWidth * 0.85]`.
Size computePinchSize({
  required Map<int, Offset> pointers,
  required double startDistance,
  required Size startSize,
  required Size screenSize,
}) {
  assert(pointers.length == 2, 'pinch requires exactly two pointers');
  assert(startDistance > 0, 'startDistance must be positive');

  final positions = pointers.values.toList(growable: false);
  final currentDistance = (positions[0] - positions[1]).distance;
  if (currentDistance <= 0 || startSize.width <= 0 || startSize.height <= 0) {
    return startSize;
  }

  final ratio = currentDistance / startDistance;
  const double minWidth = 120.0;
  final double maxWidth = screenSize.width * 0.85;
  final newWidth = (startSize.width * ratio).clamp(minWidth, maxWidth);
  final aspect = startSize.width / startSize.height;
  return Size(newWidth, newWidth / aspect);
}
```

- [ ] **Step 2: Run tests to confirm they pass**

Run:
```bash
flutter test test/plugin/pl_player/mini_player/gesture_math_test.dart
```

Expected: 4 tests PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/plugin/pl_player/mini_player/gesture_math.dart \
        test/plugin/pl_player/mini_player/gesture_math_test.dart
git commit -m "feat: add pinch-size helper and unit tests for mini-player"
```

---

### Task 3: Integrate pinch into the mini-player view

**Files:**
- Modify: `lib/plugin/pl_player/mini_player/view.dart`

- [ ] **Step 1: Import the helper**

Add near the top of the file:

```dart
import 'package:PiliPlus/plugin/pl_player/mini_player/gesture_math.dart';
```

- [ ] **Step 2: Replace resize state fields**

Find:
```dart
  Offset? _resizePointerStart;
  Size? _resizeStartSize;
```

Replace with:
```dart
  final Map<int, Offset> _activePointers = {};
  double? _pinchStartDistance;
  Size? _pinchStartSize;
```

Keep the existing drag fields unchanged:
```dart
  Offset? _dragPointerStart;
  Offset? _dragStartPos;
```

- [ ] **Step 3: Replace the drag `Listener` callbacks with drag+pinch callbacks**

Find the full-area `Listener` (currently used only for drag). It starts around:
```dart
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
```

Replace it with:

```dart
              // Drag + pinch listener — raw pointer events, no gesture arena conflict
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (event) {
                    _activePointers[event.pointer] = event.position;
                    final ctrl = widget.ctrl;

                    if (_activePointers.length == 1) {
                      _dragStartPos = ctrl.position.value;
                      _dragPointerStart = event.position;
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
                    } else if (_activePointers.length == 1 &&
                        _dragStartPos != null &&
                        _dragPointerStart != null) {
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
```

- [ ] **Step 4: Add helpers**

Add these methods to `_MiniPlayerContentState` (near `_onTap`):

```dart
  /// Returns true if [globalPosition] is inside the bottom control bar.
  bool _isInControlBar(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return false;
    final local = box.globalToLocal(globalPosition);
    return local.dy > box.size.height - 40;
  }

  void _handlePointerLift() {
    _pinchStartDistance = null;
    _pinchStartSize = null;

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
```

- [ ] **Step 5: Remove the resize handle widget**

Find and delete the entire `Positioned(right: 0, bottom: 0)` block that contains `Icons.fit_screen_rounded` (the resize handle). It starts around:

```dart
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
                      if (_resizePointerStart == null ||
                          _resizeStartSize == null) {
                        return;
                      }
                      final ctrl = widget.ctrl;
                      final delta = event.position - _resizePointerStart!;
                      final newWidth = (_resizeStartSize!.width + delta.dx)
                          .clamp(120.0, widget.screenSize.width * 0.85);
                      final aspect =
                          _resizeStartSize!.width / _resizeStartSize!.height;
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
```

After deletion, the `children` list ends with the bottom control bar.

- [ ] **Step 6: Commit**

```bash
git add lib/plugin/pl_player/mini_player/view.dart
git commit -m "feat: replace mini-player resize icon with pinch-to-zoom"
```

---

### Task 4: Run verification commands

- [ ] **Step 1: Run unit tests**

```bash
flutter test test/plugin/pl_player/mini_player/gesture_math_test.dart
```

Expected: 4 tests PASS.

- [ ] **Step 2: Run static analysis on changed files**

```bash
flutter analyze lib/plugin/pl_player/mini_player/view.dart \
                 lib/plugin/pl_player/mini_player/gesture_math.dart
```

Expected: no errors or warnings.

- [ ] **Step 3: Commit (if any formatting changes)**

If `flutter analyze` or `dart format` produced changes, commit them:

```bash
git add -A
git commit -m "style: format pinch-to-zoom changes"
```

---

### Task 5: Manual verification checklist

Run the app on a device or emulator and verify:

- [ ] Single-finger drag still moves the mini-player.
- [ ] Two-finger pinch on the video area scales the mini-player up and down.
- [ ] Aspect ratio stays 16:9 during pinch.
- [ ] Mini-player width stops at `120` minimum and `screenWidth * 0.85` maximum.
- [ ] Tapping the video area still opens the original video page.
- [ ] Control-bar play/pause/close buttons still work.
- [ ] The `fit_screen_rounded` resize icon is no longer visible.
- [ ] No crash when lifting one finger during a pinch or when pointers cancel.

---

### Task 6: Push and open/update PR

- [ ] **Step 1: Push branch**

```bash
git push origin fix/mini-player-red-screen
```

- [ ] **Step 2: Confirm PR checks**

Open https://github.com/tantianvip-spec/PiliPlus/pull/1 and confirm:

- `Run Tests` passes.
- `Mini-Player Analysis` passes.
- `Build APK` produces a downloadable artifact.

- [ ] **Step 3: Download and install test APK**

Download `PiliPlus-Test-APK` from the PR Artifacts and install on a real device to complete the manual checklist.

---

## Spec coverage check

| Spec requirement | Implementing task |
|---|---|
| Pinch on video area | Task 3, Step 3 (full-area Listener handles 2 pointers) |
| Maintain 16:9 aspect ratio | Task 2 helper preserves `startSize.width / startSize.height` |
| Size limits `120 ~ screenWidth * 0.85` | Task 2 helper clamps width |
| Remove resize icon | Task 3, Step 5 |
| Preserve drag | Task 3, Step 3 (1-pointer path unchanged) |
| Preserve tap-to-expand | Stack order unchanged; Listener is translucent |
| Preserve control bar | Control bar remains top of stack |
| Edge cases (overlap, lift, cancel) | Task 3, Step 4 `_handlePointerLift`; Task 2 helper guards |

## Placeholder scan

- No TBD/TODO placeholders.
- All code blocks contain complete, copy-pasteable code.
- All file paths are exact.
- All commands include expected output.

## Type consistency check

- `_activePointers` is `Map<int, Offset>` everywhere.
- `_pinchStartDistance` is `double?` everywhere.
- `_pinchStartSize` is `Size?` everywhere.
- `computePinchSize` signature matches import and call sites.
