import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:homot/src/rust/frb_generated.dart';
import 'package:homot/src/rust/api/graph.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import "dart:math";
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:homot/pages.dart';
import 'package:homot/graph_painter.dart';
import 'package:homot/utility.dart';
import "package:go_router/go_router.dart";
import 'dart:io';
import 'dart:collection';
import 'package:matrix4_transform/matrix4_transform.dart';
import 'package:patterns_canvas/patterns_canvas.dart';
import 'package:csv/csv.dart';

// List of pairs of background and foreground colors for displaying
// domains.  Taken from the ColorBrewer example color sets.
// Format is (BGcolor, FG color)
enum SelectedBy { none, structure, subtree, subtreeStructure }

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
  // Without this, every colour not set below gets a light-mode shade
  brightness: Brightness.dark,
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

var graphColorList = [
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
    Color(0xafffff6d),
    Color(0xff000000),
    PatternType.checkers,
    Color(0xafffff6d),
    Color(0xFF000000),
  ),
  (
    Color(0x6fffff6d),
    Color(0xff000000),
    PatternType.raindrops,
    Color(0x6fffff6d),
    Color(0xFF000000),
  ),
  (
    Color(0xcfffff6d),
    Color(0xff000000),
    PatternType.texture,
    Color(0xcfffff6d),
    Color(0xFF000000),
  ),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  final SharedPreferencesAsync prefs = SharedPreferencesAsync();
  String font = await prefs.getString("homot_font") ?? "Roboto";
  double evalMax = await prefs.getDouble("homot_evalMax") ?? 10.0;
  double evalMin = await prefs.getDouble("homot_evalMin") ?? 0.0;
  double domEvalMin = await prefs.getDouble("homot_domEvalMin") ?? 0.0;
  double domEvalMax = await prefs.getDouble("homot_domEvalMax") ?? 10.0;
  double scale = await prefs.getDouble("homot_scale") ?? 1.0;
  double lineWidth = await prefs.getDouble("homot_lineWidth") ?? 2.0;
  int mode = await prefs.getInt("homot_mode") ?? 3;
  int dataFileType = await prefs.getInt("homot_datatype") ?? 3;
  bool addPatterns = await prefs.getBool("homot_patterns") ?? false;
  bool showInterproSuperfamily =
      await prefs.getBool("homot_show_superfamily") ?? true;
  bool showInterproFamily = await prefs.getBool("homot_show_family") ?? true;
  bool showInterproDomain = await prefs.getBool("homot_show_domain") ?? true;
  bool showInterproRepeat = await prefs.getBool("homot_show_repeat") ?? true;
  bool showInterproSite = await prefs.getBool("homot_show_site") ?? true;
  bool showInterproOther = await prefs.getBool("homot_show_other") ?? true;
  bool useSeqEvals = await prefs.getBool("homot_use_seq_evals") ?? false;
  bool useDomEvals = await prefs.getBool("homot_use_dom_evals") ?? false;
  int temp2 = await prefs.getInt("homot_interpro_show_id_as") ?? 0;
  ShowInterproIdEnum showInterproIDAs;
  switch (temp2) {
    case 0:
      showInterproIDAs = ShowInterproIdEnum.id;
    case 1:
      showInterproIDAs = ShowInterproIdEnum.shortName;
    case 2:
      showInterproIDAs = ShowInterproIdEnum.longName;
    default:
      showInterproIDAs = ShowInterproIdEnum.id;
  }
  bool temp = await prefs.getBool("homot_interpro_names_from_pfam") ?? true;
  ShowNamesFrom namesFrom = temp ? ShowNamesFrom.pfam : ShowNamesFrom.interpro;
  int temp3 = await prefs.getInt("homot_drawtype") ?? 2;
  GraphDrawType drawType;
  switch (temp3) {
    case 0:
      drawType = GraphDrawType.line;
    case 1:
      drawType = GraphDrawType.outline;
    case 2:
      drawType = GraphDrawType.fill;
    default:
      drawType = GraphDrawType.fill;
  }
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
                useSeqEvals,
                useDomEvals,
                evalMax,
                evalMin,
                domEvalMax,
                domEvalMin,
                lineWidth,
                dataFileType,
                addPatterns,
                showInterproSuperfamily,
                showInterproFamily,
                showInterproDomain,
                showInterproRepeat,
                showInterproSite,
                showInterproOther,
                showInterproIDAs,
                namesFrom,
                drawType,
              ),
        ),
        ChangeNotifierProvider(create: (_) => SearchData()),
      ],
      child: TopLevel(),
    ),
  );
}

//  Top-level application
class TopLevel extends StatefulWidget {
  const TopLevel({super.key});
  @override
  State<TopLevel> createState() => _TopLevelState();
}

class _TopLevelState extends State<TopLevel> {
  @override
  Widget build(BuildContext context) {
    return Consumer<HSettings>(
      builder: (context, hsettings, child) {
        return MaterialApp(
          theme: hsettings.lightTheme,
          darkTheme: hsettings.darkTheme,
          themeMode: hsettings.themeMode,
          debugShowCheckedModeBanner: false,
          title: 'Homot',
          home: MediaQuery.withNoTextScaling(child: MacMenu()),
        );
      },
    );
  }
}

enum BrightModes { light, dark, system }

enum GraphDrawType { line, outline, fill }

enum ShowNamesFrom { pfam, interpro }

enum ShowInterproIdEnum { id, shortName, longName }

// ChangeNotifier for theme state
class HSettings with ChangeNotifier {
  BrightModes _mode = BrightModes.light;
  DataFileType _dataType = DataFileType.infer;

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
  bool _useSeqEvals = false;
  bool _useDomEvals = false;
  ShowNamesFrom _namesFrom = ShowNamesFrom.pfam;
  ShowInterproIdEnum _showInterproIDAs = ShowInterproIdEnum.id;

  GraphDrawType _drawType = GraphDrawType.fill;
  late SharedPreferencesAsync _prefs;
  List<(Color, Color, PatternType, Color, Color)> get graphColors {
    return graphColorList;
  }

  HSettings(
    SharedPreferencesAsync prefs,
    int mode,
    String font,
    double scale,
    bool useSeqEvals,
    bool useDomEvals,
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
    GraphDrawType drawType,
  ) {
    _prefs = prefs;
    _font = font;
    _scale = scale;
    _useSeqEvals = useSeqEvals;
    _useDomEvals = useDomEvals;
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
    _drawType = drawType;

    switch (mode) {
      case 1:
        _mode = BrightModes.light;
      case 2:
        _mode = BrightModes.dark;
      case 3:
        _mode = BrightModes.system;
      default:
        _mode = BrightModes.system;
    }
    switch (dataType) {
      case 1:
        _dataType = DataFileType.domTblOut;
      case 2:
        _dataType = DataFileType.blast;
      case 3:
        _dataType = DataFileType.infer;
      default:
        _dataType = DataFileType.infer;
    }
  }

  // Builds the app's theme from a colour scheme.  The light and dark themes
  // differ only in their colour scheme and scrollbar thumb colours.
  ThemeData _buildTheme(
    ColorScheme scheme,
    Color thumbActiveColor,
    double thumbIdleAlpha,
  ) {
    return ThemeData(
      colorScheme: scheme,
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
          color: scheme.surface,
          border: Border.all(color: scheme.onSurface, width: 1.0),
          borderRadius: BorderRadius.circular(4.0),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: WidgetStateProperty.all<bool>(true),
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.dragged) ||
              states.contains(WidgetState.hovered)) {
            // Colour when being dragged or hovered (Desktop/Web)
            return thumbActiveColor.withValues(alpha: 0.5);
          }
          return Colors.grey.withValues(alpha: thumbIdleAlpha); // Default
        }),
      ),
    );
  }

  set drawType(GraphDrawType newType) {
    _drawType = newType;
    switch (newType) {
      case GraphDrawType.line:
        _prefs.setInt("homot_drawtype", 0);
      case GraphDrawType.outline:
        _prefs.setInt("homot_drawtype", 1);
      case GraphDrawType.fill:
        _prefs.setInt("homot_drawtype", 2);
    }
    notifyListeners();
  }

  set mode(BrightModes newmode) {
    _mode = newmode;
    switch (newmode) {
      case BrightModes.light:
        _prefs.setInt("homot_mode", 1);
      case BrightModes.dark:
        _prefs.setInt("homot_mode", 2);
      case BrightModes.system:
        _prefs.setInt("homot_mode", 3);
    }
    notifyListeners();
  }

  set dataType(DataFileType newtype) {
    _dataType = newtype;
    switch (newtype) {
      case DataFileType.domTblOut:
        _prefs.setInt("homot_datatype", 1);
      case DataFileType.blast:
        _prefs.setInt("homot_datatype", 2);
      case DataFileType.infer:
        _prefs.setInt("homot_datatype", 3);
    }
    notifyListeners();
  }

  set font(String font) {
    _font = font;
    _prefs.setString("homot_font", font);
    notifyListeners();
  }

  set scale(double scale) {
    _scale = scale;
    _prefs.setDouble("homot_scale", scale);
    notifyListeners();
  }

  set evalMax(double newMax) {
    _evalMax = newMax;
    _prefs.setDouble("homot_evalMax", newMax);
    notifyListeners();
  }

  set domEvalMax(double newMax) {
    _domEvalMax = newMax;
    _prefs.setDouble("homot_domEvalMax", newMax);
    notifyListeners();
  }

  set evalMin(double newMin) {
    _evalMin = newMin;
    _prefs.setDouble("homot_evalMin", newMin);
    notifyListeners();
  }

  set domEvalMin(double newMin) {
    _domEvalMin = newMin;
    _prefs.setDouble("homot_domEvalMin", newMin);
    notifyListeners();
  }

  set lineWidth(double newWidth) {
    if (newWidth > 0) {
      _lineWidth = newWidth;
      _prefs.setDouble("homot_lineWidth", newWidth);
      notifyListeners();
    }
  }

  set addPatterns(bool val) {
    _addPatterns = val;
    _prefs.setBool("homot_patterns", val);
    notifyListeners();
  }

  set showInterproSuperfamily(bool val) {
    _showInterproSuperfamily = val;
    _prefs.setBool("homot_show_superfamily", val);
    notifyListeners();
  }

  set showInterproFamily(bool val) {
    _showInterproFamily = val;
    _prefs.setBool("homot_show_family", val);
    notifyListeners();
  }

  set showInterproDomain(bool val) {
    _showInterproDomain = val;
    _prefs.setBool("homot_show_domain", val);
    notifyListeners();
  }

  set showInterproRepeat(bool val) {
    _showInterproRepeat = val;
    _prefs.setBool("homot_show_repeat", val);
    notifyListeners();
  }

  set showInterproSite(bool val) {
    _showInterproSite = val;
    _prefs.setBool("homot_show_site", val);
    notifyListeners();
  }

  set showInterproOther(bool val) {
    _showInterproOther = val;
    _prefs.setBool("homot_show_other", val);
    notifyListeners();
  }

  set useSeqEvals(bool val) {
    _useSeqEvals = val;
    _prefs.setBool("homot_use_seq_evals", val);
    notifyListeners();
  }

  set useDomEvals(bool val) {
    _useDomEvals = val;
    _prefs.setBool("homot_use_dom_evals", val);
    notifyListeners();
  }

  set showInterproIdAs(ShowInterproIdEnum val) {
    _showInterproIDAs = val;
    _prefs.setInt("homot_interpro_show_id_as", val.index);
    notifyListeners();
  }

  set showNamesFrom(ShowNamesFrom val) {
    _namesFrom = val;
    if (val == ShowNamesFrom.pfam) {
      _prefs.setBool("homot_interpro_names_from_pfam", true);
    } else {
      _prefs.setBool("homot_interpro_names_from_pfam", false);
    }
    notifyListeners();
  }

  ThemeData get lightTheme => _buildTheme(lightScheme, Colors.black, 0.75);
  ThemeData get darkTheme => _buildTheme(darkScheme, Colors.white, 0.5);
  // MaterialApp picks between lightTheme and darkTheme using this, and follows
  // changes to the OS appearance itself when it's ThemeMode.system.
  ThemeMode get themeMode => switch (_mode) {
    BrightModes.light => ThemeMode.light,
    BrightModes.dark => ThemeMode.dark,
    BrightModes.system => ThemeMode.system,
  };
  double get scale => _scale;
  String get font => _font;
  BrightModes get mode => _mode;
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
  bool get useSeqEvals => _useSeqEvals;
  bool get useDomEvals => _useDomEvals;
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

  final TransformationController _tController = TransformationController();
  final ItemScrollController _sController = ItemScrollController();

  ItemScrollController get itemScrollController => _sController;
  TransformationController get tController => _tController;

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

  TrackRegions get trackRegions => _trackRegions;
  Size get size => _size;
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
  Matrix4 get transform => _transform;
  double get translateX => _translateX;
  double get translateY => _translateY;
  double get scale => _scale;
  set rootRadius(double rad) {
    _rootRadius = rad;
  }

  set translateX(double x) {
    _translateX = x;
    updateTransform();
  }

  set translateY(double y) {
    _translateY = y;
    updateTransform();
  }

  set scale(double s) {
    _scale = s;
    updateTransform();
  }

  set trackRegions(TrackRegions tr) {
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
    _graphRoot = -1;
    _currentRoot = -1;
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

  set graphRoot(PlatformInt64 newRoot) {
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
    if (_history.isEmpty || _historyIndex < 0) {
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

  void setRotation(double newRotation) {
    if (newRotation >= 0 && newRotation <= 2 * pi) {
      _rotation = newRotation;
      updateTransform();
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

  // True while a data load is in progress, so the Load Data button can be
  // disabled.  Kept here rather than in the page's state so that it survives
  // navigating away from and back to the main page during a load.
  bool _loading = false;
  bool get loading => _loading;
  set loading(bool value) {
    _loading = value;
    notifyListeners();
  }

  String get exportFile => _exportFile;
  set exportFile(String newExportFile) {
    _exportFile = newExportFile;
    notifyListeners();
  }

  // Don't notify listeners after these functions,
  // because we want to make all changes, then trigger a load
  void setAnnotationsFile(String newAnnotations) {
    _annotationsFile = newAnnotations;
    _annFileSet = true;
    _annFileDir = parentDir(newAnnotations) ?? _annFileDir;
    notifyListeners();
  }

  void addDomtbloutFile(String domtblout) {
    _domtbloutFiles.add(domtblout);
    _domtbloutFilesSet = true;
    _domtbloutFileDir = parentDir(domtblout) ?? _domtbloutFileDir;
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
      _domtbloutFileDir = parentDir(domtblout) ?? _domtbloutFileDir;
      notifyListeners();
    }
  }

  // Writes the contents of the current page to _exportFile.  Returns null on
  // success, or a description of the error if the export failed.  It doesn't
  // show the error itself, because the caller's dialog is usually gone by the
  // time the write finishes; the caller reports it with a context that's still mounted.
  Future<String?> exportCurrentPage(
    String currentpage,
    SearchData searchdata,
    bool pfamNames,
    bool showInterproSuperfamily,
    bool showInterproFamily,
    bool showInterproDomain,
    bool showInterproRepeat,
    bool showInterproSite,
    bool showInterproOther,
  ) async {
    IOSink? outSink;
    try {
      outSink = File(_exportFile).openWrite(mode: FileMode.write);
      _writePage(
        currentpage,
        searchdata,
        pfamNames,
        showInterproSuperfamily,
        showInterproFamily,
        showInterproDomain,
        showInterproRepeat,
        showInterproSite,
        showInterproOther,
        outSink,
      );
      // Errors opening or writing the file are reported here
      await outSink.flush();
      await outSink.close();
      return null;
    } catch (e) {
      // Close the sink if we can, but report the original error
      try {
        await outSink?.close();
      } catch (_) {}
      return e.toString();
    }
  }

  void _writePage(
    String currentpage,
    SearchData searchdata,
    bool pfamNames,
    bool showInterproSuperfamily,
    bool showInterproFamily,
    bool showInterproDomain,
    bool showInterproRepeat,
    bool showInterproSite,
    bool showInterproOther,
    IOSink outSink,
  ) {
    List<List<String>> outData;
    switch (currentpage) {
      case "/allstructure":
        outData = _exportAllStructure(
          searchdata,
          pfamNames,
          showInterproSuperfamily,
          showInterproFamily,
          showInterproDomain,
          showInterproRepeat,
          showInterproSite,
          showInterproOther,
        );
        break;
      case "/subtreestructure":
        outData = _exportSubtreeStructure(
          searchdata,
          pfamNames,
          showInterproSuperfamily,
          showInterproFamily,
          showInterproDomain,
          showInterproRepeat,
          showInterproSite,
          showInterproOther,
        );
        break;
      case "/allevalue":
        outData = _exportAllEval(
          searchdata,
          pfamNames,
          showInterproSuperfamily,
          showInterproFamily,
          showInterproDomain,
          showInterproRepeat,
          showInterproSite,
          showInterproOther,
        );
        break;
      case "/subtreeevalue":
        outData = _exportSubtreeEval(
          searchdata,
          pfamNames,
          showInterproSuperfamily,
          showInterproFamily,
          showInterproDomain,
          showInterproRepeat,
          showInterproSite,
          showInterproOther,
        );
        break;
      case "/sequence":
        outData = [
          _exportSequence(
            searchdata.hits[searchdata.selectedHit.toInt()],
            pfamNames,
            showInterproSuperfamily,
            showInterproFamily,
            showInterproDomain,
            showInterproRepeat,
            showInterproSite,
            showInterproOther,
          ),
        ];
        break;
      default:
        outData = [
          ["No data to export"],
        ];
    }
    final csvOut = csv.encode(outData);
    outSink.write(csvOut);
  }

  List<String> _header() {
    return [
      "Format:",
      "SeqEvalue",
      "HitName",
      "(QueryName, QueryStart, QueryEnd)*",
      "ANNOTATIONS:",
      "(Name, Evalue, Start, End)*",
    ];
  }

  List<List<String>> _exportAllStructure(
    SearchData searchdata,
    bool pfamNames,
    bool showInterproSuperfamily,
    bool showInterproFamily,
    bool showInterproDomain,
    bool showInterproRepeat,
    bool showInterproSite,
    bool showInterproOther,
  ) {
    List<List<String>> outString = [_header()];
    for (var category in searchdata.rootHits) {
      outString += _exportCategory(
        category,
        searchdata,
        pfamNames,
        showInterproSuperfamily,
        showInterproFamily,
        showInterproDomain,
        showInterproRepeat,
        showInterproSite,
        showInterproOther,
      );
      outString += [[]]; // blank line between categories
    }
    return outString;
  }

  List<List<String>> _exportSubtreeStructure(
    SearchData searchdata,
    bool pfamNames,
    bool showInterproSuperfamily,
    bool showInterproFamily,
    bool showInterproDomain,
    bool showInterproRepeat,
    bool showInterproSite,
    bool showInterproOther,
  ) {
    List<List<String>> outString = [_header()];
    for (var category in searchdata.currentHits) {
      outString += _exportCategory(
        category,
        searchdata,
        pfamNames,
        showInterproSuperfamily,
        showInterproFamily,
        showInterproDomain,
        showInterproRepeat,
        showInterproSite,
        showInterproOther,
      );
      outString += [[]];
    }
    return outString;
  }

  List<List<String>> _exportAllEval(
    SearchData searchdata,
    bool pfamNames,
    bool showInterproSuperfamily,
    bool showInterproFamily,
    bool showInterproDomain,
    bool showInterproRepeat,
    bool showInterproSite,
    bool showInterproOther,
  ) {
    List<List<String>> outString = [_header()];
    for (var hit in searchdata.hits) {
      outString += [
        _exportHit(
          hit,
          pfamNames,
          showInterproSuperfamily,
          showInterproFamily,
          showInterproDomain,
          showInterproRepeat,
          showInterproSite,
          showInterproOther,
        ),
      ];
    }
    return outString;
  }

  List<List<String>> _exportSubtreeEval(
    SearchData searchdata,
    bool pfamNames,
    bool showInterproSuperfamily,
    bool showInterproFamily,
    bool showInterproDomain,
    bool showInterproRepeat,
    bool showInterproSite,
    bool showInterproOther,
  ) {
    List<List<String>> outString = [_header()];
    Int64List hitIndices = Int64List(0);
    switch (searchdata.selectedBy) {
      case SelectedBy.subtree:
        hitIndices = searchdata.currentHitsByEvalue;
        break;
      case SelectedBy.subtreeStructure:
        hitIndices = searchdata.currentHits[searchdata.selectedStructure].hits;
        break;
      case SelectedBy.structure:
        hitIndices = searchdata.rootHits[searchdata.selectedStructure].hits;
        break;
      default:
        hitIndices = Int64List(0);
    }
    for (var hitIndex in hitIndices) {
      outString += [
        _exportHit(
          searchdata.hits[hitIndex.toInt()],
          pfamNames,
          showInterproSuperfamily,
          showInterproFamily,
          showInterproDomain,
          showInterproRepeat,
          showInterproSite,
          showInterproOther,
        ),
      ];
    }
    return outString;
  }

  List<List<String>> _exportCategory(
    SigCategory category,
    SearchData searchdata,
    bool pfamNames,
    bool showInterproSuperfamily,
    bool showInterproFamily,
    bool showInterproDomain,
    bool showInterproRepeat,
    bool showInterproSite,
    bool showInterproOther,
  ) {
    List<List<String>> outString;
    String header =
        "${category.hits.length} Hits with Domain Structure ${searchdata.structures[category.signature]}";
    outString = [
      [header],
    ];

    for (var hit in category.hits) {
      var theHit = searchdata.hits[hit.toInt()];
      outString += [
        _exportHit(
          theHit,
          pfamNames,
          showInterproSuperfamily,
          showInterproFamily,
          showInterproDomain,
          showInterproRepeat,
          showInterproSite,
          showInterproOther,
        ),
      ];
    }
    return outString;
  }

  List<String> _exportHit(
    Hit hit,
    bool pfamNames,
    bool showInterproSuperfamily,
    bool showInterproFamily,
    bool showInterproDomain,
    bool showInterproRepeat,
    bool showInterproSite,
    bool showInterproOther,
  ) {
    List<String> outString = [hit.seqEvalue.toStringAsExponential(2), hit.name];
    for (var query in hit.queries) {
      outString += [
        query.name,
        query.seqStart.toString(),
        query.seqEnd.toString(),
      ];
    }
    outString += ["ANNOTATIONS:"];
    for (var domain in hit.structureDomains) {
      if (domain.source != AnnotationType.interpro ||
          (domain.iType == IEntryType.superfamily && showInterproSuperfamily) ||
          (domain.iType == IEntryType.family && showInterproFamily) ||
          (domain.iType == IEntryType.domain && showInterproDomain) ||
          (domain.iType == IEntryType.repeat && showInterproRepeat) ||
          (domain.iType == IEntryType.site && showInterproSite) ||
          (domain.iType == IEntryType.other && showInterproOther)) {
        if (domain.source == AnnotationType.interpro &&
            pfamNames &&
            domain.pfamName.isNotEmpty) {
          outString += [domain.pfamName];
        } else {
          outString += [domain.name];
        }
        outString += [
          domain.domEvalue.toStringAsExponential(2),
          domain.seqStart.toString(),
          domain.seqEnd.toString(),
        ];
      }
    }
    return outString;
  }
}

List<String> _exportSequence(
  Hit hit,
  bool pfamNames,
  bool showInterproSuperfamily,
  bool showInterproFamily,
  bool showInterproDomain,
  bool showInterproRepeat,
  bool showInterproSite,
  bool showInterproOther,
) {
  List<String> outString = [hit.seqEvalue.toStringAsExponential(2), hit.name];
  for (var query in hit.queries) {
    outString += [
      query.name,
      query.seqStart.toString(),
      query.seqEnd.toString(),
    ];
  }
  outString += ["ANNOTATIONS:"];
  for (var domain in hit.domains) {
    if (domain.source != AnnotationType.interpro ||
        (domain.iType == IEntryType.superfamily && showInterproSuperfamily) ||
        (domain.iType == IEntryType.family && showInterproFamily) ||
        (domain.iType == IEntryType.domain && showInterproDomain) ||
        (domain.iType == IEntryType.repeat && showInterproRepeat) ||
        (domain.iType == IEntryType.site && showInterproSite) ||
        (domain.iType == IEntryType.other && showInterproOther)) {
      if (domain.source == AnnotationType.interpro &&
          pfamNames &&
          domain.pfamName.isNotEmpty) {
        outString += [domain.pfamName];
      } else {
        outString += [domain.name];
      }
      outString += [
        domain.domEvalue.toStringAsExponential(2),
        domain.seqStart.toString(),
        domain.seqEnd.toString(),
      ];
    }
  }
  return outString;
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
          title: const Text("About homot"),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Version 1.0.0\n",
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                FilledButton(
                  onPressed: () {
                    showLicensePage(context: context, applicationName: "homot");
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
  @override
  Widget build(BuildContext context) {
    return PlatformMenuBar(
      menus: <PlatformMenuItem>[
        PlatformMenu(
          label: 'homot',
          menus: <PlatformMenuItem>[
            PlatformMenuItem(
              label: "About homot",
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
                      title: const Text("Quit homot?"),
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

class NonMacMenuBar extends StatefulWidget {
  const NonMacMenuBar({super.key});

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
                  title: const Text("Quit homot?"),
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
            'Quit homot',
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
}

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
  SelectedBy _selectedBy = SelectedBy.none;
  SelectedBy _previousSelectedBy = SelectedBy.none;
  HashMap<String, (Color, Color, PatternType, Color, Color)> _domainColors =
      HashMap();
  PlatformInt64 _selectedHit = -1;
  SelectedBy get selectedBy => _selectedBy;
  set selectedBy(SelectedBy method) {
    _selectedBy = method;
    notifyListeners();
  }

  set previousSelectedBy(SelectedBy method) {
    _previousSelectedBy = method;
  }

  SelectedBy get previousSelectedBy => _previousSelectedBy;
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
  set currentHitsByEvalue(Int64List hits) {
    _currentHitsByEvalue = hits;
    notifyListeners();
  }

  set selectedHit(PlatformInt64 theHit) {
    if (-1 <= theHit && theHit < _hits.length) {
      _selectedHit = theHit;
      notifyListeners();
    }
  }

  void setSearchResults(SearchResults results) {
    _hits = results.hits;
    _hitStructures = results.hitStructures;
    _structures = results.structures;
    _domainsContained = [];
    for (var domain in results.domainsContained) {
      if (!_domainsContained.contains(domain) &&
          domain != "Sequence not in annotation database") {
        _domainsContained.add(domain);
      }
    }

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

  set currentHits(List<SigCategory> hits) {
    _currentHits = hits;
    _currentLoaded = true;
    notifyListeners();
  }

  set selectedStructure(int newCat) {
    if (newCat >= 0 && newCat < _structures.length) {
      _selectedStructure = newCat;
      notifyListeners();
    }
  }

  (Color, Color, PatternType, Color, Color) getColors(String domain) {
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
