/* draw_data.dart: routines and widgets to render HMMER-generated data objects in the GUI.
 * Contents:
 * - DrawDomains: draws a representation of the domains that a sequence contains
 * - DomainPainter: custom painter object that draws domains
 * - DrawHit: Displays the data for a single hit 
 * - DrawCategory: Displays the data for a category of hits
NPC: 4/23/25 [The Cushy Office]
*/

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:HMMot/src/rust/api/gather_hits.dart';
import 'package:HMMot/src/rust/frb_generated.dart';
import 'package:HMMot/main.dart';
import 'package:HMMot/utility.dart';
import 'package:provider/provider.dart';
import "package:go_router/go_router.dart";
import 'package:touchable/touchable.dart';


void _addButton(List<Widget> buttons, double top, double bottom, double left, double right, String dName, String dDesc, String cName,
double sEval, double dEval, int sLen, int hLen, int sStart, int sEnd, int hStart, int hEnd, bool query, BuildContext context) {
  String tooltipText = query ? "Query: ${dName}\nDomain e-value:${dEval.toStringAsExponential(2)} Sequence e-value: ${sEval.toStringAsExponential(2)}\nSequence length: ${sLen} HMM length: ${hLen}\nDomain matched sequence positions ${sStart}-${sEnd}\nDomain matched HMM positions: ${hStart}-${hEnd}":
  "Domain: ${dName}\nDescription: ${dDesc} \nClan: C${cName}\nDomain e-value:${dEval.toStringAsExponential(2)} Sequence e-value: ${sEval.toStringAsExponential(2)}\nSequence length: ${sLen} HMM length: ${hLen}\nDomain matched sequence positions ${sStart}-${sEnd}\nDomain matched HMM positions: ${hStart}-${hEnd}";
  buttons.add(Positioned(
    top: top,
    //bottom: bottom,
    left: left,
    //right: right,
    child: Tooltip(
      message: tooltipText,
      textStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
          color: Theme.of(context).colorScheme.onSurface),
        child: Container(width: right - left, height: bottom - top, color: Colors.transparent,),
      ),
    ));
  }
/// DrawDomains: draws a representation of the domains that a sequence contains
class DrawDomains extends StatelessWidget {
  DrawDomains({
    super.key,
    required this.sequence,
    required this.length,
    required this.domains,
    required this.width,
    required this.queries,
    required this.overview,
    required this.seqLength,
    required this.seqEvalue,
    required this.allDomains,
  });

  //final List<Domain> domains;
  final String sequence;
  final int length;
  final List<Domain> domains;
  final double width;
  final List<Domain> queries;
  final OverviewData overview;
  final int seqLength;
  final double seqEvalue;
  final bool allDomains;

  (double, double) _calc_text_dimensions(TextTheme textTheme) {
    // The easiest way to get the dimensions of some
    // text seems to be to try rendering them and then measure the result.
    TextPainter testPainter = TextPainter(
      textAlign: TextAlign.start,
      textDirection: TextDirection.ltr,
    );
    if (allDomains){
      testPainter.text = TextSpan(
      text: "Annotated Domains:",
      style: textTheme.bodyMedium,
    );
    }
    else{
      testPainter.text = TextSpan(
      text: "Domain Structure:",
      style: textTheme.bodyMedium,
    );
    }
    testPainter.layout();
    return (testPainter.width, testPainter.preferredLineHeight);
  }
  List<int> _map_domains_to_rows(List<Domain> domains){
    List<int> rows = [];
    List<List<Pair<int,int>>> Lines = [[]];
    for (var domain in domains){
      bool foundSpot = false;
      for (var i=0; i < Lines.length; i++){
        // first, see if the domain fits at the beginning of the row
        if(Lines[i].length ==0 || domain.seqEnd < Lines[i][0].a){
          Lines[i].insert(0, Pair(domain.seqStart, domain.seqEnd));
          rows.add(i);  // this domain fits in row i
          foundSpot = true;
          break;
        }
        // then, see if it fits at the end 
        if(domain.seqStart > Lines[i][Lines[i].length-1].b){
          // fits at the end of the row
          Lines[i].add(Pair(domain.seqStart, domain.seqEnd));
          rows.add(i);
          foundSpot = true;
          break;
        }
        // If it doesn't fit at the start or the end, see if it fits between existing ones
        for(var j = 0; j< Lines[i].length -1; j++){
          if(domain.seqStart > Lines[i][j].b && domain.seqEnd < Lines[i][j+1].a){
            // fits between items j and J+1
            Lines[i].insert(j+1, Pair(domain.seqStart, domain.seqEnd));
            rows.add(i);
            foundSpot = true;
            break;
          }
        }
      }
      // if we get here without finding a spot, we need to start a new row
      if(!foundSpot){
        rows.add(Lines.length);
        Lines.add([Pair(domain.seqStart, domain.seqEnd)]);
      }
    }
    return rows;
  }
  @override
  Widget build(BuildContext context) {
    double textHeight, textWidth;
    (textWidth, textHeight) =_calc_text_dimensions(Theme.of(context).textTheme);

    var domainRows = _map_domains_to_rows(domains);
    var queryRows = _map_domains_to_rows(queries);
    // now, figure out how many lines are needed for the queries.  This is harder,
    // because they aren't pre-sorted
    var queryStartRow = domainRows.reduce(max) + 1;
    var numLines = queryStartRow + queryRows.reduce(max) + 1;

    List<Widget> buttons = CreateButtons(domains, domainRows, width, (width - textWidth) /length, textWidth, textHeight, queryStartRow, 
    queries, queryRows, seqLength, seqEvalue, context);
    var _myPainter = DomainPainter(
          context: context,
          domains: domains,
          domainRows: domainRows,
          totalWidth: width,
          widthPerChar:
              (width - textWidth) /
              length,
          widthOffset: textWidth,
          heightPerLine: textHeight,
          queryStartRow: queryStartRow,
          queries: queries,
          queryRows: queryRows, 
          overview: overview,
          textTheme: Theme.of(context).textTheme,
          colorScheme: Theme.of(context).colorScheme,
          buttons: buttons,
          allDomains: allDomains,
        );
    return Stack(
      children:<Widget>[CanvasTouchDetector(
        gesturesToOverride: [GestureType.onTapDown],
        builder: (context) =>
        CustomPaint(
        size: Size(
          width,
          textHeight * (numLines* lineSpace + (lineSpace/2)),
        ),
        painter: _myPainter,
      ),),
      ]+buttons,
    );
  }
}

const double lineSpace = 1.4;

List<Widget> CreateButtons(
  final List<Domain> domains,
  final List<int> domainRows,
  final double totalWidth,
  final double widthPerChar,
  final double widthOffset,
  final double heightPerLine,
  final int queryStartRow,
  final List<Domain> queries,
  final List<int> queryRows,
  final int seqLength,
  final double seqEvalue,
  final BuildContext context
){
  List<Widget> buttons = [];
  var row = 0;
  double oldEnd = widthOffset;
  for (var i = 0; i<domains.length; i++) {
    final domain = domains[i];
    final double start = domain.seqStart * widthPerChar + widthOffset;
    final double end = domain.seqEnd * widthPerChar + widthOffset;
    final double domainWidth = end - start;
    _addButton(buttons, ((domainRows[i])* lineSpace + (lineSpace/2)) * heightPerLine, 
    (((queryStartRow+ domainRows[i])* lineSpace + (lineSpace/2)) * heightPerLine) + heightPerLine,  
    start, start + domainWidth, domain.name, domain.description, domain.clan, seqEvalue, domain.domEvalue, seqLength, domain.hmmLength, domain.seqStart, domain.seqEnd, domain.hmmStart,
    domain.hmmEnd, false, context);
  }
  for (var i = 0; i<queries.length; i++) {
    final query = queries[i];
    final double start = query.seqStart * widthPerChar + widthOffset;
    final double end = query.seqEnd * widthPerChar + widthOffset;
    final double domainWidth = end - start;
    _addButton(buttons, ((queryStartRow+ queryRows[i])* lineSpace + (lineSpace/2)) * heightPerLine, 
    (((queryStartRow+ queryRows[i])* lineSpace + (lineSpace/2)) * heightPerLine) + heightPerLine,  
    start, start + domainWidth, query.name, query.description, query.clan, seqEvalue, query.domEvalue, seqLength, query.hmmLength, query.seqStart, query.seqEnd, query.hmmStart,
    query.hmmEnd, true, context);
  }
  return buttons;
}
class DomainPainter extends CustomPainter {
  final BuildContext context;
  final List<Domain> domains;
  final List<int> domainRows;
  final double totalWidth;
  final double widthPerChar;
  final double widthOffset;
  final double heightPerLine;
  final int queryStartRow;
  final List<Domain> queries;
  final List<int> queryRows;
  final OverviewData overview;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  List<Widget> buttons;
  final bool allDomains;

  DomainPainter({
    required this.context,
    required this.domains,
    required this.domainRows,
    required this.totalWidth,
    required this.widthPerChar,
    required this.widthOffset,
    required this.heightPerLine,
    required this.queryStartRow,
    required this.queries,
    required this.queryRows,
    required this.overview,
    required this.textTheme,
    required this.colorScheme,
    required this.buttons,
    required this.allDomains,
  });

  _drawDomains(
    Canvas canvas,
    TouchyCanvas myCanvas,
    Paint paint,
    int startRow,
    List<Domain> domains,
    List<int> domainRows,
    TextTheme textTheme,
    List<Widget> buttons,
  ){
    List<double> lastEnds = List<double>.filled(domainRows.reduce(max)+1, widthOffset);

    for (var i = 0; i<domains.length; i++) {
      final domain = domains[i];
      final double start = domain.seqStart * widthPerChar + widthOffset;
      final double end = domain.seqEnd * widthPerChar + widthOffset;
      final double domainWidth = end - start;
  //    print(domain.name + " " + (startRow+domainRows[i]).toString());
      _draw_domain(
        canvas,
        myCanvas,
        paint,
        Offset(start, ((startRow+ domainRows[i])* lineSpace + (lineSpace/2)) * heightPerLine),
        domainWidth,
        heightPerLine,
        lastEnds[domainRows[i]],
        domain,
        textTheme,
        buttons,
      );
      lastEnds[domainRows[i]] = end;
    }
    for (int j = 0; j < lastEnds.length; j++){
      if (lastEnds[j] < totalWidth) {
        final p1 = Offset(lastEnds[j], ((startRow+j)*lineSpace +(lineSpace/2)) *heightPerLine +(heightPerLine * (lineSpace/2)));
        final p2 = Offset(totalWidth, ((startRow+j)* lineSpace + (lineSpace/2)) * heightPerLine + (heightPerLine * (lineSpace/2)));
        canvas.drawLine(p1, p2, paint..color=Theme.of(context).colorScheme.onSurface..strokeWidth= 2.0);
    }
    }
  }
  
  
   _draw_domain(
    Canvas canvas,
    TouchyCanvas myCanvas,
    Paint paint,
    Offset position,
    double width,
    double height,
    double lastEnd,
    Domain domain,
    TextTheme textTheme,
    List<Widget> buttons,
  ) {
    // First, the line preceeding the domain
    final double start = position.dx;
    if (start > lastEnd) {
      final p1 = Offset(lastEnd, position.dy + (heightPerLine * (lineSpace/2)));
      final p2 = Offset(start, position.dy + (heightPerLine * (lineSpace/2)));
      canvas.drawLine(p1, p2, paint..color = Theme.of(context).colorScheme.onSurface..strokeWidth = 2.0);
    }
    if (width <= height) {
      // domain too small to draw pretty edges
      canvas.drawRect(
        Rect.fromLTWH(position.dx, position.dy, width, height),
        paint..color = overview.get_colors(domain.name).$1..style=PaintingStyle.fill,
      );
      canvas.drawRect(
        Rect.fromLTWH(position.dx, position.dy, width, height),
        paint..color = Theme.of(context).colorScheme.onSurface..style=PaintingStyle.stroke..strokeWidth = 2.0,
      );
    } else {
      // Have enough room to draw the edges we want
      Path path = Path();
      // start at bottom left of domain
      path.moveTo(position.dx + height / 2, position.dy + height);
      if (domain.fullMatchStart) {
        // Round end to start
        Rect oval = Rect.fromLTWH(position.dx, position.dy, height, height);
        path.arcTo(oval, pi / 2, pi, false);
      } else {
        // jagged end
        path.lineTo(position.dx, position.dy + 5 * height / 6);
        path.lineTo(position.dx + height / 2, position.dy + 4 * height / 6);
        path.lineTo(position.dx, position.dy + 3 * height / 6);
        path.lineTo(position.dx + height / 2, position.dy + 2 * height / 6);
        path.lineTo(position.dx, position.dy + 1 * height / 6);
        path.lineTo(position.dx + height / 2, position.dy);
      }
      path.lineTo(
        position.dx + (width - (height / 2)),
        position.dy,
      ); // top edge of domain
      if (domain.fullMatchEnd) {
        // Round end to start
        Rect oval = Rect.fromLTWH(
          position.dx + width - (height),
          position.dy,
          height,
          height,
        );
        path.arcTo(oval, 3 * pi / 2, pi, false);
      } else {
        // jagged end
        path.lineTo(position.dx + width, position.dy + height / 6);
        path.lineTo(
          position.dx + (width - height / 2),
          position.dy + 2 * height / 6,
        );
        path.lineTo(position.dx + width, position.dy + 3 * height / 6);
        path.lineTo(
          position.dx + (width - height / 2),
          position.dy + 4 * height / 6,
        );
        path.lineTo(position.dx + width, position.dy + 5 * height / 6);
        path.lineTo(position.dx + (width - height / 2), position.dy + height);
      }
      path.lineTo(position.dx + height / 2, position.dy + height);
      myCanvas.drawPath(path, paint..color = overview.get_colors(domain.name).$1..style=PaintingStyle.fill,
        // add a gesture recognizer to the domain
      );
    
      myCanvas.drawPath(path, paint..color = Theme.of(context).colorScheme.onSurface..style=PaintingStyle.stroke..strokeWidth = 2.0);
    }
    // Now, add the name of the domain
    TextPainter painter;
    painter = TextPainter(
      textAlign: TextAlign.start,
      textDirection: TextDirection.ltr,
    );
    String name = "";
    double textOffset = position.dx + (width / 2);
    String evalString = domain.domEvalue.toStringAsExponential(2);

    // see if all the data we'd like to display fits in the domain
    name = domain.name + " (" + evalString + ")";
    painter.text =
        painter.text = TextSpan(
          text: name,
          style: textTheme.bodyMedium!.copyWith(
            color: overview.get_colors(domain.name).$2,
          ),
        );
    painter.layout();
    if (painter.width <= (width - heightPerLine)) {
      // -2 to make sure domain extends past name
      Offset textPosition = Offset(textOffset - painter.width / 2, position.dy);
      painter.paint(canvas, textPosition);
    } else {
      //see if the domain name fits
      name = domain.name;
      painter.text = TextSpan(
        text: name,
        style: textTheme.bodyMedium!.copyWith(
          color: overview.get_colors(domain.name).$2,
        ),
      );
      painter.layout();
      if (painter.width <= (width - heightPerLine)) {
        // -2 to make sure domain extends past name
        Offset textPosition = Offset(
          textOffset - painter.width / 2,
          position.dy,
        );
        painter.paint(canvas, textPosition);
      } else {
        //Cram in what we can
        int numChars = domain.name.length;
        while (painter.width > (width - heightPerLine) && numChars > 0) {
          numChars -= 1;
          name = domain.name.substring(0, numChars);
          painter.text = TextSpan(
            text: name,
            style: textTheme.bodyMedium!.copyWith(
              color: overview.get_colors(domain.name).$2,
            ),
          );
          painter.layout();
        }
        Offset textPosition = Offset(
          textOffset - painter.width / 2,
          position.dy,
        );
        painter.paint(canvas, textPosition);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    var myCanvas = TouchyCanvas(context, canvas);
    // Draw domain structure of the sequence that the hit matched
    Paint paint = new Paint()..style = PaintingStyle.fill;
    TextPainter legendPainter = TextPainter(
      textAlign: TextAlign.start,
      textDirection: TextDirection.ltr,
    );
    if(allDomains){
      legendPainter.text = TextSpan(
        text: "Annotated Domains:",
        style: textTheme.bodyMedium!.copyWith(color: colorScheme.onSurface),
      );
    }
    else{
      legendPainter.text = TextSpan(
        text: "Domain Structure:",
        style: textTheme.bodyMedium!.copyWith(color: colorScheme.onSurface),
      );
    }

    legendPainter.layout();
    legendPainter.paint(canvas, Offset(0, 0));
    legendPainter.text = TextSpan(
      text: "Query(ies):",
      style: textTheme.bodyMedium!.copyWith(color: colorScheme.onSurface),
    );

    legendPainter.layout();
    legendPainter.paint(canvas, Offset(0, (queryStartRow*lineSpace+(lineSpace/2)) *heightPerLine));
    // draw the structure/annotated domains
    _drawDomains(canvas, myCanvas, paint, 0, domains, domainRows, textTheme, buttons);
    // draw the queries

    // add the representation of the hit(s) to the sequence
    _drawDomains(canvas, myCanvas, paint, queryStartRow, queries, queryRows, textTheme, buttons);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


//Widget to draw the data for a hit
class DrawHit extends StatefulWidget {
  const DrawHit({super.key, required this.hit, required this.overview, this.allDomains = false});
  final Hit hit;
  final bool allDomains;
  final OverviewData overview;
  State<DrawHit> createState() => _DrawHitState();
}

class _DrawHitState extends State<DrawHit> {
  final GlobalKey key = GlobalKey();
  Size textSize = Size(0, 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _calculateRenderBoxWidth(),
    );
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
 //   print("Drawing hit: " + widget.hit.name+ "With  "+ widget.hit.queries.length.toString() + " queriy hits");
    final width = MediaQuery.sizeOf(context).width;
    if (widget.allDomains){
      return DrawDomains(
      sequence: widget.hit.sequence,
      length: widget.hit.seqLength,
      domains: widget.hit.domains,
      width: width,
      queries: widget.hit.queries,
      overview: widget.overview,
      seqLength: widget.hit.seqLength,
      seqEvalue: widget.hit.seqEvalue,
      allDomains: widget.allDomains,
    );
    }
    else{return DrawDomains(
      sequence: widget.hit.sequence,
      length: widget.hit.seqLength,
      domains: widget.hit.structureDomains,
      width: width,
      queries: widget.hit.queries,
      overview: widget.overview,
      seqLength: widget.hit.seqLength,
      seqEvalue: widget.hit.seqEvalue,
      allDomains: widget.allDomains,
    );}
  }
}


// Widget to display the information for a category of hits
class DrawCategory extends StatelessWidget {
  const DrawCategory({
    super.key,
    required this.which,
    required this.category,
    required this.overview,
  });

  final SigCategory category;
  final int which;
  final OverviewData overview;

  @override
  Widget build(BuildContext context) {
    return Consumer<HitLists>(
      builder: (context, hitLists, child) {
        return  Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    "${category.numHits} sequences with domain structure ${category.signature}",
                  ),
                  Text("Example: " + category.example.name),
                  DrawHit(hit: category.example, overview: overview),
               Align( alignment: Alignment(1.0,0.0), child: IconButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                          onPressed: () {
                            hitLists.setSelected(which);
                            context.go("/category");
                          },
                          icon: Icon(Icons.search, color: Theme.of(context).colorScheme.onPrimary),
                        ),), ],
        );
      },
    );
  }
}

