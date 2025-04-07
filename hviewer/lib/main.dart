import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hviewer/src/rust/api/simple.dart';
import 'package:hviewer/src/rust/api/gather_hits.dart';
import 'package:hviewer/src/rust/frb_generated.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart'; 

import 'dart:io';

Future<void> main() async {
  await RustLib.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OverviewData()),
        ChangeNotifierProvider(create: (_) => HitLists()),
        ChangeNotifierProvider(create: (_) => FileData()),
      ],
      child: MyApp(),
      ),
  );
}

ThemeData _hTheme(brightness) {
  return ThemeData(
    brightness: brightness,
    primaryColor: Colors.black,
    fontFamily: 'FiraMono',
    textTheme: TextTheme(bodyMedium: TextStyle(fontSize:16)),
  );
}

//  Top-level application
class MyApp extends StatelessWidget {
    const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<OverviewData, FileData>(
      builder: (context, overview, filedata, child){
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Hviewer',
        theme: _hTheme(Brightness.light),
        initialRoute: '/',
        routes: {
          '/': (context) => const FileForm(),
          '/overview': (context) => const DrawOverview(),
        },
      );
    }
  );
  }
}


// ChangeNotifier for state storage
class OverviewData with ChangeNotifier{
  ResultsOverview _overview = ResultsOverview(numHits: 0, numCategories: 0, categories: []);

  int get numHits => _overview.numHits;
  int get numCategories => _overview.numCategories;
  List<SigCategory> get categories => _overview.categories;

  void set(ResultsOverview newOverview){
    _overview = newOverview;
    notifyListeners();
  }

  void clear(){
    _overview = ResultsOverview(numHits: 0, numCategories: 0, categories: []);
    notifyListeners();
  }
}

// ChangeNotifier for input files
class FileData with ChangeNotifier{
  String _annotationsFile = "";
  List<String> _domtbloutFiles = [];

  String get annotationsFile => _annotationsFile;
  List<String> get domtbloutFiles => _domtbloutFiles;

  // Don't notify listners after these functions,
  // because we want to make all changes, then trigger a load
  void setAnnotationsFile(String newAnnotations){
    _annotationsFile = newAnnotations;
  }

  void addDomtbloutFile(String domtblout){
    _domtbloutFiles.add(domtblout);
  }

  void clearDomtbloutFiles(){
    _domtbloutFiles = [];
  }

  // Notify listeners once we've made all changes. 
  void triggerLoad(){
    notifyListeners();
  }

}

//ChangeNotifier for hit lists
class HitLists with ChangeNotifier{
  List<HitList> _hitLists = [];

  List<HitList> get hitLists => _hitLists;

  void clear(){
    _hitLists = [];
    notifyListeners();
  }

  void set(int which, HitList newHitList){
    assert(which < _hitLists.length);
    _hitLists[which] = newHitList;
    notifyListeners();
  }

  void init(int numHitLists){
    for (var q = 0; q < numHitLists; q++){
      HitList newHit = HitList(numHits: 0, signature: "", hits: []);
      _hitLists.add(newHit);
    } 
    notifyListeners();
  }
}

//Widget to draw the data for a hit
class DrawHit extends StatefulWidget{
  const DrawHit({
    super.key,
    required this.hit,
  });
  final Hit hit;
  State<DrawHit> createState() => _DrawHitState();

}

class _DrawHitState extends State<DrawHit> {
  final GlobalKey key = GlobalKey();
  ScrollController _scrollController = ScrollController();
  Size textSize = Size(0, 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _calculateRenderBoxWidth());
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
    final TextStyle textStyle = TextStyle(
      color: Colors.black,
      fontSize: 16,
      fontFamily: 'FiraMono',
    );
    return SizedBox(
      width: MediaQuery.sizeOf(context).width,
      child:  IntrinsicHeight (
          child: 
            Row(
              children: [
                Center(
                  child: 
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.max,
                        children:[
                          Text("Sequence: ${widget.hit.name}", style: textStyle),
                          Text("Domain Structure:", style: textStyle),
                          Text("Query Hits:", style: textStyle),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Scrollbar(
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    child: Column(children: [
                      Text(widget.hit.sequence, style: textStyle, key: key),
                      DrawDomains(seqlength: widget.hit.sequence.length, domains: widget.hit.domains, dimensions: textSize, queries: widget.hit.queries),
                        ],),
                  ),
              ),
                ),
          ]),
        ),
      );
  }
}


/// DrawDomains: draws a representation of the domains that a sequence contains
class DrawDomains extends StatelessWidget {
  const DrawDomains({
    super.key,
    required this.seqlength,
    required this.domains,
    required this.dimensions,
    required this.queries,
  });

  //final List<Domain> domains;
  final int seqlength;
  final List<Domain> domains;
  final Size dimensions;
  final List<Domain> queries;

  @override
  Widget build(BuildContext context) {
    final widthPerChar = dimensions.width / seqlength;
    final height = dimensions.height;
    final width = dimensions.width;
    return Container(
      child: CustomPaint(
      size: Size(width, height*2 + 4.0),
      painter: DomainPainter(domains: domains, widthPerChar: widthPerChar, height: height, queries: queries),
      ),  
      );
  }

}

class DomainPainter extends CustomPainter {
  final List<Domain> domains;
  final double widthPerChar;
  final double height;
  final List<Domain> queries;

  DomainPainter({
    required this.domains,
    required this.widthPerChar,
    required this.height,
    required this.queries
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    // Draw domain structure of the sequence that the hit matched
    for (final domain in domains) {
      final double start = domain.start*widthPerChar;
      final double end = domain.end * widthPerChar;
      final double domainWidth = end - start;
      final RRect rect = RRect.fromRectAndRadius(Rect.fromLTWH(start, 0, domainWidth, height), const Radius.circular(5));
      canvas.drawRRect(rect, paint);

      TextPainter painter;
      painter = TextPainter(
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      String name = "";
      double textOffset = 0.0;
      if (domain.name.length <=domain.end - domain.start){
        name = domain.name;
        textOffset = ((((domain.end - domain.start) - domain.name.length)) / 2 * widthPerChar);
      }
      else{
        name = domain.name.substring(0, domain.end - domain.start);
        textOffset = 0;
      }
      painter.text= TextSpan(
        text: name,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontFamily: 'FiraMono',
        ),
      );
      painter.layout();
      Offset position = Offset(start+textOffset, 0);
      painter.paint(canvas, position);
    }
    // add the representation of the hit(s) to the sequence
      for (final query in queries) {
      final double start = query.start*widthPerChar;
      final double end = query.end * widthPerChar;
      final double domainWidth = end - start;
      final RRect rect = RRect.fromRectAndRadius(Rect.fromLTWH(start, height+4.0, domainWidth, height), const Radius.circular(5));
      canvas.drawRRect(rect, paint..color = Colors.blue);

      TextPainter painter;
      painter = TextPainter(
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      String name = "";
      double textOffset = 0.0;
      if (query.name.length <=query.end - query.start){
        name = query.name;
        textOffset = ((((query.end - query.start) - query.name.length)) / 2 * widthPerChar);
      }
      else{
        name = query.name.substring(0, query.end - query.start);
        textOffset = 0;
      }
      painter.text= TextSpan(
        text: name,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontFamily: 'FiraMono',
        ),
      );
      painter.layout();
      Offset position = Offset(start+textOffset, height+4.0);
      painter.paint(canvas, position);
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
  });

  final SigCategory category;
  final int which;

  @override
  Widget build(BuildContext context) {
    return Consumer<HitLists>(
            builder: (context, hitLists, child){
              return InkWell(
                onTap:() {
                  Navigator.push(context,
                  MaterialPageRoute(builder: (context) =>
                    DrawHitList(which: which)
                    ),
                  );
                },
                hoverColor: Colors.green,
                child:
                  Padding(
                    padding: EdgeInsets.all(4),
                    child: Material(
                    elevation: 2.0,
                    shadowColor: Colors.black,
                    child: DecoratedBox(
                    decoration: BoxDecoration(
                     borderRadius: BorderRadius.circular(12.0),
                     border: Border.all(color: Colors.black),
                      ),
                    child:
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${category.numHits} hits with domain signature ${category.signature}"),
                          Text("Example: "),
                          DrawHit(hit: category.example),
                          ],
                      ),
                    ), 
                    ),
                  ),
                );
            }
    );
  }
}

// Widget that displays the results overview
class DrawOverview extends StatefulWidget {
  const DrawOverview({
    super.key,
  });

  @override
  State<DrawOverview> createState() => _DrawOverviewState();
}
class _DrawOverviewState extends State<DrawOverview> {
  final ScrollController _scrollController2 = ScrollController();
  @override
  Widget build(BuildContext context) {
   return Material( 
    child: Consumer<OverviewData>(
            builder: (context, overview, child){
              return Column(children: [
        ElevatedButton(
                    onPressed: (){
                      Navigator.pushNamed(context, '/');
                    },
                    child: const Text("Back"),
                    ),        
    Text("${overview.numHits} hits found, with ${overview.numCategories} different domain signatures."),
    Expanded( 
      child: Scrollbar(
        controller: _scrollController2,
        child: ListView.builder(
          controller: _scrollController2,
        itemCount: overview.numCategories,
        itemBuilder: (BuildContext context, int index){
          return DrawCategory(which: index, category: overview.categories[index]);
        }
        ),
      ),
    ),
    ]
    );
  }));
}
}

//Widget to select annotation data directory
class annDataSelect extends StatefulWidget{
  const annDataSelect({super.key,});

  @override
  _annDataSelectState createState() => _annDataSelectState();
}

class _annDataSelectState extends State<annDataSelect>{
  @override
  bool _selected = false;
  String _aPath = "";
  String _annPrompt = "Select directory containing annotated sequence database";

  Widget build(BuildContext context) {
    return Consumer3<OverviewData, HitLists,FileData>(
            builder: (context, overview, hitLists, filedata, child){
              return ElevatedButton(
                onPressed: () async {
                  String? annTemp = await FilePicker.platform.getDirectoryPath(dialogTitle: "Select directory containing annotated sequence database");
                  if (annTemp == null) {
                  } else {
                    setState(() {
                filedata._annotationsFile= annTemp;
                _selected = true;
                _annPrompt = "Annotations database: ${filedata._annotationsFile}";
                });
              }
          },
          child: Text(_annPrompt),
        );
      }
    );
  }
}

// Widget to select domtblout files
class domTblSelect extends StatefulWidget{
  const domTblSelect({super.key,});

  @override
  _domTblSelectState createState() => _domTblSelectState();
}

class _domTblSelectState extends State<domTblSelect>{
  @override
  bool _selected = false;
  String _dPath = "";
  String _dPrompt = "Select .domtblout files";

  Widget build(BuildContext context) {
    return Consumer3<OverviewData, HitLists,FileData>(
            builder: (context, overview, hitLists, filedata, child){
              return ElevatedButton(
                onPressed: () async {
                  FilePickerResult? dTemp = await FilePicker.platform.pickFiles(allowMultiple: true, dialogTitle: "Select .domtblout file(s)");
                  if (dTemp == null) {
                  } 
                  else {
                    setState(() {
                      filedata._domtbloutFiles = dTemp.paths.map((path) => path!).toList();
                      _selected = true;
                      _dPrompt = ".domtblout files: ${filedata._domtbloutFiles.join('\n')}"; // join the paths for display
                });
              }
          },
          child: Text(_dPrompt),
        );
      }
    );
  }
}

// Widget to enter information about what files to read
class FileForm extends StatefulWidget{
  const FileForm({super.key,});


  @override
  _FileFormState createState() => _FileFormState();
}

class _FileFormState extends State<FileForm>{
  String? _anntemp = "";
  List<Domain> temp=[];
  FilePickerResult? result; // used in file picker
  String _temp="";  // used in converting domtblout file input into list
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
 
  @override
  Widget build(BuildContext context){
    return Scaffold(
        appBar: AppBar(
          title: const Text("Hviewer"),
        ),
        body: 
          Center(
            child: Consumer3<OverviewData, HitLists,FileData>(
            builder: (context, overview, hitLists, filedata, child){
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      annDataSelect(),
                      domTblSelect(),
                      ],),
                  ElevatedButton(
                    onPressed: (){
                          const loadingSnackBar = SnackBar(
                            duration: Duration(days: 1),
                            backgroundColor: Colors.yellow,
                            content: Center(child: Text("Loading Data",
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 24,
                                fontFamily: 'FiraMono',
                                ),)));
                          ScaffoldMessenger.of(context).showSnackBar(loadingSnackBar);

                          _searchResults = loadData(annfile: filedata._annotationsFile, domtbloutFiles: filedata._domtbloutFiles);
                          ScaffoldMessenger.of(context).clearSnackBars();
                          if(!_searchResults.succeeded){
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            //duration: Duration(days: 1),
                            backgroundColor: Colors.red,
                            content: Center(child: Text("Load Failed: ${_searchResults.errMsg}",
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 24,
                                fontFamily: 'FiraMono',
                                ),))));
                          }
                          else{
                            overview.set(_searchResults.overview);
                            hitLists.init(_searchResults.overview.numCategories);
                            for(var iter1 = 0; iter1 < _searchResults.overview.numCategories; iter1++){
                              hitLists.set(iter1, _searchResults.hitLists[iter1]);
                            }
                              Navigator.pushNamed(context, '/overview');
                          }
                          //Navigator.pushNamed(context, '/overview');
                        },
                    child: const Text("Load Data"),
                    ),
                ],
              );
            }
          ),
        ),
      );
  }
}

//Widget to display a list of hits
class DrawHitList extends StatefulWidget{
  const DrawHitList({super.key,
  required this.which});

  final int which;
  @override
  State<DrawHitList> createState() => _DrawHitListState();
}

class _DrawHitListState extends State<DrawHitList>{
  final ScrollController _scrollController3 = ScrollController();
  @override
  Widget build(BuildContext context){
    return Material(child: Consumer<HitLists>(
            builder: (context, hitLists, child){
              return Column(children: [
                ElevatedButton(
                    onPressed: (){
                      Navigator.pushNamed(context, '/overview');
                    },
                    child: const Text("Back"),
                ),
                Text("${hitLists.hitLists[widget.which].numHits} hits found with domain structure ${hitLists.hitLists[widget.which].signature}"),
                Expanded( 
                  child: Scrollbar(
                  controller: _scrollController3,
                  child: ListView.builder(
                    controller: _scrollController3,
                    itemCount: hitLists.hitLists[widget.which].numHits,
                    itemBuilder: (BuildContext context, int index){
                      return DrawHit(hit: hitLists.hitLists[widget.which].hits[index]);
                    }
                  ),
                ),
                ),
              ],);
            }
    ),);
  }
}

// Sticking this here in global-land feels gross, but makes the flutter rust bridge happy and not crash.
SearchResults _searchResults = SearchResults(succeeded: false,
                                                errMsg: "",
                                                overview: ResultsOverview(numHits: 0, numCategories: 0, categories: []),
                                                hitLists: []
                                                );