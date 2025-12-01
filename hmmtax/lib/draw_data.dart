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
import 'package:hmmtax/src/rust/api/graph.dart';
import 'package:hmmtax/src/rust/frb_generated.dart';
import 'package:hmmtax/main.dart';
import 'package:hmmtax/utility.dart';
import 'package:hmmtax/printing.dart';

import 'package:provider/provider.dart';
import "package:go_router/go_router.dart";
import 'package:touchable/touchable.dart';

(double, double) _calc_legend_dimensions(TextTheme textTheme, bool allDomains) {
    // The easiest way to get the dimensions of some
    // text seems to be to try rendering them and then measure the result.
    TextPainter testPainter = TextPainter(
      textAlign: TextAlign.start,
      textDirection: TextDirection.ltr,
    );
    if (allDomains){
      testPainter.text = TextSpan(
      text: "Annotated Domains: ",
      style: textTheme.bodyMedium,
    );
    }
    else{
      testPainter.text = TextSpan(
      text: "Domain Structure: ",
      style: textTheme.bodyMedium,
    );
    }
    testPainter.layout();
    return (testPainter.width, testPainter.preferredLineHeight);
  }

void _addButton(List<Widget> buttons, double top, double bottom, double left, double right, String dName, String dDesc, String cName,
double sEval, double dEval, int sLen, int hLen, int sStart, int sEnd, int hStart, int hEnd, bool query, bool fromBlast, BuildContext context) {
  String tooltipText = query ? fromBlast?"Query: ${dName}\nSequence e-value: ${sEval.toStringAsExponential(2)}\nSequence length: ${sLen}\nDomain matched target positions ${sStart}-${sEnd}\nDomain matched query positions: ${hStart}-${hEnd}":
  "Query: ${dName}\nDomain e-value:${dEval.toStringAsExponential(2)}\nSequence e-value: ${sEval.toStringAsExponential(2)}\nSequence length: ${sLen}\nHMM length: ${hLen}\nDomain matched query positions ${sStart}-${sEnd}\nDomain matched HMM positions: ${hStart}-${hEnd}":
  "Domain: ${dName}\nDescription: ${dDesc} \nClan: ${cName}\nDomain e-value:${dEval.toStringAsExponential(2)}\nSequence e-value: ${sEval.toStringAsExponential(2)}\nSequence length: ${sLen}\nHMM length: ${hLen}\nDomain matched sequence positions ${sStart}-${sEnd}\nDomain matched HMM positions: ${hStart}-${hEnd}";
  
  //print("addding button at top=$top bottom=$bottom left=$left right=$right\n" );
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
typedef dCoord = ({int domain, int start, int end});
class DrawDomains extends StatelessWidget {
  DrawDomains({
    super.key,
    required this.sequence,
    required this.length,
    required this.domains,
    required this.width,
    required this.queries,
    required this.searchdata,
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
  final SearchData searchdata;
  final int seqLength;
  final double seqEvalue;
  final bool allDomains;
  List<List<int>> _map_domains_to_rows(List<Domain> domains){
    List<List<dCoord>> Lines = [[]];
    int whichDomain =0;
    for (var domain in domains){
      bool foundSpot = false;
      for (var i=0; i < Lines.length; i++){
        // first, see if the domain fits at the beginning of the row
        if(Lines[i].isEmpty || domain.seqEnd < Lines[i][0].start){
          Lines[i].insert(0, (domain: whichDomain, start: domain.seqStart, end: domain.seqEnd));
          foundSpot = true;
          break;
        }
        // then, see if it fits at the end 
        if(domain.seqStart > Lines[i][Lines[i].length-1].end){
          // fits at the end of the row
          Lines[i].add((domain: whichDomain, start: domain.seqStart, end: domain.seqEnd));
          foundSpot = true;
          break;
        }
        // If it doesn't fit at the start or the end, see if it fits between existing ones
        for(var j = 0; j< Lines[i].length -1; j++){
          if(domain.seqStart > Lines[i][j].end && domain.seqEnd < Lines[i][j+1].start){
            // fits between items j and J+1
            Lines[i].insert(j+1, (domain: whichDomain, start: domain.seqStart, end: domain.seqEnd));
            foundSpot = true;
            break;
          }
        }
      }
      // if we get here without finding a spot, we need to start a new row
      if(!foundSpot){
        Lines.add([(domain:whichDomain, start: domain.seqStart, end: domain.seqEnd)]);
      }
      whichDomain += 1;
    }
    List<List<int>>retval = [];
    for (var i = 0; i<Lines.length; i++){
      retval.add([]);
      for (var j = 0; j<Lines[i].length; j++){
        // add the row number to the domain
        retval[i].add(Lines[i][j].domain);
      }
    }

    return retval;
  }

  @override
  Widget build(BuildContext context) {
    //  print("DRawDomains called with length = $length and width = $width");
    double textHeight, textWidth;
    (textWidth, textHeight) =_calc_legend_dimensions(Theme.of(context).textTheme, allDomains);
    var newDomains = List<Domain>.from(domains);
    // Handle the case where there are no domains
    if (newDomains.isEmpty) {
      newDomains.add(Domain(
        name: "No Domains",
        description: "No domains found in this sequence",
        clan: "No Clan",
        seqStart: 0,
        seqEnd: length,
        hmmStart: 0,
        hmmEnd: length,
        hmmLength: length,
        domEvalue: seqEvalue,
        fullMatchStart: true,
        fullMatchEnd: true,
        fromBlast: false,
      ));
    }
    // Sort the domains by start position


    var domainRows = _map_domains_to_rows(newDomains);
    var queryRows = _map_domains_to_rows(queries);
    // now, figure out how many lines are needed for the queries.  This is harder,
    // because they aren't pre-sorted
    var queryStartRow = domainRows.isNotEmpty ? domainRows.length :1;
    var numLines = queryRows.isNotEmpty ? queryStartRow + queryRows.length: 1;
  //print("width = $width textWidth = $textWidth length = $length");
    List<Widget> buttons = CreateButtons(newDomains, domainRows, width, (width - textWidth) /length, textWidth, textHeight, queryStartRow, 
    queries, queryRows, seqLength, seqEvalue, context);
    var _myPainter = DomainPainter(
          context: context,
          domains: newDomains,
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
          searchdata: searchdata,
          textTheme: Theme.of(context).textTheme,
          colorScheme: Theme.of(context).colorScheme,
          buttons: buttons,
          allDomains: allDomains,
        );
    return Stack(
      children:<Widget>[
        CustomPaint(
        size: Size(
          width,
          textHeight * (numLines* lineSpace + (lineSpace/2)),
        ),
        painter: _myPainter,
      ),
      ]+buttons,
    );
  }
}

const double lineSpace = 1.4;

List<Widget> CreateButtons(
  final List<Domain> domains,
  final List<List<int>> domainRows,
  final double totalWidth,
  final double widthPerChar,
  final double widthOffset,
  final double heightPerLine,
  final int queryStartRow,
  final List<Domain> queries,
  final List<List<int>> queryRows,
  final int seqLength,
  final double seqEvalue,
  final BuildContext context
){
  List<Widget> buttons = [];
  var row = 0;
  double oldEnd = widthOffset;
  for (var i = 0; i<domainRows.length; i++) {
    for(var j = 0; j<domainRows[i].length; j++){
      final domain = domains[domainRows[i][j]];
      final double start = domain.seqStart * widthPerChar + widthOffset;
      final double end = domain.seqEnd * widthPerChar + widthOffset;
      final double domainWidth = end - start;
      _addButton(buttons, (i* lineSpace + (lineSpace/2)) * heightPerLine, 
      (((i)* lineSpace + (lineSpace/2)) * heightPerLine) + heightPerLine,  
      start, start + domainWidth, domain.name, domain.description, domain.clan, seqEvalue, domain.domEvalue, seqLength, domain.hmmLength, domain.seqStart, domain.seqEnd, domain.hmmStart,
      domain.hmmEnd, false, domain.fromBlast, context);
    
    }
  }
  for (var i = 0; i<queryRows.length; i++) {
    for (var j= 0; j<queryRows[i].length; j++){
      final query = queries[queryRows[i][j]];
      final double start = query.seqStart * widthPerChar + widthOffset;
      final double end = query.seqEnd * widthPerChar + widthOffset;
      final double domainWidth = end - start;
      _addButton(buttons, ((queryStartRow+ i)* lineSpace + (lineSpace/2)) * heightPerLine, 
        (((queryStartRow+ i)* lineSpace + (lineSpace/2)) * heightPerLine) + heightPerLine,  
        start, start + domainWidth, query.name, query.description, query.clan, seqEvalue, query.domEvalue, seqLength, query.hmmLength, query.seqStart, query.seqEnd, query.hmmStart,
        query.hmmEnd, true,query.fromBlast, context);
    }
  }
  return buttons;
}
class DomainPainter extends CustomPainter {
  final BuildContext context;
  final List<Domain> domains;
  final List<List<int>> domainRows;
  final double totalWidth;
  final double widthPerChar;
  final double widthOffset;
  final double heightPerLine;
  final int queryStartRow;
  final List<Domain> queries;
  final List<List<int>> queryRows;
  final SearchData searchdata;
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
    required this.searchdata,
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
    List<List<int>> domainRows,
    TextTheme textTheme,
    List<Widget> buttons,
  ){
    List<double> lastEnds = List<double>.filled(domainRows.length, widthOffset);

    for (var i = 0; i<domainRows.length; i++) {
      for (var j = 0; j < domainRows[i].length; j++){
        final domain = domains[domainRows[i][j]];
        final double start = domain.seqStart * widthPerChar + widthOffset;
        final double end = domain.seqEnd * widthPerChar + widthOffset;
        final double domainWidth = end - start;
//
        _draw_domain(
          canvas,
          myCanvas,
          paint,
          Offset(start, ((startRow+ i)* lineSpace) * heightPerLine),
          domainWidth,
          heightPerLine,
          lastEnds[i],
          domain,
          textTheme,
          buttons,
        );
        lastEnds[i] = end;
      }
    }
    for (int j = 0; j < lastEnds.length; j++){
      if (lastEnds[j] < totalWidth) {
        final p1 = Offset(lastEnds[j], ((startRow+j)*lineSpace +(lineSpace/2)) *heightPerLine);
        final p2 = Offset(totalWidth, ((startRow+j)* lineSpace + (lineSpace/2)) * heightPerLine);
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
    final double startY = position.dy + (heightPerLine * (lineSpace-1)/2); // adjust for spacing between rows
    if (start > lastEnd) {
      final p1 = Offset(lastEnd, position.dy + (heightPerLine * (lineSpace/2)));
      final p2 = Offset(start, position.dy + (heightPerLine * (lineSpace/2)));
      canvas.drawLine(p1, p2, paint..color = Theme.of(context).colorScheme.onSurface..strokeWidth = 2.0);
    }
    if (width <= height) {
      // domain too small to draw pretty edges
      canvas.drawRect(
        Rect.fromLTWH(position.dx, startY, width, height),
        paint..color = searchdata.get_colors(domain.name).$1..style=PaintingStyle.fill,
      );
      canvas.drawRect(
        Rect.fromLTWH(position.dx, startY, width, height),
        paint..color = Theme.of(context).colorScheme.onSurface..style=PaintingStyle.stroke..strokeWidth = 2.0,
      );
    } else {
      // Have enough room to draw the edges we want
      Path path = Path();
      // start at bottom left of domain
      path.moveTo(position.dx + height / 2, startY + height);
      if (domain.fullMatchStart) {
        // Round end to start
        Rect oval = Rect.fromLTWH(position.dx, startY, height, height);
        path.arcTo(oval, pi / 2, pi, false);
      } else {
        // jagged end
        path.lineTo(position.dx, startY + 5 * height / 6);
        path.lineTo(position.dx + height / 2, startY + 4 * height / 6);
        path.lineTo(position.dx, startY + 3 * height / 6);
        path.lineTo(position.dx + height / 2, startY + 2 * height / 6);
        path.lineTo(position.dx, startY + 1 * height / 6);
        path.lineTo(position.dx + height / 2, startY);
      }
      path.lineTo(
        position.dx + (width - (height / 2)),
        startY,
      ); // top edge of domain
      if (domain.fullMatchEnd) {
        // Round end 
        Rect oval = Rect.fromLTWH(
          position.dx + width - (height),
          startY,
          height,
          height,
        );
        path.arcTo(oval, 3 * pi / 2, pi, false);
      } else {
        // jagged end
        path.lineTo(position.dx + width, startY + height / 6);
        path.lineTo(
          position.dx + (width - height / 2),
          startY + 2 * height / 6,
        );
        path.lineTo(position.dx + width, startY + 3 * height / 6);
        path.lineTo(
          position.dx + (width - height / 2),
          startY + 4 * height / 6,
        );
        path.lineTo(position.dx + width, startY + 5 * height / 6);
        path.lineTo(position.dx + (width - height / 2), startY + height);
      }
      path.lineTo(position.dx + height / 2, startY + height);
      canvas.drawPath(path, paint..color = searchdata.get_colors(domain.name).$1..style=PaintingStyle.fill);
    
      canvas.drawPath(path, paint..color = Theme.of(context).colorScheme.onSurface..style=PaintingStyle.stroke..strokeWidth = 2.0);
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
            color: searchdata.get_colors(domain.name).$2,
          ),
        );
    painter.layout();
    if (painter.width <= (width - heightPerLine)) {
      // -2 to make sure domain extends past name
      Offset textPosition = Offset(textOffset - painter.width / 2, startY);
      painter.paint(canvas, textPosition);
    } else {
      //see if the domain name fits
      name = domain.name;
      painter.text = TextSpan(
        text: name,
        style: textTheme.bodyMedium!.copyWith(
          color: searchdata.get_colors(domain.name).$2,
        ),
      );
      painter.layout();
      if (painter.width <= (width - heightPerLine)) {
        // -2 to make sure domain extends past name
        Offset textPosition = Offset(
          textOffset - painter.width / 2,
          startY,
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
              color: searchdata.get_colors(domain.name).$2,
            ),
          );
          painter.layout();
        }
        Offset textPosition = Offset(
          textOffset - painter.width / 2,
          startY,
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
    legendPainter.paint(canvas, Offset(0, ((lineSpace-1)/2) *heightPerLine));
    legendPainter.text = TextSpan(
      text: "Query(ies):",
      style: textTheme.bodyMedium!.copyWith(color: colorScheme.onSurface),
    );

    legendPainter.layout();
    legendPainter.paint(canvas, Offset(0, (queryStartRow*lineSpace+((lineSpace-1)/2)) *heightPerLine));
    // draw the structure/annotated domains
    _drawDomains(canvas, myCanvas, paint, 0, domains, domainRows, textTheme, buttons);
    // draw the queries

    // add the representation of the hit(s) to the sequence
    _drawDomains(canvas, myCanvas, paint, queryStartRow, queries, queryRows, textTheme, buttons);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

double requiredHitWidth(Hit hit, bool allDomains, bool showSequence, BuildContext context){
  //textWidth here is the width of the legend text
  TextPainter painter;
  painter = TextPainter(
    textAlign: TextAlign.start,
    textDirection: TextDirection.ltr,
  );      // find the height of a line using the same method we'll use when drawing.
  painter.text = TextSpan(
    text: "test",
      style: Theme.of(context).textTheme.bodyMedium,
      );
  painter.layout();
  double heightPerLine = painter.preferredLineHeight;
  double widthPerChar = 0.0;
  for ( var domain in hit.queries){
    // figure out how long the domain needs to be to fit the text we'll put in it
    String evalString = domain.domEvalue.toStringAsExponential(2);
    String name = domain.name + " (" + evalString + ")";
    painter.text = TextSpan(
      text: name,
      style: Theme.of(context).textTheme.bodyMedium,
    );
    painter.layout();
    double domainWidth = painter.width + heightPerLine; // add heightperline to make room for rounded edges
    double domainWidthPerChar = domainWidth / (domain.seqEnd - domain.seqStart);
    if (domainWidthPerChar > widthPerChar){ //this domain needs more room per character than previous ones
      widthPerChar = domainWidthPerChar; 
    };
  }
  // Now repeat for the sequence domains
  for ( var domain in allDomains ? hit.domains : hit.structureDomains){
        // figure out how long the domain needs to be to fit the text we'll put in it
    String evalString = domain.domEvalue.toStringAsExponential(2);
    String name = domain.name + " (" + evalString + ")";
    painter.text = TextSpan(
      text: name,
      style: Theme.of(context).textTheme.bodyMedium,
    );
    painter.layout();
    double domainWidth = painter.width + heightPerLine; // add heightperline to make room for rounded edges
    double domainWidthPerChar = domainWidth / (domain.seqEnd - domain.seqStart);
    if (domainWidthPerChar > widthPerChar){ //this domain needs more room per character than previous ones
      widthPerChar = domainWidthPerChar; 
    };
  }
  if (showSequence){
    // also consider the width needed to show the sequence
    String seqText = hit.sequence;
    painter.text = TextSpan(
      text: seqText,
      style: Theme.of(context).textTheme.bodyMedium,
    );
    painter.layout();
    double seqWidth = painter.width/hit.sequence.length;
    if (seqWidth > widthPerChar){
      widthPerChar = seqWidth;        
    }
  }
  return (widthPerChar * hit.seqLength) + _calc_legend_dimensions(Theme.of(context).textTheme, allDomains).$1;
}

//Widget to draw the data for a hit
class DrawHit extends StatefulWidget {
  const DrawHit({super.key, required this.hit, required this.searchdata, this.allDomains = false, this.fullWidth = true, this.showSequence = false, this.sequence = "" });
  final Hit hit;
  final bool allDomains;
  final bool fullWidth;
  final SearchData searchdata;
  final bool showSequence;
  final String sequence;
  State<DrawHit> createState() => _DrawHitState();
}

class _DrawHitState extends State<DrawHit> {
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
 //   print("Drawing hit: " + widget.hit.name+ "With  "+ widget.hit.queries.length.toString() + " queriy hits");
    final width;
    double widthPerChar = 0.0;
    double textWidth, textHeight;
    (textWidth, textHeight) =_calc_legend_dimensions(Theme.of(context).textTheme, widget.allDomains);
    if (widget.fullWidth){
      width = max(requiredHitWidth(widget.hit, widget.allDomains, widget.showSequence, context), MediaQuery.sizeOf(context).width);
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      scrollbarOrientation: ScrollbarOrientation.bottom,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DrawDomains(
              sequence: widget.hit.sequence,
              length: widget.hit.seqLength,
              domains: widget.allDomains ? widget.hit.domains: widget.hit.structureDomains,
              width: width,
              queries: widget.hit.queries,
              searchdata: widget.searchdata,
              seqLength: widget.hit.seqLength,
              seqEvalue: widget.hit.seqEvalue,
              allDomains: widget.allDomains,
            ),
            if(widget.showSequence) Text("Sequence:", style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),),
            if (widget.showSequence) Padding(
              padding: EdgeInsets.only(left: textWidth),
              child: Text(
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),
              widget.sequence,
            ),),
          ],
        ),
        ),
      );
    }
    else{ // make the hit fit in the window
      width = MediaQuery.sizeOf(context).width;
      textWidth =0.0;
          return  Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DrawDomains(
              sequence: widget.hit.sequence,
              length: widget.hit.seqLength,
              domains: widget.allDomains ? widget.hit.domains: widget.hit.structureDomains,
              width: width,
              queries: widget.hit.queries,
              searchdata: widget.searchdata,
              seqLength: widget.hit.seqLength,
              seqEvalue: widget.hit.seqEvalue,
              allDomains: widget.allDomains,
            ),
            if(widget.showSequence) Text("Sequence:", style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),),
            if (widget.showSequence) Padding(
              padding: EdgeInsets.only(left: textWidth),
              child: Text(
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),
              widget.sequence,
            ),),
          ],
      );
    }

  }
}


// Widget to display the information for a category of hits
class DrawCategory extends StatelessWidget {
  const DrawCategory({
    super.key,
    required this.which,
    required this.from,
    required this.fullWidth,
  });

  final int which;
  final selectedby from;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Consumer2<SearchData, GraphData>(
      builder: (context, searchdata, graphdata, child) {
        final SigCategory category = from == selectedby.structure ? searchdata.rootHits[which] : searchdata.currentHits[which]; 
        return  Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    "${category.hits.length} sequences with domain structure ${searchdata.structures[category.signature]}",
                  ),
                  Text("Example: " + searchdata.hits[category.hits[0].toInt()].name),
                  DrawHit( hit: searchdata.hits[category.hits[0].toInt()], searchdata: searchdata, fullWidth: fullWidth),
            ],
        );
      },
    );
  }
}

