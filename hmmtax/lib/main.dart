import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:hmmtax/src/rust/api/simple.dart';
import 'package:hmmtax/src/rust/frb_generated.dart';
import 'package:hmmtax/src/rust/api/graph.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import"dart:math";
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

// List of pairs of background and foregrund colors for displaying
// domains.  Taken from the ColorBrewer example color sets.
// Format is (BGcolor, FG color)
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

const numColors = 9;
const shadesPerColor = 5;

var lightGraphColors =[
  (Colors.amber[500], Colors.black),
  (Colors.amber[700], Colors.black),
  (Colors.amber[900], Colors.black),
  (Colors.amber[600], Colors.black),
  (Colors.amber[800], Colors.white),
  (Colors.blue[500], Colors.white),
  (Colors.blue[700], Colors.white),
  (Colors.blue[900], Colors.white),
  (Colors.blue[600], Colors.white),
  (Colors.blue[900], Colors.white),
  (Colors.red[500], Colors.white),
  (Colors.red[700], Colors.white),
  (Colors.red[900], Colors.white),
  (Colors.red[600], Colors.white),
  (Colors.red[800], Colors.white),  
  (Colors.purple[500], Colors.white),
  (Colors.purple[700], Colors.white),
  (Colors.purple[900], Colors.white),
  (Colors.purple[600], Colors.white),
  (Colors.purple[800], Colors.white),
    (Colors.green[500], Colors.white),
  (Colors.green[700], Colors.white),
  (Colors.green[900], Colors.white),
  (Colors.green[600], Colors.white),
  (Colors.green[800], Colors.white),
  (Colors.cyan[500], Colors.black),
  (Colors.cyan[700], Colors.white),
  (Colors.cyan[900], Colors.white),
  (Colors.cyan[600], Colors.white),
  (Colors.cyan[800], Colors.white),
  (Colors.orange[500], Colors.black),
  (Colors.orange[700], Colors.black),
  (Colors.orange[900], Colors.black),
  (Colors.orange[600], Colors.white),
  (Colors.orange[800], Colors.white),
  (Colors.pink[500], Colors.white),
  (Colors.pink[700], Colors.white),
  (Colors.pink[900], Colors.white),
  (Colors.pink[600], Colors.white),
  (Colors.pink[800], Colors.white),
  (Colors.teal[500], Colors.white),
  (Colors.teal[700], Colors.white),
  (Colors.teal[900], Colors.white),
  (Colors.teal[600], Colors.white),
  (Colors.teal[800], Colors.white),

];

var darkGraphColors =[
  (Colors.amber[100], Colors.black),
  (Colors.amber[300], Colors.black),
  (Colors.amber[500], Colors.black),
  (Colors.amber[200], Colors.black),
  (Colors.amber[400], Colors.black),
  (Colors.blue[100], Colors.black),
  (Colors.blue[300], Colors.black),
  (Colors.blue[500], Colors.black ),
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
  double domEvalMax = await prefs.getDouble("Hmmtax_domEvalMAx") ?? 10.0;
  double scale = await prefs.getDouble("Hmmtax_scale")?? 1.0;
  double lineWidth= await prefs.getDouble("Hmmtax_lineWidth")?? 2.0;
  int mode = await prefs.getInt("Hmmtax_mode") ?? 3;
  runApp(  MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FileData()),
        ChangeNotifierProvider(create: (_) => GraphData()),
        ChangeNotifierProvider(create: (_) => HSettings(prefs, mode, font, scale, evalMax, domEvalMax, lineWidth)),
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
        body: Center(
          child: Text("Hello, world")
        ),),);
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
  double _lineWidth = 2.0;
  late SharedPreferencesAsync _prefs; 
  List<(Color?, Color?)> get graphColors {
    if (_mode == brightModes.light ||
    (_mode == brightModes.system &&  ThemeMode.system == ThemeMode.light)) {
      return lightGraphColors;
    } else {
      return darkGraphColors;
    }
  }

  HSettings(SharedPreferencesAsync prefs, int mode, String font, double scale, double evalMax, double domEvalMax, double lineWidth){
    _prefs = prefs;
    _font = font;
    _scale = scale;
    _evalMax = evalMax;
    _domEvalMax = domEvalMax;
    _lineWidth = lineWidth;
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
        _prefs.setInt("Hmmtax_mode", 1);
      case brightModes.dark:
        _prefs.setInt("Hmmtax_mode", 2);
      case brightModes.system:
        _prefs.setInt("Hmmtax_mode", 3);
    }
    notifyListeners();
  }
  void set font(String font) {
    _font = font;
    _prefs.setString("Hmmtax_font", font);
    notifyListeners();
  }
  void set scale(double scale){
    _scale = scale;
    _prefs.setDouble("Hmmtax_scale", scale);
    notifyListeners();
  }

  void set evalMax(double newMax){
    _evalMax = newMax;
    _prefs.setDouble("Hmmtax_evalMax", newMax);
    notifyListeners();
  }

  void set domEvalMax(double newMax){
    _domEvalMax = newMax;
    _prefs.setDouble("Hmmtax_domEvalMax", newMax);
    notifyListeners();
  }
  void set lineWidth(double newWidth){
    if (newWidth > 0){
      _lineWidth = newWidth;
    }
  }
  ThemeData get themeData => _updateTheme();
  double get scale => _scale;
  String get font => _font;
  brightModes get mode => _mode;
  double get evalMax => _evalMax;
  double get domEvalMax => _domEvalMax;
  double get lineWidth => _lineWidth; 
}

// ChangeNotifier for graph data
class GraphData with ChangeNotifier {
  PlatformInt64 _graphRoot = -1;  // This is the root node of the entire graph, not the root of the part that's displayed
  Map<PlatformInt64, Node> _graph ={};
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
  TrackRegions _trackRegions= TrackRegions(0); // Data structure to track regions of the graph on screen
  TrackRegions get trackRegions => _trackRegions;
  final TransformationController _tController = TransformationController();
  final ItemScrollController _sController = ItemScrollController();

  ItemScrollController get itemScrollController=> _sController;
  TransformationController get tController => _tController;
  double get radPerLevel => _radPerLevel;
  set radPerLevel(double rad){
    _radPerLevel = rad;
  }
  void updateTransform(){
    Matrix4Transform m4t = Matrix4Transform();
    m4t = m4t.scale(_scale, origin: Offset(_size.width/2, _size.height/2));
    m4t = m4t.rotateByCenter(_rotation, _size);
    m4t = m4t.translate(x: _translateX*_scale, y: _translateY*_scale);
    _transform = m4t.matrix4;
    notifyListeners();
  }
  set transform(Matrix4 newTransform){
    _transform = newTransform;
    notifyListeners();
  }
  set size(Size newSize){
    _size = newSize;
  }
  String historyNames(int index){
    if (index >=0 && index < _historyNames.length){
      return _historyNames[index];
    }
    else{
      return "None";
    }
  }

  int history(int index){
    if (index >=0 && index < _history.length){
      return _history[index];
    }
    else{
      return -1;
    }
  }
  void setHistoryIndex(int newIndex){
    if (newIndex >=0 && newIndex < _history.length){
      _historyIndex = newIndex;
      if(_sController.isAttached){_sController.jumpTo(index: _historyIndex, alignment: 0.5);}
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
  set rootRadius(double rad){
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

  PlatformInt64 findNode(double xPos, double yPos, double centerX, double centerY) {
    return _trackRegions.findNode(xPos, yPos, centerX, centerY, _radPerLevel, _rootRadius);
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
  Node getNode(PlatformInt64 nodeId){
    return _graph[nodeId]!;
  }
  void addRoot(PlatformInt64 newRoot) {
    if (_graph.containsKey(newRoot)) {
      _currentRoot = newRoot;
      _history.add(newRoot);
      _historyNames.add(_graph[newRoot]!.name);
      _historyIndex +=1; 
      if(_sController.isAttached){_sController.jumpTo(index: _historyIndex, alignment: 0.5);}
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
  void incrementIndex(){
    if (_historyIndex < _history.length -1){
      // There's history to go forward through
      _historyIndex +=1;
      setRoot(_history[_historyIndex]);
     if(_sController.isAttached){_sController.jumpTo(index: _historyIndex, alignment: 0.5);}
    }
  }

  void decrementIndex(){
    if (_historyIndex > 0){
      // There's history to go back through
      _historyIndex -= 1;
      setRoot(_history[_historyIndex]);
    if(_sController.isAttached){_sController.jumpTo(index: _historyIndex, alignment: 0.5);}
    }
  }
  // removes elements of the history that are past the current pointer so that we 
  // can go deeper
  void popPastIndex(){
    if (_history.length ==0 || _historyIndex <0){ // nothing to pop
      return;
    }
    var numPops = (_history.length - _historyIndex)-1; // need the -1 because of zero-index arrays
    while (numPops > 0){
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
    if (newRotation> 0 && newRotation <= 2*pi) {
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

enum PdfUnits{inches, cm}

// ChangeNotifier for input files
class FileData with ChangeNotifier {
  String _annotationsFile = "";
  List<String> _domtbloutFiles = [];
  bool _annFileSet = false;
  bool _domtbloutFilesSet = false;
  String _annFileDir = ".";
  String _domtbloutFileDir = ".";
  String _pdfFile = "";
  String _pdfFileDir =".";
  bool _pdfFileSet = false;
  double _pdfHeight = 11.0;
  double _pdfWidth = 8.5;
  PdfUnits _pdfUnits = PdfUnits.inches;
  String get pdfFile => _pdfFile;
  String get pdfFileDir => _pdfFileDir;
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
  double get pdfHeight => _pdfHeight;
  double get pdfWidth => _pdfWidth;
  PdfUnits get pdfUnits => _pdfUnits;

  void set pdfHeight(double height){
    _pdfHeight = height;
    notifyListeners();
  }
  void set pdfWidth(double width){
    _pdfWidth = width;
    notifyListeners();
  }
  void set pdfUnits(PdfUnits unit){
    _pdfUnits = unit;
    notifyListeners();
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
 void setPdfFile(String newFile) {
    _pdfFile = newFile;
    _pdfFileSet = true;
    var splits = newFile.split('/');
    if(splits.length > 1){
      _pdfFileDir = splits.getRange(0, splits.length-1).join("/");
    }
    notifyListeners();
  }
}

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
    GoRoute(path: '/settings',
    builder: (context, state) => const SettingsPage(),),
    GoRoute(path: '/graph',
    builder: (context, state) => const GraphPage(),),
    GoRoute(path: '/allstructure',
    builder: (context, state) => const AllStructurePage(),),
    GoRoute(path: '/subtreestructure',
    builder: (context, state) => const SubtreeStructurePage(),),
    GoRoute(path: '/subtreeevalue',
    builder: (context, state) => const SubtreeEvaluePage(),),
    GoRoute(path: '/allevalue',
    builder: (context, state) => const AllEvaluePage(),),
    GoRoute(path: '/sequence',
    builder: (context, state) => const SequencePage(),),
  ]);
  Widget build(BuildContext context) {
    return PlatformMenuBar(
      menus: <PlatformMenuItem>[
        PlatformMenu(
          label: 'Hmmtax',
          menus: <PlatformMenuItem>[
            PlatformMenuItem(
              label: "About Hmmtax",
              onSelected: () {
                showAboutDialog(
                  context: context,
                  applicationName: "Hmmtax",
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
                return AlertDialog(title: const Text("Quit Hmmtax?"),
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
    return MenuAnchor(
      menuChildren: <Widget>[
        MenuItemButton(
          style: MenuItemButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.onPrimary,),
          onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: 'Hmmtax: A taxonomy viewer for HMMER',
                applicationVersion: '0.0.1',
              );
            },
            child: Text("About",
              style: TextStyle(color: Theme.of(context).colorScheme.primary,),),
        ),
        MenuItemButton(
            style: MenuItemButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.onPrimary,),
            onPressed: () {
              showDialog(context: context,
                builder: (BuildContext context){
                return AlertDialog(title: const Text("Quit Hmmtax?"),
                  backgroundColor: Theme.of(context).colorScheme.onPrimary,
                  titleTextStyle: TextStyle(color: Theme.of(context).colorScheme.primary,),
                  actions: <Widget>[
                    ElevatedButton(
                      style: MenuItemButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary,),
                      onPressed: (){exit(0);}, child: Text("Quit",style: TextStyle(color: Theme.of(context).colorScheme.onPrimary,),),),
                    ElevatedButton(
                      style: MenuItemButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary,),
                      onPressed:(){Navigator.pop(context,'Cancel');}, child: Text("Cancel", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary,),),),
                    ],
                  );
                },
              );
            },
            child: Text('Quit Hmmtax',
            style: TextStyle(color: Theme.of(context).colorScheme.primary,),),
          ),
        MenuItemButton(
            style: MenuItemButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.onPrimary,),
            onPressed: () {
              drawPdfDialog(context);
            },
            child: Text('Export to PDF',
            style: TextStyle(color: Theme.of(context).colorScheme.primary,),),
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
                applicationName: 'Hmmtax: A taxonomy viewer for HMMER',
                applicationVersion: '0.0.1',
              );
            },
          ),
          MenuEntry(
            label: 'Quit Hmmtax',
            onPressed: () {
              showDialog(context: context,
                builder: (BuildContext context){
                return AlertDialog(title: const Text("Quit Hmmtax?"),
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
 
// class that holds the results of a search
class SearchData with ChangeNotifier{
  List<Hit> _hits = [];
  Uint32List _hitStructures = Uint32List(0);
  List<String> _structures = [];
  List<String> _domainsContained = [];
  List<SigCategory> _rootHits = [];
  List<SigCategory> _currentHits = [];
  bool _resultsLoaded = false;
  bool _currentLoaded = false;
  int _selectedStructure = -1;
  HashMap<String, (Color, Color)> _domainColors = HashMap();
  PlatformInt64 _selectedHit = -1;

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
  void set selectedHit(PlatformInt64 theHit){
    if (0<= theHit &&  theHit < _hits.length){
      _selectedHit = theHit;
      notifyListeners();
    }
  }

  void setSearchResults(SearchResults results){
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

  void set currentHits(List<SigCategory> hits){
    _currentHits = hits;
    _currentLoaded = true;
    notifyListeners();
  }

  void clearCurrentLoaded(){
    _currentLoaded = false;
    notifyListeners();
  }

  void set selectedStructure(int newCat){
    if(newCat >= 0 && newCat < _structures.length){
      _selectedStructure = newCat;
      notifyListeners();
    }
  }

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
}