/* main_page.dart: MainPage -- the first page a user sees, which lets them select the
 * annotated database and the domtblout/BLAST files they wish to view
 */

import 'package:material_ui/material_ui.dart';
import 'package:homot/main.dart';
import 'package:homot/utility.dart';
import 'package:homot/src/rust/api/graph.dart';
import 'package:provider/provider.dart';
import "package:go_router/go_router.dart";
import 'package:homot/pages/scroll_offsets.dart';

// Page to select the annotation database and the hit files to read
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final ScrollController _mainScrollController = ScrollController();
  String? dtemp;
  @override
  void dispose() {
    //ScaffoldMessenger.of(context).clearSnackBars();
    _mainScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.primary,
        appBar: HomotAppBar(text: "Select Data"),
        body: Consumer4<FileData, GraphData, SearchData, HSettings>(
          builder: (
            context,
            filedata,
            graphdata,
            searchdata,
            hsettings,
            child,
          ) {
            return Column(
              //mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  "Annotations Database:",
                ),

                AnnDbSelect(),

                Text(
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  "Search Result File(s):",
                ),
                Builder(
                  builder: (context) {
                    return Flexible(
                      child: Scrollbar(
                        controller: _mainScrollController,
                        child: ListView.builder(
                          shrinkWrap: true,
                          controller: _mainScrollController,
                          itemCount: filedata.domtbloutFiles.length,
                          itemBuilder: (BuildContext context, int index) {
                            return DomtblEdit(which: index);
                          },
                        ),
                      ),
                    );
                  },
                ),
                DomtblSelect(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    ElevatedButton(
                      onPressed:
                          filedata.domtbloutFiles.isNotEmpty
                              ? () async {
                                filedata.clearDomtbloutFiles();
                              }
                              : null,
                      child: Text(
                        "Clear",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                Center(
                  child: ElevatedButton(
                    onPressed:
                        !filedata.loading &&
                                filedata.annFileSet &&
                                filedata.domtbloutFiles.isNotEmpty
                            ? () async {
                              // Disable the button until this load finishes,
                              // however it finishes (success, error, or exception)
                              filedata.loading = true;
                              // Grab the messenger before the await so the
                              // loading snackbar can be cleared even if this
                              // page is disposed while the data loads.
                              final messenger = ScaffoldMessenger.of(context);
                              messenger.showSnackBar(
                                SnackBar(
                                  duration: Duration(days: 1),
                                  backgroundColor: Colors.yellow,
                                  content: Center(
                                    child: Text(
                                      "Loading Data",
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ),
                                ),
                              );
                              try {
                                //Gather hits from the domtblout files
                                var results = await (fetchGraph(
                                  annfile: filedata.annotationsFile,
                                  domtbloutFiles: filedata.domtbloutFiles,
                                  evalMax:
                                      hsettings.useSeqEvals
                                          ? hsettings.evalMax
                                          : double.infinity,
                                  evalMin:
                                      hsettings.useSeqEvals
                                          ? hsettings.evalMin
                                          : 0.0,
                                  domEvalMax:
                                      hsettings.useDomEvals
                                          ? hsettings.domEvalMax
                                          : double.infinity,
                                  domEvalMin:
                                      hsettings.useDomEvals
                                          ? hsettings.domEvalMin
                                          : 0.0,
                                  fileType: hsettings.dataType,
                                  interproShowSuperfamily:
                                      hsettings.showInterproSuperfamily,
                                  interproShowFamily:
                                      hsettings.showInterproFamily,
                                  interproShowDomain:
                                      hsettings.showInterproDomain,
                                  interproShowRepeat:
                                      hsettings.showInterproRepeat,
                                  interproShowSite: hsettings.showInterproSite,
                                  interproShowOther:
                                      hsettings.showInterproOther,
                                  interproShowPfamNames:
                                      (hsettings.showNamesFrom ==
                                          ShowNamesFrom.pfam),
                                ));
                                messenger.clearSnackBars();
                                if (!context.mounted) return;
                                // Update the overview data
                                // A successful load with no hits still returns a
                                // one-node graph (the taxonomy root), so check
                                // the hit list rather than the graph.
                                if (!results.succeeded ||
                                    results.hits.isEmpty ||
                                    results.graph.isEmpty) {
                                  String message;
                                  if (results.succeeded) {
                                    message =
                                        "No hits found that met reporting criteria";
                                  } else {
                                    message =
                                        "Data load failed.\n${results.message}";
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      //duration: Duration(days: 1),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(days: 100),
                                      content: Center(
                                        child: Column(
                                          children: [
                                            Text(message),
                                            ElevatedButton(
                                              child: Text(
                                                "Close",
                                                style: TextStyle(
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).colorScheme.onSurface,
                                                ),
                                              ),
                                              onPressed: () {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).hideCurrentSnackBar();
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                } else {
                                  allStructureScrollOffset = 0.0;
                                  allEvalueScrollOffset = 0.0;
                                  selectedStructureScrollOffset = 0.0;
                                  selectedEvalueScrollOffset = 0.0;
                                  //  print("${results.hits.length}");
                                  graphdata.clearGraph();
                                  graphdata.setGraph(results.graph);
                                  graphdata.setDepth(results.depth);
                                  graphdata.setMaxLevels(results.depth - 1);
                                  graphdata.clearDeletedNodes();
                                  graphdata.addRoot(
                                    results.root,
                                  ); // set the current root to the overall root
                                  graphdata.graphRoot =
                                      results
                                          .root; // and set the overall root as well.
                                  searchdata.setSearchResults(results);
                                  searchdata.selectedBy =
                                      SelectedBy.none; // reset selection
                                  searchdata.selectedHit = -1;
                                  context.go("/allstructure");
                                }
                              } catch (e) {
                                messenger.clearSnackBars();
                                var message2 =
                                    "Homot has encountered an exception while loading data.\nPlease check that you have specified a valid annotations database and search results file.\n$e";
                                // Use the captured messenger: this page's context
                                // may no longer be mounted after the await.
                                messenger.showSnackBar(
                                  SnackBar(
                                    //duration: Duration(days: 1),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(days: 100),
                                    content: Center(
                                      child: Column(
                                        children: [
                                          Text(message2),
                                          ElevatedButton(
                                            child: Text("Close"),
                                            onPressed: () {
                                              messenger.hideCurrentSnackBar();
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              } finally {
                                filedata.loading = false;
                              }
                            }
                            : null,
                    child: Text(
                      filedata.loading ? "Loading…" : "Load Data",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: MainNavBar(whereAmI: WhichPage.home),
      ),
    );
  }
}
