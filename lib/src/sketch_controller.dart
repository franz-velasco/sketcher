import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:sketch/src/element_modifiers.dart';
import 'package:sketch/src/elements.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

enum SketchMode {
  line,
  path,
  text,
  edit,
}

class SketchController extends ChangeNotifier {
  SketchController({
    this.elements = const IListConst([]),
  }) : _history = Queue<IList<SketchElement>>.from(elements);

  // ignore: unused_field
  Queue<IList<SketchElement>> _history;

  final IList<SketchElement> elements;

  SketchElement? activeElement;
  HitPoint? hitpoint;

  SketchMode sketchMode = SketchMode.edit;

  Color color = const Color(0xFF000000);
  LineType lineType = LineType.full;
  double lineThickness = 5;

  void onPanDown(DragDownDetails details) {
    switch (sketchMode) {
      case SketchMode.line:
      case SketchMode.path:
      case SketchMode.text:
      case SketchMode.edit:
        final touchedElement = elements
            .firstWhereOrNull((e) => e.getHit(details.localPosition) != null);
        if (touchedElement == null) {
          print("Nothing touched");
          return;
        }
        final hitPoint = touchedElement.getHit(details.localPosition);
        if (hitPoint is HitPointLine) {
          print("Success");
          print(hitPoint.hitType);
        }
      //elements.remove(touchedElement);
      //activeElement = touchedElement;
      //notifyListeners();
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
      case SketchMode.path:
      case SketchMode.text:
      case SketchMode.edit:
    }
  }

  void onPanEnd(DragEndDetails details) {
    switch (sketchMode) {
      case SketchMode.line:
      case SketchMode.path:
      case SketchMode.text:
      case SketchMode.edit:
    }
  }

  void onPanCancel() {
    switch (sketchMode) {
      case SketchMode.line:
      case SketchMode.path:
      case SketchMode.text:
      case SketchMode.edit:
    }
  }
}
