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
    settings
  }
class MainNavBar extends StatelessWidget {
  const MainNavBar({super.key,
                    required this.whereAmI});
  final WhichPage whereAmI;

  
  static const List<String> _routes = <String>[
    "/",
    "/overview",
    "/category",
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
                icon: Icon(Icons.details,
                color: (whereAmI != WhichPage.category) &&hitLists.selected >=0  ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).disabledColor),
                enabled: (whereAmI != WhichPage.category) && hitLists.selected >=0,
                label: 'Category View',
              ),
            ],
          ),
        );
      },
    );
  }
}


