import 'dart:math';
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
  (Color(0xff5475b4), Color(0xffffffff)),
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
  final double graphRadius;

  GraphPainter(this.context, this.graphData, this.graphRadius);

  void drawNode(Map<PlatformInt64, Node> graph, PlatformInt64 nodeId, PlatformInt64 parentId, Offset center, double startRadius, double radPerLevel, 
    int startLevel, int maxLevel, TouchyCanvas myCanvas, Color myColor, Paint paint) {
    var node = graph[nodeId]!;
    var parent = graph[parentId]!;
    bool drawChildren = node.ranknum < maxLevel;

    var myRadius = startRadius + ((node.ranknum - startLevel) * radPerLevel);
    if (!drawChildren){ // Handle the case where this node would be off the edge
      myRadius = maxLevel * radPerLevel;
    }
    
    var myAngle = (node.myArcStart + node.myArcEnd) / 2;
    var myOffset = Offset(center.dx + (myRadius * cos(myAngle)), center.dy + (myRadius * sin(myAngle)));
    // Note: In Flutter, the y-axis increases downward, and angles increase clockwise, not counter-clockwise so we add sin(myAngle) to the y-coordinate.

    var parentRadius = startRadius + ((parent.ranknum - startLevel) * radPerLevel);
   
    var parentOffset = Offset(center.dx + (parentRadius * cos(myAngle)), center.dy + (parentRadius * sin(myAngle)));
    myCanvas.drawLine(parentOffset, myOffset, paint);

    if (drawChildren){
      double arcPerChild  = (node.myArcEnd - node.myArcStart) / max(node.totalDescendants, 1);
      if (node.children.length >1){ // Need to draw the arc for this node  
        var rect = Rect.fromCircle(center: center, radius: myRadius);

        // the +1's in this calculation are to leave some space between the outer nodes of the graph
        double arcStart = node.myArcStart + (graph[node.children[0].toInt()]!.totalDescendants+1) * arcPerChild / 2;
        double arcEnd = node.myArcEnd - (graph[node.children[node.children.length -1].toInt()]!.totalDescendants+1) * arcPerChild / 2;
        double sweep = arcEnd - arcStart;
        myCanvas.drawArc(rect, arcStart, sweep, false, paint);

      }

      double lastEnd = node.myArcStart; // Leave a little space before the first child;
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
    var myCanvas = TouchyCanvas(context, canvas);
    var paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    var drawnLevels = min((graphData.depth - graphData.graph[graphData.root]!.ranknum), graphData.maxLevels);
    var radPerLevel = graphRadius / drawnLevels; // How much radius to add per level of the graph
    var center = Offset(size.width / 2, size.height / 2);
    var maxLevel = graphData.graph[graphData.root]!.ranknum + drawnLevels;

    var root = graphData.graph[graphData.root]!;

    root.myArcStart = 0.0;
    root.myArcEnd = 2 * pi;
    myCanvas.drawCircle(center, graphRadius, paint..style = PaintingStyle.fill);
    paint.style = PaintingStyle.stroke;
    drawNode(graphData.graph, graphData.root, graphData.root, center, 0, radPerLevel, root.ranknum, maxLevel, myCanvas, Colors.black, paint);

  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) {
    return oldDelegate.graphData != graphData || oldDelegate.graphRadius != graphRadius;
  }
}