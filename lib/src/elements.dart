// ignore_for_file: avoid_non_null_assertion
import 'dart:math';
import 'dart:ui' as ui;

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:sketch/src/dashed_path_painter.dart';
import 'package:sketch/src/element_modifiers.dart';
import 'package:sketch/src/extensions.dart';

const double toleranceRadius = 20.0;
const double toleranceRadiusPOI = 40.0;

sealed class SketchElement with Drawable, Hitable {}

class LineEle extends SketchElement {
  LineEle(
    this.start,
    this.end,
    this.color,
    this.lineType,
    this.strokeWidth, {
    this.description,
  });

  /// The Line to be drawn
  final Point<double> start;

  ///
  final Point<double> end;

  /// [LineEle] modifiers
  ui.Color color;

  ///
  LineType lineType;

  ///
  double strokeWidth;

  /// optional description
  final String? description;

  /// Defines and returns the paint for full lines
  Paint _getLineTypeFullPaint(Color? activeColor) {
    return ui.Paint()
      ..color = activeColor ?? color
      ..strokeWidth = strokeWidth
      ..strokeCap = ui.StrokeCap.round
      ..style = ui.PaintingStyle.stroke;
  }

  /// Draws circles around the start and end points of the line
  void _drawActiveElementEnds({required ui.Canvas canvas, required Color color}) {
    const double activeElementEndRadius = 15.0;
    final activeElementEndPaint = Paint()..color = color.withOpacity(0.5);
    canvas.drawCircle(
      ui.Offset(start.x, start.y),
      activeElementEndRadius,
      activeElementEndPaint,
    );
    canvas.drawCircle(
      ui.Offset(end.x, end.y),
      activeElementEndRadius,
      activeElementEndPaint,
    );
  }

  /// Draws an arrow (full line and arrowhead) at the given point [arrowAt]
  void _drawArrow(
    Point<double> arrowAt, {
    required ui.Canvas canvas,
    Color? activeColor,
  }) {
    final ui.Paint paint = _getLineTypeFullPaint(activeColor);

    // direction of arrowhead
    final dX = arrowAt == end ? end.x - start.x : start.x - end.x;
    final dY = arrowAt == end ? end.y - start.y : start.y - end.y;
    final angle = atan2(dY, dX);

    // dimensions of arrowhead
    final arrowSize = 15;
    final arrowAngle = 25 * pi / 180;

    final path = Path();
    path.moveTo(arrowAt.x - arrowSize * cos(angle - arrowAngle), arrowAt.y - arrowSize * sin(angle - arrowAngle));
    path.lineTo(arrowAt.x, arrowAt.y);
    path.lineTo(arrowAt.x - arrowSize * cos(angle + arrowAngle), arrowAt.y - arrowSize * sin(angle + arrowAngle));
    path.close();
    // draw arrow
    canvas.drawPath(path, paint);
    // draw full line
    _drawFullLine(canvas: canvas, activeColor: activeColor);
  }

  /// Draws a full line
  void _drawFullLine({required ui.Canvas canvas, Color? activeColor}) {
    final ui.Paint paint = _getLineTypeFullPaint(activeColor);
    canvas.drawLine(
      ui.Offset(start.x, start.y),
      ui.Offset(end.x, end.y),
      paint,
    );
  }

  @override
  void draw(ui.Canvas canvas, ui.Size size, [Color? activeColor]) {
    switch (lineType) {
      case LineType.dashed:
      case LineType.dotted:
        final path = ui.Path()..moveTo(start.x, start.y);
        path.lineTo(end.x, end.y);
        DashedPathPainter(
          originalPath: path,
          pathColor: activeColor ?? color,
          strokeWidth: strokeWidth,
          dashGapLength: strokeWidth * lineType.dashGapLengthFactor,
          dashLength: strokeWidth * lineType.dashLengthFactor,
        ).paint(canvas, size);
        break;
      case LineType.full:
        _drawFullLine(canvas: canvas, activeColor: activeColor);
      case LineType.arrowBetween:
        _drawArrow(end, canvas: canvas, activeColor: activeColor);
        _drawArrow(start, canvas: canvas, activeColor: activeColor);
        break;
      case LineType.arrowEnd:
        _drawArrow(end, canvas: canvas, activeColor: activeColor);
        break;
      case LineType.arrowStart:
        _drawArrow(start, canvas: canvas, activeColor: activeColor);
        break;
    }
    if (activeColor != null) {
      _drawActiveElementEnds(canvas: canvas, color: activeColor);
    }
  }

  /// TODO: needs documentation & improvement/simplification
  LineHitType? _hitTest(Offset position) {
    final s = Point(start.x, start.y);
    final e = Point(end.x, end.y);
    final p = Point(position.dx, position.dy);
    final double a = s.distanceTo(p);
    final b = e.distanceTo(p);
    final c = s.distanceTo(e);

    if (a < toleranceRadiusPOI || pow(b, 2) > pow(a, 2) + pow(c, 2)) {
      return a < toleranceRadiusPOI ? LineHitType.start : null;
    } else if (b < toleranceRadiusPOI || pow(a, 2) > pow(b, 2) + pow(c, 2)) {
      return b < toleranceRadiusPOI ? LineHitType.end : null;
    } else {
      final t = (a + b + c) / 2;
      final h = 2 / c * sqrt(t * (t - a) * (t - b) * (t - c));
      return h < toleranceRadius ? LineHitType.line : null;
    }
  }

  @override
  HitPointLine? getHit(ui.Offset offset) {
    LineHitType? lineHitType = _hitTest(offset);
    return lineHitType != null ? HitPointLine(this, offset, lineHitType) : null;
  }

  @override
  SketchElement create(ui.Offset updateOffset) {
    // TODO: implement create
    throw UnimplementedError();
  }

  @override
  SketchElement update(ui.Offset updateOffset, HitPoint hitPoint) {
    // todo: improve Hitable mixin to prevent type checking
    if (hitPoint is! HitPointLine) return this;
    switch (hitPoint.hitType) {
      case LineHitType.start:
        // set start of line to point of mouse/finger
        final Point<double> newStart = Point(updateOffset.dx, updateOffset.dy);
        return LineEle(newStart, end, color, lineType, strokeWidth);
      case LineHitType.end:
        // set end of line to point of mouse/finger
        final Point<double> newEnd = Point(updateOffset.dx, updateOffset.dy);
        return LineEle(start, newEnd, color, lineType, strokeWidth);
      case LineHitType.line:
        // vector between drag start and end
        final differenceVector = updateOffset - hitPoint.hitOffset;

        // using the original start and end position
        final LineEle originalElement = hitPoint.element as LineEle;
        final originalStart = originalElement.start;
        final originalEnd = originalElement.end;

        // creating the new element
        final Point<double> newStart = originalStart + Point(differenceVector.dx, differenceVector.dy);
        final Point<double> newEnd = originalEnd + Point(differenceVector.dx, differenceVector.dy);
        return LineEle(newStart, newEnd, color, lineType, strokeWidth);
    }
  }
}

class PathEle extends SketchElement {
  PathEle(
    this.points,
    this.color,
    this.lineType,
    this.strokeWidth,
  );

  /// The [points] of the Path to be drawn.
  final IList<Point<double>> points;

  /// The [color] of the text.
  final ui.Color color;

  ///
  final LineType lineType;

  ///
  final double strokeWidth;

  @override
  void draw(ui.Canvas canvas, ui.Size size, [Color? activeColor]) {
    final path = ui.Path()..moveTo(points[0].x, points[0].y);

    points
      ..removeAt(0)
      ..forEach((p) {
        path.lineTo(p.x, p.y);
      });

    final currentColor = activeColor ?? color;

    switch (lineType) {
      case LineType.dashed:
      case LineType.dotted:
        DashedPathPainter(
          originalPath: path,
          pathColor: currentColor,
          strokeWidth: strokeWidth,
          dashGapLength: strokeWidth * lineType.dashGapLengthFactor,
          dashLength: strokeWidth * lineType.dashLengthFactor,
        ).paint(canvas, size);
      case _:
        final ui.Paint paint = ui.Paint()
          ..color = currentColor
          ..strokeWidth = strokeWidth
          ..strokeCap = ui.StrokeCap.round
          ..style = ui.PaintingStyle.stroke;
        canvas.drawPath(path, paint);
    }
  }

  /// Returns true if offset/position is near any of the Path's points
  @override
  HitPoint? getHit(ui.Offset offset) {
    final currentPosition = Point<double>(offset.dx, offset.dy);
    List<Point<double>> initialPoints = List.from(points);
    bool gotHit = false;

    for (final currentCheckingPoint in initialPoints) {
      if (currentCheckingPoint.distanceTo(currentPosition) < toleranceRadiusPOI) {
        gotHit = true;
        break;
      }
    }

    return gotHit ? HitPointPath(this, offset) : null;
  }

  @override
  SketchElement create(ui.Offset updateOffset) {
    // TODO: implement create
    throw UnimplementedError();
  }

  @override
  SketchElement update(ui.Offset updateOffset, HitPoint hitPoint) {
    final differenceVector = updateOffset - hitPoint.hitOffset;
    final originalElement = hitPoint.element as PathEle;
    final originalPoints = originalElement.points;
    final movementPoint = Point(differenceVector.dx, differenceVector.dy);
    final updatedPoints = originalPoints.map((element) => element + movementPoint).toIList();

    return PathEle(updatedPoints, color, lineType, strokeWidth);
  }
}

class TextEle extends SketchElement {
  TextEle(
    this.text,
    this.color,
    this.point,
  ) : textPainter = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(color: Colors.white),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );

  /// The [text] to be drawn.
  final String text;

  /// The [color] of the text.
  final ui.Color color;

  /// The [point] where the text should be drawn.
  final Point<double> point;

  /// A [textPainter] that will paint the text on the canvas.
  final TextPainter textPainter;

  @override
  void draw(ui.Canvas canvas, ui.Size size, [Color? activeColor]) {
    final position = Offset(point.x, point.y);
    textPainter.layout(maxWidth: size.width);

    // background of text element
    final backgroundPaint = ui.Paint()..color = activeColor ?? Colors.black;
    canvas.drawRRect(
      RRect.fromRectXY(
        Rect.fromCenter(
          center: position,
          width: textPainter.width + 16,
          height: textPainter.height + 16,
        ),
        10,
        10,
      ),
      backgroundPaint,
    );

    // the actual text
    textPainter.paint(
      canvas,
      position - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  HitPoint? getHit(ui.Offset offset) {
    return offset.dx >= point.x - textPainter.width / 2 &&
            offset.dx <= point.x + textPainter.width / 2 &&
            offset.dy >= point.y - textPainter.height / 2 &&
            offset.dy <= point.y + textPainter.height / 2
        ? HitPointText(this, offset)
        : null;
  }

  @override
  SketchElement create(ui.Offset updateOffset) {
    // TODO: implement create
    throw UnimplementedError();
  }

  @override
  SketchElement update(ui.Offset updateOffset, HitPoint hitPoint) {
    return TextEle(
      text,
      color,
      Point(updateOffset.dx, updateOffset.dy),
    );
  }
}

class PolyEle extends SketchElement {
  PolyEle(
    this.points,
    this.color,
    this.lineType,
    this.strokeWidth, {
    this.closed = false,
    this.activePointIndex,
    this.descriptions,
  });

  final IList<Point<double>> points;

  /// If start point is same as endpoint (that doesn't get added again to the points list)
  final bool closed;

  /// [LineEle] modifiers
  final ui.Color color;

  ///
  final LineType lineType;

  ///
  final double strokeWidth;

  /// optional description
  final IList<String?>? descriptions;

  /// Contains the index of the point being updated
  int? activePointIndex;

  @override
  SketchElement create(ui.Offset updateOffset) {
    // TODO: implement create
    throw UnimplementedError();
  }

  @override
  void draw(ui.Canvas canvas, ui.Size size, [ui.Color? activeColor]) {
    final path = ui.Path()..moveTo(points[0].x, points[0].y);

    points
      ..removeAt(0)
      ..forEach((p) => path.lineTo(p.x, p.y));

    final currentColor = activeColor ?? color;

    // Close the path if poly is closed
    if (closed) path.close();

    switch (lineType) {
      case LineType.dashed:
      case LineType.dotted:
        DashedPathPainter(
          originalPath: path,
          pathColor: currentColor,
          strokeWidth: strokeWidth,
          dashGapLength: strokeWidth * lineType.dashGapLengthFactor,
          dashLength: strokeWidth * lineType.dashLengthFactor,
        ).paint(canvas, size);
      case _:
        final ui.Paint paint = ui.Paint()
          ..color = currentColor
          ..strokeWidth = strokeWidth
          ..strokeCap = ui.StrokeCap.round
          ..style = ui.PaintingStyle.stroke;

        canvas.drawPath(path, paint);
    }

    if (activeColor != null) {
      _drawActiveElementPoints(canvas: canvas, color: activeColor);
    }
  }

  @override
  HitPointPoly? getHit(ui.Offset offset) {
    PolyHitType? polyHitType = _hitTest(offset);
    return polyHitType != null ? HitPointPoly(this, offset, polyHitType) : null;
  }

  @override
  SketchElement update(ui.Offset updateOffset, HitPoint hitPoint) {
    if (hitPoint is! HitPointPoly) return this;

    switch (hitPoint.hitType) {
      case PolyHitType.start:
      case PolyHitType.midPoints:
      case PolyHitType.end:
        final activeIndex = activePointIndex ??
            points.indexWhere(
                (element) => element.distanceTo(Point<double>(updateOffset.dx, updateOffset.dy)) < toleranceRadius);

        if (activeIndex == -1) return this;

        final Point<double> newPoint = Point(updateOffset.dx, updateOffset.dy);
        final newPointList = points.replace(activeIndex, newPoint);

        return PolyEle(newPointList, color, lineType, strokeWidth, activePointIndex: activeIndex, closed: closed);

      case PolyHitType.line:
        final differenceVector = updateOffset - hitPoint.hitOffset;
        final originalElement = hitPoint.element as PolyEle;
        final originalPoints = originalElement.points;
        final movementPoint = Point(differenceVector.dx, differenceVector.dy);
        final updatedPoints = originalPoints.map((element) => element + movementPoint).toIList();

        return PolyEle(updatedPoints, color, lineType, strokeWidth, closed: closed);
    }
  }

  void _drawActiveElementPoints({required ui.Canvas canvas, required Color color}) {
    const double activeElementEndRadius = 15.0;
    final activeElementEndPaint = Paint()..color = color.withOpacity(0.5);

    for (var point in points) {
      canvas.drawCircle(
        point.toOffset(),
        activeElementEndRadius,
        activeElementEndPaint,
      );
    }
  }

  /// Checks if polyline is hit
  PolyHitType? _hitTest(Offset position) {
    final hitPoint = Point<double>(position.dx, position.dy);

    // Check if first/last point of poly was hit
    final endPointHitType = _getEndPointsHitType(points.first, points.last, hitPoint);

    if (endPointHitType != null) {
      return endPointHitType;
    } else if (points.any((element) => element.distanceTo(hitPoint) < toleranceRadiusPOI)) {
      return PolyHitType.midPoints;
    } else {
      // Check if poly was hit between lines
      List<({Point<double> start, Point<double> end})> linesFromPoly = [];
      Point<double>? previousPoint;

      for (var point in [...points, if (closed) points.first]) {
        if (previousPoint != null) {
          linesFromPoly.add((
            start: Point<double>(previousPoint.x, previousPoint.y),
            end: Point<double>(point.x, point.y),
          ));
        }
        previousPoint = point;
      }

      final isBetweenPoints = linesFromPoly.any((element) => _isBetweenPoints(element.start, element.end, hitPoint));

      return isBetweenPoints ? PolyHitType.line : null;
    }
  }

  /// Returns PolyHitType.start if startPoint is hit
  /// Returns PolyHitType.end if endPoint is hit
  /// else, return null
  PolyHitType? _getEndPointsHitType(Point<double> startPoint, Point<double> endPoint, Point<double> hitPoint) {
    final a = startPoint.distanceTo(hitPoint);
    final b = endPoint.distanceTo(hitPoint);
    final c = startPoint.distanceTo(endPoint);

    final startGotHit = (a < toleranceRadiusPOI || pow(b, 2) > pow(a, 2) + pow(c, 2)) && a < toleranceRadiusPOI;
    final endGotHit = (b < toleranceRadiusPOI || pow(a, 2) > pow(b, 2) + pow(c, 2)) && b < toleranceRadiusPOI;

    if (!startGotHit && !endGotHit) {
      return null;
    } else {
      return startGotHit ? PolyHitType.start : PolyHitType.end;
    }
  }

  /// Returns true if polyLine is hit between points
  bool _isBetweenPoints(Point<double> point1, Point<double> point2, Point<double> currentPoint) {
    double distanceToPoint1 = _getDistanceBetweenPoints(currentPoint, point1);
    double distanceToPoint2 = _getDistanceBetweenPoints(currentPoint, point2);
    double lineLength = _getDistanceBetweenPoints(point1, point2);

    return distanceToPoint1 + distanceToPoint2 <= lineLength + toleranceRadius;
  }

  double _getDistanceBetweenPoints(Point<double> p1, Point<double> p2) {
    double dx = p1.x - p2.x;
    double dy = p1.y - p2.y;
    return sqrt(dx * dx + dy * dy);
  }
}

mixin Drawable {
  ///
  void draw(ui.Canvas canvas, ui.Size size, [Color? activeColor]);
}

mixin Hitable {
  ///
  HitPoint? getHit(ui.Offset startOffset);

  ///
  SketchElement update(ui.Offset updateOffset, HitPoint hitPoint);

  ///
  SketchElement create(ui.Offset updateOffset);
}

sealed class HitPoint {
  HitPoint(
    this.element,
    this.hitOffset,
  );

  final SketchElement element;
  final Offset hitOffset;
}

class HitPointLine extends HitPoint {
  HitPointLine(
    super.element,
    super.hitOffset,
    this.hitType,
  );

  final LineHitType hitType;
}

class HitPointPoly extends HitPoint {
  HitPointPoly(
    super.element,
    super.hitOffset,
    this.hitType,
  );

  final PolyHitType hitType;
}

class HitPointPath extends HitPoint {
  HitPointPath(
    super.element,
    super.hitOffset,
  );
}

class HitPointText extends HitPoint {
  HitPointText(
    super.element,
    super.hitOffset,
  );
}

enum LineHitType { start, end, line }

enum PolyHitType { start, end, line, midPoints }

extension Editable on SketchElement {
  /// Returns values for element that are editable
  /// In following order: color, lineType, strokeWidth
  (Color?, LineType?, double?) getEditableValues() {
    final SketchElement element = this;
    switch (element) {
      case LineEle():
        return (element.color, element.lineType, element.strokeWidth);
      case PathEle():
        return (element.color, element.lineType, element.strokeWidth);
      case PolyEle():
        return (element.color, element.lineType, element.strokeWidth);
      case _:
        return (null, null, null);
    }
  }
}
