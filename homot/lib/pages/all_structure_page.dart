/* all_structure_page.dart: AllStructurePage -- all hits, grouped by domain structure
 */

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:homot/main.dart';
import 'package:homot/utility.dart';
import 'package:homot/draw_data.dart';
import 'package:homot/src/rust/api/graph.dart';
import 'package:provider/provider.dart';
import 'package:homot/pages/scroll_offsets.dart';

// Widget that displays all results by structure
class AllStructurePage extends StatefulWidget {
  const AllStructurePage({super.key});

  @override
  State<AllStructurePage> createState() => _AllStructurePageState();
}

class _AllStructurePageState extends State<AllStructurePage> {
  final ScrollController _allStructureScrollController = ScrollController(
    initialScrollOffset: allStructureScrollOffset,
    onDetach: (position) {
      allStructureScrollOffset = position.pixels;
    },
  );
  List<int> lengths = [];

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SelectionArea(
        child: Consumer3<SearchData, GraphData, HSettings>(
          builder: (context, searchdata, graphdata, hsettings, child) {
            final List<SigCategory> theHits = searchdata.rootHits;
            if (lengths.length != theHits.length) {
              lengths = List.filled(theHits.length, 0);
            }
            for (int i = 0; i < theHits.length; i++) {
              lengths[i] =
                  searchdata
                      .hits[searchdata.rootHits[i].hits[0].toInt()]
                      .seqLength;
            }
            lengths.sort((a, b) => a < b ? -1 : 1);
            int maxLength = lengths.isNotEmpty ? lengths.reduce(max) : 1;
            if (lengths.isNotEmpty &&
                (0.75 * maxLength > lengths[(lengths.length * 0.9).toInt()])) {
              //     print("changing maxlength from $maxLength to ${lengths[(lengths.length * 0.9).toInt()]}");
              maxLength = lengths[(lengths.length * 0.9).toInt()];
            }
            double ppr = pixelsPerResidue(
              maxLength,
              Theme.of(context).textTheme,
              context,
            );
            int numHits = searchdata.hits.length;
            final hitCount = numHits != 1 ? "hits" : "hit";
            final strucText =
                theHits.length != 1
                    ? "different domain structures"
                    : "domain structure";

            return Scaffold(
              backgroundColor: Theme.of(context).colorScheme.primary,
              appBar: HomotAppBar(
                text:
                    "$numHits $hitCount found, with ${theHits.length} $strucText",
              ),
              body: Scrollbar(
                controller: _allStructureScrollController,
                child: ListView.builder(
                  controller: _allStructureScrollController,
                  itemCount: theHits.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      color: Theme.of(context).colorScheme.surface,
                      child: DrawCategory(
                        which: index,
                        from: SelectedBy.structure,
                        context: context,
                        maxLength: maxLength,
                        pixelsPerResidue: ppr,
                      ),
                    );
                  },
                ),
              ),
              bottomNavigationBar: MainNavBar(whereAmI: WhichPage.allstructure),
            );
          },
        ),
      ),
    );
  }
}
