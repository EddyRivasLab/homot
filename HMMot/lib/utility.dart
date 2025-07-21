import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:HMMot/src/rust/api/gather_hits.dart';
import 'package:HMMot/src/rust/frb_generated.dart';
import 'package:HMMot/main.dart';
import 'package:HMMot/pages.dart';
import 'package:HMMot/draw_data.dart';
import 'package:osler_icons/osler_icons.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:input_quantity/input_quantity.dart';
import "dart:io";
import "package:go_router/go_router.dart";
import "dart:developer";

import 'package:flutter/material.dart';
import 'package:system_fonts/system_fonts.dart';


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
  State<HmmotSystemFontSelector> createState() => _HmmotSystemFontSelectorState();
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
      textStyle: widget.textStyle != null
          ? widget.textStyle!.copyWith(fontFamily: widget.isFontPreviewEnabled ? widget.initial : null)
          : Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontFamily: widget.isFontPreviewEnabled ? widget.initial : null, overflow: TextOverflow.ellipsis),
      dropdownMenuEntries: fontNames.map<DropdownMenuEntry<String>>((String value) {
        return DropdownMenuEntry<String>(
          value: value,
          label: value,
          style: MenuItemButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            backgroundColor: Theme.of(context).colorScheme.surface,
              textStyle: widget.textStyle != null
                  ? widget.textStyle!.copyWith(fontFamily: widget.isFontPreviewEnabled ? value : null)
                  : Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontFamily: widget.isFontPreviewEnabled ? value : null, overflow: TextOverflow.ellipsis)),
        );
      }).toList(),
    );
  }
}


class HmmotAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HmmotAppBar({
    super.key,
    required this.text,
  });

  final String text;
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
    Widget build(BuildContext context) {
      return AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: Text(
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
          text
        ),
        leading: NonMacMenuBar(),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            color: Theme.of(context).colorScheme.onPrimary,
            tooltip: "Settings",
            onPressed: () {
                context.go("/settings");
            },
          ),
          
        ]
      );
    }
}

enum WhichPage{
    home,
    overview,
    category,
    settings,
    sequence,
  }
class MainNavBar extends StatelessWidget {
  const MainNavBar({super.key,
                    required this.whereAmI});
  final WhichPage whereAmI;

  
  static const List<String> _routes = <String>[
    "/",
    "/overview",
    "/category",
    "/sequence",
  ];


  @override
  Widget build(BuildContext context) {
    return Consumer2<OverviewData, HitLists>(
      builder: (context, overview, hitLists, child) {
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
              context.go(_routes[index]);
            },
            destinations: <Widget>[
              NavigationDestination(
                icon: Icon(Icons.home,
                color: whereAmI != WhichPage.home ?Theme.of(context).colorScheme.onPrimary: Theme.of(context).disabledColor),
                enabled: whereAmI != WhichPage.home,
                tooltip: "",
                label: 'Select Data',
              ),
              NavigationDestination(
                icon: Icon(Icons.public,
                color: (whereAmI != WhichPage.overview) && overview.overviewLoaded ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).disabledColor),
                enabled: (whereAmI != WhichPage.overview) && overview.overviewLoaded,
                tooltip: "",
                label: 'All Results',
              ),
              NavigationDestination(
                icon: Icon(Icons.search,
                color: (whereAmI != WhichPage.category) &&hitLists.selected >=0  ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).disabledColor),
                enabled: (whereAmI != WhichPage.category) && hitLists.selected >=0,
                tooltip: "",
                label: 'Domain Structure',
              ),
              NavigationDestination(
                icon: Icon(OslerMonotoneIcons.dna,
                color: (whereAmI != WhichPage.sequence) &&hitLists.sequence >=0  ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).disabledColor),
                enabled: (whereAmI != WhichPage.sequence) && hitLists.sequence >=0,
                tooltip:"",
                label: 'Sequence',
              ),
            ],
          ),
        );
      },
    );
  }
}

class AnnDbSelect extends StatefulWidget{
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
    if(context.read<FileData>().annotationsFile.isEmpty){
      myController.text = "None Selected";
    }
    else{
      myController.text = context.read<FileData>().annotationsFile;
    }
  }

  Widget build(BuildContext context) {
    return Consumer<FileData>(
      builder: (context, filedata, child) {
        return Card(
          color: Theme.of(context).colorScheme.surface,
          child: Row(children: [
          Expanded(child: TextFormField(
            controller: myController,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onFieldSubmitted: (String? value) async{
              if(value != null&& Directory(value).existsSync()){filedata.setAnnotationsFile(value);
                  }},
            validator: (String? value){
              return(value == null || !Directory(value).existsSync()) ? "Must be valid  directory path":null;
            },
        ),),
        IconButton(icon: Icon(Icons.folder),
        color: Theme.of(context).colorScheme.onSurface,
          onPressed: () async {
            String? dTemp = await FilePicker.platform.getDirectoryPath(
              initialDirectory: filedata.annFileDir,
              dialogTitle: "Select .annotated database directory",
            );
            if (dTemp == null) {
            } else {
                  if (Directory(dTemp).existsSync()) {
                    filedata.setAnnotationsFile(dTemp);
                    myController.text = dTemp;
                  }
                };
          },),
        ],),);
      }
    );
  }
}
class DomtblSelect extends StatefulWidget{
  const DomtblSelect({super.key});
  @override
  State<DomtblSelect> createState() => _DomtblSelectState();
}
class _DomtblSelectState extends State<DomtblSelect> {
  final myController = TextEditingController();

  @override
  void initState() {
    super.initState();
    myController.text = "Select or enter .domtblout file(s)";
  }
    Widget build(BuildContext context) {
    return Consumer<FileData>(
      builder: (context, filedata, child) {
        return Card(
          color: Theme.of(context).colorScheme.surface,
          child: Row(children: [
          Expanded(child: TextFormField(style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),
            controller: myController,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onFieldSubmitted: (String? value) async{
              if(value != null&& File(value).existsSync()){filedata.addDomtbloutFile(value);
                  myController.text = "Select or enter .domtblout file(s)"; 
                  }},
            validator: (String? value){
              return(value == null || !File(value).existsSync()) ? "Must be valid filename":null;
            },
        ),),
        IconButton(icon: Icon(Icons.folder),
        color: Theme.of(context).colorScheme.onSurface,
          onPressed: () async {
            FilePickerResult? dTemp = await FilePicker.platform.pickFiles(
              initialDirectory: filedata.domtbloutFileDir,
              allowMultiple: true,
              dialogTitle: "Select .domtblout file(s)",
            );
            if (dTemp == null) {
            } else {
                for (String? path in dTemp.paths) {
                  if (path != null && File(path).existsSync()) {
                    filedata.addDomtbloutFile(path);
                    print(filedata.domtbloutFiles);
                  }
                }
              };
          },),
        ],),);
      }
    );
  }
}

class DomtblEdit extends StatelessWidget{  
  const DomtblEdit({
    super.key,
    required this.which,
  });

  final int which;

  Widget build(BuildContext context) {
    return Consumer<FileData>(
      builder: (context, filedata, child) {
        return Card(
          color: Theme.of(context).colorScheme.surface,
          child: Row(children: [
          Expanded(child: TextFormField(style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface),
            initialValue: (which >=0 && which < filedata.domtbloutFiles.length)? filedata.domtbloutFiles[which]: "Illegal index passed to DomTblEdit",
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onFieldSubmitted: (String? value) async{
              if(value != null&& File(value).existsSync()&& which >=0 && which < filedata.domtbloutFiles.length)
              {filedata.setDomtbloutFile(which, value);
                  }},
            validator: (String? value){
              return(value == null || !File(value).existsSync()) ? "Must be valid filename":null;
            },
        ),),
        IconButton(icon: Icon(Icons.delete),
        color: Theme.of(context).colorScheme.onSurface,
          onPressed: () { if(which >=0 && which < filedata.domtbloutFiles.length){
            filedata.deleteDomtbloutFile(filedata.domtbloutFiles[which]);
            filedata.notifyListeners;
      }},),
        ],),);
      });
  }
}

class Pair<T1, T2>{
  final T1 a;
  final T1 b;

  Pair(this.a, this.b);
}