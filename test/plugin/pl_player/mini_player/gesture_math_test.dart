import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/plugin/pl_player/mini_player/gesture_math.dart';

void main() {
  const screenSize = Size(800, 600);
  const startSize = Size(200, 112.5);
  const minWidth = 120.0;
  const maxWidth = 680.0; // 0.85 * 800

  group('computePinchSize', () {
    test('no scale returns start size', () {
      const pointers = <int, Offset>{
        1: Offset(100, 100),
        2: Offset(200, 100),
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
      const pointers = <int, Offset>{
        1: Offset(50, 100),
        2: Offset(250, 100),
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
      const pointers = <int, Offset>{
        1: Offset(190, 100),
        2: Offset(200, 100),
      };
      expect(
        computePinchSize(
          pointers: pointers,
          startDistance: 100,
          startSize: startSize,
          screenSize: screenSize,
        ),
        const Size(minWidth, minWidth * 9 / 16),
      );
    });

    test('pinch out clamps to maximum width', () {
      const pointers = <int, Offset>{
        1: Offset(0, 100),
        2: Offset(800, 100),
      };
      expect(
        computePinchSize(
          pointers: pointers,
          startDistance: 100,
          startSize: startSize,
          screenSize: screenSize,
        ),
        const Size(maxWidth, maxWidth * 9 / 16),
      );
    });

    test('narrow screen clamps to minWidth without crashing', () {
      const pointers = <int, Offset>{
        1: const Offset(50, 100),
        2: const Offset(250, 100),
      };
      expect(
        computePinchSize(
          pointers: pointers,
          startDistance: 100,
          startSize: startSize,
          screenSize: const Size(100, 100),
        ),
        const Size(minWidth, minWidth * 9 / 16),
      );
    });

    test('returns start size with fewer than two pointers', () {
      const pointers = <int, Offset>{
        1: Offset(100, 100),
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

    test('returns start size when startDistance is zero', () {
      const pointers = <int, Offset>{
        1: Offset(100, 100),
        2: Offset(200, 100),
      };
      expect(
        computePinchSize(
          pointers: pointers,
          startDistance: 0,
          startSize: startSize,
          screenSize: screenSize,
        ),
        startSize,
      );
    });

    test('preserves non-16:9 aspect ratio', () {
      const startSize = Size(200, 150);
      const pointers = <int, Offset>{
        1: Offset(50, 100),
        2: Offset(250, 100),
      };
      expect(
        computePinchSize(
          pointers: pointers,
          startDistance: 100,
          startSize: startSize,
          screenSize: screenSize,
        ),
        const Size(400, 300),
      );
    });
  });
}
