import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:homot/src/rust/frb_generated.dart';
import 'package:homot/main.dart';
import 'package:homot/pages.dart';

import 'package:osler_icons/osler_icons.dart';
import 'package:provider/provider.dart';
import 'package:input_quantity/input_quantity.dart';
import "dart:io";
import "package:go_router/go_router.dart";
import "dart:developer";

import 'package:flutter/material.dart';
import 'package:system_fonts/system_fonts.dart';
import 'package:file_selector/file_selector.dart';

// This is a very lightly modified version of the SystemFontSelector from the system_fonts package.
/// [SystemFontSelector] is a [DropdownMenu] widget that displays a list of all the available fonts in the system.
/// The user can select a font from the list and the font will be loaded and font name will be passed to the `onFontSelected` callback.
/// All the font names can be showed in their fontfamily if `isFontPreviewEnabled` is set to `true` but this will cause every font to be loaded.
/// Remember every font can be loaded once and if loaded, font will be available for app lifetime,
/// so if you somehow loaded every font once you can use font preview without any additional cost in every [SystemFontSelector] instance.
class HmmotSystemFontSelector extends StatefulWidget {
  const HmmotSystemFontSelector({
    this.initial,
    this.width = 200,
    this.isFontPreviewEnabled = false,
    this.textStyle,
    this.onFontSelected,
    super.key,
  });

  final String? initial;
  final double width;
  final bool isFontPreviewEnabled;
  final TextStyle? textStyle;

  final Function(String)? onFontSelected;

  @override
  State<HmmotSystemFontSelector> createState() =>
      _HmmotSystemFontSelectorState();
}

class _HmmotSystemFontSelectorState extends State<HmmotSystemFontSelector> {
  String? dropdownValue;
  List<String> fontNames = [];
  String? init;

  @override
  void initState() {
    super.initState();
    if (widget.isFontPreviewEnabled) {
      _loadAllFonts();
    } else {
      setState(() {
        fontNames = SystemFonts().getFontList();
      });
    }
    if (widget.initial != null) {
      SystemFonts().loadFont(widget.initial!);
      setState(() {
        init = widget.initial;
      });
    }
  }

  _loadAllFonts() async {
    fontNames = await SystemFonts().loadAllFonts();
    setState(() {
      init = widget.initial;
      widget.onFontSelected?.call(widget.initial ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<String>(
      initialSelection: init,
      width: widget.width,
      onSelected: (String? value) {
        setState(() {
          dropdownValue = value;
          widget.onFontSelected?.call(value ?? '');
        });
      },
      textStyle:
          widget.textStyle != null
              ? widget.textStyle!.copyWith(
                fontFamily: widget.isFontPreviewEnabled ? widget.initial : null,
              )
              : Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontFamily: widget.isFontPreviewEnabled ? widget.initial : null,
                overflow: TextOverflow.ellipsis,
              ),
      dropdownMenuEntries:
          fontNames.map<DropdownMenuEntry<String>>((String value) {
            return DropdownMenuEntry<String>(
              value: value,
              label: value,
              style: MenuItemButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                backgroundColor: Theme.of(context).colorScheme.surface,
                textStyle:
                    widget.textStyle != null
                        ? widget.textStyle!.copyWith(
                          fontFamily:
                              widget.isFontPreviewEnabled ? value : null,
                        )
                        : Theme.of(context).textTheme.bodyMedium!.copyWith(
                          fontFamily:
                              widget.isFontPreviewEnabled ? value : null,
                          overflow: TextOverflow.ellipsis,
                        ),
              ),
            );
          }).toList(),
    );
  }
}

class homotAppBar extends StatelessWidget implements PreferredSizeWidget {
  const homotAppBar({super.key, required this.text});

  final String text;
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).primaryColor,
      title: Text(
        style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        text,
      ),
      leading: NonMacMenuBar(),
      actions: [
        TooltipTheme(
          data: TooltipThemeData(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
            ),
            textStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          child: IconButton(
            icon: const Icon(Icons.settings),
            color: Theme.of(context).colorScheme.onPrimary,
            tooltip: "Settings",
            onPressed: () {
              context.go("/settings");
            },
          ),
        ),
      ],
    );
  }
}

enum WhichPage {
  home,
  allstructure,
  graph,
  subgraphstructure,
  allevalue,
  subtreeevalue,
  settings,
  sequence,
}

class MainNavBar extends StatelessWidget {
  const MainNavBar({super.key, required this.whereAmI});
  final WhichPage whereAmI;

  static const List<String> _routes = <String>[
    "/",
    "/graph",
    "/allstructure",
    "/allevalue",
    "/subtreestructure",
    "/subtreeevalue",
    "/sequence",
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer2<SearchData, GraphData>(
      builder: (context, searchdata, graphdata, child) {
        return NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelTextStyle: WidgetStateProperty.all<TextStyle>(
              TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 16,
              ),
            ),
          ),
          child: NavigationBar(
            backgroundColor: Theme.of(context).primaryColor,
            onDestinationSelected: (int index) {
              ScaffoldMessenger.of(
                context,
              ).clearSnackBars(); // clean up any snack bars
              context.go(_routes[index]);
            },
            destinations: <Widget>[
              NavigationDestination(
                icon: Icon(
                  Icons.folder,
                  color:
                      whereAmI != WhichPage.home
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).disabledColor,
                ),
                enabled: whereAmI != WhichPage.home,
                tooltip: "",
                label: 'Select Data',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.account_tree_rounded,
                  color:
                      (whereAmI != WhichPage.graph) && (graphdata.depth != 0)
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).disabledColor,
                ),
                enabled:
                    (whereAmI != WhichPage.graph) && (graphdata.depth != 0),
                tooltip: null,
                label: 'Taxonomic Display',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.category,
                  color:
                      (whereAmI != WhichPage.allstructure) &&
                              searchdata.resultsLoaded
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).disabledColor,
                ),
                enabled:
                    (whereAmI != WhichPage.allstructure) &&
                    searchdata.resultsLoaded,
                tooltip: "",
                label: 'All Hits by Domain Structure',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.swap_vert,
                  color:
                      (whereAmI != WhichPage.allevalue) &&
                              searchdata.resultsLoaded
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).disabledColor,
                ),
                enabled:
                    (whereAmI != WhichPage.allevalue) &&
                    searchdata.resultsLoaded,
                tooltip: "",
                label: 'All Hits by e-value',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.category,
                  color:
                      (whereAmI != WhichPage.subgraphstructure) &&
                              graphdata.currentRoot != graphdata.graphRoot
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).disabledColor,
                ),
                enabled:
                    (whereAmI != WhichPage.subgraphstructure) &&
                    graphdata.currentRoot != graphdata.graphRoot,
                tooltip: "",
                label: 'Selected Subtree by Domain Structure',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.swap_vert,
                  color:
                      (whereAmI != WhichPage.subtreeevalue) &&
                              searchdata.selectedBy != selectedby.none
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).disabledColor,
                ),
                enabled:
                    (whereAmI != WhichPage.subtreeevalue) &&
                    searchdata.selectedBy != selectedby.none,
                tooltip: "",
                label: 'Selected hits by e-value',
              ),
              NavigationDestination(
                icon: Icon(
                  OslerMonotoneIcons.dna,
                  color:
                      (whereAmI != WhichPage.sequence) &&
                              searchdata.selectedHit >= 0
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).disabledColor,
                ),
                enabled:
                    (whereAmI != WhichPage.sequence) &&
                    searchdata.selectedHit >= 0,
                tooltip: "",
                label: 'Selected Sequence',
              ),
            ],
          ),
        );
      },
    );
  }
}

class AnnDbSelect extends StatefulWidget {
  const AnnDbSelect({super.key});
  @override
  State<AnnDbSelect> createState() => _AnnDbSelectState();
}

class _AnnDbSelectState extends State<AnnDbSelect> {
  final myController = TextEditingController();
  @override
  void dispose() {
    myController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (context.read<FileData>().annotationsFile.isEmpty) {
      myController.text = "None Selected";
    } else {
      myController.text = context.read<FileData>().annotationsFile;
    }
  }

  Widget build(BuildContext context) {
    return Consumer<FileData>(
      builder: (context, filedata, child) {
        return Card(
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: myController,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  onFieldSubmitted: (String? value) async {
                    if (value != null && Directory(value).existsSync()) {
                      filedata.setAnnotationsFile(value);
                    }
                  },
                  validator: (String? value) {
                    return (value == null || !Directory(value).existsSync())
                        ? "Must be valid  directory path"
                        : null;
                  },
                ),
              ),
              IconButton(
                icon: Icon(Icons.folder),
                color: Theme.of(context).colorScheme.onSurface,
                onPressed: () async {
                  String? dTemp = await getDirectoryPath(
                    initialDirectory: filedata.annFileDir,
                    confirmButtonText: "Select Annotations Database",
                  );

                  if (dTemp == null) {
                  } else {
                    if (Directory(dTemp).existsSync()) {
                      filedata.setAnnotationsFile(dTemp);
                      myController.text = dTemp;
                    }
                  }
                  ;
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class DomtblSelect extends StatefulWidget {
  const DomtblSelect({super.key});
  @override
  State<DomtblSelect> createState() => _DomtblSelectState();
}

class _DomtblSelectState extends State<DomtblSelect> {
  final myController = TextEditingController();

  @override
  void initState() {
    super.initState();
    myController.text = "Select or enter search result file(s)";
  }

  Widget build(BuildContext context) {
    return Consumer<FileData>(
      builder: (context, filedata, child) {
        return Card(
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  controller: myController,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  onFieldSubmitted: (String? value) async {
                    if (value != null && File(value).existsSync()) {
                      filedata.addDomtbloutFile(value);
                      myController.text =
                          "Select or enter search result file(s)";
                    }
                  },
                  validator: (String? value) {
                    return (value == null || !File(value).existsSync())
                        ? "Must be valid filename"
                        : null;
                  },
                ),
              ),
              IconButton(
                icon: Icon(Icons.folder),
                color: Theme.of(context).colorScheme.onSurface,
                onPressed: () async {
                  List<XFile>? dTemp = await openFiles(
                    initialDirectory: filedata.domtbloutFileDir,
                    confirmButtonText: "Select search result file(s)",
                  );
                  if (dTemp == null) {
                  } else {
                    for (XFile xfile in dTemp) {
                      if (xfile.path != null && File(xfile.path).existsSync()) {
                        filedata.addDomtbloutFile(xfile.path);
                      }
                    }
                  }
                  ;
                  null;
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class DomtblEdit extends StatefulWidget {
  const DomtblEdit({required this.which, super.key});
  final int which;
  @override
  State<DomtblEdit> createState() => _DomtblEditState();
}

class _DomtblEditState extends State<DomtblEdit> {
  Widget build(BuildContext context) {
    return Consumer<FileData>(
      builder: (context, filedata, child) {
        return Card(
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  initialValue:
                      (widget.which >= 0 &&
                              widget.which < filedata.domtbloutFiles.length)
                          ? filedata.domtbloutFiles[widget.which]
                          : "Illegal index passed to DomTblEdit",
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  onFieldSubmitted: (String? value) async {
                    if (value != null &&
                        File(value).existsSync() &&
                        widget.which >= 0 &&
                        widget.which < filedata.domtbloutFiles.length) {
                      filedata.setDomtbloutFile(widget.which, value);
                    }
                  },
                  validator: (String? value) {
                    return (value == null || !File(value).existsSync())
                        ? "Must be valid filename"
                        : null;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class Pair<T1, T2> {
  final T1 a;
  final T1 b;

  Pair(this.a, this.b);
}

void showExportDialog(BuildContext context) {
  final myController = TextEditingController();
  myController.text = "Enter or choose output file name";
  final currentLocation =
      GoRouter.of(context).routerDelegate.currentConfiguration.uri.toString();

  showDialog(
    context: context,
    builder: (BuildContext context) {
        return AlertDialog(
        title: const Text("Export Page Contents to CsV"),
        backgroundColor: Theme.of(context).colorScheme.onPrimary,
        titleTextStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
        content: Consumer3<FileData, SearchData, HSettings>(
          builder: (context, filedata, searchData, hsettings, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        decoration: InputDecoration(
                          hintText: "Enter output file name",
                          hintStyle: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        controller: myController,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        onFieldSubmitted: (String? value) async {
                          if (value != null) {
                            filedata.exportFile;
                            myController.text = filedata.exportFile;
                          }
                        },
                        validator: (String? value) {
                          if (value == null) {
                            return "Please specify a file";
                          } else {
                            var splits = value.split('/');
                            String dir = "";
                            if (splits.length > 1) {
                              dir = splits
                                  .getRange(0, splits.length - 1)
                                  .join("/");
                            } else {
                              dir = "";
                            }
                            return (!Directory(dir).existsSync())
                                ? "Directory does not exist"
                                : null;
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.folder),
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: () async {
                        final FileSaveLocation? loc = await getSaveLocation();
                        if (loc == null) {
                        } else {
                          filedata.exportFile = loc.path;
                          myController.text = loc.path;
                        }
                        ;
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        actions: <Widget>[
          Consumer3<FileData, HSettings, SearchData>(
            builder: (context, filedata, hsettings, searchdata, child) =>
          ElevatedButton(
            style: MenuItemButton.styleFrom(
              backgroundColor: filedata.exportFile != "" ?Theme.of(context).colorScheme.primary : Theme.of(context).disabledColor,
            ),
            onPressed: filedata.exportFile != "" ? () {
              filedata.exportCurrentPage(currentLocation, searchdata, hsettings.showNamesFrom == ShowNamesFrom.pfam, hsettings.showInterproSuperfamily, hsettings.showInterproFamily,
              hsettings.showInterproDomain, hsettings.showInterproRepeat, hsettings.showInterproSite, hsettings.showInterproOther, context);
              Navigator.pop(context, 'Cancel');
            } : null,
            child: Text(
              "Export",
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
          ),),
          ElevatedButton(
            style: MenuItemButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () {
              Navigator.pop(context, 'Cancel');
            },
            child: Text(
              "Cancel",
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
          ),
        ],
      );
    },
  
  );
}
