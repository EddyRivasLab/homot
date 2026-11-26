/* all_evalue_page.dart: AllEvaluePage -- all hits, sorted by e-value
 */

import 'dart:math';
import 'package:material_ui/material_ui.dart';
import 'package:homot/main.dart';
import 'package:homot/utility.dart';
import 'package:homot/draw_data.dart';
import 'package:provider/provider.dart';
import "package:go_router/go_router.dart";
import 'package:homot/pages/scroll_offsets.dart';

// Widget that displays all results by evalue
class AllEvaluePage extends StatefulWidget {
  const AllEvaluePage({super.key});

  @override
  State<AllEvaluePage> createState() => _AllEvaluePageState();
}

class _AllEvaluePageState extends State<AllEvaluePage> {
  final ScrollController _allEvalueScrollController = ScrollController(
    initialScrollOffset: allEvalueScrollOffset,
    onDetach: (position) {
      allEvalueScrollOffset = position.pixels;
    },
  );
  List<bool> fullWidth = [];
  List<bool> showExpand = [];
  List<int> lengths = [];

  @override
  void dispose() {
    _allEvalueScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SelectionArea(
        child: Consumer3<SearchData, GraphData, HSettings>(
          builder: (context, searchdata, graphdata, hsettings, child) {
            if (fullWidth.length != searchdata.hits.length) {
              // something has changed, reset the fullwidth list
              fullWidth = List.filled(searchdata.hits.length, false);
              showExpand = List.filled(searchdata.hits.length, false);
              lengths = List.filled(searchdata.hits.length, 0);
            }
            int maxLength = 0;
            for (int i = 0; i < searchdata.hits.length; i++) {
              lengths[i] = searchdata.hits[i].seqLength;
            }
            maxLength = lengths.isNotEmpty ? lengths.reduce(max) : 1;
            lengths.sort((a, b) => a < b ? -1 : 1);
            if (lengths.isNotEmpty &&
                (0.75 * maxLength > lengths[(lengths.length * 0.9).toInt()])) {
              //       print("changing maxlength from $maxLength to ${lengths[(lengths.length * 0.9).toInt()]}");
              maxLength = lengths[(lengths.length * 0.9).toInt()];
            }
            final screenWidth = MediaQuery.sizeOf(context).width;
            double ppr = pixelsPerResidue(
              maxLength,
              Theme.of(context).textTheme,
              context,
            );
            return Scaffold(
              backgroundColor: Theme.of(context).colorScheme.primary,
              appBar: HomotAppBar(text: "${searchdata.hits.length} hits found"),
              body: Scrollbar(
                controller: _allEvalueScrollController,
                child: ListView.builder(
                  controller: _allEvalueScrollController,
                  itemCount: searchdata.hits.length,
                  itemBuilder: (BuildContext context, int index) {
                    showExpand[index] =
                        (requiredHitWidth(
                              searchdata.hits[index],
                              false,
                              false,
                              context,
                            ) >
                            screenWidth) ||
                        (searchdata.hits[index].seqLength > maxLength);
                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      color: Theme.of(context).colorScheme.surface,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                overflow: TextOverflow.clip,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium!.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                "Sequence: ${searchdata.hits[index].name}"
                                "\nE-Value: ${searchdata.hits[index].seqEvalue.toStringAsExponential(2)}"
                                "\nTaxon: ${graphdata.graph[searchdata.hits[index].taxid]!.name}"
                                "\nDescription: ${searchdata.hits[index].description}",
                              ),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  showExpand[index]
                                      ? RotatedBox(
                                        quarterTurns: 1,
                                        child: IconButton.outlined(
                                          iconSize: 24 * hsettings.scale,

                                          onPressed: () {
                                            fullWidth[index] =
                                                !fullWidth[index];
                                            setState(() {});
                                          },
                                          icon:
                                              fullWidth[index]
                                                  ? Icon(
                                                    Icons.compress,
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.onSurface,
                                                  )
                                                  : Icon(
                                                    Icons.expand,
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.onSurface,
                                                  ),
                                        ),
                                      )
                                      : SizedBox.shrink(),
                                  IconButton.outlined(
                                    iconSize: 24 * hsettings.scale,
                                    onPressed: () {
                                      searchdata.selectedHit = index;
                                      context.go("/sequence");
                                    },
                                    icon: Icon(
                                      Icons.search,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          DrawHit(
                            hit: searchdata.hits[index],
                            searchdata: searchdata,
                            fullWidth: fullWidth[index],
                            maxLength: maxLength,
                            pixelsPerResidue: ppr,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              bottomNavigationBar: MainNavBar(whereAmI: WhichPage.allevalue),
            );
          },
        ),
      ),
    );
  }
}
