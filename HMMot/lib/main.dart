import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:HMMot/src/rust/api/gather_hits.dart';
import 'package:HMMot/src/rust/frb_generated.dart';
import 'package:HMMot/draw_data.dart';
import 'package:HMMot/pages.dart';
import 'package:HMMot/utility.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import "package:go_router/go_router.dart";
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
  WidgetsFlutterBinding.ensureInitialized();
  final SharedPreferencesAsync prefs = SharedPreferencesAsync();
  String font = await prefs.getString("HMMot_font") ?? "Roboto";
  double evalMax = await prefs.getDouble("HMMot_evalMax") ?? 10.0;
  double domEvalMax = await prefs.getDouble("HMMot_domEvalMAx") ?? 10.0;
  double scale = await prefs.getDouble("HMMot_scale")?? 1.0;
  int mode = await prefs.getInt("HMMot_mode") ?? 3;
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OverviewData()),
        ChangeNotifierProvider(create: (_) => HitLists()),
        ChangeNotifierProvider(create: (_) => FileData()),
        ChangeNotifierProvider(create: (_) => HSettings(prefs, mode, font, scale, evalMax, domEvalMax)),
      ],
      child: TopLevel(),
    ),
  );
}

ColorScheme lightScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff5475b4),
    primary: const Color(0xff5475b4),
    secondary: const Color(0xff9e0142),
    surface: const Color(0xffffffff),
    error: const Color(0xfff46d43),
    onPrimary: const Color(0xffffffff),
    onSecondary: const Color(0xffffffff),
    onSurface: const Color(0xff000000),
    onError: const Color(0xffffffff),
  );

ColorScheme darkScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff5475b4),
    primary: const Color(0xff5475b4),
    secondary: const Color(0xff9e0142),
    surface: const Color(0xff000000),
    error: const Color(0xfff46d43),
    onPrimary: const Color(0xffffffff),
    onSecondary: const Color(0xffffffff),
    onSurface: const Color(0xffffffff),
    onError: const Color(0xff000000),
  );


// Wrapper that selects the correct menu bar for the platform
class MenuWrapper extends StatelessWidget {

  Widget build(BuildContext context) {
    
    return (Platform.isMacOS) ? MacMenu(): TopLevel();
        
        }
}


// Mac menus3
class MacMenu extends StatefulWidget {
  const MacMenu({super.key});

  @override
  State<MacMenu> createState() => _MacMenuBarState();
}

enum QuitResponses{
  quit,
  cancel
}
class _MacMenuBarState extends State<MacMenu> {
  final _router=GoRouter(routes: <RouteBase>[
    GoRoute(path: '/',
    builder: (context, state) => MainPage(),
    ),
    GoRoute(path:'/overview',
     builder:(context, state) => OverviewPage(),),
    GoRoute(path:'/category',
    builder:  (context, state) => const CategoryPage(),),
    GoRoute(path: '/settings',
    builder: (context, state) => const SettingsPage(),),
    GoRoute(path: "/sequence",
    builder: (context, state) => const SequencePage(),),
  ]);
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
            PlatformMenuItem(
              label: 'Quit',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyQ,
                meta: true,
              ),
              
              onSelected: () {
              showDialog(context: context,
                builder: (BuildContext context){
                return AlertDialog(title: const Text("Quit HMMot?"),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  titleTextStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary,),
                  actions: <Widget>[
                    ElevatedButton(
                      style: MenuItemButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.onPrimary,),
                      onPressed: (){exit(0);}, child: Text("Quit",style: TextStyle(color: Theme.of(context).colorScheme.primary,),),),
                    ElevatedButton(
                      style: MenuItemButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.onPrimary,),
                      onPressed:(){Navigator.pop(context,'Cancel');}, child: Text("Cancel", style: TextStyle(color: Theme.of(context).colorScheme.primary,),),),
                    ],
                  );
                },
              );
              },  
            ),
          ],
        ),
      ],

      child: Router.withConfig(config: _router),
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
    return MenuAnchor(
      menuChildren: <Widget>[
        MenuItemButton(
          style: MenuItemButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary,),
          onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: 'HMMot: The HMMer Observation Tool',
                applicationVersion: '0.0.1',
              );
            },
            child: Text("About",
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary,),),
        ),
        MenuItemButton(
            style: MenuItemButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary,),
            onPressed: () {
              showDialog(context: context,
                builder: (BuildContext context){
                return AlertDialog(title: const Text("Quit HMMot?"),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  titleTextStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary,),
                  actions: <Widget>[
                    ElevatedButton(
                      style: MenuItemButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.onPrimary,),
                      onPressed: (){exit(0);}, child: Text("Quit",style: TextStyle(color: Theme.of(context).colorScheme.primary,),),),
                    ElevatedButton(
                      style: MenuItemButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.onPrimary,),
                      onPressed:(){Navigator.pop(context,'Cancel');}, child: Text("Cancel", style: TextStyle(color: Theme.of(context).colorScheme.primary,),),),
                    ],
                  );
                },
              );
            },
            child: Text('Quit HMMot',
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary,),),
          ),
      ],
      builder: (BuildContext context, MenuController controller, Widget? child){
        return IconButton(
          icon: const Icon(Icons.menu), 
          color: Theme.of(context).colorScheme.onPrimary,
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
        );
      }
    );
  }


  List<MenuEntry> _getMenus(BuildContext context) {
    return [
      MenuEntry(
        label: 'Menu',
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
            label: 'Quit HMMot',
            onPressed: () {
              showDialog(context: context,
                builder: (BuildContext context){
                return AlertDialog(title: const Text("Quit HMMot?"),
                  actions: <Widget>[
                    TextButton(onPressed: (){exit(0);}, child: const Text("Quit"),),
                    TextButton( onPressed:(){Navigator.pop(context,'Cancel');}, child: const Text("Cancel"),),
                    ],
                  );
                },
              );
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
    return Consumer<HSettings>(
      builder: (context, hsettings, child) {
        return MaterialApp(
              theme: hsettings.themeData,
              debugShowCheckedModeBanner: false,
              title: 'HMMot',
              home: MacMenu(),
              initialRoute: '/',
              routes: {
                '/main': (context) => const MainPage(),
                '/overview': (context) => const OverviewPage(),
                '/category': (context) => const CategoryPage(),
                '/settings': (context) => const SettingsPage(),
                "/sequence": (context) => const SequencePage(),
              },
            );
      },
    );
  }
}

enum brightModes {
  light,
  dark,
  system,
}
// ChangeNotifier for theme state
class HSettings with ChangeNotifier {

  brightModes _mode = brightModes.light;
  ThemeData? _themeData;

  String _font = "Roboto";
  double _scale = 1.0;
  double _evalMax = 10.0;
  double _domEvalMax = 10.0;
  late SharedPreferencesAsync _prefs; 

  HSettings(SharedPreferencesAsync prefs, int mode, String font, double scale, double evalMax, double domEvalMax){
    _prefs = prefs;
    _font = font;
    _scale = scale;
    _evalMax = evalMax;
    _domEvalMax = domEvalMax;
    switch (mode){
      case 1:
        _mode = brightModes.light;
      case 2:
        _mode = brightModes.dark;
      case 3:
        _mode = brightModes.system;
      default:
        print("Illegal value passed to mode in HSettings");
    } 
  }

  ThemeData _updateTheme() {
    if (_mode == brightModes.light ||
    (_mode == brightModes.system &&  ThemeMode.system == ThemeMode.light)) {
      return ThemeData(
        colorScheme: lightScheme,
        fontFamily: _font,
        textTheme: TextTheme(
          displayLarge: TextStyle(fontSize: 57 * _scale),
          displayMedium: TextStyle(fontSize: 45 * _scale),
          displaySmall: TextStyle(fontSize: 36 * _scale),
          headlineLarge: TextStyle(fontSize: 32 * _scale),
          headlineMedium: TextStyle(fontSize: 28 * _scale),
          headlineSmall: TextStyle(fontSize: 24 * _scale),
          titleLarge: TextStyle(fontSize: 22 * _scale),
          titleMedium: TextStyle(fontSize: 16 * _scale),
          titleSmall: TextStyle(fontSize: 14 * _scale),
          bodyLarge: TextStyle(fontSize: 16 * _scale),
          bodyMedium: TextStyle(fontSize: 14 * _scale),
          bodySmall: TextStyle(fontSize: 12 * _scale),
          labelLarge: TextStyle(fontSize: 14* _scale),
          labelMedium: TextStyle(fontSize: 12 * _scale),
          labelSmall: TextStyle(fontSize: 11 * _scale),
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: lightScheme.surface,
            border: Border.all(
              color: lightScheme.onSurface,
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(4.0),
          ),
        ),
      );
    } else {
      return ThemeData(
        colorScheme: darkScheme,
        fontFamily: _font,
                textTheme: TextTheme(
          displayLarge: TextStyle(fontSize: 57 * _scale),
          displayMedium: TextStyle(fontSize: 45 * _scale),
          displaySmall: TextStyle(fontSize: 36 * _scale),
          headlineLarge: TextStyle(fontSize: 32 * _scale),
          headlineMedium: TextStyle(fontSize: 28 * _scale),
          headlineSmall: TextStyle(fontSize: 24 * _scale),
          titleLarge: TextStyle(fontSize: 22 * _scale),
          titleMedium: TextStyle(fontSize: 16 * _scale),
          titleSmall: TextStyle(fontSize: 14 * _scale),
          bodyLarge: TextStyle(fontSize: 16 * _scale),
          bodyMedium: TextStyle(fontSize: 14 * _scale),
          bodySmall: TextStyle(fontSize: 12 * _scale),
          labelLarge: TextStyle(fontSize: 14* _scale),
          labelMedium: TextStyle(fontSize: 12 * _scale),
          labelSmall: TextStyle(fontSize: 11 * _scale),
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            border: Border.all(
              color: darkScheme.onSurface,
              width: 1.0,
            ),
            color: darkScheme.surface,
            borderRadius: BorderRadius.circular(4.0),
          ),),
      );
    }
  }
  void set mode(brightModes newmode){
    _mode=newmode;
    switch (newmode){
      case brightModes.light:
        _prefs.setInt("HMMot_mode", 1);
      case brightModes.dark:
        _prefs.setInt("HMMot_mode", 2);
      case brightModes.system:
        _prefs.setInt("HMMot_mode", 3);
    }
    notifyListeners();
  }
  void set font(String font) {
    _font = font;
    _prefs.setString("HMMot_font", font);
    notifyListeners();
  }
  void set scale(double scale){
    _scale = scale;
    _prefs.setDouble("HMMot_scale", scale);
    notifyListeners();
  }

  void set evalMax(double newMax){
    _evalMax = newMax;
    _prefs.setDouble("HMMot_evalMax", newMax);
    notifyListeners();
  }

  void set domEvalMax(double newMax){
    _domEvalMax = newMax;
    _prefs.setDouble("HMMot_domEvalMax", newMax);
    notifyListeners();
  }
  
  ThemeData get themeData => _updateTheme();
  double get scale => _scale;
  String get font => _font;
  brightModes get mode => _mode;
  double get evalMax => _evalMax;
  double get domEvalMax => _domEvalMax; 
}

// ChangeNotifier for the search results
class OverviewData with ChangeNotifier {
  ResultsOverview _overview = ResultsOverview(
    numHits: 0,
    numCategories: 0,
    categories: [],
    domainsContained: [],
  );
  bool _overviewLoaded = false;
  bool _categoryLoaded = false;

  HashMap<String, (Color, Color)> _domainColors = HashMap();
  int get numHits => _overview.numHits;
  int get numCategories => _overview.numCategories;
  List<SigCategory> get categories => _overview.categories;
  bool get overviewLoaded => _overviewLoaded;
  bool get categoryLoaded => _categoryLoaded;

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
    _overviewLoaded = true;
    _categoryLoaded = false;
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

  void setCategoryLoaded(bool loaded){
    _categoryLoaded = loaded;
  }
}

// ChangeNotifier for input files
class FileData with ChangeNotifier {
  String _annotationsFile = "";
  List<String> _domtbloutFiles = [];
  bool _annFileSet = false;
  bool _domtbloutFilesSet = false;
  String _annFileDir = ".";
  String _domtbloutFileDir = ".";

  String get annotationsFile => _annotationsFile;
  List<String> get domtbloutFiles => _domtbloutFiles;
  bool get annFileSet => _annFileSet;
  bool get domtbloutFilesSet => _domtbloutFilesSet;
  String get annFileDir => _annFileDir;
  String get domtbloutFileDir => _domtbloutFileDir;
  String get annFilePrompt {
    if (_annotationsFile.isEmpty) {
      return "Select";
    } else {
      return "Change";
    }
  }
  // Don't notify listners after these functions,
  // because we want to make all changes, then trigger a load
  void setAnnotationsFile(String newAnnotations) {
    _annotationsFile = newAnnotations;
    _annFileSet = true;
    var splits = newAnnotations.split('/');
    if(splits.length > 1){
      _annFileDir = splits.getRange(0, splits.length-1).join("/");
    }
    notifyListeners();
  }

  void addDomtbloutFile(String domtblout) {
    _domtbloutFiles.add(domtblout);
    _domtbloutFilesSet = true;
    var splits = domtblout.split('/');
    if(splits.length > 1){
      _domtbloutFileDir = splits.getRange(0, splits.length-1).join("/");
    }
    notifyListeners();
  }

  void clearDomtbloutFiles() {
    _domtbloutFiles = [];
    _domtbloutFilesSet = false;
    notifyListeners();
  }
  void setDomtbloutFile(int which, String domtblout){
    if (which >= 0 && which < _domtbloutFiles.length){
      _domtbloutFiles[which] = domtblout;
    var splits = domtblout.split('/');
    if(splits.length > 1){
      _domtbloutFileDir = splits.getRange(0, splits.length-1).join("/");
    }
      notifyListeners();
    }
  }

  void deleteDomtbloutFile(String domtblout) {
    _domtbloutFiles.remove(domtblout);
    if (_domtbloutFiles.isEmpty) {
      _domtbloutFilesSet = false;
    }
    notifyListeners();
  }

}

//ChangeNotifier for hit lists
class HitLists with ChangeNotifier {
  List<HitList> _hitLists = [];
  int _selected = -1;
  int _sequence = -1;

  int get sequence => _sequence;

  void setSequence(int seq) {
    _sequence = seq;
  }
  List<HitList> get hitLists => _hitLists;
  int get selected => _selected;
  void clear() {
    _hitLists = [];
    notifyListeners();
  }
  void setSelected(int which){
    _selected = which;
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

