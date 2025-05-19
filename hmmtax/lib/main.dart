import 'package:flutter/material.dart';
import 'package:hmmtax/src/rust/api/simple.dart';
import 'package:hmmtax/src/rust/frb_generated.dart';
import 'package:hmmtax/src/rust/api/graph.dart';
import"dart:math";
import 'package:touchable/touchable.dart';
import 'package:provider/provider.dart';


Future<void> main() async {
  await RustLib.init();
  runApp(ChangeNotifierProvider(
    create: (_)=> GraphState(),
    child: MyApp(),
    ));
}

class GraphState with ChangeNotifier{

  BigInt _root = BigInt.from(0);

  BigInt get root => _root;

  void set root(BigInt root){
     _root = root;
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Graph my_graph = fetchGraph(numLevels: BigInt.from(8));
    return Consumer<GraphState>(
      builder: (context, graphState, child){ 
    
        return MaterialApp(
      home: Scaffold(
       // appBar: AppBar(title: const Text('flutter_rust_bridge quickstart')),
        body: Center(
          child: DrawGraph(graph: my_graph, root: graphState.root,
          ),
        ),),);
      });
  }
}

class DrawGraph extends StatelessWidget {
  const DrawGraph({
    super.key,
    required this.graph,
    required this.root,
    });

  final Graph graph;
  final BigInt root;
  

  @override
  Widget build(BuildContext context) {
    return Container(
      child: CanvasTouchDetector(
        gesturesToOverride:[GestureType.onTapDown],
        builder: (context) => 
        CustomPaint(
        size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
        painter: GraphPainter(graph: graph, startWidth: MediaQuery.of(context).size.width, startHeight: MediaQuery.of(context).size.height
        -(kToolbarHeight + MediaQuery.of(context).padding.top + kBottomNavigationBarHeight),
        root: root, 
        heightPerLeaf: 
          MediaQuery.of(context).size.height/graph.leavesPerLevel[min(graph.numLevels.toInt(), maxLevels)-1].toDouble(),
          context: context),
      ),
      ),
    );
  }
}


int maxLevels = 5;
// This is the maximum number of levels to be drawn in the graph
class GraphPainter extends CustomPainter {
  const GraphPainter({required this.graph, required this.startWidth, required this.startHeight, required this.heightPerLeaf, 
  required this.root, required this.context});
  final Graph graph;
  final double startWidth;
  final double startHeight;
  final double heightPerLeaf;
  final BigInt root;
  final BuildContext context;

  void _paintSubtree(Graph graph, BigInt root, int level, double top, double bottom, double left, double right, double widthPerLevel,
  double heightPerLeaf, TouchyCanvas canvas, Canvas origCanvas, Paint paint) {
    if (level > maxLevels){ //leave, as we're too deep 
      return;
    }
    // First, draw the line corresponding to the root node
    canvas.drawLine(Offset(left, top + (bottom-top)/2), Offset(left+widthPerLevel, 
    top+(bottom-top)/2), paint..color = Colors.black);
    canvas.drawCircle(Offset(left+widthPerLevel, top+(bottom-top)/2), 10, paint..color=Colors.orange..style=PaintingStyle.fill,
    onTapDown: (tapdetail) {
      print("poked, root = ${root}");
      Provider.of<GraphState>(context, listen:false ).root= root;
      },
    );
    // Then, draw the sub-trees, if any
    double heightUsed = 0.0;
    double barstart = 0.0;
    double barend = 0.0;
    
    print("GraphPainter called with root ${root}");
    for (int i = 0; i< graph.nodes[root.toInt()].children.length; i++) {
      BigInt child = graph.nodes[root.toInt()].children[i];
      double newLeft = left + widthPerLevel;
      double newTop = top + heightUsed;
      double ourHeight = graph.nodes[child.toInt()].numLeaves.toDouble()*heightPerLeaf;
      double newBottom = newTop + ourHeight;
      heightUsed += ourHeight;
      if (i == 0) {
        barstart = newTop+(newBottom-newTop)/2;
      }
      if (i == graph.nodes[root.toInt()].children.length-1) {
        barend = newTop+(newBottom-newTop)/2;
      }
      _paintSubtree(graph, child, level+1, newTop, newBottom, newLeft, right, widthPerLevel, heightPerLeaf, canvas, origCanvas, 
      paint);
    }
    if (!graph.nodes[root.toInt()].children.isEmpty) {
      canvas.drawLine(Offset(left+widthPerLevel, barstart), Offset(left+widthPerLevel, barend), paint..color = Colors.black);
    }
  }


  @override
  void paint(Canvas canvas, Size size) {
    print("Paint called with root ${root.toInt()}");
    var myCanvas = TouchyCanvas(context, canvas);
    Paint paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    _paintSubtree(graph, root, 0, 0.0, size.height, 0.0, size.width,  
    size.width/min(graph.numLevels.toDouble(), maxLevels.toDouble()), 
    size.height/graph.nodes[root.toInt()].numLeaves.toDouble(), myCanvas, canvas, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
