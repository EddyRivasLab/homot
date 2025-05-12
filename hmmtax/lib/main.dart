import 'package:flutter/material.dart';
import 'package:hmmtax/src/rust/api/simple.dart';
import 'package:hmmtax/src/rust/frb_generated.dart';
import 'package:hmmtax/src/rust/api/graph.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('flutter_rust_bridge quickstart')),
        body: Center(
          child: DrawGraph(),
          ),
        ),
    );
  }
}
class DrawGraph extends StatelessWidget {
  const DrawGraph({super.key});

  @override
  Widget build(BuildContext context) {
    Graph my_graph = fetchGraph(numLevels: BigInt.from(3));
    return Text("Graph had ${my_graph.nodes.length} nodes\n");
  }
}

