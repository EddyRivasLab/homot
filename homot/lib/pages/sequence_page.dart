/* sequence_page.dart: SequencePage -- details for a single sequence
 */

import 'package:flutter/material.dart';
import 'package:homot/main.dart';
import 'package:homot/utility.dart';
import 'package:homot/draw_data.dart';
import 'package:homot/src/rust/api/graph.dart';
import 'package:provider/provider.dart';

// Page that shows the details for a single sequence
class SequencePage extends StatefulWidget {
  const SequencePage({super.key});

  @override
  State<SequencePage> createState() => _SequencePageState();
}

class _SequencePageState extends State<SequencePage> {
  bool fullWidth = false;
  bool showExpand = false;
  final ScrollController _scrollController2 = ScrollController();
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return Material(
      child: Consumer3<SearchData, GraphData, HSettings>(
        builder: (context, searchdata, graphdata, hsettings, child) {
          Hit theHit = searchdata.hits[searchdata.selectedHit.toInt()];
          showExpand =
              requiredHitWidth(theHit, true, true, context) > screenWidth;
          return SelectionArea(
            child: Scaffold(
              backgroundColor: Theme.of(context).colorScheme.primary,
              appBar: HomotAppBar(text: "Sequence ${theHit.name}"),
              body: SingleChildScrollView(
                controller: _scrollController2,
                child: Card(
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
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            "Sequence: ${theHit.name}"
                            "\nE-Value: ${theHit.seqEvalue.toStringAsExponential(4)}"
                            "\nTaxon: ${graphdata.graph[theHit.taxid]!.name}"
                            "\nDescription: ${theHit.description}",
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              showExpand
                                  ? RotatedBox(
                                    quarterTurns: 1,
                                    child: IconButton.outlined(
                                      iconSize: 24 * hsettings.scale,

                                      onPressed: () {
                                        fullWidth = !fullWidth;
                                        setState(() {});
                                      },
                                      icon:
                                          fullWidth
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
                            ],
                          ),
                        ],
                      ),
                      DrawHit(
                        hit: theHit,
                        allDomains: true,
                        searchdata: searchdata,
                        fullWidth: fullWidth,
                        showSequence: true,
                        sequence: theHit.sequence,
                        maxLength: theHit.seqLength,
                        pixelsPerResidue: pixelsPerResidue(
                          theHit.seqLength,
                          Theme.of(context).textTheme,
                          context,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              bottomNavigationBar: MainNavBar(whereAmI: WhichPage.sequence),
            ),
          );
        },
      ),
    );
  }
}
