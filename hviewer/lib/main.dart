import 'package:flutter/material.dart';
import 'package:hviewer/src/rust/api/simple.dart';
import 'package:hviewer/src/rust/api/results_overview.dart';
import 'package:hviewer/src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MyApp());
}

String _printAnnotation(){
  return("Blorg");
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    var annotation_file= "?";
    var domtblout_file = "?";
    return MaterialApp(
      theme: ThemeData(brightness: Brightness.dark,
      primaryColor: Colors.green
      ),
      home: Scaffold(
  
 
        body: Center(
          child: Sequence(name: "seq1",
          domains: [
            Domain(name: "domain1", start: 1, end: 10),
            Domain(name: "domain2", start: 11, end: 20),
          ],
          sequence: "ACGTACGTACGTACGTACGTACGTACGTACGTACGTACGT",
          ),
        ),
      ),
    );
  }
}

class Sequence extends StatelessWidget{
  const Sequence({
    super.key,
    required this.name,
    required this.sequence,
    required this.domains,
  });

  final String name;
  final String sequence;
  final List<Domain> domains;

  @override
  Widget build(BuildContext context) {
    final TextStyle textStyle = TextStyle(
      color: Colors.green,
      fontSize: 16,
    );
    return Row(children: [
      Text(name, style: textStyle),
      Column(children: [
        Text(sequence, style: textStyle),
        DrawDomains(residues: 20, pixelwidth: 200.0),
      ],)
    ],);
  }
}

class DrawDomains extends StatelessWidget {
  const DrawDomains({
    super.key,
   // required this.domains,
    required this.residues,
    required this.pixelwidth,
  });

  //final List<Domain> domains;
  final int residues;
  final double pixelwidth;

  @override
  Widget build(BuildContext context) {
    return Container(width: pixelwidth,
    height: 50,
    color: Colors.green,);

  }
}