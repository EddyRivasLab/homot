/* pages.dart: the different pages used in HMMot.
 * Each page lives in its own file under lib/pages/; this file re-exports them so
 * that code can keep importing 'package:homot/pages.dart'.
 *
 * MainPage -- select the annotation database and hit files to view
 * SettingsPage -- configure the application
 * GraphPage -- display the taxonomy graph
 * AllStructurePage / AllEvaluePage -- all hits, by domain structure or e-value
 * SubtreeStructurePage / SubtreeEvaluePage -- selected hits, by domain structure or e-value
 * SequencePage -- details for a single sequence
 *
NPC: 8/19/25 [The Cushy Office]
*/

export 'package:homot/pages/scroll_offsets.dart';
export 'package:homot/pages/main_page.dart';
export 'package:homot/pages/settings_page.dart';
export 'package:homot/pages/graph_page.dart';
export 'package:homot/pages/all_structure_page.dart';
export 'package:homot/pages/all_evalue_page.dart';
export 'package:homot/pages/subtree_structure_page.dart';
export 'package:homot/pages/subtree_evalue_page.dart';
export 'package:homot/pages/sequence_page.dart';
