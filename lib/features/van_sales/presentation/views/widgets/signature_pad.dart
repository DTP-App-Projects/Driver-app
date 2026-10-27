import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Holds the strokes of a [SignaturePad] and turns them into a PNG file for
/// `POST /driver/uploads`.
class SignatureController extends ChangeNotifier {
  final List<List<Offset>> _strokes = [];
  Size _size = Size.zero;

  List<List<Offset>> get strokes => _strokes;

  bool get isEmpty => _strokes.every((stroke) => stroke.length < 2);

  void _start(Offset point) {
    _strokes.add([point]);
    notifyListeners();
  }

  void _extend(Offset point) {
    if (_strokes.isEmpty) return;
    _strokes.last.add(point);
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    notifyListeners();
  }

  /// White background, black ink, written to a temporary PNG. Null when
  /// nothing was signed.
  Future<File?> toPngFile() async {
    if (isEmpty || _size.isEmpty) return null;
    const scale = 2.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    canvas.drawRect(Offset.zero & _size, Paint()..color = Colors.white);
    _SignaturePainter.paintStrokes(canvas, _strokes);

    final image = await recorder.endRecording().toImage((_size.width * scale).ceil(), (_size.height * scale).ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return null;

    final file = File("${Directory.systemTemp.path}/van_signature_${DateTime.now().millisecondsSinceEpoch}.png");
    await file.writeAsBytes(bytes.buffer.asUint8List());
    return file;
  }
}

/// Finger signature box.
class SignaturePad extends StatelessWidget {
  const SignaturePad({super.key, required this.controller, required this.height});

  final SignatureController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        controller._size = Size(constraints.maxWidth, height);
        // Raw pointer events draw; the empty drag handlers win the gesture
        // arena so the surrounding list does not scroll while signing.
        return Listener(
          onPointerDown: (event) => controller._start(event.localPosition),
          onPointerMove: (event) => controller._extend(event.localPosition),
          child: GestureDetector(
            onVerticalDragStart: (_) {},
            onHorizontalDragStart: (_) {},
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: height,
                width: constraints.maxWidth,
                color: const Color(0xffFBFBFC),
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) => CustomPaint(painter: _SignaturePainter(controller.strokes)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes);

  final List<List<Offset>> strokes;

  static void paintStrokes(Canvas canvas, List<List<Offset>> strokes) {
    final paint = Paint()
      ..color = const Color(0xff101828)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) => paintStrokes(canvas, strokes);

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
