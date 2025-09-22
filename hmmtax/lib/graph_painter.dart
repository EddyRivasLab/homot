import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:hmmtax/main.dart';
import 'package:hmmtax/utility.dart';
import 'package:touchable/touchable.dart';
import 'package:hmmtax/src/rust/api/graph.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

// List of pairs of background and foregrund colors for displaying
// domains.  Taken from the ColorBrewer example color sets.
// Folmat is (BGcolor, FG color)
const domainColors = [
  (Color(0xff9e0142), Color(0xffffffff)),
  (Color(0xff40004b), Color(0xffffffff)),
  (Color(0xff006837), Color(0xffffffff)),
  (Color(0xffd53e4f), Color(0xffffffff)),
  (Color(0xff1a9850), Color(0xffffffff)),
  (Color(0xff0000ff), Color(0xffffffff)),
  (Color(0xfff46d43), Color(0xffffffff)),
  (Color(0xff6a3d9a), Color(0xffffffff)),
  (Color(0xffabd9e9), Color(0xff000000)),
  (Color(0xff68bd63), Color(0xffffffff)),
  (Color(0xfffdae61), Color(0xffffffff)),
  (Color(0xffff0000), Color(0xff000000)),
  (Color(0xfffee08b), Color(0xff000000)),
  (Color(0xffbc80bd), Color(0xff000000)),
  (Color(0xffffffbf), Color(0xff000000)),
  (Color(0xffa6d96a), Color(0xff000000)),
  (Color(0xffcab2d6), Color(0xff000000)),
  (Color(0xfffdaaac), Color(0xff000000)),
  (Color(0xff00ff00), Color(0xff000000)),
];
class GraphPainter extends CustomPainter {
  final BuildContext context;
  final GraphData graphData;
  final double devicePixelRatio;
  final TransformationController tController;
  final double graphRadius;
  GraphPainter(this.context, this.graphData, this.devicePixelRatio, this.tController, this.graphRadius);


  // Recursive function to draw a node and its children
  void drawNode(Map<PlatformInt64, Node> graph, PlatformInt64 nodeId, PlatformInt64 parentId, Offset center, double startRadius, double radPerLevel, 
    int startLevel, int maxLevel, Canvas myCanvas, Color myColor, Paint paint) {

    if (nodeId == parentId){ // This is the root node of the current graph, so reset the trackRegions structure
      graphData.trackRegions = TrackRegions(1+maxLevel-startLevel);
    }

    var node = graph[nodeId]!;
    // Add the node's region to the trackRegion structure
    graphData.trackRegions.addRegion(node.ranknum - startLevel, Region(node.myArcStart, node.myArcEnd, nodeId));
    var parent = graph[parentId]!;
    bool drawChildren = node.ranknum < maxLevel;
    double scaleFactor = tController.value.getMaxScaleOnAxis();
    var myRadius = startRadius + ((node.ranknum - startLevel) * radPerLevel);
    if (!drawChildren){ // Handle the case where this node would be off the edge
      myRadius = maxLevel * radPerLevel;
    }
    
    var myAngle = (node.myArcStart + node.myArcEnd) / 2;
    var myOffset = Offset(center.dx + (myRadius * cos(myAngle)), center.dy + (myRadius * sin(myAngle)));
    // Note: In Flutter, the y-axis increases downward, and angles increase clockwise, not counter-clockwise so we add sin(myAngle) to the y-coordinate.

    var parentRadius = startRadius + ((parent.ranknum - startLevel) * radPerLevel);
   
    var parentOffset = Offset(center.dx + (parentRadius * cos(myAngle)), center.dy + (parentRadius * sin(myAngle)));
    myCanvas.drawLine(parentOffset, myOffset, paint..strokeWidth=2.0/scaleFactor);
   // _addButton(buttons, node.name,  myOffset.dx/devicePixelRatio-20, myOffset.dy/devicePixelRatio-10, 40, 20, (){print("Node ${node.name} clicked");});

    if (drawChildren){
      double arcPerChild  = (node.myArcEnd - node.myArcStart) / max(node.totalDescendants, 1);
      if (node.children.length >1){ // Need to draw the arc for this node  
        var rect = Rect.fromCircle(center: center, radius: myRadius);

        // the +1's in this calculation are to leave some space between the outer nodes of the graph
        double arcStart = node.myArcStart + (graph[node.children[0].toInt()]!.totalDescendants+1) * arcPerChild / 2;
        double arcEnd = node.myArcEnd - (graph[node.children[node.children.length -1].toInt()]!.totalDescendants+1) * arcPerChild / 2;
        double sweep = arcEnd - arcStart;
        myCanvas.drawArc(rect, arcStart, sweep, false, paint..style = PaintingStyle.stroke..color = myColor..strokeWidth=2.0/scaleFactor);

      }

      double lastEnd = node.myArcStart;
      var i =0;
      for (var childId in node.children) {
        if (node.ranknum == startLevel){
          myColor = domainColors[i % domainColors.length].$1;
          i += 1;
        }
        paint.color = myColor;
        var childNode = graph[childId.toInt()]!;
        childNode.myArcStart = lastEnd;
        childNode.myArcEnd = lastEnd + (arcPerChild * (childNode.totalDescendants+1));
        lastEnd = childNode.myArcEnd;
        
        drawNode(graph, childId.toInt(), nodeId, center, startRadius, radPerLevel, startLevel, maxLevel, myCanvas, myColor, paint);
      }
    }   
  }


  @override
  void paint(Canvas canvas, Size size) {

    var paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final recorder = ui.PictureRecorder();
    final double logicalWidth = size.width * devicePixelRatio;
    final double logicalHeight = size.height * devicePixelRatio;
    final logicalSize = Size(logicalWidth, logicalHeight);
    final double logicalRadius = graphRadius * devicePixelRatio;

    final Canvas logicalCanvas = Canvas(recorder);
    //logicalCanvas.scale(devicePixelRatio);

   // var myCanvas = TouchyCanvas(context, logicalCanvas);

    var drawnLevels = min((graphData.depth - graphData.graph[graphData.root]!.ranknum), graphData.maxLevels);
    var radPerLevel = logicalRadius / drawnLevels; // How much radius to add per level of the graph
    graphData.radPerLevel = graphRadius/drawnLevels; // graphdata's radPerLevel should be in graph units, not screen
    var center = Offset(logicalSize.width / 2, logicalSize.height / 2);
    var maxLevel = graphData.graph[graphData.root]!.ranknum + drawnLevels;

    var root = graphData.graph[graphData.root]!;

    root.myArcStart = 0.0;
    root.myArcEnd = 2 * pi;
    logicalCanvas.drawCircle(center, logicalRadius, paint..style = PaintingStyle.fill..color = Theme.of(context).colorScheme.surface);
    paint.style = PaintingStyle.stroke;
    drawNode(graphData.graph, graphData.root, graphData.root, center, 0, radPerLevel, root.ranknum, maxLevel, logicalCanvas,  Theme.of(context).colorScheme.onSurface, 
    paint);
    final ui.Picture picture = recorder.endRecording();
    canvas.scale(1 / devicePixelRatio);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    //canvas.rotate(graphData.rotation);
    canvas.translate(-1 *center.dx, -1* center.dy);
    canvas.drawPicture(picture);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) {
    return oldDelegate.graphData != graphData || oldDelegate.graphRadius != graphRadius;
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
    List<List<Region>> _radii; // List of lists of regions, one list per radius level
    
    TrackRegions(this._numLevels) : _radii = List.generate(_numLevels, (index) => <Region>[]);
    addRegion(int level, Region region) {
      if (level < 0 || level >= _numLevels) {
        throw RangeError('Level $level is out of bounds for TrackRegions with $_numLevels levels.');
      }
      // expect that the common case will be adding regions in order, so check the end first  
      if (_radii[level].isEmpty || _radii[level].last.startAngle <= region.startAngle) {
        _radii[level].add(region);
        return;
      }

      // If not inserting at the end, find the right place for the new region
      int insertIndex = _radii[level].indexWhere((r) => r.startAngle > region.startAngle);
      if (insertIndex == -1) {
        _radii[level].add(region);
      } else {
        _radii[level].insert(insertIndex, region); 
      }
    }

    // wrapper around binary search to find the region at a given level and angle
    // and return its nodeId
    PlatformInt64 findNode(double xPos, double yPos, double centerX, double centerY, double radPerLevel) {
      // Convert the cartesian coords to an angle.  Both flutter Y-coordinates and angles are flipped
      // around the X-axis, which cancels as far as atan is concerned
      double angle = 0.0;
      double dx = xPos -centerX;
      double dy = yPos -centerY;

      double radius = sqrt((dx * dx) + (dy * dy));
      int level = (radius/radPerLevel).ceil();
      print("radius = $radius, radPerLevel=$radPerLevel");
      if (xPos != centerX){ // avoid divide-by-zero

        double baseAngle = atan(dy/dx);
        
        // now, account for the fact that atan has limited range
        if (dx > 0 && dy >=0){ // quadrant 1
          angle = baseAngle;
        }
        if (dx > 0 && dy <0){
          // Quadrant 4 because of flipped axis
          angle = baseAngle + 2*pi;
        }
        if(dx <0){
          // quadrant 2 or 3
          angle = baseAngle +pi;
        }
        if(angle <0 || angle > 2*pi){
          print("illegal angle of ${angle} generated");
        }
      }
      else{ // define the angle of the origin point as 0. Won't matter, because the center node
      // has radius = 0 angle from 0 to 2pi
        if(yPos > centerY) {
          angle = pi/2;
        }
        else if(yPos < centerY){
          angle = 3*pi/2;
        }
      }

      if (level < 0 || level >= _numLevels) {
        throw RangeError('Level $level is out of bounds for TrackRegions with $_numLevels levels.');
      }
      int max = _radii[level].length - 1;
      List<Region> theLevel = _radii[level];
      print("Searching Level $level, which contains nodes");
      for (int i = 0; i < theLevel.length; i++){
        print("${theLevel[i].startAngle}, ${theLevel[i].endAngle}, ${theLevel[i].nodeId}");
      }
      if (theLevel[0].startAngle > angle || theLevel[max].startAngle <= angle) {
        return theLevel[max].nodeId; // angle lies in the wrap-around region
      }
      return _binarySearch(theLevel, angle, 0, max);
    }

    // Standard binary search algorithm adapted for our needs
    PlatformInt64
    _binarySearch(List<Region> regions, double angle, int min, int max) {
      print("Binary searching $min $max");
      if (min > max) {
        throw RangeError("Binary search failed to find angle $angle ");
      }
      int mid = (min + max) >> 1; // Divide by 2
      if (regions[mid].startAngle <= angle && regions[mid + 1].startAngle > angle) {
        return regions[mid].nodeId;
      } else if (regions[mid].startAngle > angle) {
        return _binarySearch(regions, angle, min, mid - 1);
      } else {
        return _binarySearch(regions, angle, mid + 1, max);
      }
    }
}