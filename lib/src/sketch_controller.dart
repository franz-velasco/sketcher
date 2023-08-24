import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:sketch/src/element_modifiers.dart';
import 'package:sketch/src/elements.dart';
import 'package:sketch/src/extensions.dart';

enum SketchMode {
  line,
  path,
  text,
  edit,
}

class SketchController extends ChangeNotifier {
  SketchController({
    this.elements = const IListConst([]),
    this.selectionColor = Colors.orange,
    this.magnifierScale = 1.5,
    this.magnifierSize = 100,
    this.magnifierBorderWidth = 3.0,
    this.magnifierColor = Colors.grey,
    this.gridLinesColor = Colors.grey,
    this.onEditText,
    Uint8List? backgroundImageBytes,
    LineType? lineType,
    Color? color,
    SketchMode? sketchMode,
    double? strokeWidth,
    bool? isGridLinesEnabled,
  })  : _history = Queue<IList<SketchElement>>.of(<IList<SketchElement>>[elements]),
        _sketchMode = sketchMode ?? SketchMode.edit,
        _lineType = lineType ?? LineType.full,
        _color = color ?? Colors.black,
        _strokeWidth = strokeWidth ?? 10,
        _backgroundImageBytes = backgroundImageBytes,
        _isGridLinesEnabled = isGridLinesEnabled ?? false;

  // ignore: unused_field
  Queue<IList<SketchElement>> _history;

  IList<SketchElement> elements;

  Future<String?> Function(String? text)? onEditText;

  SketchElement? _activeElement;
  HitPoint? hitPoint;

  SketchMode _sketchMode;

  Color _color;
  LineType _lineType;
  double _strokeWidth;
  bool _isGridLinesEnabled = false;

  final Color selectionColor;
  final Color gridLinesColor;

  Uint8List? _backgroundImageBytes;
  Size? _initialAspectRatio;

  // magnifier properties
  final double magnifierScale;
  final double magnifierSize;
  final double magnifierBorderWidth;
  final Color magnifierColor;

  /// Note: Workaround. Remove when adding of text programmatically is improved.
  /// Used to identify the position of the text to be added using [addTextElement]
  int _addedTextElementCount = 0;

  SketchElement? get activeElement => _activeElement;

  SketchMode get sketchMode => _sketchMode;

  Color get color => activeElementColor ?? _color;

  LineType get lineType => activeElementLineType ?? _lineType;

  double get strokeWidth => activeElementStrokeWidth ?? _strokeWidth;

  bool get isGridLinesEnabled => _isGridLinesEnabled;

  Size? get initialAspectRatio => _initialAspectRatio;

  Uint8List? get backgroundImageBytes => _backgroundImageBytes;

  /// Returns the color of the active/selected element if there is one
  Color? get activeElementColor {
    final element = _activeElement;
    if (element == null) return null;
    return element.getEditableValues().$1;
  }

  /// Returns the lineType of the active/selected element if there is one
  LineType? get activeElementLineType {
    final element = _activeElement;
    if (element == null) return null;
    return element.getEditableValues().$2;
  }

  /// Returns the strokeWidth of the active/selected element if there is one
  double? get activeElementStrokeWidth {
    final element = _activeElement;
    if (element == null) return null;
    return element.getEditableValues().$3;
  }

  set sketchMode(SketchMode sketchMode) {
    // prevent selection throughout the sketch modes
    deactivateActiveElement();
    _sketchMode = sketchMode;
  }

  /// Sets color for activeElement or, in case no
  /// active element is selected, as default color
  set color(Color color) {
    final element = _activeElement;
    if (element == null) {
      // set default color
      _color = color;
    } else {
      // set active element color
      switch (element) {
        case LineEle():
          _activeElement = LineEle(
            element.start,
            element.end,
            color,
            element.lineType,
            element.strokeWidth,
          );
        case PathEle():
          _activeElement = PathEle(
            element.points,
            color,
            element.lineType,
            element.strokeWidth,
          );
        case PolyEle():
          _activeElement = PolyEle(
            element.points,
            color,
            element.lineType,
            element.strokeWidth,
            closed: element.closed,
          );
        case _:
      }
    }
    notifyListeners();
    _addChangeToHistory();
  }

  /// Sets lineType for activeElement or, in case no
  /// active element is selected, as default lineType
  set lineType(LineType lineType) {
    final element = _activeElement;
    if (element == null) {
      // set default lineType
      _lineType = lineType;
    } else {
      // set active lineType
      switch (element) {
        case LineEle():
          _activeElement = LineEle(
            element.start,
            element.end,
            element.color,
            lineType,
            element.strokeWidth,
          );
        case PathEle():
          _activeElement = PathEle(
            element.points,
            element.color,
            lineType,
            element.strokeWidth,
          );
        case PolyEle():
          _activeElement = PolyEle(
            element.points,
            element.color,
            lineType,
            element.strokeWidth,
            closed: element.closed,
          );
        case _:
      }
    }
    notifyListeners();
    _addChangeToHistory();
  }

  /// Sets strokeWidth for activeElement or, in case no
  /// active element is selected, as default lineType
  set strokeWidth(double strokeWidth) {
    final element = _activeElement;
    if (element == null) {
      // set default lineType
      _strokeWidth = strokeWidth;
    } else {
      // set active lineType
      switch (element) {
        case LineEle():
          _activeElement = LineEle(
            element.start,
            element.end,
            element.color,
            element.lineType,
            strokeWidth,
          );
        case PathEle():
          _activeElement = PathEle(
            element.points,
            element.color,
            element.lineType,
            strokeWidth,
          );
        case PolyEle():
          _activeElement = PolyEle(
            element.points,
            element.color,
            element.lineType,
            strokeWidth,
            closed: element.closed,
          );
        case _:
      }
    }
    notifyListeners();
    _addChangeToHistory();
  }

  /// Set the boolean value to determine if grid lines should be enabled
  set isGridLinesEnabled(bool enabled) {
    _isGridLinesEnabled = enabled;
    notifyListeners();
  }

  /// Set the initial aspect ratio for the sketch area to be able
  /// to scale the sketch correctly when the aspect ratio changes
  set initialAspectRatio(Size? initialAspectRatio) {
    if (_initialAspectRatio != null) return;
    _initialAspectRatio = initialAspectRatio;
    notifyListeners();
  }

  /// Set the background image for the sketch area
  set backgroundImageBytes(Uint8List? backgroundImageBytes) {
    _backgroundImageBytes = backgroundImageBytes;
    notifyListeners();
  }

  void undo() {
    if (_history.isEmpty) return;
    deactivateActiveElement();
    _history.removeLast();
    elements = _history.last;
    notifyListeners();
  }

  bool get undoPossible => _history.length > 1;

  bool get deletePossible => _activeElement != null;

  /// Add all elements (even the active element) to history
  void _addChangeToHistory() {
    // add activeElement to all elements
    final element = _activeElement;

    // TODO(Jayvee) : Remove when a better implementation for activePointIndex is applied
    if (element is PolyEle) element.activePointIndex = null;

    final allElements = element == null ? elements : elements.add(element);

    // save a history entry only if the current elements list differs from the last
    if (_history.last != allElements) {
      _history.add(allElements);
    }

    // keep history length at max. 5 steps
    if (_history.length > 6) _history.removeFirst();

    notifyListeners();
  }

  /// Removes activeElement if it exists and moves it back to the elements list
  void deactivateActiveElement() {
    final element = _activeElement;
    if (element != null) {
      elements = elements.add(element);
      _activeElement = null;
      notifyListeners();
    }
  }

  void deleteActiveElement() {
    _activeElement = null;
    _addChangeToHistory();
    notifyListeners();
  }

  /// Add a [text] element to the sketch
  /// If [position] is null, get the text element using [_getTextElementPosition]
  /// Increment [_addedTextElementCount] after adding a text element
  void addTextElement(String? text, {Point<double>? position}) {
    deactivateActiveElement();
    if (text != null && text.isNotEmpty) {
      final textPosition = position ?? _getTextElementPosition();

      _activeElement = TextEle(text, color, textPosition);
      _addedTextElementCount++;

      notifyListeners();
      _addChangeToHistory();
    }
  }

  /// Position the text based on addedTextElementCount
  /// it will start from the top left of the screen, going down
  /// It will move the text position to the next column every 10 texts
  Point<double> _getTextElementPosition() {
    final divValue = _addedTextElementCount ~/ 10;
    final modValue = _addedTextElementCount % 10;

    final x = (divValue + 1) * 40.0;
    final y = (modValue + 1) * 20.0;

    return Point<double>(x, y);
  }

  /// Finds the nearest point on a line defined by two points (p1 and p2)
  /// from a given target point.
  ///
  /// The function calculates the nearest point on the line passing through p1 and p2
  /// from the target point. It returns the coordinates of the nearest point as a
  /// [Point<double>] object.
  ///
  /// The function takes three parameters:
  /// - [p1]: The first point defining the line.
  /// - [p2]: The second point defining the line.
  /// - [targetPoint]: The point for which we want to find the nearest point on the line.
  ///
  /// The function returns a [Point<double>] object representing the nearest point on
  /// the line from the [targetPoint].
  Point<double> _findNearestPointOnLine(Point<double> p1, Point<double> p2, Offset targetPoint) {
    // Calculate the vector from point p1 to point p2
    Point<double> lineVector = Point<double>(p2.x - p1.x, p2.y - p1.y);

    // Calculate the vector from point p1 to the target point
    Point<double> targetVector = Point<double>(targetPoint.dx - p1.x, targetPoint.dy - p1.y);

    // Calculate the dot product
    double dotProduct = lineVector.x * targetVector.x + lineVector.y * targetVector.y;

    // Calculate the squared length of the line vector
    double lineLengthSquared = lineVector.x * lineVector.x + lineVector.y * lineVector.y;

    // Calculate the parameter 't' to find the nearest point on the line
    double t = dotProduct / lineLengthSquared;

    // If t < 0, the nearest point is before p1 on the line
    // If t > 1, the nearest point is after p2 on the line
    // Otherwise, the nearest point is between p1 and p2 on the line
    if (t < 0) {
      return p1;
    } else if (t > 1) {
      return p2;
    } else {
      // Calculate the nearest point on the line
      double nearestX = p1.x + t * lineVector.x;
      double nearestY = p1.y + t * lineVector.y;
      return Point<double>(nearestX, nearestY);
    }
  }

  /// Upon drag update, snaps the point of a line to the nearest endpoint of a poly within the tolerance radius
  /// If the point of line goes on the midpoints/line, no snapping will happen
  void _updateMagneticLineToPoly(
      DragUpdateDetails details, LineEle activeLineElement, HitPointLine hitPointLine, PolyEle polyElement) {
    final touchedPolyHitPoint = polyElement.getHit(details.localPosition) as HitPointPoly;
    final polyStartPoint = polyElement.points.first;
    final polyEndPoint = polyElement.points.last;
    final startPointHit = polyStartPoint.distanceTo(details.localPosition.toPoint()) < toleranceRadiusPOI;

    switch (touchedPolyHitPoint.hitType) {
      case PolyHitType.line:
        _activeElement = activeLineElement.update(details.localPosition, hitPointLine);
        break;
      case PolyHitType.midPoints:
        final nearestMidPoint = polyElement.points
            .firstWhereOrNull((element) => element.distanceTo(details.localPosition.toPoint()) < toleranceRadius);
        if (nearestMidPoint != null) {
          _activeElement = activeLineElement.update(nearestMidPoint.toOffset(), hitPointLine);
        }
      case PolyHitType.start:
      case PolyHitType.end:
        final targetPoint = startPointHit ? polyStartPoint.toOffset() : polyEndPoint.toOffset();
        _activeElement = activeLineElement.update(targetPoint, hitPointLine);
        break;
    }
  }

  /// Updates the active element with the new position and snaps
  /// the line to the nearest line if it is close enough
  void _updateMagneticLine(
      DragUpdateDetails details, SketchElement element, HitPointLine hitPointLine, LineEle lineEle) {
    final nearestPoint = _findNearestPointOnLine(
      lineEle.start,
      lineEle.end,
      details.localPosition,
    );

    _activeElement = element.update(
      nearestPoint.toOffset(),
      hitPointLine,
    );
  }

  void onPanDown(DragDownDetails details) {
    deactivateActiveElement();
    switch (sketchMode) {
      case SketchMode.line:
        final startPoint = Point(details.localPosition.dx, details.localPosition.dy);
        _activeElement = LineEle(
          startPoint,
          startPoint + Point(1, 1),
          color,
          _lineType,
          _strokeWidth,
        );
        notifyListeners();
        break;
      case SketchMode.path:
        final startPoint = Point(details.localPosition.dx, details.localPosition.dy);
        _activeElement = PathEle(
          IList([startPoint]),
          color,
          _lineType,
          _strokeWidth,
        );
        notifyListeners();
        break;

      case SketchMode.text:
        break;
      case SketchMode.edit:
        final touchedElement = elements.reversed.firstWhereOrNull((e) => e.getHit(details.localPosition) != null);
        if (touchedElement == null) {
          // nothing touched
          return;
        }
        hitPoint = touchedElement.getHit(details.localPosition);

        // remove element from the elements list and hand it over to the active painter
        elements = elements.remove(touchedElement);
        _activeElement = touchedElement;
        notifyListeners();
    }
  }

  void onPanStart(DragStartDetails details) {
    switch (sketchMode) {
      case SketchMode.line:
      case SketchMode.path:
      case SketchMode.text:
      case SketchMode.edit:
    }
  }

  void onPanUpdate(DragUpdateDetails details) {
    switch (sketchMode) {
      case SketchMode.line:
        final element = _activeElement;
        if (element == null) return;
        final hitPointLine = HitPointLine(
          element, // doesn't get used
          Offset.zero, // doesn't get used
          LineHitType.end,
        );

        final touchedElement = elements.firstWhereOrNull((e) => e.getHit(details.localPosition) != null);
        if (touchedElement is LineEle) {
          _updateMagneticLine(details, element, hitPointLine, touchedElement);
        } else if (touchedElement is PolyEle) {
          _updateMagneticLineToPoly(details, element as LineEle, hitPointLine, touchedElement);
        } else {
          _activeElement = element.update(
            details.localPosition,
            hitPointLine,
          );
        }
        notifyListeners();
        break;
      case SketchMode.path:
        final element = _activeElement;
        final isPathElement = element is PathEle;
        if (element == null || !isPathElement) return;

        final currentPoint = Point(details.localPosition.dx, details.localPosition.dy);
        _activeElement = PathEle(
          IList([
            ...element.points,
            currentPoint,
          ]),
          element.color,
          element.lineType,
          element.strokeWidth,
        );

        notifyListeners();
        break;
      case SketchMode.text:
      case SketchMode.edit:
        final element = _activeElement;
        final localHitPoint = hitPoint;

        if (element == null) return;
        if (localHitPoint == null) return;

        switch (element) {
          case LineEle():
            if (localHitPoint is HitPointLine) {
              final touchedElement = elements.reversed.firstWhereOrNull((e) => e.getHit(details.localPosition) != null);
              if (touchedElement is LineEle) {
                _updateMagneticLine(details, element, localHitPoint, touchedElement);
              } else if (touchedElement is PolyEle) {
                _updateMagneticLineToPoly(details, element, localHitPoint, touchedElement);
              } else {
                _activeElement = element.update(
                  details.localPosition,
                  localHitPoint,
                );
              }

              notifyListeners();
            }
          case PathEle():
            if (localHitPoint is HitPointPath) {
              _activeElement = element.update(details.localPosition, localHitPoint);
              notifyListeners();
            }
          case PolyEle():
            if (localHitPoint is HitPointPoly) {
              final touchedElement = elements.reversed.firstWhereOrNull((e) => e.getHit(details.localPosition) != null);

              /// Poly merging to itself
              if (touchedElement == null) {
                final activePointIndex = element.activePointIndex;
                final selectedPoint =
                    activePointIndex != null ? element.points.get(activePointIndex, orElse: null) : null;
                final firstElement = element.points.first;
                final lastElement = element.points.last;

                // If there is no selected point, or if there are only 3 points, we only update the active Elements normally
                if (selectedPoint == null || element.points.length <= 3) {
                  _activeElement = element.update(details.localPosition, localHitPoint);
                } else {
                  // If start and end point meet within the toleranceRadius, snap it to each other and update activeElement
                  final isStart = selectedPoint == element.points.first;
                  final isEnd = selectedPoint == element.points.last;
                  final localPoint = details.localPosition.toPoint();

                  if ((isStart && localPoint.distanceTo(lastElement) < toleranceRadius) ||
                      (isEnd && localPoint.distanceTo(firstElement) < toleranceRadius)) {
                    final updatedPoint = isEnd ? firstElement : lastElement;
                    _activeElement = element.update(updatedPoint.toOffset(), localHitPoint) as PolyEle;
                  } else {
                    _activeElement = element.update(details.localPosition, localHitPoint);
                  }
                }
              } else if (touchedElement is PolyEle) {
                _handlePolyToPolyMerging(element, touchedElement, details, localHitPoint);
              } else if (touchedElement is LineEle) {
                _handlePolyToLineMerging(element, touchedElement, details, localHitPoint);
              } else {
                _activeElement = element.update(details.localPosition, localHitPoint);
              }
              notifyListeners();
            }
          case TextEle():
            _activeElement = element.update(
              details.localPosition,
              localHitPoint,
            );
            notifyListeners();
            break;
        }
    }
  }

  /// Poly to Poly can only merge on their endpoints
  void _handlePolyToPolyMerging(
      PolyEle element, PolyEle touchedElement, DragUpdateDetails details, HitPoint localHitPoint) {
    final hitPointLine = touchedElement.getHit(details.localPosition);
    if (hitPointLine == null) return;
    final hitType = hitPointLine.hitType;

    switch (hitType) {
      case PolyHitType.line:
        _activeElement = element.update(details.localPosition, localHitPoint);
      case PolyHitType.midPoints:
        final nearestMidPoint = touchedElement.points
            .firstWhereOrNull((element) => element.distanceTo(details.localPosition.toPoint()) < toleranceRadius);
        if (nearestMidPoint != null) {
          _activeElement = element.update(nearestMidPoint.toOffset(), hitPointLine);
        }
      case PolyHitType.start:
      case PolyHitType.end:
        final newPoint =
            hitPointLine.hitType == PolyHitType.start ? touchedElement.points.first : touchedElement.points.last;
        _activeElement = element.update(newPoint.toOffset(), localHitPoint) as PolyEle;
    }
  }

  void _handlePolyToLineMerging(
      PolyEle activePolyElement, LineEle lineElement, DragUpdateDetails details, HitPoint localHitPoint) {
    final hitPointLine = lineElement.getHit(details.localPosition);
    if (hitPointLine == null) return;
    final hitType = hitPointLine.hitType;

    if (hitType == LineHitType.line) {
      _activeElement = activePolyElement.update(details.localPosition, localHitPoint);
    } else {
      final newPoint = hitPointLine.hitType == LineHitType.start ? lineElement.start : lineElement.end;
      _activeElement = activePolyElement.update(newPoint.toOffset(), localHitPoint) as PolyEle;
    }
  }

  List<Point<double>>? _onMergeTwoLines(
    Point<double> line1Start,
    Point<double> line1End,
    Point<double> line2Start,
    Point<double> line2End,
  ) {
    List<Point<double>>? createMergedList(Point<double> a, Point<double> b, Point<double> c) => [a, b, c];

    if (line1Start == line2Start) {
      return createMergedList(line2End, line1Start, line1End);
    } else if (line1End == line2End) {
      return createMergedList(line1Start, line2End, line2Start);
    } else if (line1Start == line2End) {
      return createMergedList(line1End, line1Start, line2Start);
    } else if (line2Start == line1End) {
      return createMergedList(line1Start, line2Start, line2End);
    }

    return null;
  }

  void _checkMergeLine(DragEndDetails details, LineEle lineElement, HitPointLine hitPointLine) {
    final touchedElement =
        elements.reversed.where((element) => element is LineEle || element is PolyEle).firstWhereOrNull((e) {
      return e.getHit(lineElement.start.toOffset()) != null || e.getHit(lineElement.end.toOffset()) != null;
    });

    if (touchedElement is LineEle) {
      final points = _onMergeTwoLines(touchedElement.start, touchedElement.end, lineElement.start, lineElement.end);

      if (points != null) {
        elements = elements.removeAll([touchedElement, lineElement]);
        _activeElement = PolyEle(IList(points), color, lineType, strokeWidth);
      }
      notifyListeners();
    } else if (touchedElement is PolyEle && !touchedElement.closed) {
      final newPoints = _onMergePolyAndLine(touchedElement, lineElement);
      if (newPoints != null) {
        elements = elements.removeAll([touchedElement, lineElement]);
        _activeElement = PolyEle(newPoints, color, lineType, strokeWidth, closed: touchedElement.closed);
        notifyListeners();
      }
    }
  }

  IList<Point<double>>? _onMergePolyAndLine(PolyEle polyLine, LineEle line) {
    final activeElementPoints = [
      line.start,
      line.end,
    ];

    final polyStartPoint = polyLine.points.first;
    final polyEndPoint = polyLine.points.last;

    if (activeElementPoints.contains(polyStartPoint)) {
      final newPoint = line.start == polyStartPoint ? line.end : line.start;
      return IList([newPoint, ...polyLine.points]);
    } else if (activeElementPoints.contains(polyEndPoint)) {
      final newPoint = line.start == polyEndPoint ? line.end : line.start;
      return IList([...polyLine.points, newPoint]);
    } else {
      return null;
    }
  }

  void onPanEnd(DragEndDetails details) {
    switch (sketchMode) {
      case SketchMode.line:
        final element = _activeElement;
        if (element == null) return;
        final hitPointLine = HitPointLine(
          element, // doesn't get used
          Offset.zero, // doesn't get used
          LineHitType.end,
        );

        _checkMergeLine(details, element as LineEle, hitPointLine);

        deactivateActiveElement();
        break;
      case SketchMode.path:
      case SketchMode.text:
        // deselect painted element in non-edit mode after painting is done
        deactivateActiveElement();
      case SketchMode.edit:
        final element = _activeElement;

        /// Handle merging of PolyEle on pan end
        if (element is PolyEle && !element.closed) {
          final touchedElement = elements.firstWhereOrNull((e) {
            if (e is PolyEle || e is LineEle) {
              final startPointHit = e.getHit(element.points.first.toOffset()) != null;
              final endPointHit = e.getHit(element.points.last.toOffset()) != null;
              return startPointHit || endPointHit;
            }
            return false;
          });

          IList<Point<double>>? newPoints;

          if (touchedElement is PolyEle && !touchedElement.closed) {
            final firstPointsMatched = touchedElement.points.first == element.points.first;
            final lastPointsMatched = touchedElement.points.last == element.points.last;

            if (firstPointsMatched || lastPointsMatched) {
              final reversedElementPoints = firstPointsMatched ? element.points.reversed : element.points;
              final reversedTouchedPoints = firstPointsMatched ? touchedElement.points : touchedElement.points.reversed;
              newPoints = IList([...reversedElementPoints, ...reversedTouchedPoints]);
            } else if (touchedElement.points.first == element.points.last) {
              newPoints = IList([...element.points, ...touchedElement.points]);
            } else if (touchedElement.points.last == element.points.first) {
              newPoints = IList([...touchedElement.points, ...element.points]);
            }
          } else if (touchedElement is LineEle) {
            final points = _onMergePolyAndLine(element, touchedElement);
            if (points != null) newPoints = points;
          }

          if (touchedElement != null && newPoints != null) elements = elements.remove(touchedElement);

          newPoints ??= element.points;
          final isClosed = newPoints.first == newPoints.last || element.closed;

          _activeElement = PolyEle(newPoints.removeDuplicates(), color, lineType, strokeWidth, closed: isClosed);
        } else if (element is LineEle) {
          final hitPointLine = HitPointLine(
            element, // doesn't get used
            Offset.zero, // doesn't get used
            LineHitType.end,
          );
          _checkMergeLine(details, element, hitPointLine);
        }
    }

    _addChangeToHistory();
  }

  void onPanCancel() {
    switch (sketchMode) {
      case SketchMode.line:
      case SketchMode.path:
      case SketchMode.text:
      case SketchMode.edit:
    }
  }

  void onTapUp(TapUpDetails tapUpDetails) {
    switch (sketchMode) {
      // On tap up while text mode, call onEditText and pass a null value for the string value of the text since it is new
      case SketchMode.text:
        final position = Point(tapUpDetails.localPosition.dx, tapUpDetails.localPosition.dy);
        onEditText?.call(null).then((value) {
          if (value != null && value.isNotEmpty) {
            _activeElement = TextEle(value, color, position);
            notifyListeners();
            _addChangeToHistory();
          }
        });
      // On tap up while edit mode and selected element is text, call onEditText and pass the text element's value
      case SketchMode.edit:
        final element = _activeElement;
        final localHitPoint = hitPoint;

        if (element == null) return;
        if (localHitPoint == null) return;

        switch (element) {
          case TextEle():
            final position = Point(tapUpDetails.localPosition.dx, tapUpDetails.localPosition.dy);
            onEditText?.call(element.text).then((value) {
              if (value != null && value.isNotEmpty) {
                _activeElement = TextEle(value, color, position);
                notifyListeners();
                _addChangeToHistory();
              }
            });
          case _:
            break;
        }
      case _:
        _addChangeToHistory();
        break;
    }
  }
}
