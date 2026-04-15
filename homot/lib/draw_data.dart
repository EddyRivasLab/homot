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
import 'package:homot/src/rust/api/graph.dart';
import 'package:homot/src/rust/frb_generated.dart';
import 'package:homot/main.dart';
import 'package:homot/utility.dart';
import 'package:provider/provider.dart';
import "package:go_router/go_router.dart";
import 'package:patterns_canvas/patterns_canvas.dart';

const EDGEPAD = 3.0; // padding to leave at the edge of the screen when drawing a hit

double pixelsPerResidue(int maxLength, TextTheme textTheme, BuildContext context) {
  double textWidth, textHeight;
  (textWidth, textHeight) = _calc_legend_dimensions(
    textTheme,
  );

  double screenWidth = MediaQuery.sizeOf(context).width;
  return (screenWidth - textWidth) / maxLength;
}

String _iType_to_string(IEntryType iType){
  switch (iType){
    case IEntryType.superfamily:
      return "Superfamily";
    case IEntryType.family:
      return "Family";
    case IEntryType.domain:
      return "Domain";
    case IEntryType.repeat:
      return "Repeat";
    case IEntryType.site:
      return "Site";
    case IEntryType.other:
      return "Other";
  }
}
(double, double) _calc_legend_dimensions(TextTheme textTheme) {
  // The easiest way to get the dimensions of some
  // text seems to be to try rendering them and then measure the result.
  TextPainter testPainter = TextPainter(
    textAlign: TextAlign.start,
    textDirection: TextDirection.ltr,
  );
  testPainter.text = TextSpan(
      text: "Structure\nQuery\nHomology\nSequence ",
      style: textTheme.bodyMedium,
    );
  
  
  testPainter.layout();
  return (testPainter.width, testPainter.preferredLineHeight);
}

void _addButton(
  List<Widget> buttons,
  double top,
  double bottom,
  double left,
  double right,
  Domain domain,
  bool query,
  int seqLength,
  double seqEvalue,
  bool usePfamNames,
  BuildContext context,
) {
  String tooltipText;
 if (domain.source == AnnotationType.interpro){
  tooltipText = _iType_to_string(domain.iType)+ ":";
  if (domain.iType == "Domain" && usePfamNames && domain.pfamName != ""){
    tooltipText += " "+ domain.pfamName;
  }
  else{
    tooltipText += " "+ domain.name;
  }
  if(domain.ipShort != ""){
    tooltipText += "\nInterPro Short Name: " + domain.ipShort;
  }
  else{
    tooltipText += "\nInterPro Short Name: none";
  }
  if(domain.ipLong != ""){
    tooltipText += "\nInterPro Long Name: " + domain.ipLong;
  }
  else{
    tooltipText += "\nInterPro Long Name: none";
  }
  tooltipText += "\nDescription: " + domain.description;
  tooltipText += "\nTarget sequence length: " + seqLength.toString();

  tooltipText += "\n"+_iType_to_string(domain.iType)+ " occupied sequence positions "+
      domain.seqStart.toString() +
      "-" +
      domain.seqEnd.toString();
 }
 else{
    if (query) {
      tooltipText = "Query: "+ domain.name;
      if (!domain.fromBlast){
        tooltipText += "\nDomain E-value: " + domain.domEvalue.toStringAsExponential(2);
      }
      tooltipText += "\nSequence e-value: " + seqEvalue.toStringAsExponential(2);
      tooltipText += "\nTarget sequence length: " + seqLength.toString();
      if(!domain.fromBlast){
        tooltipText += "\nDomain HMM length: " + domain.hmmLength.toString();
      }
      tooltipText += "\nQuery matched sequence positions "+
          domain.seqStart.toString() +
          "-" +
          domain.seqEnd.toString();
      if (!domain.fromBlast){
        tooltipText += "\nDomain matched HMM positions " +
            domain.hmmStart.toString() +
            "-" +
            domain.hmmEnd.toString();
      }
    }
    else{tooltipText = "Domain: "+ domain.name;
      tooltipText += "\nDescription: " + domain.description;
      if (!domain.fromBlast){
        tooltipText += "\nDomain E-value: " + domain.domEvalue.toStringAsExponential(2);
      }
      tooltipText += "\nSequence e-value: " + seqEvalue.toStringAsExponential(2);
      tooltipText += "\nTarget sequence length: " + seqLength.toString();
      if(!domain.fromBlast){
        tooltipText += "\nDomain HMM length: " + domain.hmmLength.toString();
      }
      tooltipText += "\nQuery matched sequence positions "+
          domain.seqStart.toString() +
          "-" +
          domain.seqEnd.toString();
      if (!domain.fromBlast){
        tooltipText += "\nDomain matched HMM positions " +
            domain.hmmStart.toString() +
            "-" +
            domain.hmmEnd.toString();
      }
    }
  };
  buttons.add(
    Positioned(
      top: top,
      //bottom: bottom,
      left: left,
      //right: right,
      child: Tooltip(
        message: tooltipText,
        textStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
        child: Container(
          width: right - left,
          height: bottom - top,
          color: Colors.transparent,
        ),
      ),
    ),
  );
}

/// DrawDomains: draws a representation of the domains that a sequence contains
typedef dCoord = ({int domain, int start, int end});

class DrawDomains extends StatelessWidget {
  DrawDomains({
    super.key,
    required this.context,
    required this.sequence,
    required this.length,
    required this.domains,
    required this.width,
    required this.queries,
    required this.searchdata,
    required this.seqLength,
    required this.seqEvalue,
    required this.allDomains,
    required this.pixelsPerResidue,
  });

  //final List<Domain> domains;
  final BuildContext context;
  final String sequence;
  final int length;
  final List<Domain> domains;
  final double width;
  final List<Domain> queries;
  final SearchData searchdata;
  final int seqLength;
  final double seqEvalue;
  final bool allDomains;
  final double pixelsPerResidue;
  List<List<int>> _map_domains_to_rows(List<Domain> domains) {
    List<List<dCoord>> Lines = [[]];
    int whichDomain = 0;
    final bool showSuperfamilies = Provider.of<HSettings>(context, listen: false).showInterproSuperfamily;
    final bool showFamilies = Provider.of<HSettings>(context, listen: false).showInterproFamily;
    final bool showDomains = Provider.of<HSettings>(context, listen: false).showInterproDomain;
    final bool showRepeats = Provider.of<HSettings>(context, listen: false).showInterproRepeat;
    final bool showSites = Provider.of<HSettings>(context, listen: false).showInterproSite;
    final bool showOther = Provider.of<HSettings>(context, listen: false).showInterproOther;  
    for (var domain in domains) {
      whichDomain += 1; // increment here so that this gets incremented even when we skip a domain
      // means we have to subtract one from the domain number when we insert, though.
      if (domain.source == AnnotationType.interpro){
        // This is an InterPro domain; see if we should show it 
        if (domain.iType == IEntryType.superfamily && !showSuperfamilies) continue;
        if (domain.iType == IEntryType.family && !showFamilies) continue;
        if (domain.iType == IEntryType.domain && !showDomains) continue;
        if (domain.iType == IEntryType.repeat && !showRepeats) continue;
        if (domain.iType == IEntryType.site && !showSites) continue;
        if (domain.iType == IEntryType.other  && !showOther) continue;
        }

      bool foundSpot = false;
      //print("Placing domain ${domain.name} at ${domain.seqStart}-${domain.seqEnd} ");
      for (var i = 0; i < Lines.length; i++) {
        // first, see if the domain fits at the beginning of the row
        if (Lines[i].isEmpty || domain.seqEnd < Lines[i][0].start) {
          Lines[i].insert(0, (
            domain: whichDomain-1,
            start: domain.seqStart,
            end: domain.seqEnd,
          ));
          foundSpot = true;
          break;
        }
        // then, see if it fits at the end
        if (domain.seqStart > Lines[i][Lines[i].length - 1].end) {
          // fits at the end of the row
          Lines[i].add((
            domain: whichDomain-1,
            start: domain.seqStart,
            end: domain.seqEnd,
          ));
          foundSpot = true;
          break;
        }
        // If it doesn't fit at the start or the end, see if it fits between existing ones
        for (var j = 0; j < Lines[i].length - 1; j++) {
          if (domain.seqStart > Lines[i][j].end &&
              domain.seqEnd < Lines[i][j + 1].start) {
            // fits between items j and J+1
            Lines[i].insert(j + 1, (
              domain: whichDomain-1,
              start: domain.seqStart,
              end: domain.seqEnd,
            ));
            foundSpot = true;
            break;
          }
        }
      }
      // if we get here without finding a spot, we need to start a new row
      if (!foundSpot) {
        Lines.add([
          (domain: whichDomain-1, start: domain.seqStart, end: domain.seqEnd),
        ]);
      }
    }
    List<List<int>> retval = [];
    for (var i = 0; i < Lines.length; i++) {
      retval.add([]);
      for (var j = 0; j < Lines[i].length; j++) {
        // add the row number to the domain
        retval[i].add(Lines[i][j].domain);
      }
    }

    return retval;
  }

  @override
  Widget build(BuildContext context) {
    //  print("DrawDomains called with length = $length and width = $width");
    double textHeight, textWidth;
    (textWidth, textHeight) = _calc_legend_dimensions(
      Theme.of(context).textTheme,
    );
    var newDomains = List<Domain>.from(domains);
    // Handle the case where there are no domains
    if (newDomains.isEmpty) {
      newDomains.add(
        Domain(
          name: "No Structure",
          description: "No structure found for this sequence",
          clan: "No Clan",
          seqStart: 0,
          seqEnd: seqLength,
          hmmStart: 0,
          hmmEnd: length,
          hmmLength: length,
          domEvalue: double.infinity,
          fullMatchStart: true,
          fullMatchEnd: true,
          fromBlast: false,
          source: AnnotationType.other,
          ipShort: "",
          ipLong: "",
          pfamName: "",
          iType: IEntryType.other,
        ),
      );
    }
    // Sort the domains by start position

    var domainRows = _map_domains_to_rows(newDomains);
    var queryRows = _map_domains_to_rows(queries);
    // now, figure out how many lines are needed for the queries.  This is harder,
    // because they aren't pre-sorted
    var queryStartRow = domainRows.isNotEmpty ? domainRows.length : 1;
    var numLines = queryRows.isNotEmpty ? queryStartRow + queryRows.length : 1;
    //print("width = $width textWidth = $textWidth length = $length");
    List<Widget> buttons = CreateButtons(
      newDomains,
      domainRows,
      width,
      textWidth,
      textHeight,
      queryStartRow,
      queries,
      queryRows,
      seqLength,
      seqEvalue,
      context,
      pixelsPerResidue,
    );
    var _myPainter = DomainPainter(
      context: context,
      domains: newDomains,
      domainRows: domainRows,
      totalWidth: width,
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
      pixelsPerResidue: pixelsPerResidue,
    );
    return Stack(
      children:
          <Widget>[
            CustomPaint(
              size: Size(
                width,
                textHeight * (numLines * lineSpace + (lineSpace / 2)),
              ),
              painter: _myPainter,
            ),
          ] +
          buttons,
    );
  }
}

const double lineSpace = 1.4;

List<Widget> CreateButtons(
  final List<Domain> domains,
  final List<List<int>> domainRows,
  final double totalWidth,
  final double widthOffset,
  final double heightPerLine,
  final int queryStartRow,
  final List<Domain> queries,
  final List<List<int>> queryRows,
  final int seqLength,
  final double seqEvalue,
  final BuildContext context,
  final double pixelsPerResidue,
) {
  List<Widget> buttons = [];
  var row = 0;
  double oldEnd = widthOffset;
  for (var i = 0; i < domainRows.length; i++) {
    for (var j = 0; j < domainRows[i].length; j++) {
      final domain = domains[domainRows[i][j]];
      final double start = domain.seqStart * pixelsPerResidue + widthOffset;
      final double end = domain.seqEnd * pixelsPerResidue + widthOffset;
      final double domainWidth = end - start;
      _addButton(
        buttons,
        (i * lineSpace + (lineSpace / 2)) * heightPerLine,
        (((i) * lineSpace + (lineSpace / 2)) * heightPerLine) + heightPerLine,
        start,
        start + domainWidth,
        domain,
        false,
        seqLength,
        seqEvalue,
        Provider.of<HSettings>(context, listen: false).showNamesFrom == ShowNamesFrom.pfam,
        context,
      );
    }
  }
  for (var i = 0; i < queryRows.length; i++) {
    for (var j = 0; j < queryRows[i].length; j++) {
      final query = queries[queryRows[i][j]];
      final double start = query.seqStart * pixelsPerResidue + widthOffset;
      final double end = query.seqEnd * pixelsPerResidue + widthOffset;
      final double domainWidth = end - start;
      _addButton(
        buttons,
        ((queryStartRow + i) * lineSpace + (lineSpace / 2)) * heightPerLine,
        (((queryStartRow + i) * lineSpace + (lineSpace / 2)) * heightPerLine) +
            heightPerLine,
        start,
        start + domainWidth,
        query,
        true,
        seqLength,
        seqEvalue,
        Provider.of<HSettings>(context, listen: false).showNamesFrom == ShowNamesFrom.pfam,
        context,
      );
    }
  }
  return buttons;
}

class DomainPainter extends CustomPainter {
  final BuildContext context;
  final List<Domain> domains;
  final List<List<int>> domainRows;
  final double totalWidth;
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
  final double pixelsPerResidue;


  DomainPainter({
    required this.context,
    required this.domains,
    required this.domainRows,
    required this.totalWidth,
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
    required this.pixelsPerResidue,
  });

  _drawDomains(
    BuildContext context,
    Canvas canvas,
    Paint paint,
    int startRow,
    List<Domain> domains,
    List<List<int>> domainRows,
    TextTheme textTheme,
    List<Widget> buttons,
    Size size,
    double endWidth,
    bool query,
    double pixelsPerResidue,
  ) {
    List<double> lastEnds = List<double>.filled(domainRows.length, widthOffset);
    bool addPatterns = Provider.of<HSettings>(context, listen: false).addPatterns;
    bool pfamNames = Provider.of<HSettings>(context, listen: false).showNamesFrom == ShowNamesFrom.pfam;
    ShowInterproIdEnum showInterproIdAs = Provider.of<HSettings>(context, listen: false).showInterproIdAs;
    for (var i = 0; i < domainRows.length; i++) {
      if(!query){
        final p3 = Offset(widthOffset, ((startRow + i) * lineSpace) * heightPerLine);
        final p4 = Offset(widthOffset, ((startRow + i) * (lineSpace) + lineSpace) * heightPerLine);
   
        canvas.drawLine(
          p3,
          p4,
          paint
          ..color = Theme.of(context).colorScheme.onSurface
          ..strokeWidth = 2.0,
        );
      }
      for (var j = 0; j < domainRows[i].length; j++) {
        final domain = domains[domainRows[i][j]];
        final double start = domain.seqStart * pixelsPerResidue + widthOffset;
        final double end = domain.seqEnd * pixelsPerResidue + widthOffset;
        final double domainWidth = end - start;
        //
        _draw_domain(
          canvas,
          paint,
          Offset(start, ((startRow + i) * lineSpace) * heightPerLine),
          domainWidth,
          heightPerLine,
          lastEnds[i],
          domain,
          textTheme,
          buttons,
          addPatterns,
          pfamNames,
          showInterproIdAs,
          size,
          query
        );
        lastEnds[i] = end;
      }
    }
    for (int j = 0; j < lastEnds.length; j++) {
      if (lastEnds[j] <= endWidth && !query) {
       final p1 = Offset(
          lastEnds[j],
          ((startRow + j) * lineSpace + (lineSpace / 2)) * heightPerLine,
        );
        final p2 = Offset(
          endWidth,
          ((startRow + j) * lineSpace + (lineSpace / 2)) * heightPerLine,
        );
        canvas.drawLine(
          p1,
          p2,
          paint
            ..color = Theme.of(context).colorScheme.onSurface
            ..strokeWidth = 2.0,
        );

        final p3 = Offset(endWidth, ((startRow + j) * lineSpace) * heightPerLine);
        final p4 = Offset(endWidth, ((startRow + j) * (lineSpace) + lineSpace) * heightPerLine);
   
        canvas.drawLine(
          p3,
          p4,
          paint
          ..color = Theme.of(context).colorScheme.onSurface
          ..strokeWidth = 2.0,
        );
      }
    }
  }
  _draw_domain(
    Canvas canvas,
    Paint paint,
    Offset position,
    double width,
    double height,
    double lastEnd,
    Domain domain,
    TextTheme textTheme,
    List<Widget> buttons,
    bool addPatterns,
    bool pfamNames,
    ShowInterproIdEnum showInterproIdAs,
    Size size,
    bool query
  ) {
    // set this up once in case we need it
    int featuresCount = 5;
    if (searchdata.get_colors(domain.name).$3 != PatternType.horizontalLight) {
      featuresCount = (width / 10).round();
    }
    Pattern p1 = Pattern.fromValues(patternType: searchdata.get_colors(domain.name).$3, fgColor: searchdata.get_colors(domain.name).$5, 
    bgColor: searchdata.get_colors(domain.name).$4, featuresCount: featuresCount);
    // First, the line preceeding the domain
    final double start = position.dx;
    final double startY =
       query? position.dy + (heightPerLine*lineSpace)/2:  position.dy + 
       (heightPerLine *
            (lineSpace - 1) /
            2); // adjust for spacing between rows
    if (start > lastEnd && !query) {
      final p1 = Offset(
        lastEnd,
        position.dy + (heightPerLine * (lineSpace / 2)),
      );
      final p2 = Offset(start, position.dy + (heightPerLine * (lineSpace / 2)));
      canvas.drawLine(
        p1,
        p2,
        paint
          ..color = Theme.of(context).colorScheme.onSurface
          ..strokeWidth = 2.0,
      );
    }
    if (width <= height) {// domain too small to draw pretty edges
      final theRect = Rect.fromLTWH(position.dx, startY, width, height);
     if (addPatterns){
      p1.paintOnRect(canvas, size, theRect);
     }
     else{ // solid fill
      canvas.drawRect(
        theRect,
        paint
          ..color = query? Theme.of(context).colorScheme.onSurface:searchdata.get_colors(domain.name).$1
          ..style = PaintingStyle.fill,
      );
     }
     // outline region either way
      canvas.drawRect(
        Rect.fromLTWH(position.dx, startY, width, height),
        paint
          ..color = Theme.of(context).colorScheme.onSurface
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
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
      if(addPatterns) {
        p1.paintOnPath(canvas, size, path);
      }
      else {
      canvas.drawPath(
        path,
        paint
          ..color = query? Theme.of(context).colorScheme.onSurface:searchdata.get_colors(domain.name).$1
          ..style = PaintingStyle.fill,
      );
      }
      // outline the domain either way
      canvas.drawPath(
        path,
        paint
          ..color = Theme.of(context).colorScheme.onSurface
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
    // Now, add the name of the domain
    TextPainter painter;
    painter = TextPainter(
      textAlign: TextAlign.start,
      textDirection: TextDirection.ltr,
    );
    String name = "";
    double textOffset = position.dx + (width / 2);
    String evalString = (domain.fromBlast || domain.source == AnnotationType.interpro) ? "":" ("+domain.domEvalue.toStringAsExponential(2)+")";
    Color textFG = searchdata.get_colors(domain.name).$2;
    Color textBG = Color(0x00000000); // transparent
    if(addPatterns){ // text becomes white on black background for visibility
      textFG = Color(0xFFFFFFFF); // white
      textBG = Color(0xFF000000); // black
    }
    // see if all the data we'd like to display fits in the domain
    if(domain.source == AnnotationType.interpro){
      // InterPro domain; see how to display the name
      switch (domain.iType){
        case IEntryType.domain:
          if (pfamNames && domain.pfamName != ""){
            name = domain.pfamName + evalString;
          }
          else{
            switch (showInterproIdAs){
              case ShowInterproIdEnum.id:
                name = domain.name + evalString;
                break;
              case ShowInterproIdEnum.short_name:
                name = domain.ipShort != "" ? domain.ipShort + evalString : domain.name + evalString;
                break;
              case ShowInterproIdEnum.long_name:
                name = domain.ipLong != "" ? domain.ipLong + evalString : domain.name + evalString;
                break;
            }
          }
          break;
        default: 
          switch (showInterproIdAs){
              case ShowInterproIdEnum.id:
                name = domain.name + evalString;
                break;
              case ShowInterproIdEnum.short_name:
                name = domain.ipShort != "" ? domain.ipShort + evalString : domain.name + evalString;
                break;
              case ShowInterproIdEnum.long_name:
                name = domain.ipLong != "" ? domain.ipLong + evalString : domain.name + evalString;
                break;
            }
        }
    }
    else{
      name = domain.name + evalString;
    }
    //name = (domain.source == AnnotationType.interpro && pfamNames && domain.pfamName != "") ? domain.pfamName: domain.name + evalString;
    painter.text =
        painter.text = TextSpan(
          text: name,
          style: textTheme.bodyMedium!.copyWith(
            color: query?Theme.of(context).colorScheme.surface: textFG,
            backgroundColor: query?Theme.of(context).colorScheme.onSurface:textBG
          ),
        );
    painter.layout();
    if (painter.width <= (width - heightPerLine)) {
      // -2 to make sure domain extends past name
      Offset textPosition = Offset(textOffset - painter.width / 2, startY);
      painter.paint(canvas, textPosition);
    } else {
      //see if the domain name fits
    //  name = domain.source == AnnotationType.interpro && pfamNames && domain.pfamName != "" ? domain.pfamName : domain.name;
      painter.text = TextSpan(
        text: name,
        style: textTheme.bodyMedium!.copyWith(
          color: query?Theme.of(context).colorScheme.surface:textFG,
          backgroundColor: query?Theme.of(context).colorScheme.onSurface:textBG
        ),
      );
      painter.layout();
      if (painter.width <= (width - heightPerLine)) {
        Offset textPosition = Offset(textOffset - painter.width / 2, startY);
        painter.paint(canvas, textPosition);
      } else {
        //Cram in what we can
        int numChars = name.length;
        while (painter.width > (width - heightPerLine) && numChars > 0) {
          numChars -= 1;
          name = name.substring(0, numChars);
          painter.text = TextSpan(
            text: name,
            style: textTheme.bodyMedium!.copyWith(
              color: query?Theme.of(context).colorScheme.surface:textFG,
              backgroundColor: query?Theme.of(context).colorScheme.onSurface:textBG
            ),
          );
          painter.layout();
        }
        Offset textPosition = Offset(textOffset - painter.width / 2, startY);
        painter.paint(canvas, textPosition);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw domain structure of the sequence that the hit matched
    Paint paint = new Paint()..style = PaintingStyle.fill;
    TextPainter legendPainter = TextPainter(
      textAlign: TextAlign.start,
      textDirection: TextDirection.ltr,
    );
    if (allDomains) {
      legendPainter.text = TextSpan(
        text: "Structure",
        style: textTheme.bodyMedium!.copyWith(color: colorScheme.onSurface),
      );
    } else {
      legendPainter.text = TextSpan(
        text: "Structure",
        style: textTheme.bodyMedium!.copyWith(color: colorScheme.onSurface),
      );
    }

    legendPainter.layout();
    legendPainter.paint(
      canvas,
      Offset(0, ((lineSpace - 1) / 2) * heightPerLine),
    );
    legendPainter.text = TextSpan(
      text: "Query\nHomology",
      style: textTheme.bodyMedium!.copyWith(color: colorScheme.onSurface),
    );

    legendPainter.layout();
    legendPainter.paint(
      canvas,
      Offset(
        0,
        (queryStartRow * lineSpace) * heightPerLine,
      ),
    );
    // draw the structure/annotated domains
    _drawDomains(
      context,
      canvas,
      paint,
      0,
      domains,
      domainRows,
      textTheme,
      buttons,
      size,
      totalWidth,
      false,
      pixelsPerResidue
    );
    // draw the queries

    // add the representation of the hit(s) to the sequence
    _drawDomains(
      context,
      canvas,
      paint,
      queryStartRow,
      queries,
      queryRows,
      textTheme,
      buttons,
      size,
      totalWidth,
      true,
      pixelsPerResidue
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

bool abbreviationRequired(
  Hit hit,
  bool allDomains,
  bool showSequence,
  BuildContext context,
  double pixelsPerResidue,
) {
  bool pfamNames = Provider.of<HSettings>(context, listen: false).showNamesFrom == ShowNamesFrom.pfam;
  //textWidth here is the width of the legend text
  TextPainter painter;
  painter = TextPainter(
    textAlign: TextAlign.start,
    textDirection: TextDirection.ltr,
  ); // find the height of a line using the same method we'll use when drawing.
  painter.text = TextSpan(
    text: "test",
    style: Theme.of(context).textTheme.bodyMedium,
  );
  painter.layout();
  double heightPerLine = painter.preferredLineHeight;
  double widthPerChar = 0.0;
  for (var domain in hit.queries) {
    // figure out how long the domain needs to be to fit the text we'll put in it
    String evalString = "("+domain.domEvalue.toStringAsExponential(2)+ ") ";
    String name = (domain.source == AnnotationType.interpro && pfamNames && domain.pfamName != "") ? domain.pfamName: domain.name + evalString;
    painter.text = TextSpan(
      text: name,
      style: Theme.of(context).textTheme.bodyMedium,
    );
    painter.layout();
    double domainWidth =
        painter.width +
        heightPerLine; // add heightperline to make room for rounded edges
    if (domainWidth/pixelsPerResidue > ((domain.seqEnd - domain.seqStart)+1)){ // the text is too big to fit
      return true;
    }
  }
  // Now repeat for the sequence domains
  for (var domain in allDomains ? hit.domains : hit.structureDomains) {
    // figure out how long the domain needs to be to fit the text we'll put in it
    String evalString = domain.domEvalue.toStringAsExponential(2);
    String name = domain.name + " (" + evalString + ")";
    painter.text = TextSpan(
      text: name,
      style: Theme.of(context).textTheme.bodyMedium,
    );
    painter.layout();
    double domainWidth =
        painter.width +
        heightPerLine; // add heightperline to make room for rounded edges
    if (domainWidth/pixelsPerResidue > ((domain.seqEnd - domain.seqStart)+1)){ // the text is too big to fit
      return true;
    }
  }
  if (showSequence) {
    // also consider the width needed to show the sequence
    String seqText = hit.sequence;
    painter.text = TextSpan(
      text: seqText,
      style: Theme.of(context).textTheme.bodyMedium,
    );
    painter.layout();
    double seqWidth = painter.width/hit.sequence.length;
    if (seqWidth > pixelsPerResidue){ 
      return true;
    }
  }
  return false; // if we get here, the text fits without abbreviation
}

double requiredHitWidth(
  Hit hit,
  bool allDomains,
  bool showSequence,
  BuildContext context,
) {
  bool pfamNames = Provider.of<HSettings>(context, listen: false).showNamesFrom == ShowNamesFrom.pfam;
  //textWidth here is the width of the legend text
  TextPainter painter;
  painter = TextPainter(
    textAlign: TextAlign.start,
    textDirection: TextDirection.ltr,
  ); // find the height of a line using the same method we'll use when drawing.
  painter.text = TextSpan(
    text: "test",
    style: Theme.of(context).textTheme.bodyMedium,
  );
  painter.layout();
  double heightPerLine = painter.preferredLineHeight;
  double widthPerChar = 0.0;
  for (var domain in hit.queries) {
    // figure out how long the domain needs to be to fit the text we'll put in it
    String evalString = domain.domEvalue.toStringAsExponential(2);
    String name = (domain.source == AnnotationType.interpro && pfamNames && domain.pfamName != "") ? domain.pfamName: domain.name + evalString;
    painter.text = TextSpan(
      text: name,
      style: Theme.of(context).textTheme.bodyMedium,
    );
    painter.layout();
    double domainWidth =
        painter.width +
        heightPerLine; // add heightperline to make room for rounded edges
    double domainWidthPerChar = domainWidth / (domain.seqEnd - domain.seqStart);
    if (domainWidthPerChar > widthPerChar) {
      //this domain needs more room per character than previous ones
      widthPerChar = domainWidthPerChar;
    }
    ;
  }
  // Now repeat for the sequence domains
  for (var domain in allDomains ? hit.domains : hit.structureDomains) {
    // figure out how long the domain needs to be to fit the text we'll put in it
    String evalString = domain.domEvalue.toStringAsExponential(2);
    String name = domain.name + " (" + evalString + ")";
    painter.text = TextSpan(
      text: name,
      style: Theme.of(context).textTheme.bodyMedium,
    );
    painter.layout();
    double domainWidth =
        painter.width +
        heightPerLine; // add heightperline to make room for rounded edges
    double domainWidthPerChar = domainWidth / (domain.seqEnd - domain.seqStart);
    if (domainWidthPerChar > widthPerChar) {
      //this domain needs more room per character than previous ones
      widthPerChar = domainWidthPerChar;
    }
    ;
  }
  if (showSequence) {
    // also consider the width needed to show the sequence
    String seqText = hit.sequence;
    painter.text = TextSpan(
      text: seqText,
      style: Theme.of(context).textTheme.bodyMedium,
    );
    painter.layout();
    double seqWidth = painter.width / hit.sequence.length;
    if (seqWidth > widthPerChar) {
      widthPerChar = seqWidth;
    }
  }
  return (widthPerChar * hit.seqLength) +
      _calc_legend_dimensions(Theme.of(context).textTheme).$1;
}

//Widget to draw the data for a hit
class DrawHit extends StatefulWidget {
  const DrawHit({
    super.key,
    required this.hit,
    required this.searchdata,
    this.allDomains = false,
    this.fullWidth = true,
    this.showSequence = false,
    this.sequence = "",
    required this.maxLength,
    required this.pixelsPerResidue
  });
  final Hit hit;
  final bool allDomains;
  final bool fullWidth;
  final SearchData searchdata;
  final bool showSequence;
  final String sequence;
  final int maxLength;  
  final double pixelsPerResidue;
  State<DrawHit> createState() => _DrawHitState();
}

class _DrawHitState extends State<DrawHit> {
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    //   print("Drawing hit: " + widget.hit.name+ "With  "+ widget.hit.queries.length.toString() + " queriy hits");
    final width;
    double textWidth, textHeight;
    (textWidth, textHeight) = _calc_legend_dimensions(
      Theme.of(context).textTheme,
    );
    double widthPerChar = requiredHitWidth(
          widget.hit,
          widget.allDomains,
          widget.showSequence,
          context,
        ) /
        widget.hit.seqLength;
    if (widget.fullWidth) {
      double expandedPixelsPerResidue = widthPerChar > widget.pixelsPerResidue ? widthPerChar : widget.pixelsPerResidue;
      int expandedLength = widget.hit.seqLength > widget.maxLength ? widget.hit.seqLength : widget.maxLength;
      width = expandedLength * expandedPixelsPerResidue + textWidth;
    //  print("fullwidth for hit ${widget.hit.name} with expanded length $expandedLength and expanded pixels per residue $expandedPixelsPerResidue gives width $width");
      return 
      Padding(
        padding: EdgeInsets.only(right:EDGEPAD),
        child: 
      Scrollbar(
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
                context: context,
                sequence: widget.hit.sequence,
                length: expandedLength,
                domains:
                    widget.allDomains
                        ? widget.hit.domains
                        : widget.hit.structureDomains,
                width: width,
                queries: widget.hit.queries,
                searchdata: widget.searchdata,
                seqLength: widget.hit.seqLength,
                seqEvalue: widget.hit.seqEvalue,
                allDomains: widget.allDomains,
                pixelsPerResidue: expandedPixelsPerResidue,
              ),
              if (widget.showSequence)
                Padding(
                  padding: EdgeInsets.only(left: textWidth),
                  child: Text(
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    widget.sequence,
                  ),
                ),
            ],
          ),
        ),
      ),);
    } 
    
    else {
      // make the hit fit in the window
      width = widget.hit.seqLength >= widget.maxLength ? MediaQuery.sizeOf(context).width-EDGEPAD: widget.hit.seqLength * widget.pixelsPerResidue + textWidth;
      textWidth = 0.0;
      double adjustedPixelsPerResidue = widget.hit.seqLength > widget.maxLength ? widget.pixelsPerResidue * (widget.maxLength.toDouble() / widget.hit.seqLength.toDouble())  : widget.pixelsPerResidue;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DrawDomains(
            context: context,
            sequence: widget.hit.sequence,
            length: widget.maxLength,
            domains:
                widget.allDomains
                    ? widget.hit.domains
                    : widget.hit.structureDomains,
            width: width,
            queries: widget.hit.queries,
            searchdata: widget.searchdata,
            seqLength: widget.hit.seqLength,
            seqEvalue: widget.hit.seqEvalue,
            allDomains: widget.allDomains,
            pixelsPerResidue: adjustedPixelsPerResidue,
          ),
          if (widget.showSequence)
            Text(
              "Sequence:",
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          if (widget.showSequence)
            Padding(
              padding: EdgeInsets.only(left: textWidth),
              child: Text(
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                widget.sequence,
              ),
            ),
        ],
      );
    }
  }
}

// Widget to display the information for a category of hits
class DrawCategory extends StatefulWidget {
  DrawCategory({
    super.key,
    required this.which,
    required this.from,
    required this.context,
    required this.maxLength,
    required this.pixelsPerResidue
  });

  final int which;
  final selectedby from;
  final int maxLength;
  final double pixelsPerResidue;
  BuildContext context;
   @override
  State<DrawCategory> createState() => _DrawCategory();
}

class _DrawCategory extends State<DrawCategory>{
  @override
  late bool fullWidth;
  void initState(){
    super.initState();
    fullWidth = false;
  }
  @override
  Widget build(BuildContext context) {
    return Consumer3<SearchData, HSettings, GraphData>(
      builder: (context, searchdata, hsettings, graphdata, child) {
        final SigCategory category =
            widget.from == selectedby.structure
                ? searchdata.rootHits[widget.which]
                : searchdata.currentHits[widget.which];
        final Hit theHit = searchdata.hits[category.hits[0].toInt()];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child:Text(
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge!.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,

                          ),
                          
                              "${category.hits.length} hits with signature ${searchdata.structures[category.signature]}"
                        ),),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                
                   Text(
                          overflow: TextOverflow.clip,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium!.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          "Example: " +
                              searchdata.hits[category.hits[0].toInt()].name +
                              "\nTaxon: " +
                              graphdata.graph[searchdata.hits[category.hits[0].toInt()].taxid]!.name+
                      
                          "\nDescription: " +
                              searchdata.hits[category.hits[0].toInt()].description

                        ),
                        
                        ],),
               Row( children:[(theHit.seqLength > widget.maxLength || abbreviationRequired(theHit, false, false, context, widget.pixelsPerResidue)) ?  
                RotatedBox(
                                  quarterTurns: 1,
                                  child: IconButton.outlined(
                                    iconSize: 24 * hsettings.scale,
                                    onPressed: () {
                                    setState(() {
                                      fullWidth = !fullWidth;});},
                                    icon:
                                        fullWidth
                                            ? Icon(
                                              Icons.compress,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                            )
                                            : Icon(
                                              Icons.expand,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                            ),
                                  ),
                                )
                                : SizedBox.shrink(),
                            IconButton.outlined(
                              iconSize: 24 * hsettings.scale,
                              onPressed: () {
                                searchdata.selectedStructure = widget.which;
                                searchdata.selectedBy = widget.from;
                                context.go("/subtreeevalue");
                              },
                              icon: Icon(
                                Icons.search,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),],),

              
          DrawHit(
              hit: searchdata.hits[category.hits[0].toInt()],
              searchdata: searchdata,
              fullWidth: fullWidth,
              maxLength: widget.maxLength,
              pixelsPerResidue: widget.pixelsPerResidue,
            ),
          ],
        );
      },
    );
  }
}
