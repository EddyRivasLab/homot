import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:homot/main.dart';
import 'package:homot/utility.dart';
import 'package:homot/src/rust/api/graph.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:patterns_canvas/patterns_canvas.dart';

// Draws a horizontal line as an example for the settings page
class LinePainter extends CustomPainter {
  final BuildContext context;
  final HSettings hSettings;
  final double devicePixelRatio;
  LinePainter(this.context, this.hSettings, this.devicePixelRatio);
  @override
  void paint(Canvas canvas, Size size) {
    var paint =
        Paint()
          ..color = Theme.of(context).colorScheme.onSurface
          ..style = PaintingStyle.stroke
          ..strokeWidth = hSettings.lineWidth / devicePixelRatio;

    Offset start = Offset(0.0, size.height / 2);
    Offset end = Offset(size.width, size.height / 2);
    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant LinePainter oldDelegate) {
    return oldDelegate.hSettings != hSettings;
  }
}

// The main drawer for the taxonomy graph
class GraphPainter extends CustomPainter {
  final BuildContext context;
  final GraphData graphData;
  final HSettings hSettings;
  final double devicePixelRatio;
  final TransformationController tController;
  final double graphRadius;
  GraphPainter(
    this.context,
    this.graphData,
    this.devicePixelRatio,
    this.tController,
    this.graphRadius,
    this.hSettings,
  );
  bool _will_text_fit(
    Canvas canvas,
    TextTheme textTheme,
    String text,
    double angle,
    double startRadius,
    double endRadius,
    double regionAngle,
    Offset center,
    Color textColor,
    Color bgColor,
    bool moveInward, // move the label in as far as possible 
  ) {
    // The easiest way to get the dimensions of some
    // text seems to be to try rendering them and then measure the result.
    TextPainter testPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    testPainter.textScaler = TextScaler.linear(1 / graphData.scale);

    testPainter.text = TextSpan(
      text: text,
      style: textTheme.bodyMedium!.copyWith(color: textColor, backgroundColor: bgColor),
    );
    testPainter
        .layout(); // laying out the text computes how much space it will take if drawn

    // Figure out how much space is available for the text.  Need to take into account
    // that text may not start at the startRadius in order to make things work right near graph origin
    if (regionAngle > pi) {
      regionAngle =
          pi; // assume that text height isn't an issue if angle wider than 180 degrees
    }
    final double availLength = endRadius - startRadius;
    final double availHeight =
        2 *
        (startRadius + availLength - testPainter.width) *
        sin(regionAngle / 2);
    // available height for text is the chord of the arc at the small end of the wedge for the node
    // if availLength < testPainter.width, this will give weird answers, but we won't draw any text
    // in that case, so it doesn't matter

    if (availLength < testPainter.width || availHeight < testPainter.height) {
      // can't fit the text, so don't draw it
      //    print("availLength = $availLength, availHeight = $availHeight, text width = ${testPainter.width}, text height = ${testPainter.height}");
      //    print("startRadius = $startRadius, endRadius = $endRadius, regionAngle = $regionAngle");
      //    print("text = $text");
      return false;
    }
    return true;
  }


  bool _write_if_fits(
    Canvas canvas,
    TextTheme textTheme,
    String text,
    double angle,
    double startRadius,
    double endRadius,
    double regionAngle,
    Offset center,
    Color textColor,
    Color bgColor,
    bool moveInward, // move the label in as far as possible 
  ) {
    // The easiest way to get the dimensions of some
    // text seems to be to try rendering them and then measure the result.
    TextPainter testPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    testPainter.textScaler = TextScaler.linear(1 / graphData.scale);

    testPainter.text = TextSpan(
      text: text,
      style: textTheme.bodyMedium!.copyWith(color: textColor, backgroundColor: bgColor),
    );
    testPainter
        .layout(); // laying out the text computes how much space it will take if drawn

    // Figure out how much space is available for the text.  Need to take into account
    // that text may not start at the startRadius in order to make things work right near graph origin
    if (regionAngle > pi) {
      regionAngle =
          pi; // assume that text height isn't an issue if angle wider than 180 degrees
    }
    final double availLength = endRadius - startRadius;
    final double availHeight =
        2 *
        (startRadius + availLength - testPainter.width) *
        sin(regionAngle / 2);
    // available height for text is the chord of the arc at the small end of the wedge for the node
    // if availLength < testPainter.width, this will give weird answers, but we won't draw any text
    // in that case, so it doesn't matter

    if (availLength < testPainter.width || availHeight < testPainter.height) {
      // can't fit the text, so don't draw it
      //    print("availLength = $availLength, availHeight = $availHeight, text width = ${testPainter.width}, text height = ${testPainter.height}");
      //    print("startRadius = $startRadius, endRadius = $endRadius, regionAngle = $regionAngle");
      //    print("text = $text");
      return false;
    }
    double slideIn = 0.0; // Amount to move the label towards the center of the graph.  
    // 0 unless we're trying to move inward

    if (moveInward){
      double minRadius = testPainter.height / (2 * sin(regionAngle/2)); 
      //print("${text}: startRadius = ${startRadius}, endRadius = ${endRadius}, minRadius = ${minRadius}");
      // Distance from center at which the wedge becomes wide enough to fit the text
      if (minRadius < endRadius - ((endRadius - startRadius)/2) - (testPainter.width /2)){ // Plenty of room, center text at midpoint of wedge
        slideIn = ((endRadius - startRadius)/2) - (testPainter.width/2);
      }
      else{
        slideIn = endRadius - (minRadius + testPainter.width);
      }
    }

    // if we get here, then we can print the text.
    double rotAngle = angle;
    double startX;
    double startY;
    double rotateX;
    double rotateY;

    if ((angle + graphData.rotation) % (2 * pi) >= pi / 2 &&
        (angle + graphData.rotation) % (2 * pi) < 3 * pi / 2) {
      // get text right-side-up, remembering that flutter angles are
      //clockwise
      rotAngle = angle + pi;
      // Offsets from the center of rotation (middle of the text) to upper left corner to get start position
      // for drawing.  These offsets will be applied in the _rotated_ frame, so an X offset translates
      // to motion along the radius.

      startX =
          -(-slideIn + (testPainter.width / 2) -
              2 * hSettings.lineWidth / graphData.scale);
      startY = -testPainter.height / 2;
    } else {
      // Offsets from the center of rotation (middle of the text) to upper left corner to get start position
      // for drawing.  These offsets will be applied in the _rotated_ frame, so an X offset translates
      // to motion along the radius.

      startX =
          -(slideIn +(testPainter.width / 2) +
              2 * hSettings.lineWidth / graphData.scale);
      startY = -testPainter.height / 2;
    }
    rotateX =
        center.dx +
        (endRadius - testPainter.width / 2) *
            cos(angle); // offsets to translate the canvas
    rotateY =
        center.dy +
        (endRadius - testPainter.width / 2) *
            sin(angle); // so that rotation works
    canvas.save();
    canvas.translate(rotateX, rotateY);
    canvas.rotate(rotAngle);
    //canvas.translate(-rotateX, -rotateY);
    testPainter.paint(canvas, Offset(startX, startY));
    canvas.restore();
    return true;
  }

  // Recursive function to draw a node and its children
  void drawNode(
    Map<PlatformInt64, Node> graph,
    PlatformInt64 nodeId,
    PlatformInt64 parentId,
    Offset center,
    double startRadius,
    double radPerLevel,
    int startLevel,
    int maxLevel,
    Canvas myCanvas,
    int majorColor,
    int minorColor,
    Paint paint,
    Size size,
  ) {
    var node = graph[nodeId]!;
    bool drawChildren = node.ranknum < maxLevel;
    Color nodeColor;
    Color fillColor, fillTextColor;
    PatternType patternType;
    Color patternFg, patternBg;
    if (nodeId == parentId) {
      // root node of current graph
      nodeColor = hSettings.themeData.colorScheme.onSurface;
      fillColor = hSettings.themeData.colorScheme.onSurface;
      fillTextColor = Colors.white;
      patternType = PatternType.dots;
      patternFg = Color(0xff000000);
      patternBg = Color(0xffffffff);
    } else {
      (nodeColor, _, _, _, _) = hSettings.graphColors[(majorColor) * shadesPerColor];
      (fillColor, fillTextColor, patternType, patternBg, patternFg) =
          hSettings.graphColors[(majorColor) * shadesPerColor + minorColor];
    }
    // keep the node from going beyond the max radius of the graph
    var myRadius = min(
      startRadius + ((node.ranknum - startLevel) * radPerLevel),
      startRadius + ((maxLevel - startLevel) * radPerLevel),
    );

    if (myRadius >= (graphRadius - ((hSettings.lineWidth/2) / (graphData.scale)))) { // make sure outer border fits
      myRadius = graphRadius - ((hSettings.lineWidth/2) / (graphData.scale));
    }

    var myAngle = (node.myArcStart + node.myArcEnd) / 2;
    var myOffset = Offset(
      center.dx + (myRadius * cos(myAngle)),
      center.dy + (myRadius * sin(myAngle)),
    );
    // Note: In Flutter, the y-axis increases downward, and angles increase clockwise, not counter-clockwise so we add sin(myAngle) to the y-coordinate.
    var parent = graph[parentId]!;
    var parentRadius =
        startRadius + ((parent.ranknum - startLevel) * radPerLevel);

    var parentOffset = Offset(
      center.dx + (parentRadius * cos(myAngle)),
      center.dy + (parentRadius * sin(myAngle)),
    );

    if (nodeId == parentId) {
      // This is the root node of the current graph, so reset the trackRegions structure
      graphData.trackRegions = TrackRegions(1 + maxLevel - startLevel);
      graphData.trackRegions.addRegion(0, Region(0, 2 * pi, nodeId));
      myCanvas.drawCircle(
        center,
        startRadius,
        paint
          ..style = PaintingStyle.fill
          ..color = nodeColor,
      );
    } else {
      // now, add the region for the node to each level it crosses
      // Won't conflict with the region we added for the root node, because parent.ranknum +1 will be > node.ranknum,
      // since node = parent
      for (
        int level = parent.ranknum + 1;
        level <= min(node.ranknum, maxLevel);
        level++
      ) {
        graphData.trackRegions.addRegion(
          level - startLevel,
          Region(node.myArcStart, node.myArcEnd, nodeId),
        );
      }

      final String nodeText = node.name + "\n" + node.hitsBelow.toString();
      final bool textFit = _will_text_fit(
        myCanvas,
        Theme.of(context).textTheme,
        nodeText,
        myAngle,
        parentRadius,
        myRadius,
        (node.myArcEnd - node.myArcStart),
        center,
        Theme.of(context).colorScheme.onSurface,
        Color(0x00000000), // transparent background for text
        false
      );
      if(textFit){ // Only draw the radial line if we have space for the text,
      // otherwise, it looks bad with wedges if we're using transparent colors
        switch(hSettings.drawType){
          case GraphDrawType.line:
            myCanvas.drawLine(parentOffset, myOffset, paint
                              ..strokeWidth = hSettings.lineWidth / graphData.scale
                              ..color = nodeColor,);
            break;
          case GraphDrawType.outline:
          // Approximation: shrink the arc angles by half the line width at both inner and outer radius
            var innerDelta = (hSettings.lineWidth/(2* graphData.scale)) / (2* parentRadius); // approximate shift as fraction of circumference
            var newArcStartInner= node.myArcStart + innerDelta;
            var newArcEndInner = node.myArcEnd - innerDelta;
            var outerDelta = (hSettings.lineWidth/(2* graphData.scale)) / (2* myRadius); // approximate shift as fraction of circumference
            var newArcStartOuter= node.myArcStart + outerDelta;
            var newArcEndOuter = node.myArcEnd - outerDelta;

            var innerRect = Rect.fromCircle(center: center, radius: parentRadius);
              var outerRect = Rect.fromCircle(center: center, radius: myRadius);
              var piePath = Path();
              piePath.moveTo(
                center.dx + (parentRadius * cos(newArcStartInner)),
                center.dy + (parentRadius * sin(newArcStartInner)),
              );
              piePath.addArc(
                innerRect,
                newArcStartInner,
                newArcEndInner - newArcStartInner,
              );
              piePath.lineTo(
                center.dx + (myRadius * cos(newArcEndOuter)),
                center.dy + (myRadius * sin(newArcEndOuter)),
              );
              piePath.addArc(
                outerRect,
                newArcEndOuter,
                -(newArcEndOuter - newArcStartOuter),
              );
              piePath.lineTo(
                center.dx + (parentRadius * cos(newArcStartInner)),
                center.dy + (parentRadius * sin(newArcStartInner)),
              );
              myCanvas.drawPath(
                piePath,
                paint
                  ..style = PaintingStyle.stroke
                  ..color = fillColor
                //  ..strokeWidth = hSettings.lineWidth / graphData.scale
                  ,
                ); 
              break;
          case GraphDrawType.fill:
            var innerRect = Rect.fromCircle(center: center, radius: parentRadius);
              var outerRect = Rect.fromCircle(center: center, radius: myRadius);
              var piePath = Path();
              piePath.moveTo(
                center.dx + (parentRadius * cos(node.myArcStart)),
                center.dy + (parentRadius * sin(node.myArcStart)),
              );
              piePath.addArc(
                innerRect,
                node.myArcStart,
                node.myArcEnd - node.myArcStart,
              );
              piePath.lineTo(
                center.dx + (myRadius * cos(node.myArcEnd)),
                center.dy + (myRadius * sin(node.myArcEnd)),
              );
              piePath.addArc(
                outerRect,
                node.myArcEnd,
                -(node.myArcEnd - node.myArcStart),
              );
              piePath.lineTo(
                center.dx + (parentRadius * cos(node.myArcStart)),
                center.dy + (parentRadius * sin(node.myArcStart)),
              );
              myCanvas.drawPath(
                piePath,
                paint
                  ..style = PaintingStyle.fill
                  ..color = fillColor
                //  ..strokeWidth = hSettings.lineWidth / graphData.scale
                  ,
                ); 
            break;
        }
        _write_if_fits( // Draw the text here so that it appears on top of any decoration
        myCanvas,
        Theme.of(context).textTheme,
        nodeText,
        myAngle,
        parentRadius,
        myRadius,
        (node.myArcEnd - node.myArcStart),
        center,
        Theme.of(context).colorScheme.onSurface,
        Color(0x00000000), // transparent background for text
        false
      );
      }
      if (!textFit && node.ranknum != startLevel) {
        // There isn't enough space to fit the data for the node, so turn it into a pie wedge out to the edge of
        // graph
        // There's never enough space to do this for the root node, so don't try
print("node=${node.name}, majorcolor=$majorColor, minorcolor=$minorColor ");
        drawChildren =
            false; // don't bother with children, since there won't be space
        var piePath = Path();
        var outerRadius = startRadius + ((maxLevel - startLevel) * radPerLevel);
        // define the rectangles we'll use to draw the inner and outer arcs of the pie wedge
        var innerRect = Rect.fromCircle(center: center, radius: parentRadius);
        var outerRect = Rect.fromCircle(center: center, radius: outerRadius);
        // and draw the wedge
        piePath.moveTo(
          center.dx + (parentRadius * cos(node.myArcStart)),
          center.dy + (parentRadius * sin(node.myArcStart)),
        );
        piePath.addArc(
          innerRect,
          node.myArcStart,
          node.myArcEnd - node.myArcStart,
        );
        piePath.lineTo(
          center.dx + (outerRadius * cos(node.myArcEnd)),
          center.dy + (outerRadius * sin(node.myArcEnd)),
        );
        piePath.addArc(
          outerRect,
          node.myArcEnd,
          -(node.myArcEnd - node.myArcStart),
        );
        piePath.lineTo(
          center.dx + (parentRadius * cos(node.myArcStart)),
          center.dy + (parentRadius * sin(node.myArcStart)),
        );

        /*myCanvas.drawPath(
          piePath,
          paint
            ..style = PaintingStyle.stroke
            ..color = fillColor,
        );*/ 
    if (hSettings.addPatterns) { // add patterns to assist color-blind users
        // By default, patterns have a fixed number of features.  This should scale the number of features proportionally to the size of the area being filled
        int featuresCount =  (((outerRadius-parentRadius)/(maxLevel *radPerLevel))* 50).round();

        final Pattern p2 = Pattern.fromValues(patternType: patternType, fgColor: patternFg, bgColor: patternBg, featuresCount: featuresCount);

        p2.paintOnPath(myCanvas, size, piePath);
         // and see if we can fit the text in the outer edge of the wedge
        _write_if_fits(
          myCanvas,
          Theme.of(context).textTheme,
          nodeText,
          myAngle,
          parentRadius,
          (maxLevel - startLevel) * radPerLevel,
          (node.myArcEnd - node.myArcStart),
          center,
          Color(0xffffffff),
          Color(0xff000000),
          true,
        );
    } else { // don't
       myCanvas.drawPath(
          piePath,
          paint
            ..style = PaintingStyle.fill
            ..color = fillColor,
        ); 
         // and see if we can fit the text in the outer edge of the wedge
        _write_if_fits(
          myCanvas,
          Theme.of(context).textTheme,
          nodeText,
          myAngle,
          parentRadius,
          (maxLevel - startLevel) * radPerLevel,
          (node.myArcEnd - node.myArcStart),
          center,
          fillTextColor,
          Color(0x00000000), // transparent background for text
          true
        );
    }
        // now, add the region for the node to each level in the wedge outside the
        //node's actual level
        for (int level = node.ranknum; level <= maxLevel; level++) {
          graphData.trackRegions.addRegion(
            level - startLevel,
            Region(node.myArcStart, node.myArcEnd, nodeId),
          );
        }

       
      }
    }
    if (drawChildren) {
      double arcPerChild =
          (node.myArcEnd - node.myArcStart) / max(node.hitsBelow, 1);
      if (node.children.length > 1) {
        // Need to draw the arc for this node
        var rect = Rect.fromCircle(center: center, radius: myRadius);

        double arcStart =
            node.myArcStart +
            (graph[node.children[0].toInt()]!.hitsBelow) * arcPerChild; 
        double arcEnd =
            node.myArcEnd; -
            (graph[node.children[node.children.length - 1].toInt()]!
                    .hitsBelow) *
                arcPerChild;
        double sweep = node.myArcEnd - node.myArcStart;
        myCanvas.drawArc(
          rect,
          node.myArcStart,
          sweep,
          false,
          paint
            ..style = PaintingStyle.stroke
            ..color = fillColor
            ..strokeWidth = hSettings.lineWidth / graphData.scale,
        );
      }

      double lastEnd = node.myArcStart;
      var i = 0;
      for (var childId in node.children) {
        if (node.ranknum == startLevel) {
          majorColor = i % numColors;
          minorColor = 0;
        }
        else{
          minorColor = (minorColor + 1) % shadesPerColor;
        }
        var childNode = graph[childId.toInt()]!;
        childNode.myArcStart = lastEnd;
        childNode.myArcEnd = lastEnd + (arcPerChild *childNode.hitsBelow);
        lastEnd = childNode.myArcEnd;

        drawNode(
          graph,
          childId.toInt(),
          nodeId,
          center,
          startRadius,
          radPerLevel,
          startLevel,
          maxLevel,
          myCanvas,
          majorColor,
          minorColor,
          paint,
          size,
        );
        i += 1;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    const rootFrac = 0.025;
    var paint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    final double logicalWidth = size.width; // * devicePixelRatio;
    final double logicalHeight = size.height; // * devicePixelRatio;
    final logicalSize = Size(logicalWidth, logicalHeight);
    final double logicalRadius = graphRadius; // * devicePixelRatio;

    int drawnLevels;
    final Canvas logicalCanvas = canvas;
    if (graphData.graph[graphData.currentRoot] != null) {
      drawnLevels = min(
      (graphData.depth - graphData.graph[graphData.currentRoot]!.ranknum),
      graphData.maxLevels,
    );}
    else{
      drawnLevels = 0;
    }
    double radPerLevel;

    if (drawnLevels != 0) {
      // Here the drawnLevels -0.75 is drawnlevels -1 full levels + 0.25 for the root node
      radPerLevel =
          (1 - rootFrac) *
          logicalRadius /
          (drawnLevels - 1); // How much radius to add per level of the graph
      graphData.radPerLevel = radPerLevel;
    } else {
      // avoid divide-by-zero
      radPerLevel = 0.0;
      graphData.radPerLevel = 0.0;
    }
    var center = Offset(logicalSize.width / 2, logicalSize.height / 2);
    int maxLevel;
    Node root; 
    
    if(graphData.graph[graphData.currentRoot] != null){
      maxLevel =
        (graphData.graph[graphData.currentRoot]!.ranknum + drawnLevels) - 1;
      root = graphData.graph[graphData.currentRoot]!;
  
    graphData.rootRadius = rootFrac * logicalRadius;
    root.myArcStart = 0.0;
    root.myArcEnd = 2 * pi;
    logicalCanvas.drawCircle(
      center,
      logicalRadius,
      paint
        ..style = PaintingStyle.fill
        ..color = Theme.of(context).colorScheme.surface,
    );
    paint.style = PaintingStyle.stroke;
    drawNode(
      graphData.graph,
      graphData.currentRoot,
      graphData.currentRoot,
      center,
      0.025 * logicalRadius,
      radPerLevel,
      root.ranknum,
      maxLevel,
      logicalCanvas,
      0,
      0,
      paint,
      size,
    );
    }
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) {
    return oldDelegate.graphData != graphData ||
        oldDelegate.graphRadius != graphRadius;
  }
}

// Class that describes a pie-shaped region of the graph on screen
class Region {
  double _startAngle;
  double _endAngle;
  PlatformInt64 _nodeId; // The node that this region represents
  Region(this._startAngle, this._endAngle, this._nodeId);

  double get startAngle => _startAngle;
  double get endAngle => _endAngle;
  PlatformInt64 get nodeId => _nodeId;
  void set startAngle(double val) => _startAngle = val;
  void set endAngle(double val) => _endAngle = val;
  void set nodeId(PlatformInt64 val) => _nodeId = val;
}

// Class to track regions of the graph at different radius levels
// code assumes that each radius level is completely occupied by regions once
// the data structure is fully populated
class TrackRegions {
  int _numLevels; // Number of radius levels being tracked
  List<List<Region>>
  _radii; // List of lists of regions, one list per radius level

  TrackRegions(this._numLevels)
    : _radii = List.generate(_numLevels, (index) => <Region>[]);
  addRegion(int level, Region region) {
    if (level < 0 || level >= _numLevels) {
      throw RangeError(
        'Level $level is out of bounds for TrackRegions with $_numLevels levels.',
      );
    }
    // expect that the common case will be adding regions in order, so check the end first
    if (_radii[level].isEmpty ||
        _radii[level].last.startAngle <= region.startAngle) {
      _radii[level].add(region);
      return;
    }

    // If not inserting at the end, find the right place for the new region
    int insertIndex = _radii[level].indexWhere(
      (r) => r.startAngle > region.startAngle,
    );
    if (insertIndex == -1) {
      _radii[level].add(region);
    } else {
      _radii[level].insert(insertIndex, region);
    }
  }

  // wrapper around binary search to find the region at a given level and angle
  // and return its nodeId
  PlatformInt64 findNode(
    double xPos,
    double yPos,
    double centerX,
    double centerY,
    double radPerLevel,
    double rootRadius,
  ) {
    // Convert the cartesian coords to an angle.  Both flutter Y-coordinates and angles are flipped
    // around the X-axis, which cancels as far as atan is concerned
    double angle = 0.0;
    double dx = xPos - centerX;
    double dy = yPos - centerY;

    double radius = sqrt((dx * dx) + (dy * dy));
    int level = 0;
    if (radius > rootRadius) {
      // 0 level has radius <= rootRadius
      level = ((radius - rootRadius) / radPerLevel).ceil();
    }
    if (level >= _radii.length) {
      // click outside graph region
      return -1;
    }
    //print("radius = $radius, radPerLevel=$radPerLevel");
    if (xPos != centerX) {
      // avoid divide-by-zero

      double baseAngle = atan(dy / dx);

      // now, account for the fact that atan has limited range
      if (dx > 0 && dy >= 0) {
        // quadrant 1
        angle = baseAngle;
      }
      if (dx > 0 && dy < 0) {
        // Quadrant 4 because of flipped axis
        angle = baseAngle + 2 * pi;
      }
      if (dx < 0) {
        // quadrant 2 or 3
        angle = baseAngle + pi;
      }
      if (angle < 0 || angle > 2 * pi) {
        print("illegal angle of ${angle} generated");
      }
    } else {
      // define the angle of the origin point as 0. Won't matter, because the center node
      // has radius = 0 angle from 0 to 2pi
      if (yPos > centerY) {
        angle = pi / 2;
      } else if (yPos < centerY) {
        angle = 3 * pi / 2;
      }
    }

    if (level < 0 || level >= _numLevels) {
      throw RangeError(
        'Level $level is out of bounds for TrackRegions with $_numLevels levels.',
      );
    }
    int max = _radii[level].length - 1;
    List<Region> theLevel = _radii[level];
    /*print("Searching Level $level, which contains nodes");
      for (int i = 0; i < theLevel.length; i++){
        print("${theLevel[i].startAngle}, ${theLevel[i].endAngle}, ${theLevel[i].nodeId}");
      }*/
    if (theLevel[0].startAngle > angle || theLevel[max].startAngle <= angle) {
      return theLevel[max].nodeId; // angle lies in the wrap-around region
    }
    return _binarySearch(theLevel, angle, 0, max);
  }

  // Standard binary search algorithm adapted for our needs
  PlatformInt64 _binarySearch(
    List<Region> regions,
    double angle,
    int min,
    int max,
  ) {
    //print("Binary searching $min $max");
    if (min > max) {
      throw RangeError("Binary search failed to find angle $angle ");
    }
    int mid = (min + max) >> 1; // Divide by 2
    if (regions[mid].startAngle <= angle &&
        regions[mid + 1].startAngle > angle) {
      return regions[mid].nodeId;
    } else if (regions[mid].startAngle > angle) {
      return _binarySearch(regions, angle, min, mid - 1);
    } else {
      return _binarySearch(regions, angle, mid + 1, max);
    }
  }
}
