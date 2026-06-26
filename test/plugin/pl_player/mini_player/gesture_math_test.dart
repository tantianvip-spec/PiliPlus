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
