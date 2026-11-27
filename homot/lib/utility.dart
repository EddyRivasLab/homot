import 'package:material_ui/material_ui.dart';
import 'package:homot/main.dart';

import 'package:osler_icons/osler_icons.dart';
import 'package:provider/provider.dart';
import "dart:io";
import "package:go_router/go_router.dart";

import 'package:system_fonts/system_fonts.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:homot/src/rust/api/graph.dart';

// Directory part of a file path, or null if the path has no directory part.
// Uses the current platform's separators, so Windows paths (C:\dir\file) work.
String? parentDir(String path) {
  final dir = p.dirname(path);
  return dir == '.' ? null : dir;
}

// Cleans up a path typed or pasted into a text field: trims surrounding
// whitespace, expands a leading ~ to the user's home directory, and strips
// trailing separators (so parentDir of "/a/db/" is "/a", not "/a/db").
String normalizeTypedPath(String path) {
  var v = path.trim();
  if (v == '~' || v.startsWith('~/') || v.startsWith('~\\')) {
    final home = _homeDir();
    if (home != null) {
      v = v.length <= 2 ? home : p.join(home, v.substring(2));
    }
  }
  return v.length > 1 ? p.normalize(v) : v;
}

String? _homeDir() =>
    Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];

// Resolves a typed path to an absolute path that satisfies [exists], or
// returns null if there is none.  The path is tried as typed first; if it is
// relative and not found, it is also tried relative to the home directory, so
// entering just "mydb" finds ~/mydb.  (An app launched from the Finder has
// "/" as its working directory, so relative paths rarely work as typed.)
String? resolveTypedPath(String value, bool Function(String) exists) {
  final v = normalizeTypedPath(value);
  if (v.isEmpty) return null;
  if (exists(v)) return p.absolute(v);
  final home = _homeDir();
  if (p.isRelative(v) && home != null) {
    final h = p.join(home, v);
    if (exists(h)) return h;
  }
  return null;
}

String? resolveTypedDir(String value) =>
    resolveTypedPath(value, (s) => Directory(s).existsSync());

String? resolveTypedFile(String value) =>
    resolveTypedPath(value, (s) => File(s).existsSync());

// Like resolveTypedFile, but for a file to be written: it only needs its
// directory to exist.  A bare name ("out.csv") counts as typed only if that
// file already exists, so it otherwise goes in the home directory rather than
// the app's working directory.
String? resolveTypedOutputFile(String value) => resolveTypedPath(value, (s) {
  if (File(s).existsSync()) return true;
  final dir = p.dirname(s);
  return dir != '.' &&
      Directory(dir).existsSync() &&
      !Directory(s).existsSync();
});

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

  Future<void> _loadAllFonts() async {
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

class HomotAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomotAppBar({super.key, required this.text});

  final String text;
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) {
    return AppBar(
      // Match the page background (colorScheme.primary).  Theme.primaryColor
      // isn't used because in dark mode it's a dark surface colour, not our blue.
      backgroundColor: Theme.of(context).colorScheme.primary,
      // Don't tint the bar a different shade when content scrolls under it
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
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
          child: TooltipVisibility(
            visible: false,
            child: NavigationBar(
              // Match the page background, as the app bar does
              backgroundColor: Theme.of(context).colorScheme.primary,
              surfaceTintColor: Colors.transparent,
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
                                searchdata.selectedBy != SelectedBy.none
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).disabledColor,
                  ),
                  enabled:
                      (whereAmI != WhichPage.subtreeevalue) &&
                      searchdata.selectedBy != SelectedBy.none,
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

  @override
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
                  // Update on every edit, not just on Enter, so a typed path is
                  // used even if the user clicks Load Data without submitting.
                  onChanged: (String value) {
                    final v = resolveTypedDir(value);
                    if (v != null && v != filedata.annotationsFile) {
                      filedata.setAnnotationsFile(v);
                    }
                  },
                  validator: (String? value) {
                    return (value == null || resolveTypedDir(value) == null)
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

  @override
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
                    if (value == null) return;
                    final v = resolveTypedFile(value);
                    if (v != null) {
                      filedata.addDomtbloutFile(v);
                      myController.text =
                          "Select or enter search result file(s)";
                    }
                  },
                  validator: (String? value) {
                    return (value == null || resolveTypedFile(value) == null)
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
                  for (XFile xfile in dTemp) {
                    if (File(xfile.path).existsSync()) {
                      filedata.addDomtbloutFile(xfile.path);
                    }
                  }
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
  @override
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
                  // Update on every edit, not just on Enter (see AnnDbSelect).
                  onChanged: (String value) {
                    final v = resolveTypedFile(value);
                    if (v != null &&
                        widget.which >= 0 &&
                        widget.which < filedata.domtbloutFiles.length &&
                        filedata.domtbloutFiles[widget.which] != v) {
                      filedata.setDomtbloutFile(widget.which, v);
                    }
                  },
                  validator: (String? value) {
                    return (value == null || resolveTypedFile(value) == null)
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

void _showExportError(BuildContext context, String error) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Unable to Export Data"),
        backgroundColor: Theme.of(context).colorScheme.error,
        titleTextStyle: TextStyle(
          color: Theme.of(context).colorScheme.onError,
          fontSize: 20.0,
          fontWeight: FontWeight.bold,
        ),
        content: Text("Error was: $error"),
        contentTextStyle: TextStyle(fontSize: 16.0),
        actions: [
          ElevatedButton(
            style: MenuItemButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              "OK",
            ),
          ),
        ],
      );
    },
  );
}

// Asks whether to overwrite an existing export file.  Returns true to replace.
Future<bool> _confirmReplace(BuildContext context, String path) async {
  final replace = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.onPrimary,
        titleTextStyle: TextStyle(color: Theme.of(context).colorScheme.primary),

        title: Text("\"${p.basename(path)}\" already exists"),
        content: Text(
          "Do you want to replace it?\n\n$path",
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
        actions: [
          TextButton(
            style: MenuItemButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            style: MenuItemButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Replace"),
          ),
        ],
      );
    },
  );
  return replace ?? false;
}

void showExportDialog(BuildContext context) {
  // The dialog builders below shadow `context`, so keep a handle on the page's
  // context for reporting errors after the dialog has closed.
  final BuildContext pageContext = context;
  // Set once here, not in the Consumer builder: the builder reruns whenever
  // FileData changes, which onChanged triggers on every keystroke.  An empty
  // field shows the hint text instead.
  final myController = TextEditingController(
    text: context.read<FileData>().exportFile,
  );

  final currentLocation =
      GoRouter.of(context).routerDelegate.currentConfiguration.uri.toString();

  // True when the export path came from the save dialog, which has already
  // asked about replacing an existing file.  Typed paths (and a path left over
  // from an earlier export) are checked before writing.
  bool pathFromPicker = false;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Export Page Contents to CsV"),
        backgroundColor: Theme.of(context).colorScheme.onPrimary,
        titleTextStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
        content: Consumer3<FileData, SearchData, HSettings>(
          builder: (context, fileData, searchData, hsettings, child) {
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
                          hintText: "Enter or choose output file name",
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
                        // Update on every edit, not just on Enter.  An
                        // unusable path clears exportFile, which disables
                        // Export, rather than leaving an earlier path in place.
                        onChanged: (String value) {
                          final v = resolveTypedOutputFile(value) ?? "";
                          pathFromPicker = false;
                          if (v != fileData.exportFile) {
                            fileData.exportFile = v;
                          }
                        },
                        validator: (String? value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Please specify a file";
                          }
                          return resolveTypedOutputFile(value) == null
                              ? "Directory does not exist"
                              : null;
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
                          pathFromPicker = true;
                          fileData.exportFile = loc.path;
                          myController.text = loc.path;
                        }
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
            builder:
                (context, filedata, hsettings, searchdata, child) =>
                    ElevatedButton(
                      style: MenuItemButton.styleFrom(
                        backgroundColor:
                            filedata.exportFile != ""
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).disabledColor,
                      ),
                      onPressed:
                          filedata.exportFile != ""
                              ? () async {
                                if (!pathFromPicker &&
                                    File(filedata.exportFile).existsSync()) {
                                  final replace = await _confirmReplace(
                                    context,
                                    filedata.exportFile,
                                  );
                                  if (!replace || !context.mounted) return;
                                }
                                Navigator.pop(context, 'Cancel');
                                final String? error = await filedata
                                    .exportCurrentPage(
                                      currentLocation,
                                      searchdata,
                                      hsettings.showNamesFrom ==
                                          ShowNamesFrom.pfam,
                                      hsettings.showInterproSuperfamily,
                                      hsettings.showInterproFamily,
                                      hsettings.showInterproDomain,
                                      hsettings.showInterproRepeat,
                                      hsettings.showInterproSite,
                                      hsettings.showInterproOther,
                                    );
                                // This dialog is gone by now, so report errors
                                // using the page that opened it.
                                if (error != null && pageContext.mounted) {
                                  _showExportError(pageContext, error);
                                }
                              }
                              : null,
                      child: Text(
                        "Export",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
          ),
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

int maxDepthBelowRoot(Node root, Map<PlatformInt64, Node> graph) {
  int depth = 0;

  if (root.ranknum > depth) {
    depth = root.ranknum;
  }
  for (var childId in root.children) {
    var childDepth = maxDepthBelowRoot(graph[childId.toInt()]!, graph);
    if (childDepth > depth) {
      depth = childDepth;
    }
  }
  return depth;
}
