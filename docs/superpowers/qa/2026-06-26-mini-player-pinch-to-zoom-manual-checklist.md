# Mini-Player Pinch-to-Zoom Manual Verification Checklist

Use a debug APK from the PR artifacts to verify the following on a real device or emulator.

## Basic visibility

- [ ] The bottom-right `fit_screen_rounded` resize icon is no longer visible on the mini-player.
- [ ] The mini-player still shows the video, play/pause, progress bar, and close button.

## Tap-to-expand

- [ ] Tapping the video area of the mini-player opens the original video page.
- [ ] Tapping the bottom control bar background does **not** expand the mini-player.
- [ ] Tapping the play/pause button toggles playback.
- [ ] Tapping the close button hides the mini-player and stops playback.

## Drag

- [ ] Single-finger drag moves the mini-player and keeps it inside the screen.
- [ ] A tiny finger wiggle on the video area is treated as a tap, not a drag.
- [ ] Dragging from the control bar does **not** move the mini-player.

## Pinch-to-zoom

- [ ] Two-finger pinch on the video area scales the mini-player up.
- [ ] Two-finger pinch scales the mini-player down.
- [ ] The mini-player keeps its original aspect ratio during pinch.
- [ ] The mini-player stops shrinking at the minimum width (~120 logical pixels).
- [ ] The mini-player stops growing at the maximum width (~85% of screen width).
- [ ] Pinching near the right/bottom edges repositions the mini-player so it stays fully on screen.
- [ ] Pinching with one finger inside the control bar does **not** resize the mini-player.
- [ ] Lifting one finger during a pinch resumes one-finger drag from the remaining finger.

## Red-screen regression (original bug)

- [ ] Play a video, navigate to another page to show the mini-player, then tap the mini-player video area — no red screen.
- [ ] After tapping, the original video page is restored and playback continues.
- [ ] Use the in-player minimize button to show the mini-player from the home page, then tap the mini-player — it opens a fresh video page and the back button returns to the home page.

## Stress / edge cases

- [ ] Rapidly pinch, drag, and tap — no crash.
- [ ] Put a second finger down inside the control bar while dragging — no odd behavior.
- [ ] Rotate the device while the mini-player is visible — player stays on screen (size may not update, but position should clamp on next gesture).
