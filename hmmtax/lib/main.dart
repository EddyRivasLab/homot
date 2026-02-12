import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:hmmtax/src/rust/api/simple.dart';
import 'package:hmmtax/src/rust/frb_generated.dart';
import 'package:hmmtax/src/rust/api/graph.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import "dart:math";
import 'package:touchable/touchable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:hmmtax/pages.dart';
import 'package:hmmtax/graph_painter.dart';
import 'package:hmmtax/utility.dart';
import "package:go_router/go_router.dart";
import 'dart:io';
import 'dart:collection';
import 'package:matrix4_transform/matrix4_transform.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:patterns_canvas/patterns_canvas.dart';

// List of pairs of background and foregrund colors for displaying
// domains.  Taken from the ColorBrewer example color sets.
// Format is (BGcolor, FG color)

const domainColors = [
  (
    Color(0xFF004949),
    Color(0xffffffff),
    PatternType.dots,
    Color(0xFF004949),
    Color(0xFF000000),
  ),
  (
    Color(0xFF009292),
    Color(0xffffffff),
    PatternType.crosshatch,
    Color(0xFF009292),
    Color(0xFF000000),
  ),
  (
    Color(0xFFFF6DB6),
    Color(0xff000000),
    PatternType.checkers,
    Color(0xFFFF6DB6),
    Color(0xFF000000),
  ),
  (
    Color(0xFFFFB6DB),
    Color(0xff000000),
    PatternType.raindrops,
    Color(0xFFFFB6DB),
    Color(0xFF000000),
  ),
  (
    Color(0xFF490092),
    Color(0xffffffff),
    PatternType.texture,
    Color(0xFF490092),
    Color(0xFF000000),
  ),
  (
    Color(0xFF006DDB),
    Color(0xffffffff),
    PatternType.subtlepatch,
    Color(0xFF006DDB),
    Color(0xFF000000),
  ),
  (
    Color(0xFFB66DFF),
    Color(0xff000000),
    PatternType.horizontalLight,
    Color(0xFFB66DFF),
    Color(0xFF000000),
  ),
  (
    Color(0xFF6DB6FF),
    Color(0xff000000),
    PatternType.verticalLight,
    Color(0xFF6DB6FF),
    Color(0xFF000000),
  ),
  (
    Color(0xFFB6DBFF),
    Color(0xff000000),
    PatternType.diagonalLight,
    Color(0xFFB6DBFF),
    Color(0xFF000000),
  ),
  (
    Color(0xFF920000),
    Color(0xffffffff),
    PatternType.dots,
    Color(0xFF920000),
    Color(0xFF000000),
  ),
  (
    Color(0xFF924900),
    Color(0xffffffff),
    PatternType.crosshatch,
    Color(0xFF924900),
    Color(0xFF000000),
  ),
  (
    Color(0xFFDB6D00),
    Color(0xffffffff),
    PatternType.checkers,
    Color(0xFFDB6D00),
    Color(0xFF000000),
  ),
  (
    Color(0xFF24FF24),
    Color(0xff000000),
    PatternType.raindrops,
    Color(0xFF24FF24),
    Color(0xFF000000),
  ),
  (
    Color(0xFFFFFF6D),
    Color(0xff000000),
    PatternType.texture,
    Color(0xFFFFFF6D),
    Color(0xFF000000),
  ),
];

const domainColorsOld = [
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

const numColors = 8;
const shadesPerColor = 4;

var lightGraphColors = [(Colors.amber[100], Colors.black, "blort")];

var darkGraphColors = [
  (
    Color(0xff009292),
    Color(0xffffffff),
    PatternType.dots,
    Color(0xFF009292),
    Color(0xFF000000),
  ),
  (
    Color(0xaf009292),
    Color(0xffffffff),
    PatternType.crosshatch,
    Color(0xaf009292),
    Color(0xFF000000),
  ),
  (
    Color(0x6F009292),
    Color(0xffffffff),
    PatternType.checkers,
    Color(0x6f009292),
    Color(0xFF000000),
  ),
  (
    Color(0xcF009292),
    Color(0xffffffff),
    PatternType.raindrops,
    Color(0xcf009292),
    Color(0xFF000000),
  ),
  (
    Color(0xFFFF6DB6),
    Color(0xff000000),
    PatternType.crosshatch,
    Color(0xFFFF6DB6),
    Color(0xFF000000),
  ),
  (
    Color(0xaFFF6DB6),
    Color(0xffffffff),
    PatternType.checkers,
    Color(0xaFFF6DB6),
    Color(0xFF000000),
  ),
  (
    Color(0x6FFF6DB6),
    Color(0xffffffff),
    PatternType.raindrops,
    Color(0x6FFF6DB6),
    Color(0xFF000000),
  ),
  (
    Color(0xcFFF6DB6),
    Color(0xffffffff),
    PatternType.texture,
    Color(0xcFFF6DB6),
    Color(0xFF000000),
  ),
  (
    Color(0xFF490092),
    Color(0xffffffff),
    PatternType.checkers,
    Color(0xFF490092),
    Color(0xFF000000),
  ),
  (
    Color(0xAF490092),
    Color(0xffffffff),
    PatternType.raindrops,
    Color(0xAF490092),
    Color(0xFF000000),
  ),
  (
    Color(0x6F490092),
    Color(0xffffffff),
    PatternType.texture,
    Color(0x6F490092),
    Color(0xFF000000),
  ),
  (
    Color(0xCF490092),
    Color(0xffffffff),
    PatternType.subtlepatch,
    Color(0xCF490092),
    Color(0xFF000000),
  ),
  (
    Color(0xFF006DDB),
    Color(0xffffffff),
    PatternType.raindrops,
    Color(0xFF006DDB),
    Color(0xFF000000),
  ),
  (
    Color(0xAF006DDB),
    Color(0xffffffff),
    PatternType.texture,
    Color(0xAF006DDB),
    Color(0xFF000000),
  ),
  (
    Color(0x6F006DDB),
    Color(0xffffffff),
    PatternType.subtlepatch,
    Color(0x6F006DDB),
    Color(0xFF000000),
  ),
  (
    Color(0xcF006DDB),
    Color(0xffffffff),
    PatternType.dots,
    Color(0xcF006DDB),
    Color(0xFF000000),
  ),
  (
    Color(0xFFB66DFF),
    Color(0xff000000),
    PatternType.texture,
    Color(0xFFB66DFF),
    Color(0xFF000000),
  ),
  (
    Color(0xAFB66DFF),
    Color(0xff000000),
    PatternType.subtlepatch,
    Color(0xAFB66DFF),
    Color(0xFF000000),
  ),
  (
    Color(0x6FB66DFF),
    Color(0xffffffff),
    PatternType.dots,
    Color(0x6FB66DFF),
    Color(0xFF000000),
  ),
  (
    Color(0xcFB66DFF),
    Color(0xff000000),
    PatternType.crosshatch,
    Color(0xcFB66DFF),
    Color(0xFF000000),
  ),
  (
    Color(0xFF920000),
    Color(0xffffffff),
    PatternType.subtlepatch,
    Color(0xFF920000),
    Color(0xFF000000),
  ),
  (
    Color(0xAF920000),
    Color(0xffffffff),
    PatternType.dots,
    Color(0xAF920000),
    Color(0xFF000000),
  ),
  (
    Color(0x6F920000),
    Color(0xffffffff),
    PatternType.crosshatch,
    Color(0x6F920000),
    Color(0xFF000000),
  ),
  (
    Color(0xcF920000),
    Color(0xffffffff),
    PatternType.checkers,
    Color(0xcF920000),
    Color(0xFF000000),
  ),
  (
    Color(0xFF24FF24),
    Color(0xff000000),
    PatternType.dots,
    Color(0xFF24FF24),
    Color(0xFF000000),
  ),
  (
    Color(0xAF24FF24),
    Color(0xff000000),
    PatternType.crosshatch,
    Color(0xAF24FF24),
    Color(0xFF000000),
  ),
  (
    Color(0x6F24FF24),
    Color(0xffffffff),
    PatternType.checkers,
    Color(0x6F24FF24),
    Color(0xFF000000),
  ),
  (
    Color(0xcF24FF24),
    Color(0xff000000),
    PatternType.raindrops,
    Color(0xcF24FF24),
    Color(0xFF000000),
  ),
  (
    Color(0xFFFFFF6D),
    Color(0xff000000),
    PatternType.crosshatch,
    Color(0xFFFFFF6D),
    Color(0xFF000000),
  ),
  (
    Color(0xAFFFFFF6D),
    Color(0xff000000),
    PatternType.checkers,
    Color(0xAFFFFFF6D),
    Color(0xFF000000),
  ),
  (
    Color(0x6FFFFFF6D),
    Color(0xff000000),
    PatternType.raindrops,
    Color(0x6FFFFFF6D),
    Color(0xFF000000),
  ),
  (
    Color(0xcFFFFFF6D),
    Color(0xff000000),
    PatternType.texture,
    Color(0xcFFFFFF6D),
    Color(0xFF000000),
  ),
];

var darkGraphColorsOld = [
  (Colors.amber[100], Colors.black),
  (Colors.amber[300], Colors.black),
  (Colors.amber[500], Colors.black),
  (Colors.amber[200], Colors.black),
  (Colors.amber[400], Colors.black),
  (Colors.blue[100], Colors.black),
  (Colors.blue[300], Colors.black),
  (Colors.blue[500], Colors.black),
  (Colors.blue[200], Colors.black),
  (Colors.blue[400], Colors.white),
  (Colors.red[100], Colors.black),
  (Colors.red[300], Colors.black),
  (Colors.red[500], Colors.white),
  (Colors.red[200], Colors.white),
  (Colors.red[400], Colors.white),
  (Colors.purple[100], Colors.black),
  (Colors.purple[300], Colors.black),
  (Colors.purple[500], Colors.white),
  (Colors.purple[200], Colors.white),
  (Colors.purple[400], Colors.white),
  (Colors.green[100], Colors.black),
  (Colors.green[300], Colors.black),
  (Colors.green[500], Colors.black),
  (Colors.green[200], Colors.black),
  (Colors.green[400], Colors.black),
  (Colors.cyan[100], Colors.black),
  (Colors.cyan[300], Colors.black),
  (Colors.cyan[500], Colors.black),
  (Colors.cyan[200], Colors.black),
  (Colors.cyan[400], Colors.black),
  (Colors.orange[100], Colors.black),
  (Colors.orange[300], Colors.black),
  (Colors.orange[500], Colors.black),
  (Colors.orange[200], Colors.black),
  (Colors.orange[400], Colors.black),
  (Colors.pink[100], Colors.black),
  (Colors.pink[300], Colors.black),
  (Colors.pink[500], Colors.white),
  (Colors.pink[200], Colors.white),
  (Colors.pink[400], Colors.white),
  (Colors.teal[100], Colors.black),
  (Colors.teal[300], Colors.black),
  (Colors.teal[500], Colors.black),
  (Colors.teal[200], Colors.white),
  (Colors.teal[400], Colors.white),
];
Future<void> main() async {
  await RustLib.init();
  WidgetsFlutterBinding.ensureInitialized();
  final SharedPreferencesAsync prefs = SharedPreferencesAsync();
  String font = await prefs.getString("Hmmtax_font") ?? "Roboto";
  double evalMax = await prefs.getDouble("Hmmtax_evalMax") ?? 10.0;
  double evalMin = await prefs.getDouble("Hmmtax_evalMin") ?? 0.0;
  double domEvalMax = await prefs.getDouble("Hmmtax_domEvalMAx") ?? 10.0;
  double domEvalMin = await prefs.getDouble("Hmmtax_domEvalMin") ?? 0.0;
  double scale = await prefs.getDouble("Hmmtax_scale") ?? 1.0;
  double lineWidth = await prefs.getDouble("Hmmtax_lineWidth") ?? 2.0;
  int mode = await prefs.getInt("Hmmtax_mode") ?? 3;
  int DataFileType = await prefs.getInt("Hmmtax_datatype") ?? 3;
  bool addPatterns = await prefs.getBool("Hmmtax_patterns") ?? false;
  bool showInterproSuperfamily = await prefs.getBool("Hmmtax_show_superfamily") ?? true;
  bool showInterproFamily = await prefs.getBool("Hmmtax_show_family") ?? true;
  bool showInterproDomain = await prefs.getBool("Hmmtax_show_domain") ?? true;
  bool showInterproRepeat = await prefs.getBool("Hmmtax_show_repeat") ?? true;
  bool showInterproSite = await prefs.getBool("Hmmtax_show_site") ?? true;
  bool showInterproOther = await prefs.getBool("Hmmtax_show_other") ?? true;
  int temp2 = await prefs.getInt("Hmmtax_interpro_show_id_as") ?? 0;
  ShowInterproIdEnum showInterproIDAs;
  switch (temp2) {
    case 0:
      showInterproIDAs = ShowInterproIdEnum.id;
    case 1:
      showInterproIDAs = ShowInterproIdEnum.short_name;
    case 2:
      showInterproIDAs = ShowInterproIdEnum.long_name;
    default:
      showInterproIDAs = ShowInterproIdEnum.id;
  }
  bool temp = await prefs.getBool("Hmmtax_interpro_names_from_pfam") ?? true;
  ShowNamesFrom namesFrom = temp ? ShowNamesFrom.pfam : ShowNamesFrom.interpro;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FileData()),
        ChangeNotifierProvider(create: (_) => GraphData()),
        ChangeNotifierProvider(
          create:
              (_) => HSettings(
                prefs,
                mode,
                font,
                scale,
                evalMax,
                evalMin,
                domEvalMax,
                domEvalMin,
                lineWidth,
                DataFileType,
                addPatterns,
                showInterproSuperfamily,
                showInterproFamily,
                showInterproDomain,
                showInterproRepeat,
                showInterproSite,
                showInterproOther,
                showInterproIDAs,
                namesFrom,
              ),
        ),
        ChangeNotifierProvider(create: (_) => SearchData()),
      ],
      child: TopLevel(),
    ),
  );
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
          title: 'Hmmtax',
          home: MediaQuery.withNoTextScaling(child: MacMenu()),
          initialRoute: '/',
          routes: {
            '/main': (context) => const MainPage(),
            '/graph': (context) => const GraphPage(),
            '/settings': (context) => const SettingsPage(),
          },
        );
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        // appBar: AppBar(title: const Text('flutter_rust_bridge quickstart')),
        body: Center(child: Text("Hello, world")),
      ),
    );
  }
}

enum brightModes { light, dark, system }
enum GraphDrawType{line, outline, fill}

enum ShowNamesFrom{pfam, interpro}
enum ShowInterproIdEnum{id, short_name, long_name}

// ChangeNotifier for theme state
class HSettings with ChangeNotifier {
  brightModes _mode = brightModes.light;
  DataFileType _dataType = DataFileType.infer;
  ThemeData? _themeData;

  String _font = "Roboto";
  double _scale = 1.0;
  double _evalMax = 10.0;
  double _evalMin = 0.0;
  double _domEvalMax = 10.0;
  double _domEvalMin = 0.0;
  double _lineWidth = 2.0;
  bool _addPatterns = false;
  bool _showInterproSuperfamily = true;
  bool _showInterproFamily = true;
  bool _showInterproDomain = true;
  bool _showInterproRepeat = true;
  bool _showInterproSite = true;
  bool _showInterproOther = true;
  ShowNamesFrom _namesFrom = ShowNamesFrom.pfam;
  ShowInterproIdEnum _showInterproIDAs = ShowInterproIdEnum.id;

  GraphDrawType _drawType = GraphDrawType.line;
  late SharedPreferencesAsync _prefs;
  List<(Color, Color, PatternType, Color, Color)> get graphColors {
    if (_mode == brightModes.light ||
        (_mode == brightModes.system && ThemeMode.system == ThemeMode.light)) {
      return darkGraphColors;
    } else {
      return darkGraphColors;
    }
  }

  HSettings(
    SharedPreferencesAsync prefs,
    int mode,
    String font,
    double scale,
    double evalMax,
    double evalMin,
    double domEvalMax,
    double domEvalMin,
    double lineWidth,
    int dataType,
    bool addPatterns,
    bool showInterproSuperfamily,
    bool showInterproFamily,
    bool showInterproDomain,
    bool showInterproRepeat,
    bool showInterproSite,
    bool showInterproOther,
    ShowInterproIdEnum showInterproIDAs,
    ShowNamesFrom namesFrom,

  ) {
    _prefs = prefs;
    _font = font;
    _scale = scale;
    _evalMax = evalMax;
    _evalMin = evalMin;
    _domEvalMax = domEvalMax;
    _domEvalMin = domEvalMin;
    _lineWidth = lineWidth;
    _addPatterns = addPatterns;
    _showInterproSuperfamily = showInterproSuperfamily;
    _showInterproDomain = showInterproDomain;
    _showInterproFamily = showInterproFamily;
    _showInterproRepeat = showInterproRepeat; 
    _showInterproSite = showInterproSite; 
    _showInterproOther = showInterproOther;
    _showInterproIDAs = showInterproIDAs;
    _namesFrom = namesFrom;

    switch (mode) {
      case 1:
        _mode = brightModes.light;
      case 2:
        _mode = brightModes.dark;
      case 3:
        _mode = brightModes.system;
      default:
        print("Illegal value passed to mode in HSettings");
    }
    switch (dataType) {
      case 1:
        _dataType = DataFileType.domTblOut;
      case 2:
        _dataType = DataFileType.blast;
      case 3:
        _dataType = DataFileType.infer;
      default:
        print("Illegal value passed to dataType in HSettings");
    }
  }

  ThemeData _updateTheme() {
    if (_mode == brightModes.light ||
        (_mode == brightModes.system && ThemeMode.system == ThemeMode.light)) {
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
          labelLarge: TextStyle(fontSize: 14 * _scale),
          labelMedium: TextStyle(fontSize: 12 * _scale),
          labelSmall: TextStyle(fontSize: 11 * _scale),
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: lightScheme.surface,
            border: Border.all(color: lightScheme.onSurface, width: 1.0),
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
          labelLarge: TextStyle(fontSize: 14 * _scale),
          labelMedium: TextStyle(fontSize: 12 * _scale),
          labelSmall: TextStyle(fontSize: 11 * _scale),
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            border: Border.all(color: darkScheme.onSurface, width: 1.0),
            color: darkScheme.surface,
            borderRadius: BorderRadius.circular(4.0),
          ),
        ),
      );
    }
  }

  void set drawType(GraphDrawType newType) {
    _drawType = newType;
    notifyListeners();
  }

  void set mode(brightModes newmode) {
    _mode = newmode;
    switch (newmode) {
      case brightModes.light:
        _prefs.setInt("Hmmtax_mode", 1);
      case brightModes.dark:
        _prefs.setInt("Hmmtax_mode", 2);
      case brightModes.system:
        _prefs.setInt("Hmmtax_mode", 3);
    }
    notifyListeners();
  }

  void set dataType(DataFileType newtype) {
    _dataType = newtype;
    switch (newtype) {
      case DataFileType.domTblOut:
        _prefs.setInt("Hmmtax_datatype", 1);
      case DataFileType.blast:
        _prefs.setInt("Hmmtax_datatype", 2);
      case DataFileType.infer:
        _prefs.setInt("Hmmtax_datatype", 3);
    }
    notifyListeners();
  }

  void set font(String font) {
    _font = font;
    _prefs.setString("Hmmtax_font", font);
    notifyListeners();
  }

  void set scale(double scale) {
    _scale = scale;
    _prefs.setDouble("Hmmtax_scale", scale);
    notifyListeners();
  }

  void set evalMax(double newMax) {
    _evalMax = newMax;
    _prefs.setDouble("Hmmtax_evalMax", newMax);
    notifyListeners();
  }

  void set domEvalMax(double newMax) {
    _domEvalMax = newMax;
    _prefs.setDouble("Hmmtax_domEvalMax", newMax);
    notifyListeners();
  }

  void set evalMin(double newMin) {
    _evalMin = newMin;
    _prefs.setDouble("Hmmtax_evalMin", newMin);
    notifyListeners();
  }

  void set domEvalMin(double newMin) {
    _domEvalMin = newMin;
    _prefs.setDouble("Hmmtax_domEvalMin", newMin);
    notifyListeners();
  }

  void set lineWidth(double newWidth) {
    if (newWidth > 0) {
      _lineWidth = newWidth;
    }
  }

  void set addPatterns(bool val) {
    _addPatterns = val;
    _prefs.setBool("Hmmtax_patterns", val);
    notifyListeners();
  } 
  void set showInterproSuperfamily(bool val) {
    _showInterproSuperfamily = val;
    _prefs.setBool("Hmmtax_show_superfamily", val);
    notifyListeners();
  } 
  void set showInterproFamily(bool val) {
    _showInterproFamily = val;
    _prefs.setBool("Hmmtax_show_family", val);
    notifyListeners();
  }
  void set showInterproDomain(bool val) {
    _showInterproDomain = val;
    _prefs.setBool("Hmmtax_show_domain", val);
    notifyListeners();
  }
  void set showInterproRepeat(bool val) {
    _showInterproRepeat = val;
    _prefs.setBool("Hmmtax_show_repeat", val);
    notifyListeners();
  }
  void set showInterproSite(bool val) {
    _showInterproSite = val;
    _prefs.setBool("Hmmtax_show_site", val);
    notifyListeners();
  }
  void set showInterproOther(bool val) {
    _showInterproOther = val;
    _prefs.setBool("Hmmtax_show_other", val);
    notifyListeners();
  }

  void set showInterproIdAs(ShowInterproIdEnum val) {
    _showInterproIDAs = val;
    _prefs.setInt("Hmmtax_interpro_show_id_as", val.index);
    notifyListeners();
  }
  void set showNamesFrom(ShowNamesFrom val){
    _namesFrom = val;
    if (val == ShowNamesFrom.pfam){
      _prefs.setBool("Hmmtax_interpro_names_from_pfam", true);
    } else {
      _prefs.setBool("Hmmtax_interpro_names_from_pfam", false);
    }     
    notifyListeners();
  }
  ThemeData get themeData => _updateTheme();
  double get scale => _scale;
  String get font => _font;
  brightModes get mode => _mode;
  double get evalMax => _evalMax;
  double get domEvalMax => _domEvalMax;
  double get evalMin => _evalMin;
  double get domEvalMin => _domEvalMin;
  double get lineWidth => _lineWidth;
  DataFileType get dataType => _dataType;
  bool get addPatterns => _addPatterns;
  bool get showInterproSuperfamily => _showInterproSuperfamily;
  bool get showInterproFamily => _showInterproFamily;
  bool get showInterproDomain => _showInterproDomain;
  bool get showInterproRepeat => _showInterproRepeat;
  bool get showInterproSite => _showInterproSite;
  bool get showInterproOther => _showInterproOther;
  ShowInterproIdEnum get showInterproIdAs => _showInterproIDAs;
  ShowNamesFrom get showNamesFrom => _namesFrom;

  GraphDrawType get drawType => _drawType;
}

// ChangeNotifier for graph data
class GraphData with ChangeNotifier {
  PlatformInt64 _graphRoot =
      -1; // This is the root node of the entire graph, not the root of the part that's displayed
  Map<PlatformInt64, Node> _graph = {};
  PlatformInt64 _currentRoot = -1; // root of the subgraph we're showing
  List<PlatformInt64> _history = [];
  List<String> _historyNames = [];
  int _historyIndex = 0;
  int _maxLevels = 0; // how many levels of the graph to show
  int _depth = 0; // depth of graph, extract from data eventually
  bool _graphSet = false;
  double _rotation = 0.0;
  double _translateX = 0.0;
  double _translateY = 0.0;
  double _scale = 1.0;
  double _radPerLevel = 0.0;
  double _rootRadius = 0.0;
  Size _size = Size.zero;
  Matrix4 _transform = Matrix4.identity();
  TrackRegions _trackRegions = TrackRegions(
    0,
  ); // Data structure to track regions of the graph on screen
  List<PlatformInt64> _deletedNodes = [];

  List<PlatformInt64> get deletedNodes => _deletedNodes;

  TrackRegions get trackRegions => _trackRegions;
  final TransformationController _tController = TransformationController();
  final ItemScrollController _sController = ItemScrollController();

  ItemScrollController get itemScrollController => _sController;
  TransformationController get tController => _tController;
  double get radPerLevel => _radPerLevel;
  set radPerLevel(double rad) {
    _radPerLevel = rad;
  }

  void updateTransform() {
    Matrix4Transform m4t = Matrix4Transform();
    m4t = m4t.scale(_scale, origin: Offset(_size.width / 2, _size.height / 2));
    m4t = m4t.rotateByCenter(_rotation, _size);
    m4t = m4t.translate(x: _translateX * _scale, y: _translateY * _scale);
    _transform = m4t.matrix4;
    notifyListeners();
  }

  set transform(Matrix4 newTransform) {
    _transform = newTransform;
    notifyListeners();
  }

  set size(Size newSize) {
    _size = newSize;
  }

  String historyNames(int index) {
    if (index >= 0 && index < _historyNames.length) {
      return _historyNames[index];
    } else {
      return "None";
    }
  }

  int history(int index) {
    if (index >= 0 && index < _history.length) {
      return _history[index];
    } else {
      return -1;
    }
  }

  void setHistoryIndex(int newIndex) {
    if (newIndex >= 0 && newIndex < _history.length) {
      _historyIndex = newIndex;
      if (_sController.isAttached) {
        _sController.jumpTo(index: _historyIndex, alignment: 0.5);
      }
    }
  }

  int get historyLength => _history.length;
  int get historyIndex => _historyIndex;
  Size get size => _size;
  Matrix4 get transform => _transform;
  double get translateX => _translateX;
  double get translateY => _translateY;
  double get scale => _scale;
  double get rootRadius => rootRadius;
  set rootRadius(double rad) {
    _rootRadius = rad;
  }

  void set translateX(double x) {
    _translateX = x;
    updateTransform();
  }

  void set translateY(double y) {
    _translateY = y;
    updateTransform();
  }

  void set scale(double s) {
    _scale = s;
    updateTransform();
  }

  void set trackRegions(TrackRegions tr) {
    _trackRegions = tr;
  }

  void clearRegions() {
    _trackRegions = TrackRegions(0);
  }

  void addRegion(int level, Region region) {
    _trackRegions.addRegion(level, region);
  }

  PlatformInt64 findNode(
    double xPos,
    double yPos,
    double centerX,
    double centerY,
  ) {
    return _trackRegions.findNode(
      xPos,
      yPos,
      centerX,
      centerY,
      _radPerLevel,
      _rootRadius,
    );
  }

  Map<PlatformInt64, Node> get graph => _graph;

  bool get graphSet => _graphSet;
  PlatformInt64 get graphRoot => _graphRoot;
  PlatformInt64 get currentRoot => _currentRoot;

  int get maxLevels => _maxLevels;
  int get depth => _depth;
  double get rotation => _rotation;
  void setGraph(Map<PlatformInt64, Node> newGraph) {
    _graph = newGraph;
    _graphSet = true;
    notifyListeners();
  }

  void clearGraph() {
    _history = [];
    _historyNames = [];
    _historyIndex = -1;
    _graphSet = false;
    _rotation = 0.0;
    _translateX = 0.0;
    _translateY = 0.0;
    _scale = 1.0;
    _transform = Matrix4.identity();
    _tController.value = Matrix4.identity();
    _trackRegions = TrackRegions(0);
    _graphRoot = 0;
    _currentRoot = 0;
    _depth = 0;
    _maxLevels = 0;
    notifyListeners();
  }

  Node getNode(PlatformInt64 nodeId) {
    return _graph[nodeId]!;
  }

  void addRoot(PlatformInt64 newRoot) {
    if (_graph.containsKey(newRoot)) {
      _currentRoot = newRoot;
      _history.add(newRoot);
      _historyNames.add(_graph[newRoot]!.name);
      _historyIndex += 1;
      if (_sController.isAttached) {
        _sController.jumpTo(index: _historyIndex, alignment: 0.5);
      }
      notifyListeners();
    }
  }

  void setRoot(PlatformInt64 newRoot) {
    if (_graph.containsKey(newRoot)) {
      _currentRoot = newRoot;
      notifyListeners();
    }
  }

  void set graphRoot(PlatformInt64 newRoot) {
    if (_graph.containsKey(newRoot)) {
      _graphRoot = newRoot;
      notifyListeners();
    }
  }

  void deleteNode(PlatformInt64 nodeId) {
    if (!_graph.containsKey(nodeId) || _deletedNodes.contains(nodeId)) {
      // node either doesn't exist or was already deleted
      return;
    }
    Node nodeToDelete = _graph[nodeId]!;
    Node parentNode = _graph[nodeToDelete.parent]!;
    _deletedNodes.add(nodeId); // Record that we've deleted this node

    // Need to remove nodeId from parent's children
    // This is really ugly, but is necessary because we keep the children
    // as an Int64List for efficiency, which is not growable.
    List<BigInt> growableList = parentNode.children.toList();
    growableList.remove(BigInt.from(nodeId));
    parentNode.children = Int64List.fromList(
      growableList.map((e) => e.toInt()).toList(),
    );
    var removedHits = nodeToDelete.hitsBelow;
    // Now need to update hitsBelow for fromNode and all its parents
    parentNode.hitsBelow -= removedHits;
    while (parentNode.parent != parentNode.taxid) {
      // Node with itself as parent is root
      BigInt childId = BigInt.from(parentNode.taxid);
      parentNode = _graph[parentNode.parent]!;
      List<BigInt> listCopy =
          parentNode.children
              .toList(); //horrible hack because of type issues comparing to contents of int64List
      if (listCopy.contains(childId)) {
        // child wasn't removed from graph
        parentNode.hitsBelow -= removedHits;
      } else {
        break; // parent chain broken, stop updating
      }
    }
    /* if(parentNode.parent == parentNode.taxid){
        // we made it to the root of the graph, need to handle the root node
        parentNode.hitsBelow -= removedHits;
      }*/
    notifyListeners();
  }

  PlatformInt64 restoreNode(PlatformInt64 nodeId) {
    if (!_graph.containsKey(nodeId) || !_deletedNodes.contains(nodeId)) {
      // node either doesn't exist or wasn't deleted
      print("Unable to delete node");
      return -2;
    }
    Node nodeToRestore = _graph[nodeId]!;
    Node parentNode = _graph[nodeToRestore.parent]!;
    //print("Restored nodes parent was ${nodeToRestore.parent}, ${parentNode.name}");
    // Need to add nodeId back to parent's children
    // This is really ugly, but is necessary because we keep the children
    // as an Int64List for efficiency, which is not growable.
    List<BigInt> growableList = parentNode.children.toList();
    //print(growableList);
    growableList.add(BigInt.from(nodeId));
    //print(growableList);
    parentNode.children = Int64List.fromList(
      growableList.map((e) => e.toInt()).toList(),
    );
    //print("${parentNode.children}");
    var restoredHits = nodeToRestore.hitsBelow;
    // Now need to update hitsBelow for fromNode and all its parents
    parentNode.hitsBelow += restoredHits;
    while (parentNode.parent != parentNode.taxid) {
      // Node with itself as parent is root
      BigInt childId = BigInt.from(parentNode.taxid);
      parentNode = _graph[parentNode.parent]!;
      List<BigInt> listCopy =
          parentNode.children
              .toList(); //horrible hack because of type issues comparing to contents of int64List
      if (listCopy.contains(childId)) {
        // child wasn't removed from graph
        parentNode.hitsBelow += restoredHits;
      } else {
        //print("Exiting early because ${parentNode.children} didn't contain ${childId} at node ${parentNode.taxid}");
        _deletedNodes.remove(nodeId);
        notifyListeners();
        return parentNode
            .taxid; // return the nodId of the first parent that was deleted
      }
    }
    //print(_deletedNodes);
    _deletedNodes.remove(nodeId); // Record that we've restored this node
    //print(_deletedNodes);
    notifyListeners();
    return -1; // -1 is an unusual success value, but we never use negative taxids
  }

  void clearDeletedNodes() {
    _deletedNodes = [];
  }

  void incrementIndex() {
    if (_historyIndex < _history.length - 1) {
      // There's history to go forward through
      _historyIndex += 1;
      setRoot(_history[_historyIndex]);
      if (_sController.isAttached) {
        _sController.jumpTo(index: _historyIndex, alignment: 0.5);
      }
    }
  }

  void decrementIndex() {
    if (_historyIndex > 0) {
      // There's history to go back through
      _historyIndex -= 1;
      setRoot(_history[_historyIndex]);
      if (_sController.isAttached) {
        _sController.jumpTo(index: _historyIndex, alignment: 0.5);
      }
    }
  }

  // removes elements of the history that are past the current pointer so that we
  // can go deeper
  void popPastIndex() {
    if (_history.length == 0 || _historyIndex < 0) {
      // nothing to pop
      return;
    }
    var numPops =
        (_history.length - _historyIndex) -
        1; // need the -1 because of zero-index arrays
    while (numPops > 0) {
      _history.removeLast();
      _historyNames.removeLast();
      numPops -= 1;
    }
    notifyListeners();
  }

  void setDepth(int newDepth) {
    if (newDepth > 0) {
      _depth = newDepth;
      notifyListeners();
    }
  }

  void setMaxLevels(int newMaxLevels) {
    if (newMaxLevels > 0) {
      _maxLevels = newMaxLevels;
      notifyListeners();
    }
  }

  void pushHistory(PlatformInt64 node) {
    _history.add(node);
    notifyListeners();
  }

  void setRotation(double newRotation) {
    if (newRotation > 0 && newRotation <= 2 * pi) {
      _rotation = newRotation;
      updateTransform();
    }
  }

  PlatformInt64 popHistory() {
    if (_history.isNotEmpty) {
      PlatformInt64 last = _history.removeLast();
      notifyListeners();
      return last;
    } else {
      return _graphRoot;
    }
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
  String _exportFile = "";
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

  String get exportFile => _exportFile;
  void set exportFile(String newExportFile) {
    _exportFile = newExportFile;
    notifyListeners();
  }

  // Don't notify listeners after these functions,
  // because we want to make all changes, then trigger a load
  void setAnnotationsFile(String newAnnotations) {
    _annotationsFile = newAnnotations;
    _annFileSet = true;
    var splits = newAnnotations.split('/');
    if (splits.length > 1) {
      _annFileDir = splits.getRange(0, splits.length - 1).join("/");
    }
    notifyListeners();
  }

  void addDomtbloutFile(String domtblout) {
    _domtbloutFiles.add(domtblout);
    _domtbloutFilesSet = true;
    var splits = domtblout.split('/');
    if (splits.length > 1) {
      _domtbloutFileDir = splits.getRange(0, splits.length - 1).join("/");
    }
    notifyListeners();
  }

  void clearDomtbloutFiles() {
    _domtbloutFiles = [];
    _domtbloutFilesSet = false;
    notifyListeners();
  }

  void setDomtbloutFile(int which, String domtblout) {
    if (which >= 0 && which < _domtbloutFiles.length) {
      _domtbloutFiles[which] = domtblout;
      var splits = domtblout.split('/');
      if (splits.length > 1) {
        _domtbloutFileDir = splits.getRange(0, splits.length - 1).join("/");
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

  void exportCurrentPage(String currentpage, SearchData searchdata, bool pfamNames, bool showInterproSuperfamily, bool showInterproFamily, bool showInterproDomain,
   bool showInterproRepeat, bool showInterproSite, bool showInterproOther, BuildContext context) async {
    var outFile = File(_exportFile);
    var outSink = outFile.openWrite(mode: FileMode.write);
    switch(currentpage){
      case "/allstructure":
        _exportAllStructure(searchdata, pfamNames, showInterproSuperfamily, showInterproFamily, showInterproDomain, showInterproRepeat, showInterproSite,
         showInterproOther, outSink);
        break;
      case "/subtreestructure":
        _exportSubtreeStructure(searchdata, pfamNames, showInterproSuperfamily, showInterproFamily, showInterproDomain, showInterproRepeat, showInterproSite,
         showInterproOther, outSink);
        break;
      case "/allevalue":
        _exportAllEval(searchdata, pfamNames, showInterproSuperfamily, showInterproFamily, showInterproDomain, showInterproRepeat, showInterproSite,
         showInterproOther, outSink);
        break;
      case "/subtreeevalue":
        _exportSubtreeEval(searchdata, pfamNames, showInterproSuperfamily, showInterproFamily, showInterproDomain, showInterproRepeat, showInterproSite,
         showInterproOther, outSink);
        break;
      case "/sequence":
        _exportSequence(searchdata.hits[searchdata.selectedHit.toInt()], pfamNames, showInterproSuperfamily, showInterproFamily, showInterproDomain, showInterproRepeat, showInterproSite,
         showInterproOther, outSink);
        break;
      default:
        outSink.writeln("No data to export");
    }
    try{
      await outSink.flush();
      await outSink.close();
    } catch (e){
      showDialog(context: context, builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Unable to Export Data"),
          backgroundColor: Theme.of(context).colorScheme.error,
          titleTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.onError,
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
          ),
          content: Text("Error was: $e"),
          contentTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.onError,
            fontSize: 16.0,
          ),
          actions: [
            ElevatedButton(
              style: MenuItemButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.onError,
            ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(style: TextStyle(color: Theme.of(context).colorScheme.error),
              "OK"),
            ),
          ],
        );
      });
    } 
  }

  String _header(){
    return "Format: SeqEvalue, HitName, (QueryName, QueryStart, QueryEnd)*, ANNOTATIONS:, (DomainName, DomainEvalue, DomainStart, DomainEnd)*";
  }

  void _exportAllStructure(SearchData searchdata, bool pfamNames, bool showInterproSuperfamily, bool showInterproFamily, bool showInterproDomain,
   bool showInterproRepeat, bool showInterproSite, bool showInterproOther, IOSink outSink){
    outSink.writeln(_header());
    for (var category in searchdata.rootHits){
      _exportCategory(category, searchdata, pfamNames, showInterproSuperfamily, showInterproFamily, showInterproDomain, showInterproRepeat, showInterproSite,
         showInterproOther, outSink);
      outSink.writeln(""); // blank line between categories
    }
  }
  void _exportSubtreeStructure(SearchData searchdata, bool pfamNames, bool showInterproSuperfamily, bool showInterproFamily, bool showInterproDomain,
   bool showInterproRepeat, bool showInterproSite, bool showInterproOther, IOSink outSink){
    outSink.writeln(_header());
    for (var category in searchdata.currentHits){
      _exportCategory(category, searchdata, pfamNames, showInterproSuperfamily, showInterproFamily, showInterproDomain, showInterproRepeat, showInterproSite,
         showInterproOther, outSink);
      outSink.writeln(""); // blank line between categories
    }
  }

  void _exportAllEval(SearchData searchdata, bool pfamNames, bool showInterproSuperfamily, bool showInterproFamily, bool showInterproDomain,
   bool showInterproRepeat, bool showInterproSite, bool showInterproOther, IOSink outSink){
    outSink.writeln(_header());
    for (var hit in searchdata.hits){
      _exportHit(hit, pfamNames, showInterproSuperfamily, showInterproFamily, showInterproDomain, showInterproRepeat, showInterproSite,
         showInterproOther, outSink);
    }
  }
void _exportSubtreeEval(SearchData searchdata, bool pfamNames, bool showInterproSuperfamily, bool showInterproFamily, bool showInterproDomain,
   bool showInterproRepeat, bool showInterproSite, bool showInterproOther, IOSink outSink){
    outSink.writeln(_header());
    Int64List hitIndices = Int64List(0);
    switch (searchdata.selectedBy) {
      case selectedby.subtree:
        hitIndices = searchdata.currentHitsByEvalue;
        break;
      case selectedby.subtree_structure:
        hitIndices = searchdata.currentHits[searchdata.selectedStructure].hits;
        break;
      case selectedby.structure:
        hitIndices = searchdata.rootHits[searchdata.selectedStructure].hits;
        break;
      default:
        hitIndices = Int64List(0);
          }
    for (var hitIndex in hitIndices){
      _exportHit(searchdata.hits[hitIndex.toInt()], pfamNames, showInterproSuperfamily, showInterproFamily, showInterproDomain, showInterproRepeat, showInterproSite,
         showInterproOther, outSink);
    }
  }

  void _exportCategory(SigCategory category, SearchData searchdata, bool pfamNames, bool showInterproSuperfamily, bool showInterproFamily, bool showInterproDomain,
   bool showInterproRepeat, bool showInterproSite, bool showInterproOther, IOSink outSink){
    var outString = "${category.hits.length} Hits with Signature ${searchdata.structures[category.signature]}";
    outSink.writeln(outString);

    for (var hit in category.hits)
    { var theHit = searchdata.hits[hit.toInt()];
      _exportHit(theHit, pfamNames, showInterproSuperfamily, showInterproFamily, showInterproDomain, showInterproRepeat, showInterproSite,
         showInterproOther,outSink); 
    }
  }

  void _exportHit(Hit hit, bool pfamNames, bool showInterproSuperfamily, bool showInterproFamily, bool showInterproDomain,
   bool showInterproRepeat, bool showInterproSite, bool showInterproOther,IOSink outSink){
   var outString = "${hit.seqEvalue},${hit.name}";
   for (var query in hit.queries){
      outString += ", ${query.name}, ${query.seqStart}, ${query.seqEnd}";
   }
    outString +=", ANNOTATIONS:";
   for (var domain in hit.structureDomains){
    if (domain.source != AnnotationType.interpro || (domain.iType == IEntryType.superfamily && showInterproSuperfamily) ||
     (domain.iType == IEntryType.family && showInterproFamily) || (domain.iType == IEntryType.domain && showInterproDomain) || 
     (domain.iType == IEntryType.repeat && showInterproRepeat) || (domain.iType == IEntryType.site && showInterproSite) || 
     (domain.iType == IEntryType.other && showInterproOther)){
      if(domain.source == AnnotationType.interpro &&pfamNames && domain.pfamName.isNotEmpty){
        outString += ", ${domain.pfamName}";
      } else {
        outString += ", ${domain.name}";
      }
      outString += ", ${domain.domEvalue}, ${domain.seqStart}, ${domain.seqEnd}";
     }
   }
   outSink.writeln(outString);
  }
}
  void _exportSequence(Hit hit, bool pfamNames, bool showInterproSuperfamily, bool showInterproFamily, bool showInterproDomain,
   bool showInterproRepeat, bool showInterproSite, bool showInterproOther,IOSink outSink){
   var outString = "${hit.seqEvalue},${hit.name}";
   for (var query in hit.queries){
      outString += ", ${query.name}, ${query.seqStart}, ${query.seqEnd}";
   }
    outString +=", ANNOTATIONS:";
   for (var domain in hit.domains){
    if (domain.source != AnnotationType.interpro || (domain.iType == IEntryType.superfamily && showInterproSuperfamily) ||
     (domain.iType == IEntryType.family && showInterproFamily) || (domain.iType == IEntryType.domain && showInterproDomain) || 
     (domain.iType == IEntryType.repeat && showInterproRepeat) || (domain.iType == IEntryType.site && showInterproSite) || 
     (domain.iType == IEntryType.other && showInterproOther)){
      if(domain.source == AnnotationType.interpro &&pfamNames && domain.pfamName.isNotEmpty){
        outString += ", ${domain.pfamName}";
      } else {
        outString += ", ${domain.name}";
      }
      outString += ", ${domain.domEvalue}, ${domain.seqStart}, ${domain.seqEnd}";
     }
   }
   outSink.writeln(outString);
  }
// Wrapper that selects the correct menu bar for the platform
class MenuWrapper extends StatelessWidget {
  Widget build(BuildContext context) {
    return (Platform.isMacOS) ? MacMenu() : TopLevel();
  }
}

// about dialog function
void showMyAboutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Theme(
        data: Theme.of(context).copyWith(
          dialogTheme: DialogThemeData(
            backgroundColor: Theme.of(context).colorScheme.onPrimary,
            titleTextStyle: Theme.of(context).textTheme.titleLarge!.copyWith(
              color: Theme.of(context).colorScheme.primary,
              //contentsTextStyle: Theme.of(context).textTheme.titleLarge!
              //    .copyWith(color: Theme.of(context).colorScheme.onPrimary),
            ),
          ),
        ),
        child: SimpleDialog(
          title: const Text("About Hmmtax"),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Version 0.1.0\n",
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                FilledButton(
                  onPressed: () {
                    showLicensePage(
                      context: context,
                      applicationName: "Hmmtax",
                    );
                  },
                  child: Text(
                    "Show Licenses",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    "Close",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

// Mac menus3
class MacMenu extends StatefulWidget {
  const MacMenu({super.key});

  @override
  State<MacMenu> createState() => _MacMenuBarState();
}

enum QuitResponses { quit, cancel }

class _MacMenuBarState extends State<MacMenu> {
  final _router = GoRouter(
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (context, state) => MainPage()),
      GoRoute(path: '/settings', builder: (context, state) => SettingsPage()),
      GoRoute(path: '/graph', builder: (context, state) => GraphPage()),
      GoRoute(
        path: '/allstructure',
        builder: (context, state) => AllStructurePage(),
      ),
      GoRoute(
        path: '/subtreestructure',
        builder: (context, state) => SubtreeStructurePage(),
      ),
      GoRoute(
        path: '/subtreeevalue',
        builder: (context, state) => SubtreeEvaluePage(key: UniqueKey()),
      ),
      GoRoute(path: '/allevalue', builder: (context, state) => AllEvaluePage()),
      GoRoute(path: '/sequence', builder: (context, state) => SequencePage()),
    ],
  );
  Widget build(BuildContext context) {
    final currentLocation =
        _router.routerDelegate.currentConfiguration.uri.toString();
    return PlatformMenuBar(
      menus: <PlatformMenuItem>[
        PlatformMenu(
          label: 'Hmmtax',
          menus: <PlatformMenuItem>[
            PlatformMenuItem(
              label: "About Hmmtax",
              onSelected: () {
                showMyAboutDialog(context);
              },
            ),
            PlatformMenuItem(
              label: 'Quit',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyQ,
                meta: true,
              ),

              onSelected: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text("Quit Hmmtax?"),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      titleTextStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      actions: <Widget>[
                        ElevatedButton(
                          style: MenuItemButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                          ),
                          onPressed: () {
                            exit(0);
                          },
                          child: Text(
                            "Quit",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          style: MenuItemButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                          ),
                          onPressed: () {
                            Navigator.pop(context, 'Cancel');
                          },
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
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
      return Consumer<FileData>(
        builder: (context, filedata, child) {
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
    final currentLocation =
        GoRouter.of(context).routerDelegate.currentConfiguration.uri.toString();
    return MenuAnchor(
      menuChildren: <Widget>[
        MenuItemButton(
          style: MenuItemButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          onPressed: () {
            showMyAboutDialog(context);
          },
          child: Text(
            "About",
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ),
        if (currentLocation != '/' &&
            currentLocation != '/settings' &&
            currentLocation != "/graph")
          MenuItemButton(
            style: MenuItemButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () {
              showExportDialog(context);
            },
            child: Text(
              "Export Page Contents to CSV",
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        MenuItemButton(
          style: MenuItemButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          onPressed: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text("Quit Hmmtax?"),
                  backgroundColor: Theme.of(context).colorScheme.onPrimary,
                  titleTextStyle: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  actions: <Widget>[
                    ElevatedButton(
                      style: MenuItemButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: () {
                        exit(0);
                      },
                      child: Text(
                        "Quit",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
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
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
          child: Text(
            'Quit Hmmtax',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ],
      builder: (
        BuildContext context,
        MenuController controller,
        Widget? child,
      ) {
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
      },
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
                applicationName: 'Hmmtax: A taxonomy viewer for HMMER',
                applicationVersion: '0.0.1',
              );
            },
          ),
          MenuEntry(
            label: 'Quit Hmmtax',
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text("Quit Hmmtax?"),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () {
                          exit(0);
                        },
                        child: const Text("Quit"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context, 'Cancel');
                        },
                        child: const Text("Cancel"),
                      ),
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

enum selectedby { none, structure, subtree, subtree_structure }

// class that holds the results of a search
class SearchData with ChangeNotifier {
  List<Hit> _hits = [];
  Uint32List _hitStructures = Uint32List(0);
  List<String> _structures = [];
  List<String> _domainsContained = [];
  List<SigCategory> _rootHits = [];
  List<SigCategory> _currentHits = [];
  Int64List _currentHitsByEvalue = Int64List(0);
  bool _resultsLoaded = false;
  bool _currentLoaded = false;
  int _selectedStructure = -1;
  selectedby _selectedBy = selectedby.none;
  selectedby _previousSelectedBy = selectedby.none;
  HashMap<String, (Color, Color, PatternType, Color, Color)> _domainColors =
      HashMap();
  PlatformInt64 _selectedHit = -1;
  selectedby get selectedBy => _selectedBy;
  selectedby get previousSelectedBy => _previousSelectedBy;
  void set selectedBy(selectedby method) {
    _selectedBy = method;
    notifyListeners();
  }

  void set previousSelectedBy(selectedby method) {
    _previousSelectedBy = method;
  }

  PlatformInt64 get selectedHit => _selectedHit;
  List<Hit> get hits => _hits;
  Uint32List get hitStructures => _hitStructures;
  List<String> get structures => _structures;
  List<String> get domainsContained => _domainsContained;
  List<SigCategory> get rootHits => _rootHits;
  List<SigCategory> get currentHits => _currentHits;
  bool get resultsLoaded => _resultsLoaded;
  bool get currentLoaded => _currentLoaded;
  int get selectedStructure => _selectedStructure;
  Int64List get currentHitsByEvalue => _currentHitsByEvalue;
  void set currentHitsByEvalue(Int64List hits) {
    _currentHitsByEvalue = hits;
    notifyListeners();
  }

  void set selectedHit(PlatformInt64 theHit) {
    if (0 <= theHit && theHit < _hits.length) {
      _selectedHit = theHit;
      notifyListeners();
    }
  }

  void setSearchResults(SearchResults results) {
    _hits = results.hits;
    _hitStructures = results.hitStructures;
    _structures = results.structures;
    _domainsContained = results.domainsContained;
    _rootHits = results.rootHits;
    _resultsLoaded = true;
    _selectedStructure = -1;
    var i = 0;
    _domainColors = HashMap();
    for (String domain in _domainsContained) {
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

  void set currentHits(List<SigCategory> hits) {
    _currentHits = hits;
    _currentLoaded = true;
    notifyListeners();
  }

  void clearCurrentLoaded() {
    _currentLoaded = false;
    notifyListeners();
  }

  void set selectedStructure(int newCat) {
    if (newCat >= 0 && newCat < _structures.length) {
      _selectedStructure = newCat;
      notifyListeners();
    }
  }

  (Color, Color, PatternType, Color, Color) get_colors(String domain) {
    if (_domainColors.containsKey(domain)) {
      return _domainColors[domain]!;
    } else {
      // Defarut to black-and-white if we don't have a color for this domain
      // (this should never happen, but just in case)
      final color = (
        Color(0xff000000),
        Color(0xffffffff),
        PatternType.subtlepatch,
        Color(0xff000000),
        Color(0xffffffff),
      );
      return color;
    }
  }
}
