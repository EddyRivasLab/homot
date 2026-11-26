/* subtree_structure_page.dart: SubtreeStructurePage -- hits below the selected subtree, grouped by domain structure
 */

import 'dart:math';
import 'package:material_ui/material_ui.dart';
import 'package:homot/main.dart';
import 'package:homot/utility.dart';
import 'package:homot/draw_data.dart';
import 'package:homot/src/rust/api/graph.dart';
import 'package:provider/provider.dart';
import 'package:homot/pages/scroll_offsets.dart';

// Widget that displays all hits to the selected subtree by structure
class SubtreeStructurePage extends StatefulWidget {
  const SubtreeStructurePage({super.key});

  @override
  State<SubtreeStructurePage> createState() => _SubtreeStructurePageState();
}

class _SubtreeStructurePageState extends State<SubtreeStructurePage> {
  final ScrollController _subtreeStructureScrollController = ScrollController(
    initialScrollOffset: selectedStructureScrollOffset,
    onDetach: (position) {
      selectedStructureScrollOffset = position.pixels;
    },
  );
  List<int> lengths = [];

  @override
  void dispose() {
    _subtreeStructureScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Consumer3<SearchData, GraphData, HSettings>(
        builder: (context, searchdata, graphdata, hsettings, child) {
          final List<SigCategory> theHits = searchdata.currentHits;
          int numHits = 0;
          for (var category in theHits) {
            numHits += category.hits.length;
          }
          final hitCount = numHits == 0 || numHits > 1 ? "hits" : "hit";
          final strucText =
              theHits.length > 1
                  ? "different domain structures"
                  : "domain structure";
          if (lengths.length != theHits.length) {
            lengths = List.filled(theHits.length, 0);
          }
          for (int i = 0; i < theHits.length; i++) {
            lengths[i] = searchdata.hits[theHits[i].hits[0].toInt()].seqLength;
          }
          lengths.sort((a, b) => a < b ? -1 : 1);
          int maxLength = lengths.isNotEmpty ? lengths.reduce(max) : 1;
          if (lengths.isNotEmpty &&
              (0.75 * maxLength > lengths[(lengths.length * 0.9).toInt()])) {
            //       print("changing maxlength from $maxLength to ${lengths[(lengths.length * 0.9).toInt()]}");
            maxLength = lengths[(lengths.length * 0.9).toInt()];
          }
          double ppr = pixelsPerResidue(
            maxLength,
            Theme.of(context).textTheme,
            context,
          );
          //      print("pixels per residue $ppr");
          return SelectionArea(
            child: Scaffold(
              backgroundColor: Theme.of(context).colorScheme.primary,
              appBar: HomotAppBar(
                text:
                    "$numHits $hitCount found under ${graphdata.graph[graphdata.currentRoot]?.name}, with ${theHits.length} $strucText",
              ),
              body: Scrollbar(
                controller: _subtreeStructureScrollController,
                child: ListView.builder(
                  controller: _subtreeStructureScrollController,
                  itemCount: theHits.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      color: Theme.of(context).colorScheme.surface,
                      child: Stack(
                        //crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DrawCategory(
                            which: index,
                            from: SelectedBy.subtreeStructure,
                            context: context,
                            maxLength: maxLength,
                            pixelsPerResidue: ppr,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              bottomNavigationBar: MainNavBar(
                whereAmI: WhichPage.subgraphstructure,
              ),
            ),
          );
        },
      ),
    );
  }
}
