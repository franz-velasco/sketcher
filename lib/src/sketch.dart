import 'package:flutter/material.dart';
import 'package:sketch/src/painter.dart';
import 'package:sketch/src/sketch_controller.dart';

class Sketch extends StatefulWidget {
  const Sketch({
    required this.controller,
    super.key,
  });

  final SketchController controller;

  @override
  State<Sketch> createState() => _SketchState();
}

class _SketchState extends State<Sketch> {
  //late TransformationController _transformationController;

  /// [panPosition] used to display the position [MagnifierDecoration]
  Offset? panPosition;

  @override
  void initState() {
    super.initState();
    //_transformationController = TransformationController();
  }

  @override
  void dispose() {
    //_transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final magnifierPosition = panPosition;
    return GestureDetector(
      excludeFromSemantics: true,
      behavior: HitTestBehavior.translucent,
      onPanDown: (DragDownDetails details) {
        setState(() => panPosition = details.localPosition);
        widget.controller.onPanDown(details);
      },
      onPanStart: (DragStartDetails details) {
        setState(() => panPosition = details.localPosition);
        widget.controller.onPanStart(details);
      },
      onPanUpdate: (DragUpdateDetails details) {
        setState(() => panPosition = details.localPosition);
        widget.controller.onPanUpdate(details);
      },
      onPanEnd: (DragEndDetails details) {
        setState(() => panPosition = null);
        widget.controller.onPanEnd(details);
      },
      onPanCancel: () {
        setState(() => panPosition = null);
        widget.controller.onPanCancel();
      },
      child: Stack(
        children: [
          CustomPaint(
            willChange: true,
            isComplex: true,
            painter: SketchPainter(
              widget.controller.elements,
            ),
            foregroundPainter: ActivePainter(
              widget.controller.activeElement,
            ),
            child: Placeholder(),
          ),
          if (magnifierPosition != null)
            Positioned(
              left: magnifierPosition.dx,
              top: magnifierPosition.dy,
              child: const RawMagnifier(
                decoration: MagnifierDecoration(
                  shape: CircleBorder(
                    side: BorderSide(color: Color(0xffffcc00), width: 3),
                  ),
                ),
                size: Size(64, 64),
                magnificationScale: 2,
              ),
            )
        ],
      ),
    );
  }
}
