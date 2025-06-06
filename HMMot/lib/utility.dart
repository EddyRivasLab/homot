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
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:input_quantity/input_quantity.dart';
import "dart:io";
import "package:go_router/go_router.dart";

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
                label: 'Select Data',
              ),
              NavigationDestination(
                icon: Icon(Icons.public,
                color: (whereAmI != WhichPage.overview) && overview.overviewLoaded ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).disabledColor),
                enabled: (whereAmI != WhichPage.overview) && overview.overviewLoaded,
                label: 'All Results',
              ),
              NavigationDestination(
                icon: Icon(Icons.search,
                color: (whereAmI != WhichPage.category) &&hitLists.selected >=0  ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).disabledColor),
                enabled: (whereAmI != WhichPage.category) && hitLists.selected >=0,
                label: 'Domain Architecture',
              ),
              NavigationDestination(
                icon: Icon(Icons.search,
                color: (whereAmI != WhichPage.sequence) &&hitLists.sequence >=0  ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).disabledColor),
                enabled: (whereAmI != WhichPage.sequence) && hitLists.sequence >=0,
                label: 'Sequence',
              ),
            ],
          ),
        );
      },
    );
  }
}

class AnnDbSelect extends StatelessWidget{
    Widget build(BuildContext context) {
    return Consumer<FileData>(
      builder: (context, filedata, child) {
        return Card(child: Row(children: [
          Expanded(child: TextFormField(style: Theme.of(context).textTheme.bodyMedium,
            initialValue: "Select or enter annotated database directory",
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onFieldSubmitted: (String? value) async{
              if(value != null&& Directory(value).existsSync()){filedata.setAnnotationsFile(value);
                  }},
            validator: (String? value){
              return(value == null || !Directory(value).existsSync()) ? "Must be valid  directory path":null;
            },
        ),),
        IconButton(icon: Icon(Icons.folder),
          onPressed: () async {
            FilePickerResult? dTemp = await FilePicker.platform.pickFiles(
              initialDirectory: filedata.annFileDir,
              allowMultiple: false,
              dialogTitle: "Select .annotated database directory",
            );
            if (dTemp == null) {
            } else {
                for (String? path in dTemp.paths) {
                  if (path != null && File(path).existsSync()) {
                    filedata.setAnnotationsFile(path);
                  }
                }
              };
          },),
        ],),);
      }
    );
  }
}
class DomtblSelect extends StatelessWidget{
    Widget build(BuildContext context) {
    return Consumer<FileData>(
      builder: (context, filedata, child) {
        return Card(child: Row(children: [
          Expanded(child: TextFormField(style: Theme.of(context).textTheme.bodyMedium,
            initialValue: "Select or enter .domtblout file(s)",
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onFieldSubmitted: (String? value) async{
              if(value != null&& File(value).existsSync()){filedata.addDomtbloutFile(value);
                  }},
            validator: (String? value){
              return(value == null || !File(value).existsSync()) ? "Must be valid filename":null;
            },
        ),),
        IconButton(icon: Icon(Icons.folder),
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
        return Card(child: Row(children: [
          Expanded(child: TextFormField(style: Theme.of(context).textTheme.bodyMedium,
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
          onPressed: () { if(which >=0 && which < filedata.domtbloutFiles.length){
            filedata.deleteDomtbloutFile(filedata.domtbloutFiles[which]);
              };
          },),
        ],),);
      });
  }
}

class Pair<T1, T2>{
  final T1 a;
  final T1 b;

  Pair(this.a, this.b);
}