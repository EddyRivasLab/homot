import 'package:flutter/material.dart';
import 'package:hmmtax/src/rust/api/simple.dart';
import 'package:hmmtax/src/rust/frb_generated.dart';
import 'package:hmmtax/src/rust/api/graph.dart';
import"dart:math";
import 'package:touchable/touchable.dart';
import 'package:provider/provider.dart';


ColorScheme lightScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff5475b4),
    primary: const Color(0xff5475b4),
    secondary: const Color(0xff9e0142),
    surface: const Color(0xffffffff),
    error: const Color(0xfff46d43),
    onPrimary: const Color(0xffffffff),
    onSecondary: const Color(0xffffffff),
    onSurface: const Color(0xff000000),
    onError: const Color(0xffffffff),
  );

ColorScheme darkScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff5475b4),
    primary: const Color(0xff5475b4),
    secondary: const Color(0xff9e0142),
    surface: const Color(0xff000000),
    error: const Color(0xfff46d43),
    onPrimary: const Color(0xffffffff),
    onSecondary: const Color(0xffffffff),
    onSurface: const Color(0xffffffff),
    onError: const Color(0xff000000),
  );


Future<void> main() async {
  await RustLib.init();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Map<int, Node> my_graph = fetchGraph(databasePath: "/Users/npcarter/annotation_data/taxid_test");
    return MaterialApp(
      home: Scaffold(
       // appBar: AppBar(title: const Text('flutter_rust_bridge quickstart')),
        body: Center(
          child: Text("Hello, world")
        ),),);
      }
  }
