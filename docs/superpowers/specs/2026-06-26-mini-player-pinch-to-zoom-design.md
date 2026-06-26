# Mini-Player Pinch-to-Zoom Resize

## Status

Approved design, ready for implementation plan.

## Context

The in-app mini-player (`lib/plugin/pl_player/mini_player/view.dart`) currently supports resizing via a bottom-right handle icon (`Icons.fit_screen_rounded`) and single-finger drag for moving. Users want to resize the mini-player with a two-finger pinch gesture and remove the resize icon.

## Goals

1. Support two-finger pinch-to-zoom resize on the mini-player video area.
2. Maintain the current 16:9 aspect ratio during resize.
3. Keep existing size constraints: width between `120.0` and `screenWidth * 0.85`.
4. Remove the current resize handle icon.
5. Preserve existing single-finger drag, tap-to-expand, and control-bar interactions.

## Non-Goals

- Free-form aspect ratio resize.
- Pinch on the control bar or outside the mini-player.
- Visual bounce/animation during resize; use direct manipulation.

## Design

### Affected File

- `lib/plugin/pl_player/mini_player/view.dart`

### State Changes in `_MiniPlayerContentState`

Remove:

- `_resizePointerStart`
- `_resizeStartSize`

Add:

- `final Map<int, Offset> _activePointers = {}` — tracks all active touch points.
- `double? _pinchStartDistance` — distance between the two pointers when pinch starts.
- `Size? _pinchStartSize` — mini-player size when pinch starts (used to preserve aspect ratio).

Keep existing drag state:

- `_dragPointerStart`
- `_dragStartPos`

### Gesture Handling

The existing full-area `Listener` is reused and extended to handle both drag and pinch.

#### `onPointerDown`

1. Add the pointer to `_activePointers`.
2. If exactly one pointer is active, enter drag mode:
   - Record `_dragPointerStart` and `_dragStartPos`.
3. If exactly two pointers are active, enter pinch mode:
   - Clear drag state.
   - Record `_pinchStartDistance` from the two pointer positions.
   - Record `_pinchStartSize` from the current mini-player size.

#### `onPointerMove`

1. Update the moving pointer position in `_activePointers`.
2. If pinch mode (two active pointers):
   - Compute current distance between the two pointers.
   - `ratio = currentDistance / _pinchStartDistance`
   - `newWidth = (_pinchStartSize!.width * ratio).clamp(120.0, screenWidth * 0.85)`
   - `aspect = _pinchStartSize!.width / _pinchStartSize!.height`
   - `ctrl.updateSize(Size(newWidth, newWidth / aspect))`
3. If drag mode (one active pointer), keep existing drag logic.

#### `onPointerUp` / `onPointerCancel`

1. Remove the pointer from `_activePointers`.
2. If one pointer remains, exit pinch mode and restart drag from the remaining pointer position.
3. If no pointers remain, clear all gesture state.

### Layout / Stack Order

The existing Stack order remains unchanged:

1. Video content (`SimpleVideo`)
2. Tap-to-expand `GestureDetector`
3. Drag + pinch `Listener` (`HitTestBehavior.translucent`)
4. Bottom control bar

Because the `Listener` is translucent, single-finger taps still pass through to the tap-to-expand `GestureDetector`, and control-bar buttons remain on top.

### Removed UI

Delete the `Positioned(right: 0, bottom: 0)` resize handle widget that contains `Icons.fit_screen_rounded`.

### Edge Cases

- **Two pointers overlap**: if the computed distance is zero, skip that frame.
- **Size out of bounds**: clamp width to `[120.0, screenWidth * 0.85]`.
- **Drag-to-pinch transition**: use the current size as the pinch start size to reduce visual jump.
- **Pinch-to-drag transition**: when one finger lifts, initialize drag from the remaining pointer.

## Testing Plan

Manual verification on device/simulator:

- Single-finger drag still moves the mini-player.
- Two-finger pinch scales the mini-player larger and smaller.
- Aspect ratio remains 16:9 during pinch.
- Mini-player stops at min/max width.
- Tapping the video area still opens the original video page.
- Control-bar play/pause/close buttons still work during/after pinch.
- No crash when pointers are lifted, cancelled, or overlap.

## Approaches Considered

1. **GestureDetector onScale**: simplest code, but conflicts with existing raw pointer drag and tap arena.
2. **Raw Listener with two-pointer tracking (selected)**: consistent with current drag implementation, full control, no arena conflicts.
3. **InteractiveViewer**: too heavy, brings unwanted pan behavior and couples poorly with existing drag/clamping.
