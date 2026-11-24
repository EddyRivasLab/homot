/* graph_page.dart: GraphPage -- displays the taxonomy graph
 */

import 'dart:math';
import 'package:material_ui/material_ui.dart';
import 'package:homot/main.dart';
import 'package:homot/utility.dart';
import 'package:homot/graph_painter.dart';
import 'package:homot/src/rust/api/graph.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:homot/pages/scroll_offsets.dart';

// Page to display taxonmomy graph
class GraphPage extends StatefulWidget {
  const GraphPage({super.key});

  @override
  _GraphPageState createState() => _GraphPageState();
}

class _GraphPageState extends State<GraphPage> {
  double scaleFactor = 1.0;
  OverlayEntry? _nodeOverlayEntry;
  OverlayEntry? _removedNodesOverlayEntry;
  OverlayEntry? _norootOverlayEntry;

  // Recompute the "selected subtree" hit lists for the node now at the center of
  // the graph.  findHitsBelowNode throws (the Rust Err string) if the graph and hit
  // data are inconsistent; in that case leave the previous selection alone and
  // tell the user rather than letting the exception escape the event handler.
  void _selectSubtree(GraphData graphdata, SearchData searchdata) {
    try {
      final HitResults hitResults = findHitsBelowNode(
        root: graphdata.currentRoot,
        graph: graphdata.graph,
        hitStructures: searchdata.hitStructures,
      );
      searchdata.currentHitsByEvalue = hitResults.hits;
      searchdata.currentHits = hitResults.categories;
      searchdata.selectedBy = SelectedBy.subtree;
      selectedStructureScrollOffset = 0.0;
      selectedEvalueScrollOffset = 0.0;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text(
            "Unable to find hits below this node: $e",
            style: TextStyle(color: Theme.of(context).colorScheme.onError),
          ),
        ),
      );
    }
  }

  void _removeAllOverlays() {
    _removeNorootOverlay();
    _removeNodeOverlay();
    _removeRemovedNodesOverlay();
  }

  // Displays an overlay showing information about the node clicked
  void _showNodeOverlay(
    BuildContext context,
    Offset tapPosition,
    Node theNode,
    GraphData graphdata,
  ) {
    String children = "";
    for (var child in theNode.children) {
      var childNode = graphdata.getNode(child.toInt());
      if (children != "") {
        children += ", ";
      }
      children += childNode.name;
    }

    String parentName = graphdata.getNode(theNode.parent).name;
    // Declare this once because we have to render it twice
    Widget theWidget = Container(
      constraints: BoxConstraints(maxWidth: graphdata.size.width / 2),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            spreadRadius: 5,
            blurRadius: 7,
            offset: Offset(3, 3),
          ),
        ],
      ),
      child: Column(
        // Size to the contents: the pop-up's layout allows up to the full
        // window height, which a default (max-size) Column would fill.
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Taxon: ${theNode.name}\nRank: ${theNode.rank}\nParent: $parentName\nChildren: $children\n${theNode.hitsBelow} hits at or below this node\n",
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          IntrinsicWidth(
            child: Align(
              alignment: AlignmentGeometry.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith((
                          states,
                        ) {
                          if (states.contains(WidgetState.disabled)) {
                            return Theme.of(
                              context,
                            ).colorScheme.primary.withAlpha(128);
                          } else {
                            return Theme.of(context).colorScheme.primary;
                          }
                        }),
                      ),
                      onPressed:
                          (theNode.taxid != theNode.parent)
                              ? () {
                                // Don't let user delete the root node
                                graphdata.deleteNode(theNode.taxid);
                                Overlay.of(context).setState(() {
                                  _removeAllOverlays();
                                });
                              }
                              : null,
                      child: Text(
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        "Remove Node from Graph",
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith((
                          states,
                        ) {
                          if (states.contains(WidgetState.disabled)) {
                            return Theme.of(
                              context,
                            ).colorScheme.primary.withAlpha(128);
                          } else {
                            return Theme.of(context).colorScheme.primary;
                          }
                        }),
                      ),
                      onPressed:
                          graphdata.deletedNodes.isNotEmpty
                              ? () {
                                Overlay.of(context).setState(() {
                                  _removeAllOverlays();
                                  _showRemovedNodesOverlay(
                                    context,
                                    tapPosition,
                                    theNode,
                                  );
                                });
                              }
                              : null,
                      child: Text(
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        "Show Removed Nodes",
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        return Theme.of(context).colorScheme.primary;
                      }),
                    ),
                    onPressed: () {
                      Overlay.of(context).setState(() {
                        _removeAllOverlays();
                      });
                    },
                    child: Text(
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      "Close",
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    _nodeOverlayEntry = OverlayEntry(
      builder: (context) {
        return CustomSingleChildLayout(
          delegate: _OnScreenPopupDelegate(tapPosition),
          child: Material(child: theWidget),
        );
      },
    );
    Overlay.of(context).insert(_nodeOverlayEntry!);
  }

  void _removeNodeOverlay() {
    _nodeOverlayEntry?.remove();
    _nodeOverlayEntry = null;
  }

  // Shows an overlay with a list of nodes that have been removed from the graph
  void _showRemovedNodesOverlay(
    BuildContext context,
    Offset tapPosition,
    Node theNode,
  ) {
    //      String parentName = graphdata.getNode(theNode.parent).name;
    ScrollController mainScrollController = ScrollController();
    // Declare this once because we have to render it twice
    Widget theWidget = Consumer<GraphData>(
      builder: (context, graphdata, child) {
        return Scrollbar(
          controller: mainScrollController,
          child: ListView.builder(
            shrinkWrap: true,
            controller: mainScrollController,
            itemCount: graphdata.deletedNodes.length,
            itemBuilder: (BuildContext context, int index) {
              return Card(
                margin: EdgeInsets.only(bottom: 8),
                color: Theme.of(context).colorScheme.surface,
                child: Row(
                  children: [
                    Text(graphdata.getNode(graphdata.deletedNodes[index]).name),
                    TextButton(
                      child: Text("Restore"),
                      onPressed: () {
                        graphdata.restoreNode(graphdata.deletedNodes[index]);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    _removedNodesOverlayEntry = OverlayEntry(
      builder: (context) {
        return Consumer<GraphData>(
          builder: (context, graphdata, child) {
            return CustomSingleChildLayout(
              delegate: _OnScreenPopupDelegate(tapPosition),
              child: SizedBox(
                width: graphdata.size.width / 4,
                child: Material(child: theWidget),
              ),
            );
          },
        );
      },
    );
    Overlay.of(context).insert(_removedNodesOverlayEntry!);
  }

  void _removeRemovedNodesOverlay() {
    _removedNodesOverlayEntry?.remove();
    _removedNodesOverlayEntry = null;
  }

  // shows a warning Overlay because it is not possible to re-center the graph on a node
  void _showNorootOverlay(
    BuildContext context,
    Offset tapPosition,
    PlatformInt64 nodeId,
    Node theNode,
  ) {
    _norootOverlayEntry = OverlayEntry(
      builder:
          (context) => CustomSingleChildLayout(
            delegate: _OnScreenPopupDelegate(tapPosition),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.yellow,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  "Node ${theNode.name} has no children",
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ),
          ),
    );
    Overlay.of(context).insert(_norootOverlayEntry!);
  }

  void _removeNorootOverlay() {
    _norootOverlayEntry?.remove();
    _norootOverlayEntry = null;
  }

  @override
  void dispose() {
    _removeAllOverlays();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double value = max(context.watch<GraphData>().maxLevels.toDouble(), 1.0);
    double rotation = context.watch<GraphData>().rotation * (360 / (2 * pi));
    double scale = context.watch<GraphData>().scale;
    double xOffset = context.watch<GraphData>().translateX;
    double yOffset = context.watch<GraphData>().translateY;

    final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    //final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: HomotAppBar(text: "Taxonomic Display"),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          var width = constraints.maxWidth;
          var height = constraints.maxHeight;
          var center = Offset(width / 2, height / 2);
          var radius =
              (min(width, height) /
                  2.0); // Leave a little space around the graph
          var availSpace = radius * 0.3;
          var legendHeight = availSpace;
          var legendWidth = availSpace;
          if (height > width) {
            legendHeight += (height - width) / 2.0;
          }
          if (width > height) {
            legendWidth += (width - height) / 2.0;
          }

          return Consumer3<HSettings, GraphData, SearchData>(
            builder: (context, hsettings, graphdata, searchdata, child) {
              graphdata.size = Size(width, height);
              return Stack(
                children: [
                  GestureDetector(
                    onTapDown: (details) {
                      _removeAllOverlays();
                      final Matrix4 inverseMatrix = Matrix4.inverted(
                        graphdata.transform,
                      );
                      final Vector3 untransformed = inverseMatrix.transform3(
                        Vector3(
                          details.localPosition.dx,
                          details.localPosition.dy,
                          0,
                        ),
                      );
                      var node = graphdata.findNode(
                        untransformed.x,
                        untransformed.y,
                        center.dx,
                        center.dy,
                      );
                      if (node >= 0 && node != graphdata.currentRoot) {
                        // click was in the graph and on a different node than the current root

                        graphdata.popPastIndex();
                        graphdata.addRoot(node);
                        _selectSubtree(graphdata, searchdata);

                        if (graphdata.getNode(node).children.isEmpty) {
                          _showNorootOverlay(
                            context,
                            details.globalPosition,
                            node,
                            graphdata.getNode(node),
                          );
                          Future.delayed(const Duration(seconds: 5), () {
                            _removeNorootOverlay();
                          });
                        }
                      }
                    },
                    onSecondaryTapDown: (details) {
                      _removeAllOverlays(); // Remove any existing overlay
                      final Matrix4 inverseMatrix = Matrix4.inverted(
                        graphdata.transform,
                      );
                      final Vector3 untransformed = inverseMatrix.transform3(
                        Vector3(
                          details.localPosition.dx,
                          details.localPosition.dy,
                          0,
                        ),
                      );
                      var node = graphdata.findNode(
                        untransformed.x,
                        untransformed.y,
                        center.dx,
                        center.dy,
                      );
                      if (node >= 0) {
                        var theNode = graphdata.getNode(node);
                        _showNodeOverlay(
                          context,
                          details.globalPosition,
                          theNode,
                          graphdata,
                        );
                      }
                    },

                    child: Transform(
                      transform: graphdata.transform,
                      child: CustomPaint(
                        size: Size(width, height),
                        painter: GraphPainter(
                          context,
                          graphdata,
                          devicePixelRatio,
                          graphdata.tController,
                          radius,
                          hsettings,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          SizedBox(
                            height: legendHeight,
                            width: legendWidth,
                            child: Card(
                              color: Theme.of(context).colorScheme.surface,
                              child: Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,

                                      children: [
                                        Ink(
                                          decoration: ShapeDecoration(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                            shape: CircleBorder(),
                                          ),
                                          child: IconButton(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onPrimary,
                                            icon: const Icon(Icons.arrow_back),
                                            onPressed: () {
                                              graphdata.decrementIndex();
                                              _selectSubtree(
                                                graphdata,
                                                searchdata,
                                              );
                                            },
                                          ),
                                        ),
                                        Text(
                                          "Graph Center History",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium!.copyWith(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                          ),
                                        ),
                                        Ink(
                                          decoration: ShapeDecoration(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                            shape: CircleBorder(),
                                          ),
                                          child: IconButton(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onPrimary,
                                            icon: const Icon(
                                              Icons.arrow_forward,
                                            ),
                                            onPressed: () {
                                              graphdata.incrementIndex();
                                              _selectSubtree(
                                                graphdata,
                                                searchdata,
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    Flexible(
                                      child: ScrollablePositionedList.separated(
                                        itemCount: graphdata.historyLength,
                                        itemScrollController:
                                            graphdata.itemScrollController,
                                        separatorBuilder: (
                                          BuildContext context,
                                          int index,
                                        ) {
                                          return SizedBox(height: 2);
                                        },
                                        itemBuilder: (
                                          BuildContext context,
                                          int index,
                                        ) {
                                          String label;
                                          if (index == graphdata.historyIndex) {
                                            label =
                                                "(Current) ${graphdata.historyNames(index)}";
                                          } else {
                                            label = graphdata.historyNames(
                                              index,
                                            );
                                          }
                                          return ElevatedButton(
                                            style: ButtonStyle(
                                              backgroundColor:
                                                  WidgetStateProperty.resolveWith(
                                                    (states) {
                                                      return Theme.of(
                                                        context,
                                                      ).colorScheme.primary;
                                                    },
                                                  ),
                                            ),
                                            onPressed: () {
                                              if (graphdata.history(index) >=
                                                  0) {
                                                graphdata.setRoot(
                                                  graphdata.history(index),
                                                );
                                                graphdata.setHistoryIndex(
                                                  index,
                                                );
                                                _selectSubtree(
                                                  graphdata,
                                                  searchdata,
                                                );
                                              }
                                            },
                                            child: Center(
                                              child: Text(
                                                label,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium!
                                                    .copyWith(
                                                      color:
                                                          Theme.of(context)
                                                              .colorScheme
                                                              .onPrimary,
                                                    ),
                                              ),
                                            ),
                                          );
                                        },
                                        //scrollDirection: Axis.vertical,
                                        //shrinkWrap: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: legendHeight,
                            width: legendWidth,
                            child: Card(
                              color: Theme.of(context).colorScheme.surface,
                              child: Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Graph Levels Shown: ${min(graphdata.maxLevels, (graphdata.depth - (graphdata.graph[graphdata.currentRoot]!.ranknum)))}",
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium!.copyWith(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          "1",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium!.copyWith(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                          ),
                                        ),
                                        Expanded(
                                          child: Slider(
                                            value: value,
                                            label: value.round().toString(),
                                            min: 1.0,
                                            max: max(
                                              1.0,
                                              graphdata.depth.toDouble(),
                                            ),
                                            divisions: max(1, graphdata.depth-1),
                                            onChanged: (double value) {
                                              setState(() {
                                                graphdata.setMaxLevels(
                                                  value.toInt(),
                                                );
                                              });
                                            },
                                          ),
                                        ),
                                        Text(
                                          "${graphdata.depth}",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium!.copyWith(
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
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          SizedBox(
                            height: legendHeight,
                            width: legendWidth,
                            child: Card(
                              color: Theme.of(context).colorScheme.surface,
                              child: Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          "X Position:",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium!.copyWith(
                                            height: 1,
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                          ),
                                        ),
                                        Expanded(
                                          child: Slider(
                                            // Clamp so a window shrink can't put the
                                            // value outside [min, max] (Slider asserts)
                                            value: xOffset.clamp(-width, width),
                                            label: xOffset.round().toString(),
                                            min: -width,
                                            max: width,
                                            onChanged: (double xOffset) {
                                              setState(() {
                                                graphdata.translateX = xOffset;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          "Y Position:",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium!.copyWith(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                          ),
                                        ),
                                        Expanded(
                                          child: Slider(
                                            value: yOffset.clamp(
                                              -height,
                                              height,
                                            ),
                                            label: yOffset.toStringAsFixed(2),
                                            min: -height,
                                            max: height,
                                            onChanged: (double yOffset) {
                                              setState(() {
                                                graphdata.translateY = yOffset;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: legendHeight,
                            width: legendWidth,
                            child: Card(
                              color: Theme.of(context).colorScheme.surface,
                              child: Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          "Rotation: 0",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium!.copyWith(
                                            height: 1,
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                          ),
                                        ),
                                        Expanded(
                                          child: Slider(
                                            value: rotation,
                                            label: rotation.round().toString(),
                                            min: 0.0,
                                            max: 360.0,
                                            onChanged: (double rotation) {
                                              setState(() {
                                                graphdata.setRotation(
                                                  (rotation) * (2 * pi / 360),
                                                );
                                              });
                                            },
                                          ),
                                        ),
                                        Text(
                                          "360",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium!.copyWith(
                                            height: 1,
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          "Scale: 0.25",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium!.copyWith(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                          ),
                                        ),
                                        Expanded(
                                          child: Slider(
                                            value: scale,
                                            label: scale.toStringAsFixed(2),
                                            min: 0.25,
                                            max: 5.0,
                                            onChanged: (double scale) {
                                              setState(() {
                                                graphdata.scale = scale;
                                              });
                                            },
                                          ),
                                        ),
                                        Text(
                                          "5",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium!.copyWith(
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
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: MainNavBar(whereAmI: WhichPage.graph),
    );
  }
}

// Positions a pop-up overlay at the tap location (in global coordinates, which
// match the overlay's), but shifts it left/up as needed so that it stays
// entirely on screen.  Flutter hands the delegate the pop-up's laid-out size,
// so this works on the first frame without measuring the widget separately.
class _OnScreenPopupDelegate extends SingleChildLayoutDelegate {
  _OnScreenPopupDelegate(this.anchor);

  final Offset anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final double x = max(0.0, min(anchor.dx, size.width - childSize.width));
    final double y = max(0.0, min(anchor.dy, size.height - childSize.height));
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_OnScreenPopupDelegate oldDelegate) =>
      oldDelegate.anchor != anchor;
}
