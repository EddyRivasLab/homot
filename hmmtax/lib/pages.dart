/* pages.dart: Routines and widgets for the different pages used it HMMot
 * Contents:
 * annDataSelect -- Widget to select the annotated database directory
 * domTblSelect -- Widget to select the domtblout files
 * MainPage -- The first page a user sees, which allows them to select the annotated database
 *             and domtblout files they wish to view
 * SettingsPage -- allows the user to configure the application
 * GraphPage -- Displays the taxonomy graph
 * 
NPC: 8/19/25 [The Cushy Office]
*/

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:hmmtax/main.dart';
import 'package:hmmtax/utility.dart';
import 'package:hmmtax/graph_painter.dart';
import 'package:hmmtax/draw_data.dart';
import 'package:hmmtax/printing.dart';
import 'package:hmmtax/src/rust/api/graph.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:input_quantity/input_quantity.dart';
import 'package:system_fonts/system_fonts.dart';
import "package:go_router/go_router.dart";
import 'package:touchable/touchable.dart';
import 'package:matrix4_transform/matrix4_transform.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter_svg/flutter_svg.dart';


// Widget to enter information about what files to read
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final ScrollController _mainScrollController = ScrollController();
  String? dtemp;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: HmmtaxAppBar(text: "Select Data"),
      body:           Consumer4<FileData, GraphData, SearchData, HSettings>(
      builder: (context, filedata, graphdata, searchdata, hsettings, child) {
              return Column(
        //mainAxisSize: MainAxisSize.min,
        children: <Widget>[
                    Text(style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onPrimary),
                    "Annotated Database:"),
                   
                   
                    AnnDbSelect(),
    
                    Text(style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onPrimary),
                    "Domtblout File(s):"),
                    Builder(
                        builder: (context) {
                            return 
                              Flexible(
                                child: Scrollbar(
                              controller: _mainScrollController,
                              child:  ListView.builder(
                              shrinkWrap: true, 
                              controller: _mainScrollController,
                              itemCount: filedata.domtbloutFiles.length,
                              itemBuilder: (BuildContext context, int index) {
                                return DomtblEdit(which: index);
                              },
                              ),
                              ),);
                        },
                      ),
                      DomtblSelect(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        ElevatedButton(
                          onPressed: filedata.domtbloutFiles.isNotEmpty ? () async {
                            filedata.clearDomtbloutFiles();
                            filedata.notifyListeners;
                          } : null,
                          child: Text("Clear"),
                        ),
                      ],
                    ),
                    Center(
                      child: ElevatedButton(
                        onPressed: filedata.annFileSet && filedata.domtbloutFiles.isNotEmpty? () async {
                          const loadingSnackBar = SnackBar(
                            duration: Duration(days: 1),
                            backgroundColor: Colors.yellow,
                            content: Center(child: Text("Loading Data")),
                          );

                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            duration: Duration(days: 1),
                            backgroundColor: Colors.yellow,
                            content: Center(child: Text("Loading Data", style: TextStyle(color: Colors.black),),),
                            ),
                          ); 
                          //Gather hits from the domtblout files
                         var results =await (fetchGraph(annfile: filedata.annotationsFile!, domtbloutFiles: filedata.domtbloutFiles, evalMax:
                          hsettings.evalMax, domEvalMax: hsettings.domEvalMax));
                          ScaffoldMessenger.of(context).clearSnackBars();
                          // Update the overview data
                          if (await !results!.succeeded) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                //duration: Duration(days: 1),
                                backgroundColor: Colors.red,
                                duration: const Duration(days: 100),
                                content: Center(
                                child: Column(
                                  children: [
                                  Text("Load Failed: ${results.message}"),
                                  ElevatedButton(child: Text("Close"),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                    },
                                  ),
                                  ],
                                ),
                              ),
                              ),
                            );
                          } else {
                            graphdata.clearGraph();
                            graphdata.setGraph(results.graph);
                            graphdata.setDepth(results.depth);
                            graphdata.setMaxLevels(results.depth);
                            graphdata.addRoot(results.root); // set the current root to the overall root
                            graphdata.graphRoot = results.root; // and set the overall root as well.
                            searchdata.setSearchResults(results);
                            searchdata.selectedBy = selectedby.none; // reset selection
                            context.go("/graph");
                          }
                        }:null,
                          child: Text("Load Data"),
                        ),
                    )
                  ],
              );
            },
          ),
      bottomNavigationBar: MainNavBar(whereAmI: WhichPage.home),
    );
  }
}

// Page to control settings
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> { 
  Future<void> _showWarning() async{
    return showDialog<void>(
      context:context,
      barrierDismissible: false,
      builder: (BuildContext context) {return AlertDialog(
        title: Text(style: Theme.of(context).textTheme.headlineLarge!.copyWith(color: Theme.of(context).colorScheme.onPrimary), 
        "Reload Data"),
        backgroundColor: Theme.of(context).colorScheme.primary,
        content: Text(style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: 
          Theme.of(context).colorScheme.onPrimary), "Data must be re-loaded for changes to e-value settings to take effect."),
        actions: [
          TextButton(child: Text(style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: 
          Theme.of(context).colorScheme.primary), 'OK'),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(Theme.of(context).colorScheme.onPrimary),
            foregroundColor: WidgetStateProperty.all(Theme.of(context).colorScheme.primary),
          ),
          onPressed: () => Navigator.of(context).pop()),
        ]
      );}
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: HmmtaxAppBar(text: "Settings"),
      body:           Consumer<HSettings>(
            builder: (context, hsettings, child) {
              return Column(
        children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          color: Theme.of(context).colorScheme.surface,
                          child:Column(
                          children: [
                          Text(style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface), "Theme"), Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                          ChoiceChip(
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            checkmarkColor: Theme.of(context).colorScheme.onSurface, 
                            selectedColor: Theme.of(context).colorScheme.surface, 
                            side: BorderSide(color: Theme.of(context).colorScheme.onSurface),
                            label: Text(style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface), "Light"),
                          selected: hsettings.mode == brightModes.light,
                          onSelected: (bool selected){
                            if (selected == true){
                              hsettings.mode= brightModes.light;
                            }
                          }),
                          ChoiceChip(label: Text(style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface), "Dark"),
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            checkmarkColor: Theme.of(context).colorScheme.onSurface, 
                            selectedColor: Theme.of(context).colorScheme.surface, 
                            side: BorderSide(color: Theme.of(context).colorScheme.onSurface),
                            selected: hsettings.mode == brightModes.dark,
                            onSelected: (bool selected){
                              if (selected == true){
                                hsettings.mode =brightModes.dark;
                              }
                            }),
                          ChoiceChip(
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            checkmarkColor: Theme.of(context).colorScheme.onSurface, 
                            selectedColor: Theme.of(context).colorScheme.surface, 
                            side: BorderSide(color: Theme.of(context).colorScheme.onSurface),
                            label: Text(style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface), "System"),
                            selected: hsettings.mode == brightModes.system,
                            onSelected: (bool selected){
                              if (selected == true){
                                hsettings.mode =brightModes.system;
                              }
                            }),],),
                          ]),),
                        Card(
                          color: Theme.of(context).colorScheme.surface,
                          child:Column(children: [
                        Text(style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface), "Select Font"),  
                        HmmotSystemFontSelector(
                          width: 200*hsettings.scale,
                          textStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),
                          initial: hsettings.font,
                          isFontPreviewEnabled: true,
                          onFontSelected: (font){
                            hsettings.font =font;
                          }
                        ),],),),
                        Card(
                          color: Theme.of(context).colorScheme.surface,
                          child:Column(children:[
                        Text(style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface), "Font Scale Factor"),
                        InputQty.double(
                          initVal: hsettings.scale,
                          minVal: 0.001,
                          steps: 0.1,
                          decoration: QtyDecorationProps(
                            qtyStyle: QtyStyle.btnOnRight,
                            border :OutlineInputBorder(borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.onSurface,)),
                          ),
                          onQtyChanged: (val) {
                            hsettings.scale =val;
                          },
                        ),],),),
                        Card(
                          color: Theme.of(context).colorScheme.surface,
                          child: IntrinsicWidth(child: Column(children: [
                          Text(style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface), "Maximum E-Value to Show"),
                          TextFormField(style: Theme.of(context).textTheme.bodyMedium,
                            initialValue: hsettings.evalMax.toString(),
                            decoration: InputDecoration(border: OutlineInputBorder()),
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            onFieldSubmitted: (String? value) async{
                              double? val = double.tryParse(value!);
                              if(val != null){hsettings.evalMax = val;
                                await(_showWarning());}
                            },
                            validator: (String? value){
                              return(value == null || double.tryParse(value) == null) ? "Must be a real number":null;
                            }),],),),),
                        Card(
                          color: Theme.of(context).colorScheme.surface,
                          child: IntrinsicWidth(child: Column(children: [
                          Text(style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),"Maximum Domain E-Value to Show"),
                          TextFormField(style: Theme.of(context).textTheme.bodyMedium,
                            initialValue: hsettings.domEvalMax.toString(),
                            decoration: InputDecoration(border: OutlineInputBorder()),
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            onFieldSubmitted: (String? value) async{
                              double? val = double.tryParse(value!);
                              if(val != null){hsettings.domEvalMax = val;
                              await(_showWarning());
                            }},
                            validator: (String? value){
                              return(value == null || double.tryParse(value) == null) ? "Must be a real number":null;
                            }),],),),),
                        Card(
                          color: Theme.of(context).colorScheme.surface,
                          child:Column(children:[
                        Text(style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface), "Graph Line Width"),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          InputQty.double(
                            initVal: hsettings.lineWidth,
                            minVal: 0.5,
                            steps: 0.5,
                            decoration: QtyDecorationProps(
                              qtyStyle: QtyStyle.btnOnRight,
                              border :OutlineInputBorder(borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.onSurface,)),
                            ),
                            onQtyChanged: (val) {
                              hsettings.lineWidth =val;
                            },
                          ),
                          SizedBox(width: 20),
                          CustomPaint(
                              size: Size(50, 10),
                              painter: LinePainter(context, hsettings, MediaQuery.of(context).devicePixelRatio),
                            ),  
                        ],),],),),
                         
                      ],
                    ),
                  ],
              );
            },
          ),
      bottomNavigationBar: MainNavBar(whereAmI: WhichPage.settings),
    );
  }
}




// Page to control settings
class GraphPage extends StatefulWidget {
  const GraphPage({super.key});

  @override
  _GraphPageState createState() => _GraphPageState();
}

class _GraphPageState extends State<GraphPage> { 
  double scaleFactor = 1.0;
  OverlayEntry? _overlayEntry;
  OverlayEntry? _norootOverlayEntry;
  @override
  Widget build(BuildContext context) {

    double _value = context.watch<GraphData>().maxLevels.toDouble();
    double _rotation = context.watch<GraphData>().rotation*(360/(2*pi));
    double _scale = context.watch<GraphData>().scale;
    double _xOffset = context.watch<GraphData>().translateX;
    double _yOffset = context.watch<GraphData>().translateY;

    final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();

    void _showNorootOverlay(BuildContext context, Offset tapPosition, PlatformInt64 nodeId, Node theNode) {
     _norootOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: tapPosition.dx,
        top: tapPosition.dy,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.yellow,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text("Node ${theNode.name} has no children, so cannot be the root of the graph",
              style: TextStyle(color: Colors.black),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_norootOverlayEntry!);

  }     
    void _removeNorootOverlay() {
    _norootOverlayEntry?.remove();
    _norootOverlayEntry = null;
  }

     void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

    void _showOverlay(BuildContext context, Offset tapPosition, PlatformInt64 nodeId, Node theNode) {
     _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: tapPosition.dx,
        top: tapPosition.dy,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              children: [
                Text('${theNode.name}, \nrank=${theNode.rank}, total descendants: ${theNode.hitsBelow} level = ${theNode.ranknum}',
                  style: TextStyle(color: Colors.white),
                ),
                  Consumer2<SearchData, GraphData>(
                    builder: (context, searchdata, graphdata, child){
                    
                      return ElevatedButton( style: ButtonStyle(backgroundColor: WidgetStateProperty.resolveWith((states){
                                      return Theme.of(context).colorScheme.primary;}),),
                                  onPressed: (){
                                    graphdata.addRoot(theNode.taxid);
                                    if (theNode.taxid != graphdata.graphRoot){
                                      // We want to see the hits below a non-root node, so need to fetch them
                                        HitResults hitResults =
                                          findHitsBelowNode(root: theNode.taxid, graph: graphdata.graph, hitStructures: searchdata.hitStructures);
                                          searchdata.currentHitsByEvalue = hitResults.hits;
                                          searchdata.currentHits = hitResults.categories;
                                    }
                                    searchdata.selectedBy =selectedby.subtree;
                                    _removeOverlay();
                                    context.go("/subtreestructure");
                                  },
                                  child: Center(child: Text("show Hits",
                                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onPrimary),),
                                  ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context)?.insert(_overlayEntry!);

  }     
  
    return Scaffold(
      backgroundColor: Colors.grey,//Theme.of(context).colorScheme.primary,
      appBar: HmmtaxAppBar(text: "Taxonomic Display"),
      body:     LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
                var width = constraints.maxWidth;
            var height = constraints.maxHeight;
            var center = Offset(width/2, height/2);
            var radius = (min(width, height)/2.0); // Leave a little space around the graph
            var availSpace = radius * 0.3;
            var legendHeight = availSpace;
            var legendWidth = availSpace;
            if (height > width){
              legendHeight += (height - width)/2.0;
            }
            if (width > height){
              legendWidth += (width - height)/2.0;
            }

        return Consumer2<HSettings, GraphData>(
            builder: (context, hsettings, graphdata, child) {
              graphdata.size = Size(width, height);
              return Stack(
                  children: [
                       GestureDetector(
                         onTapDown: (details) {
                          final Matrix4 inverseMatrix = Matrix4.inverted(graphdata.transform);
                          final Vector3 untransformed = inverseMatrix.transform3(Vector3(details.localPosition.dx, details.localPosition.dy, 0));
                          var node = graphdata.findNode(untransformed.x, untransformed.y, center.dx, center.dy, );
                          _removeOverlay();
                          _removeNorootOverlay();
                          if(node >=0){ // click was in the graph
                            if (graphdata.getNode(node).children.length == 0){
                              _showNorootOverlay(context, details.globalPosition, node, graphdata.getNode(node));
                              Future.delayed(const Duration(seconds: 5), () {
                                _removeNorootOverlay();
                              });
                            }
                          else{
                            graphdata.popPastIndex();
                            graphdata.addRoot(node);
                          };
                          }
                         },
                        onSecondaryTapDown: (details) {

                          final Matrix4 inverseMatrix = Matrix4.inverted(graphdata.transform);
                          final Vector3 untransformed = inverseMatrix.transform3(Vector3(details.localPosition.dx, details.localPosition.dy, 0));
                          var node = graphdata.findNode(untransformed.x, untransformed.y, center.dx, center.dy, );
                          _removeOverlay();
                          _removeNorootOverlay();
                          if (node >=0){
                            _showOverlay(context, details.globalPosition, node, graphdata.getNode(node));
                          }
                          },

                        child: 
                            Transform(transform: graphdata.transform, 
                            child:CustomPaint(
                              size: Size(width, height),
                              painter: GraphPainter(context, graphdata, devicePixelRatio, graphdata.tController, radius, hsettings),
                            ),  
                            ),),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[ 
                SizedBox(
                              height: legendHeight,
                              width: legendWidth,
                                  child : Card(
                                color: Theme.of(context).colorScheme.surface,
                              child:     Padding(padding: EdgeInsets.all(2.0),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                
                                children: [
                                  Ink(
                                    decoration: ShapeDecoration(color: Theme.of(context).colorScheme.primary, shape: CircleBorder()),
                                    child: IconButton(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      icon: const Icon(Icons.arrow_back),
                                      onPressed: graphdata.decrementIndex,
                                      ),
                                    ),
                                    Text("Graph Center History",
                                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),),
                                     Ink(
                                    decoration: ShapeDecoration(color: Theme.of(context).colorScheme.primary, shape: CircleBorder()),
                                    child:
                                    IconButton(color: Theme.of(context).colorScheme.onPrimary,
                                  icon: const Icon(Icons.arrow_forward),
                                  onPressed: graphdata.incrementIndex,),),
                                ]),
                                Flexible( child: ScrollablePositionedList.separated(itemCount: graphdata.historyLength,
                                itemScrollController: graphdata.itemScrollController,
                                separatorBuilder: (BuildContext context, int index){
                                  return SizedBox(height:2);
                                },
                                itemBuilder: (BuildContext context, int index){
                                  String label;
                                  if(index == graphdata.historyIndex){
                                    label = "(Current) "+graphdata.historyNames(index);
                                                                    }
                                  else{
                                    label = graphdata.historyNames(index);
                                                                    }                                  
                                  return ElevatedButton( style: ButtonStyle(backgroundColor: WidgetStateProperty.resolveWith((states){
                                      return Theme.of(context).colorScheme.primary;}),),
                                  onPressed: (){if(graphdata.history(index) >=0){
                                    graphdata.setRoot(graphdata.history(index));
                                    graphdata.setHistoryIndex(index);}},
                                  child: Center(child: Text(label,
                                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onPrimary),),
                                  ),);
                                },
                                //scrollDirection: Axis.vertical,
                                //shrinkWrap: true,
                                ),),
                              ],),
                              ),),),
                          SizedBox(
                              height: legendHeight,
                              width: legendWidth,
                              child: Card(
                                color: Theme.of(context).colorScheme.surface,
                              child: Padding(padding: EdgeInsets.all(2.0),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center,
                               children: [ Text("Graph Levels Shown: ${graphdata.maxLevels}"
                               ,style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface)),
                                Row(
                                  children: [Text("1",style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),),
                                    Expanded(child: Slider(
                            value: _value,
                            label: _value.round().toString(),
                            min: 1.0,
                            max: graphdata.depth.toDouble(),
                            divisions: graphdata.depth - 1,
                            onChanged: (double value) {
                              setState(() {
                                graphdata.setMaxLevels(value.toInt());
                              });
                            },
                          ),),
                          Text("${graphdata.depth}",style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),),
                          ],),
                          ],
                          ),),),),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[ 
                            SizedBox(
                              height: legendHeight,
                              width: legendWidth,
                              child: Card(
                                color: Theme.of(context).colorScheme.surface,
                              child:Padding(padding: EdgeInsets.all(2.0),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center,
                                children: [ 
                                Row(
                                  children: [Text("X Position:",style: Theme.of(context).textTheme.bodyMedium!.copyWith(height: 1, color: Theme.of(context).colorScheme.onSurface),),
                                    Expanded(child: Slider(
                            value: _xOffset,
                            label: _xOffset.round().toString(),
                            min: -min(width, height),
                            max: min(width, height),
                            onChanged: (double xOffset) {
                              setState(() {
                                graphdata.translateX =xOffset;
                              });
                            },
                          ),),
                                  ],),
                          Row(
                                  children: [Text("Y Offset: -${height/2}",style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),),
                                    Expanded(child: Slider(
                            value: _yOffset,
                            label: _yOffset.toStringAsFixed(2),
                            min: -height/2,
                            max: height/2,
                            onChanged: (double _yOffset) {
                              setState(() {
                                graphdata.translateY = _yOffset;
                              });
                            },
                          ),),
                          Text("${height/2}",style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),),
                          ],),
                         
                          ],),),
                         ),),
                          SizedBox(
                              height: legendHeight,
                              width: legendWidth,
                              child: Card(
                                color: Theme.of(context).colorScheme.surface,
                              child: Padding(padding: EdgeInsets.all(2.0),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center,
                                children: [ 
                                Row(
                                  children: [Text("Rotation: 0",style: Theme.of(context).textTheme.bodyMedium!.copyWith(height: 1, color: Theme.of(context).colorScheme.onSurface),),
                                    Expanded(child: Slider(
                            value: _rotation,
                            label: _rotation.round().toString(),
                            min: 0.0,
                            max: 360.0,
                            onChanged: (double rotation) {
                              setState(() {
                                graphdata.setRotation((rotation)*(2*pi/360));
                              });
                            },
                          ),),
                          Text("360",style: Theme.of(context).textTheme.bodyMedium!.copyWith(height:1, color: Theme.of(context).colorScheme.onSurface),),
                          ],),
                          Row(
                                  children: [Text("Scale: 0.25",style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),),
                                    Expanded(child: Slider(
                            value: _scale,
                            label: _scale.toStringAsFixed(2),
                            min: 0.25,
                            max: 5.0,
                            onChanged: (double _scale) {
                              setState(() {
                                graphdata.scale = _scale;
                              });
                            },
                          ),),
                          Text("5",style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),),
                          ],),
                         
                          ],),),),
                        ),
                                                  ],),
                  ],
                ),
                ],);
            },
          );}),
      bottomNavigationBar: MainNavBar(whereAmI: WhichPage.graph),
    );
  }
}



// Widget that displays all hits to the selected subtree by domain structure
class SubtreeStructurePage extends StatefulWidget {
  const SubtreeStructurePage({super.key});

  @override
  State<SubtreeStructurePage> createState() => _SubtreeStructurePageState();
}

class _SubtreeStructurePageState extends State<SubtreeStructurePage> {
  final ScrollController _scrollController2 = ScrollController();
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Consumer2<SearchData, GraphData>(
        builder: (context, searchdata, graphdata, child) {
          final List<SigCategory> theHits = searchdata.currentHits;
          int numHits =0;
          for (var category in theHits){
            numHits += category.hits.length;
          }
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.primary,
            appBar:  HmmtaxAppBar(text:"${numHits} hits found under ${graphdata.graph[graphdata.currentRoot]?.name}, with ${theHits.length} different domain structures"),
            body: Scrollbar(
              controller: _scrollController2,
              child: ListView.builder(
                controller: _scrollController2,
                itemCount: theHits.length,
                itemBuilder: (BuildContext context, int index) {
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    color: Theme.of(context).colorScheme.surface,
                    child: DrawCategory(
                      which: index,
                      from: selectedby.subtree_structure,
                    ),
                  );
                },
              ),
            ),
            bottomNavigationBar: MainNavBar(whereAmI: WhichPage.subgraphstructure),
          );
        },
      ),
    );
  }
}

// Widget that displays all results by domain structure
class AllStructurePage extends StatefulWidget {
  const AllStructurePage({super.key});

  @override
  State<AllStructurePage> createState() => _AllStructurePageState();
}
class _AllStructurePageState extends State<AllStructurePage> {
  final ScrollController _scrollController2 = ScrollController();
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Consumer2<SearchData, GraphData>(
        builder: (context, searchdata, graphdata, child) {
          final List<SigCategory> theHits = searchdata.rootHits;
          int numHits = searchdata.hits.length;
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.primary,
            appBar:  HmmtaxAppBar(text:"${numHits} hits found, with ${theHits.length} different domain structures"),
            body: Scrollbar(
              controller: _scrollController2,
              child: ListView.builder(
                controller: _scrollController2,
                itemCount: theHits.length,
                itemBuilder: (BuildContext context, int index) {
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    color: Theme.of(context).colorScheme.surface,
                    child: DrawCategory(
                      which: index,
                      from: selectedby.structure,
                    ),
                  );
                },
              ),
            ),
            bottomNavigationBar: MainNavBar(whereAmI: WhichPage.allstructure),
          );
        },
      ),
    );
  }
}

// Widget that displays all results by evalue
class AllEvaluePage extends StatefulWidget {
  const AllEvaluePage({super.key});

  @override
  State<AllEvaluePage> createState() => _AllEvaluePageState();
}

class _AllEvaluePageState extends State<AllEvaluePage> {
  final ScrollController _scrollController2 = ScrollController();
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Consumer2<SearchData, GraphData>(
        builder: (context, searchdata, graphdata, child) {

          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.primary,
            appBar:  HmmtaxAppBar(text : "${searchdata.hits.length} hits found"),
            body: Scrollbar(
              controller: _scrollController2,
              child: ListView.builder(
                controller: _scrollController2,
                itemCount: searchdata.hits.length ,
                itemBuilder: (BuildContext context, int index) {
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    color: Theme.of(context).colorScheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),
                            "Sequence: " + searchdata.hits[index].name +", E-Value: " + 
                            searchdata.hits[index].seqEvalue.toStringAsExponential(4),
                        ),
                        DrawHit(
                          hit: searchdata.hits[index],
                          searchdata: searchdata,
                        ),
                        Align( alignment: Alignment(1.0,0.0), child: IconButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                          onPressed: () {
                            searchdata.selectedHit = index;
                            context.go("/sequence");
                          },
                          icon: Icon(Icons.search, color: Theme.of(context).colorScheme.onPrimary),
                        ),),
                      ],
                    ),
                  );
                },
              ),
            ),
            bottomNavigationBar: MainNavBar(whereAmI: WhichPage.allevalue),
          );
        },
      ),
    );
  }
}

// Widget that displays a subtree's results by evalue
class SubtreeEvaluePage extends StatefulWidget {
  const SubtreeEvaluePage({super.key});

  @override
  State<SubtreeEvaluePage> createState() => _SubtreeEvaluePageState();
}

class _SubtreeEvaluePageState extends State<SubtreeEvaluePage> {
  final ScrollController _scrollController2 = ScrollController();
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Consumer2<SearchData, GraphData>(
        builder: (context, searchdata, graphdata, child) {
          Int64List hitIndices =Int64List(0);
          String title ="";
          switch (searchdata.selectedBy){
            case selectedby.subtree:
              hitIndices = searchdata.currentHitsByEvalue;

              break;
            case selectedby.subtree_structure:
              hitIndices = searchdata.currentHits[searchdata.selectedStructure].hits;
              title = "${hitIndices.length} hits found with domain structure ${searchdata.structures[searchdata.currentHits[searchdata.selectedStructure].signature]} under node ${graphdata.getNode(graphdata.currentRoot).name}";
              break;
            case selectedby.structure:
              hitIndices = searchdata.rootHits[searchdata.selectedStructure].hits;
              title = "${hitIndices.length} hits found with domain structure ${searchdata.structures[searchdata.rootHits[searchdata.selectedStructure].signature]}";
              break;
            default:
              hitIndices = Int64List(0) ;
          }
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.primary,
            appBar:  HmmtaxAppBar(text : title),
            body: Scrollbar(
              controller: _scrollController2,
              child: ListView.builder(
                controller: _scrollController2,
                itemCount: hitIndices.length,
                itemBuilder: (BuildContext context, int index) {
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    color: Theme.of(context).colorScheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),
                            "Sequence: " + searchdata.hits[hitIndices[index].toInt()].name +", E-Value: " + 
                            searchdata.hits[hitIndices[index].toInt()].seqEvalue.toStringAsExponential(4),
                        ),
                        DrawHit(
                          hit: searchdata.hits[hitIndices[index].toInt()],
                          searchdata: searchdata,
                        ),
                        Align( alignment: Alignment(1.0,0.0), child: IconButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                          onPressed: () {
                            searchdata.selectedHit = hitIndices[index].toInt();
                            context.go("/sequence");
                          },
                          icon: Icon(Icons.search, color: Theme.of(context).colorScheme.onPrimary),
                        ),),
                      ],
                    ),
                  );
                },
              ),
            ),
            bottomNavigationBar: MainNavBar(whereAmI: WhichPage.subtreeevalue),
          );
        },
      ),
    );
  }
}
// Page that shows the details for a single sequence
class SequencePage extends StatefulWidget {
  const SequencePage({super.key});

  @override
  State<SequencePage> createState() => _SequencePageState();
}

class _SequencePageState extends State<SequencePage> {
  final ScrollController _scrollController2 = ScrollController();
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Consumer<SearchData>(
        builder: (context, searchdata, child) {
          Hit theHit = searchdata.hits[searchdata.selectedHit.toInt()];
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.primary,
            appBar:  HmmtaxAppBar(text : "Sequence ${theHit.name}"),
            body: SingleChildScrollView(
              controller: _scrollController2,
              child: 
                Card(
                  margin: EdgeInsets.only(bottom: 8),
                  color: Theme.of(context).colorScheme.surface,
                  child: 
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),
                            "Sequence e-value: ${ 
                            theHit.seqEvalue.toStringAsExponential(4)}"
                        ),
                        DrawHit(
                          hit: theHit,
                          allDomains: true,
                          searchdata: searchdata,
                        ),
                        Text(
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),
                          "Sequence:",                 
                        ),
                        Text(
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),
                          theHit.sequence,
                        ),
                      ],
                    ),
                ),
            ),
            bottomNavigationBar: MainNavBar(whereAmI: WhichPage.sequence),
          );
        },
      ),
    );
  }
}

// Page that shows the details for a single sequence
class SvgPage extends StatefulWidget {
  const SvgPage({super.key});

  @override
  State<SvgPage> createState() => _SvgPageState();
}
class _SvgPageState extends State<SvgPage> {
  final ScrollController _scrollController2 = ScrollController();
  final String svgString = '''
<svg xmlns="http://www.w3.org/2000/svg" version="1.1" viewBox="0 0 166 202">
  <defs>
    <linearGradient id="triangleGradient">
      <stop offset="20%" stop-color="#000000" stop-opacity=".55" />
      <stop offset="85%" stop-color="#616161" stop-opacity=".01" />
    </linearGradient>
    <linearGradient id="rectangleGradient" x1="0%" x2="0%" y1="0%" y2="100%">
      <stop offset="20%" stop-color="#000000" stop-opacity=".15" />
      <stop offset="85%" stop-color="#616161" stop-opacity=".01" />
    </linearGradient>
  </defs>
  <path fill="#42A5F5" fill-opacity=".8" d="M37.7 128.9 9.8 101 100.4 10.4 156.2 10.4" />
  <path fill="#42A5F5" fill-opacity=".8" d="M156.2 94 100.4 94 79.5 114.9 107.4 142.8" />
  <path fill="#0D47A1" d="M79.5 170.7 100.4 191.6 156.2 191.6 156.2 191.6 107.4 142.8" />
  <g transform="matrix(0.7071, -0.7071, 0.7071, 0.7071, -77.667, 98.057)">
    <rect width="39.4" height="39.4" x="59.8" y="123.1" fill="#42A5F5" />
    <rect width="39.4" height="5.5" x="59.8" y="162.5" fill="url(#rectangleGradient)" />
  </g>
  <path d="M79.5 170.7 120.9 156.4 107.4 142.8" fill="url(#triangleGradient)" />
</svg>
''';
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Consumer<SearchData>(
        builder: (context, searchdata, child) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.primary,
            appBar:  HmmtaxAppBar(text : "SVG"),
            body:
                Card(
                  margin: EdgeInsets.only(bottom: 8),
                  color: Theme.of(context).colorScheme.surface,
                  child: SvgPicture.string(svgString, width: 500, height: 500),

                ),
            
            bottomNavigationBar: MainNavBar(whereAmI: WhichPage.sequence),
          );
        },
      ),
    );
  }
}
