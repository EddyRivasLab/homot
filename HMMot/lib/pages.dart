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

//Widget to select annotation data directory
class annDataSelect extends StatefulWidget {
  const annDataSelect({super.key});

  @override
  _annDataSelectState createState() => _annDataSelectState();
}

class _annDataSelectState extends State<annDataSelect> {
  @override
  Widget build(BuildContext context) {
    return Consumer3<OverviewData, HitLists, FileData>(
      builder: (context, overview, hitLists, filedata, child) {
        return ElevatedButton(
          onPressed: () async {
            String? annTemp = await FilePicker.platform.getDirectoryPath(
              dialogTitle:
                  "Select directory containing annotated sequence database",
            );
            if (annTemp == null) {
            } else {
              setState(() {
                filedata.setAnnotationsFile(annTemp);
                //_annPrompt = "Annotations database: ${filedata.annotationsFile}";
              });
            }
          },
          child: Text(filedata.annFilePrompt),
        );
      },
    );
  }
}

// Widget to select domtblout files
class domTblSelect extends StatefulWidget {
  const domTblSelect({super.key});

  @override
  _domTblSelectState createState() => _domTblSelectState();
}

class _domTblSelectState extends State<domTblSelect> {
  @override
  bool _selected = false;
  String _dPrompt = "Select";

  Widget build(BuildContext context) {
    return Consumer3<OverviewData, HitLists, FileData>(
      builder: (context, overview, hitLists, filedata, child) {
        return ElevatedButton(
          onPressed: () async {
            FilePickerResult? dTemp = await FilePicker.platform.pickFiles(
              allowMultiple: true,
              dialogTitle: "Select .domtblout file(s)",
            );
            if (dTemp == null) {
            } else {
                for (String? path in dTemp.paths) {
                  if (path != null) {
                    filedata.addDomtbloutFile(path);
                  }
                }
              };
            },
          child: Text(_dPrompt),
        );
      },
    );
  }
}


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
      appBar: HmmotAppBar(text: "HMMot: HMMer Results Observation Tool"),
      body:           Consumer3<FileData, HitLists, OverviewData>(
            builder: (context, filedata, hitLists, overview, child) {
              return Column(
        //mainAxisSize: MainAxisSize.min,
        children: <Widget>[
                    Text("Annotated Database:"),
                    Card(
                      child: ListTile(
                        title: Center(
                          child: Builder(
                            builder: (context) {
                              if(filedata.annFileSet){
                                return Text(filedata.annotationsFile);
                              } else {
                                return Text("None Selected");
                              };
                            },
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        annDataSelect(),
                      ],
                    ),
                    Text("Domtblout File(s):"),
                    Builder(
                        builder: (context) {
                          if(filedata.domtbloutFiles.length > 0){
                            return 
                              Flexible(
                                child: Scrollbar(
                              controller: _mainScrollController,
                              child: ListView.builder(
                              shrinkWrap: true, 
                              controller: _mainScrollController,
                              itemCount: filedata.domtbloutFiles.length,
                              itemBuilder: (BuildContext context, int index) {
                                return Card(
                                  child: 
                                  Row(
                                    children: [Text(filedata.domtbloutFiles[index]),
                                      Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () {
                                          setState(() {
                                            filedata.deleteDomtbloutFile(filedata.domtbloutFiles[index]);
                                          }
                                          );
                                        },
                                      ),
                        ],
                                      ),          
                                );
                              },
                              ),
                              ),);
                          }
                          else {
                            return Card(child: ListTile(title: Center(child: Text("None Selected"),),),);
                          };
                        },
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        ElevatedButton(
                          onPressed: () async {
                            FilePickerResult? dTemp = await FilePicker.platform.pickFiles(
                            allowMultiple: true,
                            dialogTitle: "Select .domtblout file(s)",
                            );     ;
                            if (dTemp != null) {
                              filedata.clearDomtbloutFiles();
                              for (String? path in dTemp.paths) {
                                if (path != null) {
                                filedata.addDomtbloutFile(path);
                                }
                              }
                            };
                          },
                          child: Text("Select"),
                        ),
                        ElevatedButton(
                          onPressed: filedata.domtbloutFiles.isNotEmpty ? () async {
                            FilePickerResult? dTemp = await FilePicker.platform.pickFiles(
                            allowMultiple: true,
                            dialogTitle: "Select additional .domtblout file(s)",
                            );
                            if (dTemp != null) {
                              for (String? path in dTemp.paths) {
                                if (path != null) {
                                filedata.addDomtbloutFile(path);
                                }
                              }
                            };
                          } : null,
                          child: Text("Add"),
                        ),
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
                            content: Center(child: Text("Loading Data")),
                            ),
                          ); 
                          //Gather hits from the domtblout files
                          results =loadData(annfile: filedata.annotationsFile,
                                            domtbloutFiles: filedata.domtbloutFiles,
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const OverviewPage(),
                              ),
                            );
                        };
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
  final ScrollController _mainScrollController = ScrollController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HmmotAppBar(text: "Settings"),
      body:           Consumer<HTheme>(
            builder: (context, htheme, child) {
              return Column(
        children: <Widget>[
                    ElevatedButton(onPressed: htheme.toggleTheme, child: Text("Toggle Theme")),
                    Column(
                      children: [
                        Text("Select Font"),  
                        SystemFontSelector(
                          isFontPreviewEnabled: true,
                          onFontSelected: (font){
                            htheme.setFont(font);
                          }
                        ),
                        Text("Font Scale Factor"),
                        InputQty.double(
                          initVal: htheme.scale,
                          minVal: 0.001,
                          steps: 0.1,
                          decoration: const QtyDecorationProps(
                            qtyStyle: QtyStyle.btnOnRight
                          ),
                          onQtyChanged: (val) {
                            htheme.setScale(val);
                          },
                        ),
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
            appBar:  HmmotAppBar(text:"${overview.numHits} hits found, with ${overview.numCategories} different domain signatures."),
            body: Scrollbar(
              controller: _scrollController2,
              child: ListView.builder(
                controller: _scrollController2,
                itemCount: overview.numCategories,
                itemBuilder: (BuildContext context, int index) {
                  return Container(
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

// Widget that displays the results overview
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
            appBar:  HmmotAppBar(text : "${hitLists.hitLists[hitLists.selected].numHits} hits found with domain structure ${hitLists.hitLists[hitLists.selected].signature}"),
            body: Scrollbar(
              controller: _scrollController2,
              child: ListView.builder(
                controller: _scrollController2,
                itemCount: hitLists.hitLists[hitLists.selected].numHits,
                itemBuilder: (BuildContext context, int index) {
                  return Container(
                    margin: EdgeInsets.only(bottom: 24),
                    child: Column(
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

