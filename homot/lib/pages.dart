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
import 'package:homot/main.dart';
import 'package:homot/utility.dart';
import 'package:homot/graph_painter.dart';
import 'package:homot/draw_data.dart';
import 'package:homot/src/rust/api/graph.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:input_quantity/input_quantity.dart';
import 'package:system_fonts/system_fonts.dart';
import "package:go_router/go_router.dart";
import 'package:matrix4_transform/matrix4_transform.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';


// Static variables to hold the scroll positions of the different pages so that they're
// retained when you switch from page to page.  This is ugly, but seems to be the best 
// solution Flutter supports because the pages get disposed when you navigate away from them.
// Widget to enter information about what files to read
double allStructureScrollOffset = 0.0;
double allEvalueScrollOffset = 0.0; 
double selectedStructureScrollOffset = 0.0;
double selectedEvalueScrollOffset = 0.0;
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final ScrollController _mainScrollController = ScrollController();
  String? dtemp;
  @override
  void dispose(){
    //ScaffoldMessenger.of(context).clearSnackBars();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return SelectionArea(child: Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: homotAppBar(text: "Select Data"),
      body: Consumer4<FileData, GraphData, SearchData, HSettings>(
        builder: (context, filedata, graphdata, searchdata, hsettings, child) {
          return Column(
            //mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                "Annotations Database:",
              ),

              AnnDbSelect(),

              Text(
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                "Search Result File(s):",
              ),
              Builder(
                builder: (context) {
                  return Flexible(
                    child: Scrollbar(
                      controller: _mainScrollController,
                      child: ListView.builder(
                        shrinkWrap: true,
                        controller: _mainScrollController,
                        itemCount: filedata.domtbloutFiles.length,
                        itemBuilder: (BuildContext context, int index) {
                          return DomtblEdit(which: index);
                        },
                      ),
                    ),
                  );
                },
              ),
              DomtblSelect(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  ElevatedButton(
                    onPressed:
                        filedata.domtbloutFiles.isNotEmpty
                            ? () async {
                              filedata.clearDomtbloutFiles();
                              filedata.notifyListeners;
                            }
                            : null,
                    child: Text("Clear"),
                  ),
                ],
              ),
              Center(
                child: ElevatedButton(
                  onPressed:
                      filedata.annFileSet && filedata.domtbloutFiles.isNotEmpty
                          ? () async {
                            const loadingSnackBar = SnackBar(
                              duration: Duration(days: 1),
                              backgroundColor: Colors.yellow,
                              content: Center(child: Text("Loading Data")),
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                duration: Duration(days: 1),
                                backgroundColor: Colors.yellow,
                                content: Center(
                                  child: Text(
                                    "Loading Data",
                                    style: TextStyle(color: Colors.black),
                                  ),
                                ),
                              ),
                            );
                            //Gather hits from the domtblout files
                            var results = await (fetchGraph(
                              annfile: filedata.annotationsFile!,
                              domtbloutFiles: filedata.domtbloutFiles,
                              evalMax: hsettings.useSeqEvals ? hsettings.evalMax : double.infinity ,
                              evalMin: hsettings.useSeqEvals ? hsettings.evalMin : 0.0,
                              domEvalMax: hsettings.useDomEvals ? hsettings.domEvalMax : double.infinity ,
                              domEvalMin: hsettings.useDomEvals ? hsettings.domEvalMin : 0.0,
                              fileType: hsettings.dataType,
                              interproShowSuperfamily:
                                  hsettings.showInterproSuperfamily,
                              interproShowFamily: hsettings.showInterproFamily,
                              interproShowDomain: hsettings.showInterproDomain,
                              interproShowRepeat: hsettings.showInterproRepeat, 
                              interproShowSite: hsettings.showInterproSite,
                              interproShowOther: hsettings.showInterproOther,
                              interproShowPfamNames: (hsettings.showNamesFrom == ShowNamesFrom.pfam),
                            ));
                            ScaffoldMessenger.of(context).clearSnackBars();
                            // Update the overview data
                            if (await !results!.succeeded || results.graph.length == 0) {
                              String message;
                              if(results.succeeded){
                                message = "No hits found that met reporting criteria";
                              }
                              else{
                                message = "Data load failed.\n${results.message}";
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  //duration: Duration(days: 1),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(days: 100),
                                  content: Center(
                                    child: Column(
                                      children: [
                                        Text(message),
                                        ElevatedButton(
                                          child: Text("Close"),
                                          onPressed: () {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).hideCurrentSnackBar();
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              allStructureScrollOffset = 0.0;
                              allEvalueScrollOffset = 0.0; 
                              selectedStructureScrollOffset = 0.0;
                              selectedEvalueScrollOffset = 0.0;
                            //  print("${results.hits.length}");
                              graphdata.clearGraph();
                              graphdata.setGraph(results.graph);
                              graphdata.setDepth(results.depth);
                              graphdata.setMaxLevels(results.depth);
                              graphdata.clearDeletedNodes();
                              graphdata.addRoot(
                                results.root,
                              ); // set the current root to the overall root
                              graphdata.graphRoot =
                                  results
                                      .root; // and set the overall root as well.
                              searchdata.setSearchResults(results);
                              searchdata.selectedBy =
                                  selectedby.none; // reset selection
                              searchdata.selectedHit = -1;
                              context.go("/graph");
                            }
                          }
                          : null,
                  child: Text("Load Data"),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: MainNavBar(whereAmI: WhichPage.home),
    ),);
  }
}

// Page to control settings
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final evalMinNode = FocusNode();
  final eValMinTextController = TextEditingController();
  final evalMaxNode = FocusNode();
  final eValMaxTextController = TextEditingController();
  final domEvalMinNode = FocusNode();
  final domEValMinTextController = TextEditingController();
  final domEvalMaxNode = FocusNode();
  final domEValMaxTextController = TextEditingController();

  @override void initState() {
    super.initState();
    final myProvider = Provider.of<HSettings>(context, listen: false);
    evalMinNode.addListener(() {
      if (!evalMinNode.hasFocus) { // try to update the value when we lose focus
        var parsed = num.tryParse(eValMinTextController.text);
        if (parsed != null && parsed >= 0 && parsed != myProvider.evalMin && myProvider.useSeqEvals) {
          myProvider.evalMin = parsed.toDouble();
          _showReloadWarning();
        } else {
          // If the value is invalid, reset the text field to the current valid value
          eValMinTextController.text = myProvider.evalMin.toString();
        }

      }

    });
    evalMaxNode.addListener(() {
      if (!evalMaxNode.hasFocus) { // try to update the value when we lose focus
        var parsed = num.tryParse(eValMaxTextController.text);
        if (parsed != null && parsed >= 0 && parsed != myProvider.evalMax && myProvider.useSeqEvals) {
          myProvider.evalMax = parsed.toDouble();
          _showReloadWarning();
        } else {
          // If the value is invalid, reset the text field to the current valid value
          eValMaxTextController.text = myProvider.evalMax.toString();
        }

      }

    });

      domEvalMinNode.addListener(() {
        if (!domEvalMinNode.hasFocus) { // try to update the value when we lose focus
          var parsed = num.tryParse(domEValMinTextController.text);
          if (parsed != null && parsed >= 0 && parsed != myProvider.domEvalMin && myProvider.useDomEvals) {
            myProvider.domEvalMin = parsed.toDouble();
          } else {
            // If the value is invalid, reset the text field to the current valid value
            domEValMinTextController.text = myProvider.domEvalMin.toString();
          }
  
        }
  
      });

      domEvalMaxNode.addListener(() {
        if (!domEvalMaxNode.hasFocus) { // try to update the value when we lose focus
          var parsed = num.tryParse(domEValMaxTextController.text);
          if (parsed != null && parsed >= 0 && parsed != myProvider.domEvalMax && myProvider.useDomEvals) {
            myProvider.domEvalMax = parsed.toDouble();
          } else {
            // If the value is invalid, reset the text field to the current valid value
            domEValMaxTextController.text = myProvider.domEvalMax.toString();
          }
  
        }
  
      });
  }

  @override void dispose() {
    evalMinNode.dispose();
    eValMinTextController.dispose();
    super.dispose();
  }

  _showReloadWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.yellow,
        duration: Duration(seconds: 3),
        content: Center(child: Text(
           "Data must be re-loaded for changes to e-value settings to take effect.",
          style: TextStyle(color: Colors.black),
        ),),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
      final ScrollController _mainScrollController = ScrollController();
    return  Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: homotAppBar(text: "Settings"),
      body: Consumer<HSettings>(
        builder: (context, hsettings, child) {
          return SingleChildScrollView(
            controller: _mainScrollController,
            child: Column(
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      color: Theme.of(context).colorScheme.surface,
                      child: Column(
                        children: [
                          Text(
                            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,),
                            "Theme",
                          ),
                          RadioGroup<brightModes>(
                            groupValue: hsettings.mode,
                            onChanged: (brightModes? value){
                              if (value != null){
                                hsettings.mode = value;
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                IntrinsicWidth( 
                                  child: RadioListTile<brightModes>(
                                    title: Text('Light'),
                                    value: brightModes.light,
                                  ),),
                                IntrinsicWidth( child:
                                  RadioListTile<brightModes>(
                                    title: Text('Dark'),
                                    value: brightModes.dark,
                                    ),),
                                IntrinsicWidth( 
                                  child: RadioListTile<brightModes>(
                                  title: Text('System'),
                                value: brightModes.system,
                        ),),
                      ],),
                         ),
                      
                      ],
                    ),
                  ),
                  Card(
                    color: Theme.of(context).colorScheme.surface,
                    child: Column(
                      children: [
                        Text(
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium!.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          "Font Settings",
                        ),
                      Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                       Row(
                      children: [
                        Padding(
                                    padding: const EdgeInsets.only(right: 6.0),
                                    child:Text(
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium!.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          "Font Family",
                        ),),
                        HmmotSystemFontSelector(
                          width: 200 * hsettings.scale,
                          textStyle: Theme.of(
                            context,
                          ).textTheme.bodyMedium!.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          initial: hsettings.font,
                          isFontPreviewEnabled: true,
                          onFontSelected: (font) {
                            hsettings.font = font;
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Padding(
                                    padding: const EdgeInsets.only(right: 6.0),
                                    child:Text(
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium!.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          "Font Scale Factor",
                        ),),
                        InputQty.double(
                          initVal: hsettings.scale,
                          minVal: 0.001,
                          steps: 0.1,
                          decoration: QtyDecorationProps(
                            qtyStyle: QtyStyle.btnOnRight,
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          onQtyChanged: (val) {
                            hsettings.scale = val;
                          },
                        ),
                      ],
                    ),
                    ],),],),
                  ),
                  Card(
                    color: Theme.of(context).colorScheme.surface,
                    child: Column(
                      children: [
                        Text(
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium!.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          "Draw Taxonomy As",
                        ),
                         RadioGroup<GraphDrawType>(
                      groupValue: hsettings.drawType,
                      onChanged: (GraphDrawType? value){
                        if (value != null){
                          hsettings.drawType = value;
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                        IntrinsicWidth( 
                          child: RadioListTile<GraphDrawType>(
                          title: Text('Lines'),
                          value: GraphDrawType.line,
                        ),),
                        IntrinsicWidth( 
                          child: RadioListTile<GraphDrawType>(
                          title: Text('Arc Segments'),
                          value: GraphDrawType.outline,
                        ),),
                        IntrinsicWidth( child:
                        RadioListTile<GraphDrawType>(
                          title: Text('Filled Arc Segments'),
                          value: GraphDrawType.fill,
                        ),),
                      ],)
                    ),],),
                  ),
                   Card(
                    color: Theme.of(context).colorScheme.surface,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                      Column(
                      children: [
                        Text(
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium!.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          "Graph Line Width",
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            InputQty.double(
                              initVal: hsettings.lineWidth,
                              minVal: 0.5,
                              steps: 0.5,
                              decoration: QtyDecorationProps(
                                qtyStyle: QtyStyle.btnOnRight,
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              onQtyChanged: (val) {
                                hsettings.lineWidth = val;
                              },
                            ),
                            SizedBox(width: 20),
                            CustomPaint(
                              size: Size(50, 10),
                              painter: LinePainter(
                                context,
                                hsettings,
                                MediaQuery.of(context).devicePixelRatio,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ],
                    ), 
                        IntrinsicWidth( child: CheckboxListTile(
                                title: Text(
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  "Add Patterns to Filled Regions in Taxonomy and Structure",
                                ),
                                value: hsettings.addPatterns,
                                onChanged: (bool? value) {
                                  if (value != null) {
                                    hsettings.addPatterns = value;
                                  }
                                },
                              ),),
                    ], ),
                  ),
                  Card(
                    color: Theme.of(context).colorScheme.surface,
                    child: Column(
                      children: [
                        Text(
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium!.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          "Search Result File Type",
                        ),
                         RadioGroup<DataFileType>(
                      groupValue: hsettings.dataType,
                      onChanged: (DataFileType? value){
                        if (value != null){
                          hsettings.dataType = value;
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                        IntrinsicWidth( 
                          child: RadioListTile<DataFileType>(
                          title: Text('HMMER domtblout'),
                          value: DataFileType.domTblOut,
                        ),),
                        IntrinsicWidth( child:
                        RadioListTile<DataFileType>(
                          title: Text('BLAST tabular'),
                          value: DataFileType.blast,
                        ),),
                        IntrinsicWidth( 
                          child: RadioListTile<DataFileType>(
                          title: Text('Infer from file contents'),
                          value: DataFileType.infer,
                        ),),
                      ],),
                         ),
                      ],
                    ),
                  ),
                  Card(
                    color: Theme.of(context).colorScheme.surface,
                    child: IntrinsicWidth(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(children: [Checkbox(
                                checkColor: Theme.of(context).colorScheme.onPrimary,
                                //fillColor: Theme.of(context).colorScheme.surface,
                                value: hsettings.useSeqEvals,
                                onChanged: (bool? value) {
                                  if (value != null) {
                                    hsettings.useSeqEvals = value;
                                  }
                                },
                              ),
                              Text(
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium!.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            "Only show sequences with E-values in range",
                          ),
                              ]),
                              Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6.0),
                                    child: Text(
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium!.copyWith(
                                        color:
                                            hsettings.useSeqEvals ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withAlpha(128),
                                      ),
                                      "Minimum:",
                                    ),
                                  ),
                                  IntrinsicWidth(child: ConstrainedBox(
                                    constraints: BoxConstraints(minWidth: 200),
                                    child:TextFormField(
                                    enabled: hsettings.useSeqEvals,
                                    controller: eValMinTextController..text = hsettings.evalMin.toString(),
                                    focusNode: evalMinNode,
                                    autovalidateMode: AutovalidateMode.onUserInteraction,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                        ),
                                      ),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    onFieldSubmitted: (val) {
                                      var parsed = num.tryParse(val);
                                      if (parsed != null && parsed >= 0 && parsed != hsettings.evalMin) {
                                        hsettings.evalMin = parsed.toDouble();
                                        _showReloadWarning();
                                      }
                                      else {
                                        // If the value is invalid, reset the text field to the current valid value
                                        eValMinTextController.text = hsettings.evalMin.toString();
                                      }
                                    },
                                  validator: (String? value) {
                                      return !(value != null && num.tryParse(value) != null && num.tryParse(value)! >= 0)
                                          ? "Enter a number >= 0"
                                              : null;
                  }, 
                                  ),),),
                                ],
                              ),
                              Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6.0),
                                    child: Text(
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium!.copyWith(
                                        color:
                                            hsettings.useSeqEvals ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withAlpha(128),
                                      ),
                                      "Maximum:",
                                    ),
                                  ),
                                  IntrinsicWidth(child: ConstrainedBox(
                                    constraints: BoxConstraints(minWidth: 200),
                                    child:TextFormField(
                                    enabled: hsettings.useSeqEvals,
                                    controller: eValMaxTextController..text = hsettings.evalMax.toString(),
                                    focusNode: evalMaxNode,
                                    autovalidateMode: AutovalidateMode.onUserInteraction,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                        ),
                                      ),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    onFieldSubmitted: (val) {
                                      var parsed = num.tryParse(val);
                                      if (parsed != null && parsed >= 0 && parsed != hsettings.evalMax) {
                                        hsettings.evalMax = parsed.toDouble();
                                        _showReloadWarning();
                                      }
                                      else {
                                        // If the value is invalid, reset the text field to the current valid value
                                        eValMaxTextController.text = hsettings.evalMax.toString();
                                      }
                                    },
                                  validator: (String? value) {
                                      return !(value != null && num.tryParse(value) != null && num.tryParse(value)! >= 0)
                                          ? "Enter a number >= 0"
                                              : null;
                  }, 
                                  ),),),
                                ],
                              ),
                            ],
                          ),
                    ),
                  ),
                  Card(
                    color: Theme.of(context).colorScheme.surface,
                    child: IntrinsicWidth(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(children: [Checkbox(
                                checkColor: Theme.of(context).colorScheme.onPrimary,
                                //fillColor: Theme.of(context).colorScheme.surface,
                                value: hsettings.useDomEvals,
                                onChanged: (bool? value) {
                                  if (value != null) {
                                    hsettings.useDomEvals = value;
                                  }
                                },
                              ),
                              Text(
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium!.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            "Only show domains with E-values in range\n (Only applicable to HMMER results)",
                          ),
                              ]),
                              Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6.0),
                                    child: Text(
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium!.copyWith(
                                        color:
                                            hsettings.useDomEvals ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withAlpha(128),
                                      ),
                                      "Minimum:",
                                    ),
                                  ),
                                  IntrinsicWidth(child: ConstrainedBox(
                                    constraints: BoxConstraints(minWidth: 200),
                                    child:TextFormField(
                                    enabled: hsettings.useDomEvals,
                                    controller: domEValMinTextController..text = hsettings.domEvalMin.toString(),
                                    focusNode: domEvalMinNode,
                                    autovalidateMode: AutovalidateMode.onUserInteraction,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                        ),
                                      ),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    onFieldSubmitted: (val) {
                                      var parsed = num.tryParse(val);
                                      if (parsed != null && parsed >= 0 && parsed != hsettings.domEvalMin) {
                                        hsettings.domEvalMin = parsed.toDouble();
                                        _showReloadWarning();
                                      }
                                      else {
                                        // If the value is invalid, reset the text field to the current valid value
                                        eValMinTextController.text = hsettings.domEvalMin.toString();
                                      }
                                    },
                                  validator: (String? value) {
                                      return !(value != null && num.tryParse(value) != null && num.tryParse(value)! >= 0)
                                          ? "Enter a number >= 0"
                                              : null;
                  }, 
                                  ),),),
                                ],
                              ),
                              Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6.0),
                                    child: Text(
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium!.copyWith(
                                        color:
                                            hsettings.useDomEvals ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withAlpha(128),
                                      ),
                                      "Maximum:",
                                    ),
                                  ),
                                  IntrinsicWidth(child: ConstrainedBox(
                                    constraints: BoxConstraints(minWidth: 200),
                                    child:TextFormField(
                                    enabled: hsettings.useDomEvals,
                                    controller: domEValMaxTextController..text = hsettings.domEvalMax.toString(),
                                    focusNode: domEvalMaxNode,
                                    autovalidateMode: AutovalidateMode.onUserInteraction,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                        ),
                                      ),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    onFieldSubmitted: (val) {
                                      var parsed = num.tryParse(val);
                                      if (parsed != null && parsed >= 0 && parsed != hsettings.domEvalMax) {
                                        hsettings.domEvalMax = parsed.toDouble();
                                        _showReloadWarning();
                                      }
                                      else {
                                        // If the value is invalid, reset the text field to the current valid value
                                        eValMaxTextController.text = hsettings.domEvalMax.toString();
                                      }
                                    },
                                  validator: (String? value) {
                                      return !(value != null && num.tryParse(value) != null && num.tryParse(value)! >= 0)
                                          ? "Enter a number >= 0"
                                              : null;
                  }, 
                                  ),),),
                                ],
                              ),
                            ],
                          ),
                    ),
                  ),
 /*                 Card(
                    color: Theme.of(context).colorScheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                      Text(style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium!.copyWith(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurface),
                          "InterPro Annotations (No Effect if Database Annotated From Another Source)"),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IntrinsicWidth(child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium!.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                "Show Annotations of Type(s)",
                              ),
                            CheckboxListTile(
                                title: Text(
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  "Superfamily",
                                ),
                                value: hsettings.showInterproSuperfamily,
                                onChanged: (bool? value) {
                                  if (value != null) {
                                    hsettings.showInterproSuperfamily = value;
                                  }
                                },
                              ),
                              CheckboxListTile(
                                title: Text(
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  "Family",
                                ),
                                value: hsettings.showInterproFamily,
                                onChanged: (bool? value) {
                                  if (value != null) {
                                    hsettings.showInterproFamily = value;
                                  }
                                },
                              ),
                              CheckboxListTile(
                                title: Text(
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  "Domain",
                                ),
                                value: hsettings.showInterproDomain,
                                onChanged: (bool? value) {
                                  if (value != null) {
                                    hsettings.showInterproDomain = value;
                                  }
                                },
                              ),

                              CheckboxListTile(
                                title: Text(
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  "Repeat",
                                ),
                                value: hsettings.showInterproRepeat,
                                onChanged: (bool? value) {
                                  if (value != null) {
                                    hsettings.showInterproRepeat = value;
                                  }
                                },
                              ),
                              CheckboxListTile(
                                title: Text(
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  "Site",
                                ),
                                value: hsettings.showInterproSite,
                                onChanged: (bool? value) {
                                  if (value != null) {
                                    hsettings.showInterproSite = value;
                                  }
                                },
                                
                              ),
                              CheckboxListTile(
                                title: Text(
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  "Other",
                                ),
                                value: hsettings.showInterproOther,
                                onChanged: (bool? value) {
                                  if (value != null) {
                                    hsettings.showInterproOther = value;
                                  }
                                },
                              ),
                            ],
                          ),),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium!.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                "Show InterPro Annotations As",
                              ),
                              RadioGroup<ShowInterproIdEnum>(
                                groupValue: hsettings.showInterproIdAs,
                                onChanged: (ShowInterproIdEnum? value){
                                  if (value != null){
                                    hsettings.showInterproIdAs = value;
                                  }
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                  IntrinsicWidth( 
                                    child: RadioListTile<ShowInterproIdEnum>(
                                    title: Text('InterPro ID'),
                                    value: ShowInterproIdEnum.id,
                                  ),),
                                  IntrinsicWidth( 
                                    child: RadioListTile<ShowInterproIdEnum>(
                                    title: Text('InterPro Short Name (If Available)'),
                                    value: ShowInterproIdEnum.short_name,
                                  ),),
                                  IntrinsicWidth( 
                                    child: RadioListTile<ShowInterproIdEnum>(
                                  title: Text('InterPro Long Name (If Available)'),
                                    value: ShowInterproIdEnum.long_name,
                                  ),),
                                ],),
                              ),
                            ],
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium!.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                "Show Domain Names From",
                              ),
                              RadioGroup<ShowNamesFrom>(
                                groupValue: hsettings.showNamesFrom,
                                onChanged: (ShowNamesFrom? value){
                                  if (value != null){
                                    hsettings.showNamesFrom = value;
                                  }
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                  IntrinsicWidth( 
                                    child: RadioListTile<ShowNamesFrom>(
                                    title: Text('Pfam (If Available)'),
                                    value: ShowNamesFrom.pfam,
                                  ),),
                                  IntrinsicWidth( 
                                    child: RadioListTile<ShowNamesFrom>(
                                    title: Text('InterPro'),
                                    value: ShowNamesFrom.interpro,
                                  ),),
                                ],),
                              ),
                            ],
                          ),
                        ],
                      ),
                                            ],) 
                    ),*/
                ],
              ),
            ],
          ),);
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
  OverlayEntry? _nodeOverlayEntry;
  OverlayEntry? _removedNodesOverlayEntry;
  OverlayEntry? _norootOverlayEntry;
  final GlobalKey _myKey = GlobalKey(); // key used to measure size of the nodeOverlay
  final GlobalKey _secondKey = GlobalKey(); // key used to measure size of the removedNodeOverlay

  double findX(GlobalKey theKey, Offset tapPosition, Size mySize){
    if(_myKey.currentContext!= null){
      final RenderBox renderBox = _myKey.currentContext!.findRenderObject() as RenderBox;
      Size widgetSize = renderBox.size;
      if(widgetSize.width + tapPosition.dx > mySize.width){
        return mySize.width - widgetSize.width; 
      }
      else{
        return tapPosition.dx;
      }
    }
    else{
      return tapPosition.dx;
    }
  }
  double findY(GlobalKey theKey, Offset tapPosition, Size mySize){
    if(_myKey.currentContext!= null){
      final RenderBox renderBox = _myKey.currentContext!.findRenderObject() as RenderBox;
      Size widgetSize = renderBox.size;
      if(widgetSize.height + tapPosition.dy > mySize.height){
        return mySize.height - widgetSize.height; 
      }
      else{
        return tapPosition.dy;
      }
    }
    else{
      return tapPosition.dy;
    }
  }
  void _removeAllOverlays(){
    _removeNorootOverlay();
    _removeNodeOverlay();
    _removeRemovedNodesOverlay();
  }
  // Displays an overlay showing information about the node clicked 
  void _showNodeOverlay(
      BuildContext context,
      Offset tapPosition,
      Node theNode,
      GraphData graphdata,
    )
    {
      String children = "";
      for (var child in theNode.children) {
        var childNode = graphdata.getNode(child.toInt());
        if (children != ""){
          children += ", ";
        }
        children += childNode.name;
      }

      String parentName = graphdata.getNode(theNode.parent).name;
      // Declare this once because we have to render it twice
      Widget theWidget = Container(
                  key: _myKey,
                  constraints: BoxConstraints(maxWidth: graphdata.size.width/2),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha:0.5),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: Offset(3,3),
                    )]
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                    "Taxon: ${theNode.name}\nRank: ${theNode.rank}\nParent: ${parentName}\nChildren: ${children}\n${theNode.hitsBelow} hits at or below this node\n",
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  ),
                    IntrinsicWidth(child: Align( 
                      alignment:AlignmentGeometry.centerRight,
                      child:Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                      Padding(
                                    padding: const EdgeInsets.only(right: 6.0),
                                    child:ElevatedButton(
                        style: ButtonStyle(backgroundColor:  WidgetStateProperty.resolveWith(
                                                    (states) {
                                                      if (states.contains(WidgetState.disabled)){
                                                        return Theme.of(
                                                        context,
                                                      ).colorScheme.primary.withAlpha(128);
                                                      }
                                                      else{
                                                      return Theme.of(
                                                        context,
                                                      ).colorScheme.primary;
                                                    }},
                                                  ),),
                        onPressed: (theNode.taxid != theNode.parent) ?() { // Don't let user delete the root node
                          graphdata.deleteNode(theNode.taxid);
                          Overlay.of(context).setState(() {
                            _removeAllOverlays();
                          });
                        }:null,
                        child: Text(style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                          "Remove Node from Graph"),
                      ),),
                       Padding(
                                    padding: const EdgeInsets.only(right: 6.0),
                                    child:ElevatedButton(
                        style: ButtonStyle(backgroundColor:  WidgetStateProperty.resolveWith(
                                                    (states) {
                                                      if (states.contains(WidgetState.disabled)){
                                                        return Theme.of(
                                                        context,
                                                      ).colorScheme.primary.withAlpha(128);
                                                      }
                                                      else{
                                                      return Theme.of(
                                                        context,
                                                      ).colorScheme.primary;
                                                    }},
                                                  ),),
                        onPressed: graphdata.deletedNodes.isNotEmpty ?() {
                          Overlay.of(context).setState(() {
                            _removeAllOverlays();
                            _showRemovedNodesOverlay(context, tapPosition, theNode);
                          });
                        }:null,
                        child: Text(style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),"Show Removed Nodes"),
                      ),),
                      ElevatedButton(
                        style: ButtonStyle(backgroundColor:  WidgetStateProperty.resolveWith(
                                                    (states) {
                                                      return Theme.of(
                                                        context,
                                                      ).colorScheme.primary;
                                                    },
                                                  ),),
                        onPressed: (){
                          Overlay.of(context).setState(() {
                            _removeAllOverlays();
                          });
                        },
                        child: Text(style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),"Close"),
                      ),
                    ],),),),
                    ],),
                );


      _nodeOverlayEntry = OverlayEntry(
        builder:
            (context) { 
                           Offstage( // render widget offstage so we can measure it
                offstage: true,
                child: theWidget);
            double xCoord = findX(_myKey, tapPosition, graphdata.size);
            double yCoord = findY(_myKey, tapPosition, graphdata.size);
            return
              Positioned(
              left: xCoord,
              top:  yCoord,
              child: Material(
                child: theWidget,
              ),
            );
            }
      );
      Overlay.of(context).insert(_nodeOverlayEntry!);
    }
    void _removeNodeOverlay() {
      _nodeOverlayEntry?.remove();
      _nodeOverlayEntry = null;
    }

// Shows an overlay with a list of nodes that have been removed from the graph
  void _showRemovedNodesOverlay(
      BuildContext context,
      Offset tapPosition,
      Node theNode,
    )
    {
//      String parentName = graphdata.getNode(theNode.parent).name;
      ScrollController _mainScrollController = ScrollController();
      // Declare this once because we have to render it twice
      Widget theWidget = 
              Consumer<GraphData>(
            builder: (context, graphdata, child) {
             return Scrollbar(
                      key: _secondKey,
                      controller: _mainScrollController,
                      child: ListView.builder(
                        shrinkWrap: true,
                        controller: _mainScrollController,
                        itemCount: graphdata.deletedNodes.length,
                        itemBuilder: (BuildContext context, int index) {
                          return Card(
                            margin: EdgeInsets.only(bottom: 8),
                            color: Theme.of(context).colorScheme.surface,
                            child: Row(children: [Text(graphdata.getNode(graphdata.deletedNodes[index]).name),
                            TextButton(child: Text("Restore"), onPressed: (){graphdata.restoreNode(graphdata.deletedNodes[index]);},),
                            ],
                            ),
                          );
                        },
                      ),
                );
            });

      _removedNodesOverlayEntry = OverlayEntry(
        builder:
            (context) { 
              return Consumer<GraphData>(
                builder: (context, graphdata, child){
            Offstage( // render widget offstage so we can measure it
                offstage: true,
                child: theWidget);
            double xCoord = findX(_secondKey, tapPosition, graphdata.size);
            double yCoord = findY(_secondKey, tapPosition, graphdata.size);
            return 
              Positioned(
              left: xCoord, //findX(_myKey, tapPosition, graphdata.size),
              top: yCoord, //findY(_myKey, tapPosition, graphdata.size),
              width: graphdata.size.width/4,
              child: Material(
                child: theWidget,
              ),
            );
            });
            }
      );
      Overlay.of(context).insert(_removedNodesOverlayEntry!);
    }
    void _removeRemovedNodesOverlay() {
      _removedNodesOverlayEntry?.remove();
      _removedNodesOverlayEntry = null;
    }

// shows a warning Overlay because it is not possible to re-center the graph on a node
    void _showNorootOverlay(
      BuildContext context,
      Offset tapPosition,
      PlatformInt64 nodeId,
      Node theNode,
    ) {
      _norootOverlayEntry = OverlayEntry(
        builder:
            (context) => Positioned(
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
                  child: Text(
                    "Node ${theNode.name} has no children",
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
  @override
  void dispose() {
    _removeAllOverlays();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double _value = max(context.watch<GraphData>().maxLevels.toDouble(), 1.0);
    double _rotation = context.watch<GraphData>().rotation * (360 / (2 * pi));
    double _scale = context.watch<GraphData>().scale;
    double _xOffset = context.watch<GraphData>().translateX;
    double _yOffset = context.watch<GraphData>().translateY;

    final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    //final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: homotAppBar(text: "Taxonomic Display"),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          var width = constraints.maxWidth;
          var height = constraints.maxHeight;
          var center = Offset(width / 2, height / 2);
          var radius =
              (min(width, height) /
                  2.0); // Leave a little space around the graph
          var availSpace = radius * 0.3;
          var legendHeight = availSpace;
          var legendWidth = availSpace;
          if (height > width) {
            legendHeight += (height - width) / 2.0;
          }
          if (width > height) {
            legendWidth += (width - height) / 2.0;
          }

          return Consumer3<HSettings, GraphData, SearchData>(
            builder: (context, hsettings, graphdata, searchdata, child) {
              graphdata.size = Size(width, height);
              return Stack(
                children: [
                  GestureDetector(
                    onTapDown: (details) {
                      _removeAllOverlays();
                      final Matrix4 inverseMatrix = Matrix4.inverted(
                        graphdata.transform,
                      );
                      final Vector3 untransformed = inverseMatrix.transform3(
                        Vector3(
                          details.localPosition.dx,
                          details.localPosition.dy,
                          0,
                        ),
                      );
                      var node = graphdata.findNode(
                        untransformed.x,
                        untransformed.y,
                        center.dx,
                        center.dy,
                      );
                      if (node >= 0 && node != graphdata.currentRoot) {
                        // click was in the graph and on a different node than the current root
                        if (graphdata.getNode(node).children.length == 0) {
                          _showNorootOverlay(
                            context,
                            details.globalPosition,
                            node,
                            graphdata.getNode(node),
                          );
                          Future.delayed(const Duration(seconds: 5), () {
                            _removeNorootOverlay();
                          });
                        }//else {
                          graphdata.popPastIndex();
                          graphdata.addRoot(node);
                          HitResults hitResults = findHitsBelowNode(
                            root: graphdata.getNode(node).taxid,
                            graph: graphdata.graph,
                            hitStructures: searchdata.hitStructures,
                          );
                          searchdata.currentHitsByEvalue = hitResults.hits;
                          searchdata.currentHits = hitResults.categories;
                          searchdata.selectedBy = selectedby.subtree;
                          selectedStructureScrollOffset = 0.0;
                          selectedEvalueScrollOffset = 0.0;
                        //}
                        //;
                      }
                    },
                    onSecondaryTapDown: (details) {
                      _removeAllOverlays(); // Remove any existing overlay
                      final Matrix4 inverseMatrix = Matrix4.inverted(
                        graphdata.transform,
                      );
                      final Vector3 untransformed = inverseMatrix.transform3(
                        Vector3(
                          details.localPosition.dx,
                          details.localPosition.dy,
                          0,
                        ),
                      );
                      var node = graphdata.findNode(
                        untransformed.x,
                        untransformed.y,
                        center.dx,
                        center.dy,
                      );
                      if(node>=0){
                      var theNode = graphdata.getNode(node);
                      _showNodeOverlay(context,
                        details.globalPosition,
                        theNode,
                        graphdata,
                      );}
                    },

                    child: Transform(
                      transform: graphdata.transform,
                      child: CustomPaint(
                        size: Size(width, height),
                        painter: GraphPainter(
                          context,
                          graphdata,
                          devicePixelRatio,
                          graphdata.tController,
                          radius,
                          hsettings,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          SizedBox(
                            height: legendHeight,
                            width: legendWidth,
                            child: Card(
                              color: Theme.of(context).colorScheme.surface,
                              child: Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,

                                      children: [
                                        Ink(
                                          decoration: ShapeDecoration(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                            shape: CircleBorder(),
                                          ),
                                          child: IconButton(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onPrimary,
                                            icon: const Icon(Icons.arrow_back),
                                            onPressed: graphdata.decrementIndex,
                                          ),
                                        ),
                                        Text(
                                          "Graph Center History",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium!.copyWith(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                          ),
                                        ),
                                        Ink(
                                          decoration: ShapeDecoration(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                            shape: CircleBorder(),
                                          ),
                                          child: IconButton(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onPrimary,
                                            icon: const Icon(
                                              Icons.arrow_forward,
                                            ),
                                            onPressed: graphdata.incrementIndex,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Flexible(
                                      child: ScrollablePositionedList.separated(
                                        itemCount: graphdata.historyLength,
                                        itemScrollController:
                                            graphdata.itemScrollController,
                                        separatorBuilder: (
                                          BuildContext context,
                                          int index,
                                        ) {
                                          return SizedBox(height: 2);
                                        },
                                        itemBuilder: (
                                          BuildContext context,
                                          int index,
                                        ) {
                                          String label;
                                          if (index == graphdata.historyIndex) {
                                            label =
                                                "(Current) " +
                                                graphdata.historyNames(index);
                                          } else {
                                            label = graphdata.historyNames(
                                              index,
                                            );
                                          }
                                          return ElevatedButton(
                                            style: ButtonStyle(
                                              backgroundColor:
                                                  WidgetStateProperty.resolveWith(
                                                    (states) {
                                                      return Theme.of(
                                                        context,
                                                      ).colorScheme.primary;
                                                    },
                                                  ),
                                            ),
                                            onPressed: () {
                                              if (graphdata.history(index) >=
                                                  0) {
                                                graphdata.setRoot(
                                                  graphdata.history(index),
                                                );
                                                graphdata.setHistoryIndex(
                                                  index,
                                                );
                                              }
                                            },
                                            child: Center(
                                              child: Text(
                                                label,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium!
                                                    .copyWith(
                                                      color:
                                                          Theme.of(context)
                                                              .colorScheme
                                                              .onPrimary,
                                                    ),
                                              ),
                                            ),
                                          );
                                        },
                                        //scrollDirection: Axis.vertical,
                                        //shrinkWrap: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: legendHeight,
                            width: legendWidth,
                            child: Card(
                              color: Theme.of(context).colorScheme.surface,
                              child: Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Graph Levels Shown: ${graphdata.maxLevels}",
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium!.copyWith(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          "1",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium!.copyWith(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                          ),
                                        ),
                                        Expanded(
                                          child: Slider(
                                            value: _value,
                                            label: _value.round().toString(),
                                            min: 1.0,
                                            max: max(1.0, graphdata.depth.toDouble()),
                                            divisions: max(1, graphdata.depth - 1),
                                            onChanged: (double value) {
                                              setState(() {
                                                graphdata.setMaxLevels(
                                                  value.toInt(),
                                                );
                                              });
                                            },
                                          ),
                                        ),
                                        Text(
                                          "${graphdata.depth}",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium!.copyWith(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
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
                              child: Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          "X Position:",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium!.copyWith(
                                            height: 1,
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                          ),
                                        ),
                                        Expanded(
                                          child: Slider(
                                            value: _xOffset,
                                            label: _xOffset.round().toString(),
                                            min: -width,
                                            max: width,
                                            onChanged: (double xOffset) {
                                              setState(() {
                                                graphdata.translateX = xOffset;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          "Y Position:",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium!.copyWith(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                          ),
                                        ),
                                        Expanded(
                                          child: Slider(
                                            value: _yOffset,
                                            label: _yOffset.toStringAsFixed(2),
                                            min: -height,
                                            max: height,
                                            onChanged: (double _yOffset) {
                                              setState(() {
                                                graphdata.translateY = _yOffset;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: legendHeight,
                            width: legendWidth,
                            child: Card(
                              color: Theme.of(context).colorScheme.surface,
                              child: Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          "Rotation: 0",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium!.copyWith(
                                            height: 1,
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                          ),
                                        ),
                                        Expanded(
                                          child: Slider(
                                            value: _rotation,
                                            label: _rotation.round().toString(),
                                            min: 0.0,
                                            max: 360.0,
                                            onChanged: (double rotation) {
                                              setState(() {
                                                graphdata.setRotation(
                                                  (rotation) * (2 * pi / 360),
                                                );
                                              });
                                            },
                                          ),
                                        ),
                                        Text(
                                          "360",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium!.copyWith(
                                            height: 1,
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          "Scale: 0.25",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium!.copyWith(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                          ),
                                        ),
                                        Expanded(
                                          child: Slider(
                                            value: _scale,
                                            label: _scale.toStringAsFixed(2),
                                            min: 0.25,
                                            max: 5.0,
                                            onChanged: (double _scale) {
                                              setState(() {
                                                graphdata.scale = _scale;
                                              });
                                            },
                                          ),
                                        ),
                                        Text(
                                          "5",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium!.copyWith(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: MainNavBar(whereAmI: WhichPage.graph),
    );
  }
}

// Widget that displays all hits to the selected subtree by structure
class SubtreeStructurePage extends StatefulWidget {
  const SubtreeStructurePage({super.key});

  @override
  State<SubtreeStructurePage> createState() => _SubtreeStructurePageState();
}

class _SubtreeStructurePageState extends State<SubtreeStructurePage> {
  final ScrollController _subtreeStructureScrollController = ScrollController(initialScrollOffset: selectedStructureScrollOffset, onDetach: (position){selectedStructureScrollOffset = position.pixels;});
  List<int> lengths = [];

 /* @override
  dispose() {
    print("disposing subtree structure page, saving scroll offset $selectedStructureScrollOffset");
    //selectedStructureScrollOffset = _subtreeStructureScrollController.offset;
    super.dispose();
  }*/

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Consumer3<SearchData, GraphData, HSettings>(
        builder: (context, searchdata, graphdata, hsettings, child) {
          final List<SigCategory> theHits = searchdata.currentHits;
          int numHits = 0;
          for (var category in theHits) {
            numHits += category.hits.length;
          }
          final hitCount = numHits == 0 || numHits > 1 ? "hits" : "hit";
          final strucText =
              theHits.length > 1
                  ? "different domain structures"
                  : "domain structure";
          if (lengths.length != theHits.length) {
            lengths = List.filled(theHits.length, 0);
          }
          for(int i=0; i<theHits.length; i++){
            lengths[i] = searchdata.hits[theHits[i].hits[0].toInt()].seqLength;
          }
          lengths.sort((a,b)=> a < b ? -1 : 1);
          int maxLength = lengths.reduce(max);
          if (0.75 * maxLength > lengths[(lengths.length * 0.9).toInt()]){
   //       print("changing maxlength from $maxLength to ${lengths[(lengths.length * 0.9).toInt()]}");
            maxLength = lengths[(lengths.length * 0.9).toInt()];
          }
          double ppr= pixelsPerResidue(maxLength, Theme.of(context).textTheme, context);
    //      print("pixels per residue $ppr");
          return SelectionArea(child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.primary,
            appBar: homotAppBar(
              text:
                  "${numHits} ${hitCount} found under ${graphdata.graph[graphdata.currentRoot]?.name}, with ${theHits.length} ${strucText}",
            ),
            body: Scrollbar(
             controller: _subtreeStructureScrollController,
              child: ListView.builder(
                controller: _subtreeStructureScrollController,
                itemCount: theHits.length,
                itemBuilder: (BuildContext context, int index) {
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    color: Theme.of(context).colorScheme.surface,
                    child: Stack(
                      //crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DrawCategory(
                          which: index,
                          from: selectedby.subtree_structure,
                          context: context,
                          maxLength: maxLength,
                          pixelsPerResidue: ppr,
                        ),
                        
                      ],
                    ),
                  );
                },
              ),
            ),
            bottomNavigationBar: MainNavBar(
              whereAmI: WhichPage.subgraphstructure,
            ),
          ),);
        },
      ),
    );
  }
}

// Widget that displays all results by structure
class AllStructurePage extends StatefulWidget {
  const AllStructurePage({super.key});

  @override
  State<AllStructurePage> createState() => _AllStructurePageState();
}


class _AllStructurePageState extends State<AllStructurePage> {
    final ScrollController _allStructureScrollController = ScrollController(initialScrollOffset: allStructureScrollOffset, onDetach: (position){allStructureScrollOffset = position.pixels;});
  List<int> lengths = [];

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SelectionArea( child: Consumer3<SearchData, GraphData, HSettings>(
        builder: (context, searchdata, graphdata, hsettings, child) {
          final List<SigCategory> theHits = searchdata.rootHits;
          if (lengths.length != theHits.length) {
            lengths = List.filled(theHits.length, 0);
          }
          for(int i=0; i<theHits.length; i++){
            lengths[i] = searchdata.hits[searchdata.rootHits[i].hits[0].toInt()].seqLength;
          }
            int maxLength = lengths.reduce(max);
          lengths.sort((a,b)=> a < b ? -1 : 1);
          if (0.75 * maxLength > lengths[(lengths.length * 0.9).toInt()]){
       //     print("changing maxlength from $maxLength to ${lengths[(lengths.length * 0.9).toInt()]}");
            maxLength = lengths[(lengths.length * 0.9).toInt()];
          }
          double ppr= pixelsPerResidue(maxLength, Theme.of(context).textTheme, context);
          int numHits = searchdata.hits.length;
          final hitCount = numHits != 1? "hits" : "hit";
          final strucText =
              theHits.length != 1
                  ? "different domain structures"
                  : "domain structure";
          final screenWidth = MediaQuery.sizeOf(context).width;
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.primary,
            appBar: homotAppBar(
              text:
                  "${numHits} ${hitCount} found, with ${theHits.length} ${strucText}",
            ),
            body: Scrollbar(
              controller: _allStructureScrollController,
              child: ListView.builder(
                controller: _allStructureScrollController,
                itemCount: theHits.length,
                itemBuilder: (BuildContext context, int index) {
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    color: Theme.of(context).colorScheme.surface,
                    child: 
                        DrawCategory(
                          which: index,
                          from: selectedby.structure,
                          context:context,
                          maxLength: maxLength,
                          pixelsPerResidue: ppr,
                        ),        
                  );
                },
              ),
            ),
            bottomNavigationBar: MainNavBar(whereAmI: WhichPage.allstructure),
          );
        },
      ),),
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
  final ScrollController _allEvalueScrollController = ScrollController(initialScrollOffset: allEvalueScrollOffset, onDetach: (position){allEvalueScrollOffset = position.pixels;});
  List<bool> fullWidth = [];
  List<bool> showExpand = [];
  List<int> lengths = [];
  @override

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SelectionArea( child: Consumer3<SearchData, GraphData, HSettings>(
        builder: (context, searchdata, graphdata, hsettings, child) {
          if (fullWidth.length != searchdata.hits.length) {
            // something has changed, reset the fullwidth list
            fullWidth = List.filled(searchdata.hits.length, false);
            showExpand = List.filled(searchdata.hits.length, false);
            lengths = List.filled(searchdata.hits.length, 0);
          }
          int maxLength = 0;
          for(int i=0; i<searchdata.hits.length; i++){
            lengths[i] = searchdata.hits[i].seqLength;
          }
          maxLength = lengths.reduce(max);
          lengths.sort((a,b)=> a < b ? -1 : 1);
          if (0.75 * maxLength > lengths[(lengths.length * 0.9).toInt()]){
     //       print("changing maxlength from $maxLength to ${lengths[(lengths.length * 0.9).toInt()]}");
            maxLength = lengths[(lengths.length * 0.9).toInt()];
          }
          final screenWidth = MediaQuery.sizeOf(context).width;
          double ppr= pixelsPerResidue(maxLength, Theme.of(context).textTheme, context);
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.primary,
            appBar: homotAppBar(text: "${searchdata.hits.length} hits found"),
            body: Scrollbar(
              controller: _allEvalueScrollController,
              child: ListView.builder(
                controller: _allEvalueScrollController,
                itemCount: searchdata.hits.length,
                itemBuilder: (BuildContext context, int index) {
                  showExpand[index] =
                      (requiredHitWidth(
                        searchdata.hits[index],
                        false,
                        false,
                        context,
                      ) >
                      screenWidth) || (searchdata.hits[index].seqLength > maxLength);
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    color: Theme.of(context).colorScheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                          Text(
                            overflow: TextOverflow.clip,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium!.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          "Sequence: " +
                              searchdata.hits[index].name +
                              "\nE-Value: " +
                              searchdata.hits[index].seqEvalue
                                  .toStringAsExponential(4)+"\nTaxon: "+graphdata.graph[searchdata.hits[index].taxid]!.name + '\nDescription: '+searchdata.hits[index].description,
                        ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            showExpand[index]
                                ? RotatedBox(
                                  quarterTurns: 1,
                                  child: IconButton.outlined(
                                    iconSize: 24 * hsettings.scale,
                                  
                                    onPressed: () {
                                      fullWidth[index] = !fullWidth[index];
                                      setState(() {});
                                    },
                                    icon:
                                        fullWidth[index]
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
                                searchdata.selectedHit = index;
                                context.go("/sequence");
                              },
                              icon: Icon(
                                Icons.search,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                          ],),
                        DrawHit(
                          hit: searchdata.hits[index],
                          searchdata: searchdata,
                          fullWidth: fullWidth[index],
                          maxLength: maxLength,
                          pixelsPerResidue: ppr,
                        ),
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
    ),);
  }
}

// Widget that displays a subtree's results by evalue
class SubtreeEvaluePage extends StatefulWidget {
  SubtreeEvaluePage({Key? key}) : super(key: key);

  @override
  State<SubtreeEvaluePage> createState() => _SubtreeEvaluePageState();
}

class _SubtreeEvaluePageState extends State<SubtreeEvaluePage> {
  final ScrollController _subtreeEvalueScrollController = ScrollController(initialScrollOffset: selectedEvalueScrollOffset, onDetach: (position){selectedEvalueScrollOffset = position.pixels;});
  List<bool> fullWidth = [];
  List<bool> showExpand = [];
  List<int> lengths = [];
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Consumer3<SearchData, GraphData, HSettings>(
        builder: (context, searchdata, graphdata, hsettings, child) {
          Int64List hitIndices = Int64List(0);
          String title = "";
          switch (searchdata.selectedBy) {
            case selectedby.subtree:
              hitIndices = searchdata.currentHitsByEvalue;
              title =
                  "${hitIndices.length} hits found under node ${graphdata.getNode(graphdata.currentRoot).name}";
              break;
            case selectedby.subtree_structure:
              hitIndices =
                  searchdata.currentHits[searchdata.selectedStructure].hits;
              title =
                  "${hitIndices.length} hits found with structure ${searchdata.structures[searchdata.currentHits[searchdata.selectedStructure].signature]} under node ${graphdata.getNode(graphdata.currentRoot).name}";
              break;
            case selectedby.structure:
              hitIndices =
                  searchdata.rootHits[searchdata.selectedStructure].hits;
              title =
                  "${hitIndices.length} hits found with structure ${searchdata.structures[searchdata.rootHits[searchdata.selectedStructure].signature]}";
              break;
            default:
              hitIndices = Int64List(0);
          }
          if ((fullWidth.length != hitIndices.length) ||
              (searchdata.selectedBy != searchdata.previousSelectedBy)) {
            // something has changed, reset the fullwidth list
            fullWidth = List.filled(hitIndices.length, false);
            showExpand = List.filled(hitIndices.length, false);
            lengths = List.filled(hitIndices.length, 0);
            searchdata.previousSelectedBy = searchdata.selectedBy;
          }
          final screenWidth = MediaQuery.sizeOf(context).width;
          for (int i=0; i<hitIndices.length; i++){
            lengths[i] = searchdata.hits[hitIndices[i].toInt()].seqLength;
          }
          int maxLength = lengths.reduce(max);
       //   print("max length is $maxLength");
          lengths.sort((a,b)=> a < b ? -1 : 1);
          if (0.75 * maxLength > lengths[(lengths.length * 0.9).toInt()]){
   //         print("changing maxlength from $maxLength to ${lengths[(lengths.length * 0.9).toInt()]}");
            maxLength = lengths[(lengths.length * 0.9).toInt()];
          }
          double ppr= pixelsPerResidue(maxLength, Theme.of(context).textTheme, context);
          int count = 0;
          for(int i=0; i<hitIndices.length; i++){
            if (lengths[i] > maxLength){
              count++;
            }
          }
        //  print("$count out of ${hitIndices.length} hits are longer than the max length of $maxLength");  
          return SelectionArea(child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.primary,
            appBar: homotAppBar(text: title),
            body: Scrollbar(
              controller: _subtreeEvalueScrollController,
              child: ListView.builder(
                controller: _subtreeEvalueScrollController,
                itemCount: hitIndices.length,
                itemBuilder: (BuildContext context, int index) {
                  showExpand[index] =
                      requiredHitWidth(
                        searchdata.hits[hitIndices[index].toInt()],
                        false,
                        false,
                        context,
                      ) >
                      screenWidth || (searchdata.hits[hitIndices[index].toInt()].seqLength > maxLength);
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    color: Theme.of(context).colorScheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [Text(
                            overflow: TextOverflow.clip,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium!.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          "Sequence: " +
                              searchdata.hits[hitIndices[index].toInt()].name +
                              "\nE-Value: " +
                              searchdata
                                  .hits[hitIndices[index].toInt()]
                                  .seqEvalue
                                  .toStringAsExponential(4)+"\nTaxon: "+graphdata.graph[searchdata.hits[hitIndices[index].toInt()].taxid]!.name + '\nDescription: '+searchdata.hits[hitIndices[index].toInt()].description,
                        ),
                       Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            showExpand[index]
                                ? RotatedBox(
                                  quarterTurns: 1,
                                  child: IconButton.outlined(
                                    iconSize: 24 * hsettings.scale,
                                  
                                    onPressed: () {
                                      fullWidth[index] = !fullWidth[index];
                                      setState(() {});
                                    },
                                    icon:
                                        fullWidth[index]
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
                                searchdata.selectedHit = hitIndices[index].toInt();
                                context.go("/sequence");
                              },
                              icon: Icon(
                                Icons.search,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                          ],),
                        DrawHit(
                          hit: searchdata.hits[hitIndices[index].toInt()],
                          searchdata: searchdata,
                          fullWidth: fullWidth[index],
                          maxLength: maxLength,
                          pixelsPerResidue: ppr,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            bottomNavigationBar: MainNavBar(whereAmI: WhichPage.subtreeevalue),
          ),);
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
  bool fullWidth = false;
  bool showExpand = false;
  final ScrollController _scrollController2 = ScrollController();
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return Material(
      child: Consumer3<SearchData, GraphData, HSettings>(
        builder: (context, searchdata, graphdata, hsettings, child) {
          Hit theHit = searchdata.hits[searchdata.selectedHit.toInt()];
          showExpand =
              requiredHitWidth(theHit, true, true, context) > screenWidth;
          return SelectionArea(child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.primary,
            appBar: homotAppBar(text: "Sequence ${theHit.name}"),
            body: SingleChildScrollView(
              controller: _scrollController2,
              child: Card(
                margin: EdgeInsets.only(bottom: 8),
                color: Theme.of(context).colorScheme.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                   Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                          Text(
                            overflow: TextOverflow.clip,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium!.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          "Sequence: " +
                              theHit.name +
                              "\nE-Value: " +
                              theHit.seqEvalue
                                  .toStringAsExponential(4)+"\nTaxon: "+graphdata.graph[theHit.taxid]!.name+ '\nDescription: '+theHit.description,
                        ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            showExpand
                                ? RotatedBox(
                                  quarterTurns: 1,
                                  child: IconButton.outlined(
                                    iconSize: 24 * hsettings.scale,
                                  
                                    onPressed: () {
                                      fullWidth= !fullWidth;
                                      setState(() {});
                                    },
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
                          ],
                        ),
                          ],), 
                    DrawHit(
                      hit: theHit,
                      allDomains: true,
                      searchdata: searchdata,
                      fullWidth: fullWidth,
                      showSequence: true,
                      sequence: theHit.sequence,
                      maxLength: theHit.seqLength,
                      pixelsPerResidue: pixelsPerResidue(theHit.seqLength, Theme.of(context).textTheme, context),
                    ),
                    
                  ],
                ),
              ),
            ),
            bottomNavigationBar: MainNavBar(whereAmI: WhichPage.sequence),
          ),);
        },
      ),
    );
  }
}
