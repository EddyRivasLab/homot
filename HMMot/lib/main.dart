import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:HMMot/src/rust/api/simple.dart';
import 'package:HMMot/src/rust/api/gather_hits.dart';
import 'package:HMMot/src/rust/frb_generated.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:menu_bar/menu_bar.dart';

import 'dart:io' show Platform;

// List of pairs of background and foregrund colors for displaying
// domains.  Taken from the ColorBrewer example color sets.
// Folmat is (BGcolor, FG color)
const domainColors = [
  (Color(0xff9e0142), Color(0xffffffff)),
  (Color(0xff5475b4), Color(0xffffffff)),
  (Color(0xff40004b), Color(0xffffffff)),
  (Color(0xff006837), Color(0xffffffff)),
  (Color(0xffd53e4f), Color(0xffffffff)),
  (Color(0xff1a9850), Color(0xffffffff)),
  (Color(0xff0000ff), Color(0xffffffff)),
  (Color(0xfff46d43), Color(0xffffffff)),
  (Color(0xff6a3d9a), Color(0xffffffff)),
  (Color(0xffabd9e9), Color(0xff000000)),
  (Color(0xff68bd63), Color(0xffffffff)),
  (Color(0xfffdae61), Color(0xffffffff)),
  (Color(0xffff0000), Color(0xff000000)),
  (Color(0xfffee08b), Color(0xff000000)),
  (Color(0xffbc80bd), Color(0xff000000)),
  (Color(0xffffffbf), Color(0xff000000)),
  (Color(0xffa6d96a), Color(0xff000000)),
  (Color(0xffcab2d6), Color(0xff000000)),
  (Color(0xfffdaaac), Color(0xff000000)),
  (Color(0xff00ff00), Color(0xff000000)),
];

Future<void> main() async {
  await RustLib.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OverviewData()),
        ChangeNotifierProvider(create: (_) => HitLists()),
        ChangeNotifierProvider(create: (_) => FileData()),
      ],
      child: MenuWrapper(),
    ),
  );
}

ThemeData _hTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
    textTheme: TextTheme(bodyMedium: TextStyle(fontSize: 18)),
    useMaterial3: true,
  );
}

// Wrapper that selects the correct menu bar for the platform
class MenuWrapper extends StatelessWidget {
  const MenuWrapper();

  @override
  Widget build(BuildContext context) {
    if (Platform.isMacOS) {
      return MacMenu();
    } else {
      return TopLevel();
    }
  }
}

// Mac menus3
class MacMenu extends StatefulWidget {
  const MacMenu({super.key});

  @override
  State<MacMenu> createState() => _MacMenuBarState();
}

class _MacMenuBarState extends State<MacMenu> {
  Widget build(BuildContext context) {
    return PlatformMenuBar(
      menus: <PlatformMenuItem>[
        PlatformMenu(
          label: 'HMMot',
          menus: <PlatformMenuItem>[
            PlatformMenuItem(
              label: 'About HMMot',
              onSelected: () {
                showAboutDialog(
                  context: context,
                  applicationName: "HMMot",
                  applicationVersion: "0.0.1",
                );
              },
            ),
          ],
        ),
      ],
      child: TopLevel(),
    );
  }
}

// Gratuitiously stolen from the documentation for the MenuBar class
class MenuEntry {
  const MenuEntry({
    required this.label,
    this.shortcut,
    this.onPressed,
    this.menuChildren,
  }) : assert(
         menuChildren == null || onPressed == null,
         'onPressed is ignored if menuChildren are provided',
       );

  final String label;
  final MenuSerializableShortcut? shortcut;
  final VoidCallback? onPressed;
  final List<MenuEntry>? menuChildren;

  static List<Widget> build(List<MenuEntry> selections) {
    Widget buildSelection(MenuEntry selection) {
      if (selection.menuChildren != null) {
        return SubmenuButton(
          menuChildren: MenuEntry.build(selection.menuChildren!),
          child: Text(selection.label),
        );
      }
      return Consumer3<OverviewData, HitLists, FileData>(
        builder: (context, overview, hitLists, filedata, child) {
          return MenuItemButton(
            shortcut: selection.shortcut,
            onPressed: selection.onPressed,
            child: Text(selection.label),
          );
        },
      );
    }

    return selections.map<Widget>(buildSelection).toList();
  }

  static Map<MenuSerializableShortcut, Intent> shortcuts(
    List<MenuEntry> selections,
  ) {
    final Map<MenuSerializableShortcut, Intent> result =
        <MenuSerializableShortcut, Intent>{};
    for (final MenuEntry selection in selections) {
      if (selection.menuChildren != null) {
        result.addAll(MenuEntry.shortcuts(selection.menuChildren!));
      } else {
        if (selection.shortcut != null && selection.onPressed != null) {
          result[selection.shortcut!] = VoidCallbackIntent(
            selection.onPressed!,
          );
        }
      }
    }
    return result;
  }
}

class NonMacMenuBar extends StatefulWidget {
  const NonMacMenuBar();

  @override
  State<NonMacMenuBar> createState() => _NonMacMenuBarState();
}

class _NonMacMenuBarState extends State<NonMacMenuBar> {
  @override
  Widget build(BuildContext context) {
    return Consumer3<OverviewData, HitLists, FileData>(
      builder: (context, overview, hitLists, filedata, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Expanded(child: MenuBar(children: MenuEntry.build(_getMenus()))),
          ],
        );
      },
    );
  }

  List<MenuEntry> _getMenus() {
    return [
      MenuEntry(
        label: 'File',
        menuChildren: [
          MenuEntry(
            label: 'About',
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: 'HMMot: The HMMer Observation Tool',
                applicationVersion: '0.0.1',
              );
            },
          ),
          MenuEntry(
            label: 'Select Annotated Database',
            onPressed: () async {
              String? annTemp = await FilePicker.platform.getDirectoryPath(
                dialogTitle:
                    "Select directory containing annotated sequence database",
              );
              if (annTemp == null) {
              } else {
                /*setState(() {
                  filedata.setAnnotationsFile(annTemp);
                });*/
              }
            },
          ),
        ],
      ),
    ];
  }
}

//  Top-level application
class TopLevel extends StatelessWidget {
  const TopLevel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<OverviewData, FileData>(
      builder: (context, overview, filedata, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'HMMot',
          theme: _hTheme(),
          initialRoute: '/',
          routes: {
            '/': (context) => const MainPage(),
            '/overview': (context) => const OverviewPage(),
          },
        );
      },
    );
  }
}

// ChangeNotifier for state storage
class OverviewData with ChangeNotifier {
  ResultsOverview _overview = ResultsOverview(
    numHits: 0,
    numCategories: 0,
    categories: [],
    domainsContained: [],
  );

  HashMap<String, (Color, Color)> _domainColors = HashMap();
  int get numHits => _overview.numHits;
  int get numCategories => _overview.numCategories;
  List<SigCategory> get categories => _overview.categories;

  (Color, Color) get_colors(String domain) {
    if (_domainColors.containsKey(domain)) {
      return _domainColors[domain]!;
    } else {
      // Defarut to black-and-white if we don't have a color for this domain
      // (this should never happen, but just in case)
      final color = (Color(0xff000000), Color(0xffffffff));
      return color;
    }
  }

  void set(ResultsOverview newOverview) {
    _overview = newOverview;
    _domainColors = HashMap();
    var i = 0;
    for (String domain in _overview.domainsContained) {
      if (_domainColors.containsKey(domain)) {
        // should never happen
        continue;
      }
      // Get the next color from the list
      final color = domainColors[i % domainColors.length];
      _domainColors[domain] = color;
      i++;
    }
    notifyListeners();
  }

  void clear() {
    _overview = ResultsOverview(
      numHits: 0,
      numCategories: 0,
      categories: [],
      domainsContained: [],
    );
    notifyListeners();
  }
}

// ChangeNotifier for input files
class FileData with ChangeNotifier {
  String _annotationsFile = "";
  List<String> _domtbloutFiles = [];
  bool _annFileSet = false;
  bool _domtbloutFilesSet = false;

  String get annotationsFile => _annotationsFile;
  List<String> get domtbloutFiles => _domtbloutFiles;
  bool get annFileSet => _annFileSet;
  bool get domtbloutFilesSet => _domtbloutFilesSet;
  // Don't notify listners after these functions,
  // because we want to make all changes, then trigger a load
  void setAnnotationsFile(String newAnnotations) {
    _annotationsFile = newAnnotations;
    _annFileSet = true;
    notifyListeners();
  }

  void addDomtbloutFile(String domtblout) {
    _domtbloutFiles.add(domtblout);
    _domtbloutFilesSet = true;
    notifyListeners();
  }

  void clearDomtbloutFiles() {
    _domtbloutFiles = [];
    _domtbloutFilesSet = false;
    notifyListeners();
  }

  // Notify listeners once we've made all changes.
  void triggerLoad() {
    notifyListeners();
  }
}

//ChangeNotifier for hit lists
class HitLists with ChangeNotifier {
  List<HitList> _hitLists = [];

  List<HitList> get hitLists => _hitLists;

  void clear() {
    _hitLists = [];
    notifyListeners();
  }

  void set(int which, HitList newHitList) {
    assert(which < _hitLists.length);
    _hitLists[which] = newHitList;
    notifyListeners();
  }

  void init(int numHitLists) {
    for (var q = 0; q < numHitLists; q++) {
      HitList newHit = HitList(numHits: 0, signature: "", hits: []);
      _hitLists.add(newHit);
    }
    notifyListeners();
  }
}

//Widget to draw the data for a hit
class DrawHit extends StatefulWidget {
  const DrawHit({super.key, required this.hit, required this.overview});
  final Hit hit;
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
    return DrawDomains(
      sequence: widget.hit.sequence,
      domains: widget.hit.structureDomains,
      width: width,
      queries: widget.hit.queries,
      overview: widget.overview,
    );
  }
}

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
    return Container(
      child: CustomPaint(
        size: Size(
          width,
          _calc_text_dimensions(Theme.of(context).textTheme).$2 * 2.2,
        ),
        painter: DomainPainter(
          domains: domains,
          totalWidth: width,
          widthPerChar:
              (width - _calc_text_dimensions(Theme.of(context).textTheme).$1) /
              sequence.length,
          widthOffset: _calc_text_dimensions(Theme.of(context).textTheme).$1,
          heightPerLine: _calc_text_dimensions(Theme.of(context).textTheme).$2,
          queries: queries,
          overview: overview,
          textTheme: Theme.of(context).textTheme,
          colorScheme: Theme.of(context).colorScheme,
        ),
      ),
    );
  }
}

class DomainPainter extends CustomPainter {
  final List<Domain> domains;
  final double totalWidth;
  final double widthPerChar;
  final double widthOffset;
  final double heightPerLine;
  final List<Domain> queries;
  final OverviewData overview;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  DomainPainter({
    required this.domains,
    required this.totalWidth,
    required this.widthPerChar,
    required this.widthOffset,
    required this.heightPerLine,
    required this.queries,
    required this.overview,
    required this.textTheme,
    required this.colorScheme,
  });

  void _draw_domain(
    Canvas canvas,
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
      final p1 = Offset(lastEnd, position.dy + (heightPerLine * 0.55));
      final p2 = Offset(start, position.dy + (heightPerLine * 0.55));
      canvas.drawLine(p1, p2, paint..color = Colors.black);
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
      canvas.drawPath(path, paint..color = overview.get_colors(domain.name).$1);
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
        while (painter.width > (width - heightPerLine) && numChars >= 0) {
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
      text: "Queries:",
      style: textTheme.bodyMedium!.copyWith(color: colorScheme.onSurface),
    );

    legendPainter.layout();
    legendPainter.paint(canvas, Offset(0, heightPerLine * 1.2));

    var lastEnd = widthOffset;
    for (final domain in domains) {
      final double start = domain.start * widthPerChar + widthOffset;
      if (start != lastEnd) {
        final p1 = Offset(lastEnd, heightPerLine * 0.55);
        final p2 = Offset(start, heightPerLine * 0.55);
        canvas.drawLine(p1, p2, paint..color = Colors.black);
      }
      final double end = domain.end * widthPerChar + widthOffset;
      lastEnd = end;
      final double domainWidth = end - start;
      _draw_domain(
        canvas,
        paint,
        Offset(start, 0),
        domainWidth,
        heightPerLine,
        lastEnd,
        domain,
        textTheme,
      );
    }
    if (lastEnd < totalWidth) {
      final p1 = Offset(lastEnd, heightPerLine * 0.55);
      final p2 = Offset(totalWidth, heightPerLine * 0.55);
      canvas.drawLine(p1, p2, paint..color = Colors.black);
    }
    // add the representation of the hit(s) to the sequence
    lastEnd = widthOffset;
    for (final query in queries) {
      final double start = query.start * widthPerChar + widthOffset;
      final double end = query.end * widthPerChar + widthOffset;
      final double domainWidth = end - start;
      _draw_domain(
        canvas,
        paint,
        Offset(start, 1.1 * heightPerLine),
        domainWidth,
        heightPerLine,
        lastEnd,
        query,
        textTheme,
      );
      lastEnd = end;
    }
    if (lastEnd < totalWidth) {
      final p1 = Offset(lastEnd, heightPerLine * 1.65);
      final p2 = Offset(totalWidth, heightPerLine * 1.65);
      canvas.drawLine(p1, p2, paint..color = Colors.black);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => DrawHitList(which: which, overview: overview),
              ),
            );
          },
          hoverColor: Colors.green,
          child: Padding(
            padding: EdgeInsets.all(2),
            child: Material(
              elevation: 0.0,
              shadowColor: Colors.black,
              child: Column(
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
                ],
              ),
            ),
          ),
        );
      },
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
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).primaryColor,
          title: Text(
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            "Results Overview",
          ),
          leading: BackButton(color: Theme.of(context).colorScheme.onPrimary),
        ),

        body: Consumer<OverviewData>(
          builder: (context, overview, child) {
            return Column(
              children: [
                Text(
                  "${overview.numHits} hits found, with ${overview.numCategories} different domain signatures.",
                ),
                Expanded(
                  child: Scrollbar(
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
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

//Widget to select annotation data directory
class annDataSelect extends StatefulWidget {
  const annDataSelect({super.key});

  @override
  _annDataSelectState createState() => _annDataSelectState();
}

class _annDataSelectState extends State<annDataSelect> {
  @override
  String _baseAnnPrompt =
      "Select directory containing annotated sequence database";
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
          child: Text(_baseAnnPrompt),
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
  String _dPrompt = "Select .domtblout files";

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
              setState(() {
                filedata._domtbloutFiles =
                    dTemp.paths.map((path) => path!).toList();
                _selected = true;
                filedata.notifyListeners();
              });
            }
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SafeArea(child: NonMacMenuBar()),
          Consumer<FileData>(
            builder: (context, filedata, child) {
              return Text(
                "Annotated Database Selected: ${filedata.annotationsFile}\nDomtblout File(s) Selected: ${filedata.domtbloutFiles.join("\n")}",
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MainPageState_old extends State<MainPage> {
  String? _anntemp = "";
  List<Domain> temp = [];
  FilePickerResult? result; // used in file picker
  String _temp = ""; // used in converting domtblout file input into list
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).primaryColor,
        title: Text(
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
          "HMMot",
        ),
        actions: <Widget>[
          annDataSelect(),
          domTblSelect(),
          Consumer3<OverviewData, HitLists, FileData>(
            builder: (context, overview, hitLists, filedata, child) {
              return ElevatedButton(
                onPressed: () {
                  const loadingSnackBar = SnackBar(
                    duration: Duration(days: 1),
                    backgroundColor: Colors.yellow,
                    content: Center(child: Text("Loading Data")),
                  );

                  ScaffoldMessenger.of(context).showSnackBar(loadingSnackBar);

                  _searchResults = loadData(
                    annfile: filedata._annotationsFile,
                    domtbloutFiles: filedata._domtbloutFiles,
                  );
                  ScaffoldMessenger.of(context).clearSnackBars();
                  if (!_searchResults.succeeded) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        //duration: Duration(days: 1),
                        backgroundColor: Colors.red,
                        content: Center(
                          child: Text("Load Failed: ${_searchResults.errMsg}"),
                        ),
                      ),
                    );
                  } else {
                    overview.set(_searchResults.overview);
                    hitLists.init(_searchResults.overview.numCategories);
                    for (
                      var iter1 = 0;
                      iter1 < _searchResults.overview.numCategories;
                      iter1++
                    ) {
                      hitLists.set(iter1, _searchResults.hitLists[iter1]);
                    }
                    Navigator.pushNamed(context, '/overview');
                  }
                },
                child: const Text("Load Data"),
              );
            },
          ),
        ],
      ),
      body: Consumer<FileData>(
        builder: (context, filedata, child) {
          return Text(
            "Annotated Database Selected: ${filedata.annotationsFile}\nDomtblout File(s) Selected: ${filedata.domtbloutFiles.join("\n")}",
          );
        },
      ),
    );
  }
}

//Widget to display a list of hits
class DrawHitList extends StatefulWidget {
  const DrawHitList({super.key, required this.which, required this.overview});

  final int which;
  final OverviewData overview;
  @override
  State<DrawHitList> createState() => _DrawHitListState();
}

class _DrawHitListState extends State<DrawHitList> {
  final ScrollController _scrollController3 = ScrollController();
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).primaryColor,
          title: Consumer<HitLists>(
            builder: (context, hitLists, child) {
              return Text(
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                "${hitLists.hitLists[widget.which].numHits} hits found with domain structure ${hitLists.hitLists[widget.which].signature}",
              );
            },
          ),
          leading: BackButton(color: Theme.of(context).colorScheme.onPrimary),
        ),
        body: Consumer<HitLists>(
          builder: (context, hitLists, child) {
            return Column(
              children: [
                Expanded(
                  child: Scrollbar(
                    controller: _scrollController3,
                    child: ListView.builder(
                      controller: _scrollController3,
                      itemCount: hitLists.hitLists[widget.which].numHits,
                      itemBuilder: (BuildContext context, int index) {
                        return Container(
                          margin: EdgeInsets.only(bottom: 24),
                          child: Column(
                            children: [
                              Text(
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium!.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                "Sequence: " +
                                    hitLists
                                        .hitLists[widget.which]
                                        .hits[index]
                                        .name +
                                    ", E-Value: " +
                                    hitLists
                                        .hitLists[widget.which]
                                        .hits[index]
                                        .seqEvalue
                                        .toStringAsExponential(4),
                              ),
                              DrawHit(
                                hit:
                                    hitLists.hitLists[widget.which].hits[index],
                                overview: widget.overview,
                              ),
                            ],
                          ),
                        );
                        ;
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Sticking this here in global-land feels gross, but makes the flutter rust bridge happy and not crash.
SearchResults _searchResults = SearchResults(
  succeeded: false,
  errMsg: "",
  overview: ResultsOverview(
    numHits: 0,
    numCategories: 0,
    categories: [],
    domainsContained: [],
  ),
  hitLists: [],
);
