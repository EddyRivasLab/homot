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
              Navigator.popAndPushNamed(
                context,
                "/settings"
              );
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
              Navigator.popAndPushNamed(context, _routes[index]);
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
/*
enum FontList{
  courierPrime,
  firaCode,
  inconsolata,
  lato,
  notoSans,
  sourceCodePro,
  sourceSans,
  sourceSerif
}

class FontPicker extends StatefulWidget {
  const FontPicker({super.key});

  @override
  State<FontPicker> createState() => _fontPickerState();
}
class _fontPickerState extends State<FontPicker> {
  FontList? _font = FontList.courierPrime;
  @override
  Widget build(BuildContext context) {
    return Consumer<HSettings>(
      builder: (context, htheme, child) {
        _font = switch(htheme.font){
      "Courier Prime" => FontList.courierPrime,
      "Inconsolata" => FontList.inconsolata,
      "Fira Code" => FontList.firaCode,
      "Lato" => FontList.lato,
      "Noto Sans" => FontList.notoSans,
      _ => FontList.courierPrime
    };
        return Column(
          children: [
            Text("Font"),
            ListTile(
              title: Text("Courier Prime", style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontFamily: "Courier Prime"), textAlign: TextAlign.start),
              leading: Radio<FontList>(
                value: FontList.courierPrime,
                groupValue: _font,
                onChanged: (FontList? value) {
                  setState(() {
                    htheme.setFont("Courier Prime");
                  _font = FontList.courierPrime;
                  });
                },
              ),
            ),
            ListTile(
              title: Text("Fira Code", style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontFamily: "Fira Code"), textAlign: TextAlign.start),
              leading: Radio<FontList>(
                value: FontList.firaCode,
                groupValue: _font,
                onChanged: (FontList? value) {
                  setState(() {
                    htheme.setFont("Fira Code");
                  });
                  _font = FontList.firaCode;
                },
              ),
            ),
                        ListTile(
              title: Text("Inconsolata", style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontFamily: "Inconsolata"), textAlign: TextAlign.start),
              leading: Radio<FontList>(
                value: FontList.inconsolata,
                groupValue: _font,
                onChanged: (FontList? value) {
                  setState(() {
                    htheme.setFont("Inconsolata");
                    _font = FontList.inconsolata;
                  });
                },
              ),
            ),
            ListTile(
              title: Text("Lato", style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontFamily: "Lato Bold"), textAlign: TextAlign.start),
              leading: Radio<FontList>(
                value: FontList.lato,
                groupValue: _font,
                onChanged: (FontList? value) {
                  setState(() {
                    htheme.setFont("Lato");
                  });
                  _font = FontList.lato;
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
*/
