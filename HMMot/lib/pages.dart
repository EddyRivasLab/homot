/* pages.dart: Routines and widgets for the different pages used it HMMot
 * Contents:
 * annDataSelect -- Widget to select the annotated database directory
 * domTblSelect -- Widget to select the domtblout files
 * MainPage -- The first page a user sees, which allows them to select the annotated database
 *             and domtblout files they wish to view
 * SettingsPage -- allows the user to configure the application
 * OverviewPage -- displays an overview of the search results, divided by category
 * 
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
import 'package:HMMot/draw_data.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:input_quantity/input_quantity.dart';
import 'package:system_fonts/system_fonts.dart';
import "package:go_router/go_router.dart";


// Widget to enter information about what files to read
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final ScrollController _mainScrollController = ScrollController();
  String? dtemp;
  SearchResults? results;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: HmmotAppBar(text: "HMMot: HMMer Results Observation Tool"),
      body:           Consumer4<FileData, HitLists, OverviewData, HSettings>(
            builder: (context, filedata, hitLists, overview, hsettings, child) {
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
                              child: ListView.builder(
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
                        onPressed: filedata.domtbloutFiles.isNotEmpty && filedata.annFileSet ? () async {
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
                          results =await loadData(annfile: filedata.annotationsFile,
                                            domtbloutFiles: filedata.domtbloutFiles, evalMax: hsettings.evalMax, domEvalMax: hsettings.domEvalMax
                           );
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
                                  Text("Load Failed: ${results!.errMsg}"),
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
                            overview.set(results!.overview);
                            hitLists.init(results!.overview.numCategories);
                            for (
                              var iter1 = 0;
                              iter1 < results!.overview.numCategories;
                              iter1++
                            ) {
                              hitLists.set(iter1, results!.hitLists[iter1]);
                            }
                              context.go("/overview");
                          }
                        }: null,
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
        title: const Text("Reload Data"),
        content: const Text("Data must be re-loaded for changes to e-value settings to take effect."),
        actions: [
          TextButton(child: Text(style: Theme.of(context).textTheme.bodyMedium, 'OK'),
          onPressed: () => Navigator.of(context).pop()),
        ]
      );}
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: HmmotAppBar(text: "Settings"),
      body:           Consumer<HSettings>(
            builder: (context, hsettings, child) {
              return Column(
        children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(child:Column(
                          children: [
                          Text(style: Theme.of(context).textTheme.bodyMedium, "Theme"), Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                          ChoiceChip(label: Text(style: Theme.of(context).textTheme.bodyMedium, "Light"),
                          selected: hsettings.mode == brightModes.light,
                          onSelected: (bool selected){
                            if (selected == true){
                              hsettings.mode= brightModes.light;
                            }
                          }),
                          ChoiceChip(label: Text(style: Theme.of(context).textTheme.bodyMedium, "Dark"),
                          selected: hsettings.mode == brightModes.dark,
                          onSelected: (bool selected){
                            if (selected == true){
                              hsettings.mode =brightModes.dark;
                            }
                          }),
                          ChoiceChip(label: Text(style: Theme.of(context).textTheme.bodyMedium, "System"),
                          selected: hsettings.mode == brightModes.system,
                          onSelected: (bool selected){
                            if (selected == true){
                              hsettings.mode =brightModes.system;
                            }
                          }),],),
                        ]),),
                        Card(child:Column(children: [
                        Text(style: Theme.of(context).textTheme.bodyMedium, "Select Font"),  
                        SystemFontSelector(
                          initial: hsettings.font,
                          isFontPreviewEnabled: true,
                          onFontSelected: (font){
                            hsettings.font =font;
                          }
                        ),],),),
                        Card(child:Column(children:[
                        Text(style: Theme.of(context).textTheme.bodyMedium, "Font Scale Factor"),
                        InputQty.double(
                          initVal: hsettings.scale,
                          minVal: 0.001,
                          steps: 0.1,
                          decoration: const QtyDecorationProps(
                            qtyStyle: QtyStyle.btnOnRight
                          ),
                          onQtyChanged: (val) {
                            hsettings.scale =val;
                          },
                        ),],),),
                        Card(child: IntrinsicWidth(child: Column(children: [
                          Text(style: Theme.of(context).textTheme.bodyMedium, "Maximum E-Value to Show"),
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
                        Card(child: IntrinsicWidth(child: Column(children: [
                          Text(style: Theme.of(context).textTheme.bodyMedium,"Maximum Domain E-Value to Show"),
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

// Widget that displays the results overview
class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  final ScrollController _scrollController2 = ScrollController();
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Consumer<OverviewData>(
        builder: (context, overview, child) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.primary,
            appBar:  HmmotAppBar(text:"${overview.numHits} hits found, with ${overview.numCategories} different domain signatures."),
            body: Scrollbar(
              controller: _scrollController2,
              child: ListView.builder(
                controller: _scrollController2,
                itemCount: overview.numCategories,
                itemBuilder: (BuildContext context, int index) {
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: DrawCategory(
                      which: index,
                      category: overview.categories[index],
                      overview: overview,
                    ),
                  );
                },
              ),
            ),
            bottomNavigationBar: MainNavBar(whereAmI: WhichPage.overview),
          );
        },
      ),
    );
  }
}

// Widget that displays one domain signature's worth of results
class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final ScrollController _scrollController2 = ScrollController();
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Consumer2<OverviewData, HitLists>(
        builder: (context, overview, hitLists, child) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.primary,
            appBar:  HmmotAppBar(text : "${hitLists.hitLists[hitLists.selected].numHits} hits found with domain structure ${hitLists.hitLists[hitLists.selected].signature}"),
            body: Scrollbar(
              controller: _scrollController2,
              child: ListView.builder(
                controller: _scrollController2,
                itemCount: hitLists.hitLists[hitLists.selected].numHits,
                itemBuilder: (BuildContext context, int index) {
                  return Card(
                    child: Column(
                      //crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),
                            "Sequence: " + hitLists.hitLists[hitLists.selected].hits[index].name +", E-Value: " + 
                            hitLists.hitLists[hitLists.selected].hits[index].seqEvalue.toStringAsExponential(4),
                        ),
                        DrawHit(
                          hit: hitLists.hitLists[hitLists.selected].hits[index],
                          overview: overview,
                        ),
                        Align( alignment: Alignment(1.0,0.0), child: IconButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                          onPressed: () {
                            hitLists.setSequence(index);
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
            bottomNavigationBar: MainNavBar(whereAmI: WhichPage.category),
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
      child: Consumer2<OverviewData, HitLists>(
        builder: (context, overview, hitLists, child) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.primary,
            appBar:  HmmotAppBar(text : "Sequence ${hitLists.hitLists[hitLists.selected].hits[hitLists.sequence].name}"),
            body: SingleChildScrollView(
              controller: _scrollController2,
              child: 
                Card(
                  child: 
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),
                            "Sequence e-value: ${ 
                            hitLists.hitLists[hitLists.selected].hits[hitLists.sequence].seqEvalue.toStringAsExponential(4)}"
                        ),
                        DrawHit(
                          hit: hitLists.hitLists[hitLists.selected].hits[hitLists.sequence],
                          allDomains: true,
                          overview: overview,
                        ),
                        Text(
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),
                          "Sequence:",                 
                        ),
                        Text(
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),
                          hitLists.hitLists[hitLists.selected].hits[hitLists.sequence].sequence,
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

