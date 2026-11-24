/* subtree_evalue_page.dart: SubtreeEvaluePage -- the selected set of hits, sorted by e-value
 */

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:homot/main.dart';
import 'package:homot/utility.dart';
import 'package:homot/draw_data.dart';
import 'package:provider/provider.dart';
import "package:go_router/go_router.dart";
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:homot/pages/scroll_offsets.dart';

// Widget that displays a subtree's results by evalue
class SubtreeEvaluePage extends StatefulWidget {
  const SubtreeEvaluePage({super.key});

  @override
  State<SubtreeEvaluePage> createState() => _SubtreeEvaluePageState();
}

class _SubtreeEvaluePageState extends State<SubtreeEvaluePage> {
  final ScrollController _subtreeEvalueScrollController = ScrollController(
    initialScrollOffset: selectedEvalueScrollOffset,
    onDetach: (position) {
      selectedEvalueScrollOffset = position.pixels;
    },
  );
  List<bool> fullWidth = [];
  List<bool> showExpand = [];
  List<int> lengths = [];
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Consumer3<SearchData, GraphData, HSettings>(
        builder: (context, searchdata, graphdata, hsettings, child) {
          Int64List hitIndices = Int64List(0);
          String title = "";
          switch (searchdata.selectedBy) {
            case SelectedBy.subtree:
              hitIndices = searchdata.currentHitsByEvalue;
              title =
                  "${hitIndices.length} hits found under node ${graphdata.getNode(graphdata.currentRoot).name}";
              break;
            case SelectedBy.subtreeStructure:
              hitIndices =
                  searchdata.currentHits[searchdata.selectedStructure].hits;
              title =
                  "${hitIndices.length} hits found with structure ${searchdata.structures[searchdata.currentHits[searchdata.selectedStructure].signature]} under node ${graphdata.getNode(graphdata.currentRoot).name}";
              break;
            case SelectedBy.structure:
              hitIndices =
                  searchdata.rootHits[searchdata.selectedStructure].hits;
              title =
                  "${hitIndices.length} hits found with structure ${searchdata.structures[searchdata.rootHits[searchdata.selectedStructure].signature]}";
              break;
            default:
              hitIndices = Int64List(0);
          }
          if ((fullWidth.length != hitIndices.length) ||
              (searchdata.selectedBy != searchdata.previousSelectedBy)) {
            // something has changed, reset the fullwidth list
            fullWidth = List.filled(hitIndices.length, false);
            showExpand = List.filled(hitIndices.length, false);
            lengths = List.filled(hitIndices.length, 0);
            searchdata.previousSelectedBy = searchdata.selectedBy;
          }
          final screenWidth = MediaQuery.sizeOf(context).width;
          for (int i = 0; i < hitIndices.length; i++) {
            lengths[i] = searchdata.hits[hitIndices[i].toInt()].seqLength;
          }
          int maxLength = lengths.isNotEmpty ? lengths.reduce(max) : 1;
          //   print("max length is $maxLength");
          lengths.sort((a, b) => a < b ? -1 : 1);
          if (lengths.isNotEmpty &&
              (0.75 * maxLength > lengths[(lengths.length * 0.9).toInt()])) {
            //         print("changing maxlength from $maxLength to ${lengths[(lengths.length * 0.9).toInt()]}");
            maxLength = lengths[(lengths.length * 0.9).toInt()];
          }
          double ppr = pixelsPerResidue(
            maxLength,
            Theme.of(context).textTheme,
            context,
          );

          return SelectionArea(
            child: Scaffold(
              backgroundColor: Theme.of(context).colorScheme.primary,
              appBar: HomotAppBar(text: title),
              body: Scrollbar(
                controller: _subtreeEvalueScrollController,
                child: ListView.builder(
                  controller: _subtreeEvalueScrollController,
                  itemCount: hitIndices.length,
                  itemBuilder: (BuildContext context, int index) {
                    showExpand[index] =
                        requiredHitWidth(
                              searchdata.hits[hitIndices[index].toInt()],
                              false,
                              false,
                              context,
                            ) >
                            screenWidth ||
                        (searchdata.hits[hitIndices[index].toInt()].seqLength >
                            maxLength);
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
                                "Sequence: ${searchdata.hits[hitIndices[index].toInt()].name}"
                                "\nE-Value: ${searchdata.hits[hitIndices[index].toInt()].seqEvalue.toStringAsExponential(4)}"
                                "\nTaxon: ${graphdata.graph[searchdata.hits[hitIndices[index].toInt()].taxid]!.name}"
                                "\nDescription: ${searchdata.hits[hitIndices[index].toInt()].description}",
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
                                      searchdata.selectedHit =
                                          hitIndices[index].toInt();
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
                            hit: searchdata.hits[hitIndices[index].toInt()],
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
              bottomNavigationBar: MainNavBar(
                whereAmI: WhichPage.subtreeevalue,
              ),
            ),
          );
        },
      ),
    );
  }
}
