import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hviewer/src/rust/api/simple.dart';
import 'package:hviewer/src/rust/api/results_overview.dart';
import 'package:hviewer/src/rust/frb_generated.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MyApp());
}

ThemeData _hTheme(brightness) {
  return ThemeData(
    brightness: brightness,
    primaryColor: Colors.black,
    fontFamily: 'FiraMono',
    textTheme: TextTheme(bodyMedium: TextStyle(fontSize:16)),
  );
}
class MyApp extends StatelessWidget {
    const MyApp({super.key});
  final SigCategory testCategory = const SigCategory(
                              numHits: 12,
                              signature: "domain1-averylongdomainname",
                              example: Hit(name: "seq1",
                              domains: const [
                                const Domain(name: "domain1", start: 1, end: 10, evalue: 12.0),
                                const Domain(name: "averylongdomainname", start: 11, end: 20, evalue: 12.0),
                              ],
                              queries: const[
                                const Domain(name: "query1", start: 5, end: 15, evalue: 0.01),
                                const Domain(name: "averylongqueryname", start: 16, end: 30, evalue: 0.001),
                              ],
                              sequence: "ACGTACGTACGTACGTACGTACGTACGTACGTACGTACGT",
                                          ),
                              );

  @override
  Widget build(BuildContext context) {
    var annotation_file= "?";
    var domtblout_file = "?";
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _hTheme(Brightness.light),
      home: Scaffold(
  
 
        body: Center(
          child: DrawOverview(overview: ResultsOverview(numHits: 48, numCategories: 4, categories: [testCategory, testCategory, testCategory, testCategory]),
                            ),
      ),
    ),);
  }
}

class DrawHit extends StatefulWidget{
  const DrawHit({
    super.key,
    required this.hit,
  });
  final Hit hit;
  State<DrawHit> createState() => _DrawHitState();

}

class _DrawHitState extends State<DrawHit> {
  final GlobalKey key = GlobalKey();
  ScrollController _scrollController = new ScrollController();
  Size textSize = Size(0, 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _calculateRenderBoxWidth());
  }

   void _calculateRenderBoxWidth() {
    final RenderBox? renderBox =
        key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      setState(() {
        textSize = renderBox.size;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final TextStyle textStyle = TextStyle(
      color: Colors.black,
      fontSize: 16,
      fontFamily: 'FiraMono',
    );
    return SizedBox(
      width: MediaQuery.sizeOf(context).width,
      child:  IntrinsicHeight (
          child: 
            Row(
              children: [
                Center(
                  child: 
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children:[
                          Text("Sequence: "+ widget.hit.name, style: textStyle),
                          Text("Domain Structure:", style: textStyle),
                          Text("Query Hits:", style: textStyle),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Scrollbar(
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    child: Column(children: [
                      Text(widget.hit.sequence, style: textStyle, key: key),
                      DrawDomains(seqlength: widget.hit.sequence.length, domains: widget.hit.domains, dimensions: textSize, queries: widget.hit.queries),
                        ],),
                  ),
              ),
                ),
          ]),
        ),
      );
  }
}


/// DrawDomains: draws a representation of the domains that a sequence contains
class DrawDomains extends StatelessWidget {
  const DrawDomains({
    super.key,
    required this.seqlength,
    required this.domains,
    required this.dimensions,
    required this.queries,
  });

  //final List<Domain> domains;
  final int seqlength;
  final List<Domain> domains;
  final Size dimensions;
  final List<Domain> queries;

  @override
  Widget build(BuildContext context) {
    final widthPerChar = dimensions.width / seqlength;
    final height = dimensions.height;
    final width = dimensions.width;
    return Container(
      child: CustomPaint(
      size: Size(width, height*2 + 4.0),
      painter: DomainPainter(domains: domains, widthPerChar: widthPerChar, height: height, queries: queries),
      ),  
      );
  }

}

class DomainPainter extends CustomPainter {
  final List<Domain> domains;
  final double widthPerChar;
  final double height;
  final List<Domain> queries;

  DomainPainter({
    required this.domains,
    required this.widthPerChar,
    required this.height,
    required this.queries
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    // Draw domain structure of the sequence that the hit matched
    for (final domain in domains) {
      final double start = domain.start*widthPerChar;
      final double end = domain.end * widthPerChar;
      final double domainWidth = end - start;
      final RRect rect = RRect.fromRectAndRadius(Rect.fromLTWH(start, 0, domainWidth, height), const Radius.circular(5));
      canvas.drawRRect(rect, paint);

      TextPainter painter;
      painter = TextPainter(
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      String name = "";
      double textOffset = 0.0;
      if (domain.name.length <=domain.end - domain.start){
        name = domain.name;
        textOffset = ((((domain.end - domain.start) - domain.name.length)) / 2 * widthPerChar);
      }
      else{
        name = domain.name.substring(0, domain.end - domain.start);
        textOffset = 0;
      }
      painter.text= TextSpan(
        text: name,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontFamily: 'FiraMono',
        ),
      );
      painter.layout();
      Offset position = Offset(start+textOffset, 0);
      painter.paint(canvas, position);
    }
    // add the representation of the hit(s) to the sequence
      for (final query in queries) {
      final double start = query.start*widthPerChar;
      final double end = query.end * widthPerChar;
      final double domainWidth = end - start;
      final RRect rect = RRect.fromRectAndRadius(Rect.fromLTWH(start, height+4.0, domainWidth, height), const Radius.circular(5));
      canvas.drawRRect(rect, paint..color = Colors.blue);

      TextPainter painter;
      painter = TextPainter(
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      String name = "";
      double textOffset = 0.0;
      if (query.name.length <=query.end - query.start){
        name = query.name;
        textOffset = ((((query.end - query.start) - query.name.length)) / 2 * widthPerChar);
      }
      else{
        name = query.name.substring(0, query.end - query.start);
        textOffset = 0;
      }
      painter.text= TextSpan(
        text: name,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontFamily: 'FiraMono',
        ),
      );
      painter.layout();
      Offset position = Offset(start+textOffset, height+4.0);
      painter.paint(canvas, position);
      }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


// Widget to display the information for a category of hits
class DrawCategory extends StatelessWidget {
  const DrawCategory({
    super.key,
    required this.category,
  });

  final SigCategory category;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:() {print("button pressed");},
      hoverColor: Colors.green,
      child:
        Padding(
          padding: EdgeInsets.all(4),
          child: Material(
            elevation: 2.0,
            shadowColor: Colors.black,
            child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: Colors.black),
              ),
            child:
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.numHits.toString() + " hits with domain signature " + category.signature),
                  Text("Example: "),
                  DrawHit(hit: category.example),
                ],
              ),
          ), 
        ),
        ),
    );
  }
}

// Widget that displays the results overview
class DrawOverview extends StatefulWidget {
  const DrawOverview({
    super.key,
    required this.overview,
  });

  final ResultsOverview overview;

  State<DrawOverview> createState() => _DrawOverviewState();
}
class _DrawOverviewState extends State<DrawOverview> {
  ScrollController _scrollController2 = new ScrollController();
  @override
  Widget build(BuildContext context) {
   return Column(children: [
    Text(widget.overview.numHits.toString()+ " hits found, with "+widget.overview.numCategories.toString()+" different domain signatures."),
    Expanded( 
      child: Scrollbar(
        controller: _scrollController2,
        child: ListView.builder(
          controller: _scrollController2,
        itemCount: widget.overview.numCategories,
        itemBuilder: (BuildContext context, int index){
          return DrawCategory(category: widget.overview.categories[index]);
        }
        ),
      ),
    ),
    ]
    );
  }
}
             