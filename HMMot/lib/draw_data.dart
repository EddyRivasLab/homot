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

/// DrawDomains: draws a representation of the domains that a sequence contains
class DrawDomains extends StatelessWidget {
  const DrawDomains({
    super.key,
    required this.sequence,
    required this.domains,
    required this.width,
    required this.queries,
    required this.overview,
  });

  //final List<Domain> domains;
  final String sequence;
  final List<Domain> domains;
  final double width;
  final List<Domain> queries;
  final OverviewData overview;

  (double, double) _calc_text_dimensions(TextTheme textTheme) {
    // The easiest way to get the dimensions of some
    // text seems to be to try rendering them and then measure the result.
    TextPainter testPainter = TextPainter(
      textAlign: TextAlign.start,
      textDirection: TextDirection.ltr,
    );
    testPainter.text = TextSpan(
      text: "Domain Structure:",
      style: textTheme.bodyMedium,
    );
    testPainter.layout();
    return (testPainter.width, testPainter.preferredLineHeight);
  }

  @override
  Widget build(BuildContext context) {
    double textWidth;
    double textHeight;
    (textWidth, textHeight) =_calc_text_dimensions(Theme.of(context).textTheme);
    var numLines = 1;
    int lastEnd = -1;
    // count the number of lines needed for the domain signature
    for (var domain in domains){
      if (domain.start < lastEnd){
        // move on to the next line because domains are sorted that way
        numLines+=1;
      }
      lastEnd = domain.end;
    }
    // now, figure out how many lines are needed for the queries.  This is harder,
    // because they aren't pre-sorted
    var queryStartRow = numLines;
    List<List<Pair<int,int>>> queryLines = [[]];
    List<int> queryRows = [];
    for (var query in queries){
      bool foundSpot = false;
      for (var i=0; i < queryLines.length; i++){
        // first, see if the query fits at the beginning of the row
        if(queryLines[i].length ==0 || query.end < queryLines[i][0].a){
          queryLines[i].insert(0, Pair(query.start, query.end));
          queryRows.add(i);  // this query fits in row i
          foundSpot = true;
          break;
        }
        // then, see if it fits at the end 
        if(query.start > queryLines[i][queryLines[i].length-1].b){
          // fits at the end of the row
          queryLines[i].add(Pair(query.start, query.end));
          queryRows.add(i);
          foundSpot = true;
          break;
        }
        // If it doesn't fit at the start or the end, see if it fits between existing ones
        for(var j = 0; j< queryLines[i].length -1; j++){
          if(query.start > queryLines[i][j].b && query.end < queryLines[i][j+1].a){
            // fits between items j and J+1
            queryLines[i].insert(j+1, Pair(query.start, query.end));
            queryRows.add(i);
            foundSpot = true;
            break;
          }
        }
      }
      // if we get here without finding a spot, we need to start a new row
      if(!foundSpot){
        queryRows.add(queryLines.length);
        queryLines.add([Pair(query.start, query.end)]);
      }
    }
    numLines+= queryLines.length;

    return Container(
      child: CanvasTouchDetector(
        gesturesToOverride: [GestureType.onPanStart],
        builder: (context) =>
        CustomPaint(
        size: Size(
          width,
          textHeight * (numLines* lineSpace + (lineSpace/2)),
        ),
        painter: DomainPainter(
          context: context,
          domains: domains,
          totalWidth: width,
          widthPerChar:
              (width - textWidth) /
              sequence.length,
          widthOffset: textWidth,
          heightPerLine: textHeight,
          queryStartRow: queryStartRow,
          queries: queries,
          queryRows: queryRows, 
          overview: overview,
          textTheme: Theme.of(context).textTheme,
          colorScheme: Theme.of(context).colorScheme,
        ),
      ),),
    );
  }
}

const double lineSpace = 1.2;
class DomainPainter extends CustomPainter {
  final BuildContext context;
  final List<Domain> domains;
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

  DomainPainter({
    required this.context,
    required this.domains,
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
  });

  void _draw_domain(
    Canvas canvas,
    TouchyCanvas myCanvas,
    Paint paint,
    Offset position,
    double width,
    double height,
    double lastEnd,
    Domain domain,
    TextTheme textTheme,
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
        paint..color = overview.get_colors(domain.name).$1,
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
      onPanStart: (details) {
        print("ping");},);
    
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
    legendPainter.text = TextSpan(
      text: "Domain Structure:",
      style: textTheme.bodyMedium!.copyWith(color: colorScheme.onSurface),
    );

    legendPainter.layout();
    legendPainter.paint(canvas, Offset(0, 0));
    legendPainter.text = TextSpan(
      text: "Query(ies):",
      style: textTheme.bodyMedium!.copyWith(color: colorScheme.onSurface),
    );

    legendPainter.layout();
    legendPainter.paint(canvas, Offset(0, (queryStartRow*lineSpace+(lineSpace/2)) *heightPerLine));

    var lastEnd = widthOffset;
    var row = 0;
    for (final domain in domains) {
      final double start = domain.start * widthPerChar + widthOffset;
      if(start < lastEnd){
        //we've wrapped around to a new row, need to handle
        //draw the line to the end of the row
        if(lastEnd < totalWidth){
          final p1 = Offset(lastEnd, (row * heightPerLine*lineSpace)+(heightPerLine*(lineSpace/2)));
          final p2 = Offset(totalWidth, (row * heightPerLine*lineSpace)+(heightPerLine*(lineSpace/2)));
          canvas.drawLine(p1, p2, paint..color =Theme.of(context).colorScheme.onSurface..strokeWidth= 2.0);
        }
        row +=1;
        lastEnd = widthOffset;
      }
      if (start != lastEnd) {
        final p1 = Offset(lastEnd, (row*heightPerLine*lineSpace) +(heightPerLine *(lineSpace/2)));
        final p2 = Offset(start, (row * heightPerLine * lineSpace) + (heightPerLine* (lineSpace/2)));
        canvas.drawLine(p1, p2, paint..color = Theme.of(context).colorScheme.onSurface..strokeWidth= 2.0);
      }
      final double end = domain.end * widthPerChar + widthOffset;
      lastEnd = end;
      final double domainWidth = end - start;
      _draw_domain(
        canvas,
        myCanvas,
        paint,
        Offset(start, row*heightPerLine*lineSpace),
        domainWidth,
        heightPerLine,
        lastEnd,
        domain,
        textTheme,
      );
    }
    if (lastEnd < totalWidth) {
      final p1 = Offset(lastEnd, (row *heightPerLine*lineSpace) +(heightPerLine * (lineSpace/2)));
      final p2 = Offset(totalWidth, (row * heightPerLine*lineSpace) +(heightPerLine* (lineSpace/2)));
      canvas.drawLine(p1, p2, paint..color = Theme.of(context).colorScheme.onSurface..strokeWidth= 2.0);
    }
    // add the representation of the hit(s) to the sequence
    row+=1;

    List<double> lastEnds = List<double>.filled(queryRows.reduce(max)+1, widthOffset);

    for (var i = 0; i<queries.length; i++) {
      final query = queries[i];
      final double start = query.start * widthPerChar + widthOffset;
      final double end = query.end * widthPerChar + widthOffset;
      final double domainWidth = end - start;
      _draw_domain(
        canvas,
        myCanvas,
        paint,
        Offset(start, ((row+ queryRows[i])* lineSpace + (lineSpace/2)) * heightPerLine),
        domainWidth,
        heightPerLine,
        lastEnds[queryRows[i]],
        query,
        textTheme,
      );
      lastEnds[queryRows[i]] = end;
    }
    for (int j = 0; j < lastEnds.length; j++){
      if (lastEnds[j] < totalWidth) {
        final p1 = Offset(lastEnds[j], ((queryStartRow+j)*lineSpace +(lineSpace/2)) *heightPerLine +(heightPerLine * (lineSpace/2)));
        final p2 = Offset(totalWidth, ((queryStartRow+j)* lineSpace + (lineSpace/2)) * heightPerLine + (heightPerLine * (lineSpace/2)));
        canvas.drawLine(p1, p2, paint..color=Theme.of(context).colorScheme.onSurface..strokeWidth= 2.0);
    }
    }
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
    final width = MediaQuery.sizeOf(context).width;
    if (widget.allDomains){
      return DrawDomains(
      sequence: widget.hit.sequence,
      domains: widget.hit.domains,
      width: width,
      queries: widget.hit.queries,
      overview: widget.overview,
    );
    }
    else{return DrawDomains(
      sequence: widget.hit.sequence,
      domains: widget.hit.structureDomains,
      width: width,
      queries: widget.hit.queries,
      overview: widget.overview,
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
                    "${category.numHits} sequences with domain signature ${category.signature}",
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

