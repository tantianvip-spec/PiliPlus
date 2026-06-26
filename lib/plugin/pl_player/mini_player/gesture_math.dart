import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Compute the new mini-player size from a two-finger pinch gesture.
///
/// [pointers] must contain exactly two active pointers. [startDistance] is
/// the distance between those two pointers when pinch started. [startSize]
/// is the mini-player size at that moment. [screenSize] is used to clamp
/// the width to `[120, screenWidth * 0.85]`.
///
/// Returns [startSize] when the input is invalid (not exactly two pointers,
/// zero or negative [startDistance], zero current pointer distance, a
/// zero-area [startSize], or any non-finite numeric value).
Size computePinchSize({
  required Map<int, Offset> pointers,
  required double startDistance,
  required Size startSize,
  required Size screenSize,
}) {
  if (pointers.length != 2 || startDistance <= 0) {
    return startSize;
  }

  final positions = pointers.values.toList(growable: false);
  final currentDistance = (positions[0] - positions[1]).distance;
  if (currentDistance <= 0 || startSize.width <= 0 || startSize.height <= 0) {
    return startSize;
  }
  if (!startDistance.isFinite ||
      !currentDistance.isFinite ||
      !screenSize.width.isFinite ||
      !screenSize.height.isFinite ||
      !startSize.width.isFinite ||
      !startSize.height.isFinite) {
    return startSize;
  }

  final ratio = currentDistance / startDistance;
  const double minWidth = 120.0;
  const double maxWidthFactor = 0.85;
  final double maxWidth = math.max(minWidth, screenSize.width * maxWidthFactor);
  final newWidth = (startSize.width * ratio).clamp(minWidth, maxWidth);
  final aspect = startSize.width / startSize.height;
  return Size(newWidth, newWidth / aspect);
}
