/* settings_page.dart: SettingsPage -- allows the user to configure the application
 */

import 'package:material_ui/material_ui.dart';
// input_quantity's QtyDecorationProps still expects flutter/material's InputBorder.
import 'package:flutter/material.dart'
    as fm
    show OutlineInputBorder, Material, MaterialType;
import 'package:homot/main.dart';
import 'package:homot/utility.dart';
import 'package:homot/graph_painter.dart';
import 'package:homot/src/rust/api/graph.dart';
import 'package:provider/provider.dart';
import 'package:input_quantity/input_quantity.dart';

// Page to control settings
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final evalMinNode = FocusNode();
  final eValMinTextController = TextEditingController();
  final evalMaxNode = FocusNode();
  final eValMaxTextController = TextEditingController();
  final domEvalMinNode = FocusNode();
  final domEValMinTextController = TextEditingController();
  final domEvalMaxNode = FocusNode();
  final domEValMaxTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final myProvider = Provider.of<HSettings>(context, listen: false);
    evalMinNode.addListener(() {
      if (!evalMinNode.hasFocus) {
        // try to update the value when we lose focus
        var parsed = num.tryParse(eValMinTextController.text);
        if (parsed != null &&
            parsed >= 0 &&
            parsed != myProvider.evalMin &&
            myProvider.useSeqEvals) {
          myProvider.evalMin = parsed.toDouble();
          _showReloadWarning();
        } else {
          // If the value is invalid, reset the text field to the current valid value
          eValMinTextController.text = myProvider.evalMin.toString();
        }
      }
    });
    evalMaxNode.addListener(() {
      if (!evalMaxNode.hasFocus) {
        // try to update the value when we lose focus
        var parsed = num.tryParse(eValMaxTextController.text);
        if (parsed != null &&
            parsed >= 0 &&
            parsed != myProvider.evalMax &&
            myProvider.useSeqEvals) {
          myProvider.evalMax = parsed.toDouble();
          _showReloadWarning();
        } else {
          // If the value is invalid, reset the text field to the current valid value
          eValMaxTextController.text = myProvider.evalMax.toString();
        }
      }
    });

    domEvalMinNode.addListener(() {
      if (!domEvalMinNode.hasFocus) {
        // try to update the value when we lose focus
        var parsed = num.tryParse(domEValMinTextController.text);
        if (parsed != null &&
            parsed >= 0 &&
            parsed != myProvider.domEvalMin &&
            myProvider.useDomEvals) {
          myProvider.domEvalMin = parsed.toDouble();
          _showReloadWarning();
        } else {
          // If the value is invalid, reset the text field to the current valid value
          domEValMinTextController.text = myProvider.domEvalMin.toString();
        }
      }
    });

    domEvalMaxNode.addListener(() {
      if (!domEvalMaxNode.hasFocus) {
        // try to update the value when we lose focus
        var parsed = num.tryParse(domEValMaxTextController.text);
        if (parsed != null &&
            parsed >= 0 &&
            parsed != myProvider.domEvalMax &&
            myProvider.useDomEvals) {
          myProvider.domEvalMax = parsed.toDouble();
          _showReloadWarning();
        } else {
          // If the value is invalid, reset the text field to the current valid value
          domEValMaxTextController.text = myProvider.domEvalMax.toString();
        }
      }
    });
  }

  @override
  void dispose() {
    evalMinNode.dispose();
    evalMaxNode.dispose();
    domEvalMinNode.dispose();
    domEvalMaxNode.dispose();
    eValMinTextController.dispose();
    eValMaxTextController.dispose();
    domEValMaxTextController.dispose();
    domEValMinTextController.dispose();
    super.dispose();
  }

  void _showReloadWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.yellow,
        duration: Duration(seconds: 3),
        content: Center(
          child: Text(
            "Data must be re-loaded for changes to e-value settings to take effect.",
            style: TextStyle(color: Colors.black),
          ),
        ),
      ),
    );
  }

  void _showEvalWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.yellow,
        duration: Duration(seconds: 3),
        content: Center(
          child: Text(
            "E-Value maximum threshold is below E-Value minimum threshold, no hits will be shown on reload.",
            style: TextStyle(color: Colors.black),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController mainScrollController = ScrollController();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: HomotAppBar(text: "Settings"),
      body: Consumer<HSettings>(
        builder: (context, hsettings, child) {
          return SingleChildScrollView(
            controller: mainScrollController,
            child: Column(
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      color: Theme.of(context).colorScheme.surface,
                      child: Column(
                        children: [
                          Text(
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium!.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            "Theme",
                          ),
                          RadioGroup<BrightModes>(
                            groupValue: hsettings.mode,
                            onChanged: (BrightModes? value) {
                              if (value != null) {
                                hsettings.mode = value;
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                IntrinsicWidth(
                                  child: RadioListTile<BrightModes>(
                                    title: Text('Light'),
                                    value: BrightModes.light,
                                  ),
                                ),
                                IntrinsicWidth(
                                  child: RadioListTile<BrightModes>(
                                    title: Text('Dark'),
                                    value: BrightModes.dark,
                                  ),
                                ),
                                IntrinsicWidth(
                                  child: RadioListTile<BrightModes>(
                                    title: Text('System'),
                                    value: BrightModes.system,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Card(
                      color: Theme.of(context).colorScheme.surface,
                      child: Column(
                        children: [
                          Text(
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium!.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            "Font Settings",
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6.0),
                                    child: Text(
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium!.copyWith(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                      ),
                                      "Font Family",
                                    ),
                                  ),
                                  HmmotSystemFontSelector(
                                    width: 200 * hsettings.scale,
                                    textStyle: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium!.copyWith(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    ),
                                    initial: hsettings.font,
                                    isFontPreviewEnabled: true,
                                    onFontSelected: (font) {
                                      hsettings.font = font;
                                    },
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6.0),
                                    child: Text(
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium!.copyWith(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                      ),
                                      "Font Scale Factor",
                                    ),
                                  ),
                                  _LegacyMaterial(
                                    child: InputQty.double(
                                      initVal: hsettings.scale,
                                      minVal: 0.001,
                                      steps: 0.1,
                                      decoration: QtyDecorationProps(
                                        qtyStyle: QtyStyle.btnOnRight,
                                        border: fm.OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      onQtyChanged: (val) {
                                        hsettings.scale = val;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Card(
                      color: Theme.of(context).colorScheme.surface,
                      child: Column(
                        children: [
                          Text(
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium!.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            "Draw Taxonomy As",
                          ),
                          RadioGroup<GraphDrawType>(
                            groupValue: hsettings.drawType,
                            onChanged: (GraphDrawType? value) {
                              if (value != null) {
                                hsettings.drawType = value;
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                IntrinsicWidth(
                                  child: RadioListTile<GraphDrawType>(
                                    title: Text('Lines'),
                                    value: GraphDrawType.line,
                                  ),
                                ),
                                IntrinsicWidth(
                                  child: RadioListTile<GraphDrawType>(
                                    title: Text('Arc Segments'),
                                    value: GraphDrawType.outline,
                                  ),
                                ),
                                IntrinsicWidth(
                                  child: RadioListTile<GraphDrawType>(
                                    title: Text('Filled Arc Segments'),
                                    value: GraphDrawType.fill,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Card(
                      color: Theme.of(context).colorScheme.surface,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium!.copyWith(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    ),
                                    "Graph Line Width",
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _LegacyMaterial(
                                        child: InputQty.double(
                                          initVal: hsettings.lineWidth,
                                          minVal: 0.5,
                                          steps: 0.5,
                                          decoration: QtyDecorationProps(
                                            qtyStyle: QtyStyle.btnOnRight,
                                            border: fm.OutlineInputBorder(
                                              borderSide: BorderSide(
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.onSurface,
                                              ),
                                            ),
                                          ),
                                          onQtyChanged: (val) {
                                            hsettings.lineWidth = val;
                                          },
                                        ),
                                      ),
                                      SizedBox(width: 20),
                                      CustomPaint(
                                        size: Size(50, 10),
                                        painter: LinePainter(
                                          context,
                                          hsettings,
                                          MediaQuery.of(
                                            context,
                                          ).devicePixelRatio,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IntrinsicWidth(
                            child: CheckboxListTile(
                              title: Text(
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium!.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                "Add Patterns to Filled Regions in Taxonomy and Structure",
                              ),
                              value: hsettings.addPatterns,
                              onChanged: (bool? value) {
                                if (value != null) {
                                  hsettings.addPatterns = value;
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Card(
                      color: Theme.of(context).colorScheme.surface,
                      child: Column(
                        children: [
                          Text(
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium!.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            "Search Result File Type",
                          ),
                          RadioGroup<DataFileType>(
                            groupValue: hsettings.dataType,
                            onChanged: (DataFileType? value) {
                              if (value != null) {
                                hsettings.dataType = value;
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                IntrinsicWidth(
                                  child: RadioListTile<DataFileType>(
                                    title: Text('HMMER domtblout'),
                                    value: DataFileType.domTblOut,
                                  ),
                                ),
                                IntrinsicWidth(
                                  child: RadioListTile<DataFileType>(
                                    title: Text('BLAST tabular'),
                                    value: DataFileType.blast,
                                  ),
                                ),
                                IntrinsicWidth(
                                  child: RadioListTile<DataFileType>(
                                    title: Text('Infer from file contents'),
                                    value: DataFileType.infer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Card(
                      color: Theme.of(context).colorScheme.surface,
                      child: IntrinsicWidth(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  checkColor:
                                      Theme.of(context).colorScheme.onPrimary,
                                  //fillColor: Theme.of(context).colorScheme.surface,
                                  value: hsettings.useSeqEvals,
                                  onChanged: (bool? value) {
                                    if (value != null) {
                                      hsettings.useSeqEvals = value;
                                    }
                                  },
                                ),
                                Text(
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  "Only show sequences with E-values in range",
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 6.0),
                                  child: Text(
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium!.copyWith(
                                      color:
                                          hsettings.useSeqEvals
                                              ? Theme.of(
                                                context,
                                              ).colorScheme.onSurface
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withAlpha(128),
                                    ),
                                    "Minimum:",
                                  ),
                                ),
                                IntrinsicWidth(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(minWidth: 200),
                                    child: TextFormField(
                                      enabled: hsettings.useSeqEvals,
                                      controller:
                                          eValMinTextController
                                            ..text =
                                                hsettings.evalMin.toString(),
                                      focusNode: evalMinNode,
                                      autovalidateMode:
                                          AutovalidateMode.onUserInteraction,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                          ),
                                        ),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                      ),
                                      onFieldSubmitted: (val) {
                                        var parsed = num.tryParse(val);
                                        if (parsed != null &&
                                            parsed >= 0 &&
                                            parsed != hsettings.evalMin) {
                                          hsettings.evalMin = parsed.toDouble();
                                          if (hsettings.evalMin >
                                              hsettings.evalMax) {
                                            // min > max means no hits will be shown
                                            _showEvalWarning();
                                          } else {
                                            _showReloadWarning();
                                          }
                                        } else {
                                          // If the value is invalid, reset the text field to the current valid value
                                          eValMinTextController.text =
                                              hsettings.evalMin.toString();
                                        }
                                      },
                                      validator: (String? value) {
                                        return !(value != null &&
                                                num.tryParse(value) != null &&
                                                num.tryParse(value)! >= 0)
                                            ? "Enter a number >= 0"
                                            : null;
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 6.0),
                                  child: Text(
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium!.copyWith(
                                      color:
                                          hsettings.useSeqEvals
                                              ? Theme.of(
                                                context,
                                              ).colorScheme.onSurface
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withAlpha(128),
                                    ),
                                    "Maximum:",
                                  ),
                                ),
                                IntrinsicWidth(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(minWidth: 200),
                                    child: TextFormField(
                                      enabled: hsettings.useSeqEvals,
                                      controller:
                                          eValMaxTextController
                                            ..text =
                                                hsettings.evalMax.toString(),
                                      focusNode: evalMaxNode,
                                      autovalidateMode:
                                          AutovalidateMode.onUserInteraction,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                          ),
                                        ),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                      ),
                                      onFieldSubmitted: (val) {
                                        var parsed = num.tryParse(val);
                                        if (parsed != null &&
                                            parsed >= 0 &&
                                            parsed != hsettings.evalMax) {
                                          hsettings.evalMax = parsed.toDouble();
                                          if (hsettings.evalMin >
                                              hsettings.evalMax) {
                                            // min > max means no hits will be shown
                                            _showEvalWarning();
                                          } else {
                                            _showReloadWarning();
                                          }
                                        } else {
                                          // If the value is invalid, reset the text field to the current valid value
                                          eValMaxTextController.text =
                                              hsettings.evalMax.toString();
                                        }
                                      },
                                      validator: (String? value) {
                                        return !(value != null &&
                                                num.tryParse(value) != null &&
                                                num.tryParse(value)! >= 0)
                                            ? "Enter a number >= 0"
                                            : null;
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      color: Theme.of(context).colorScheme.surface,
                      child: IntrinsicWidth(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  checkColor:
                                      Theme.of(context).colorScheme.onPrimary,
                                  //fillColor: Theme.of(context).colorScheme.surface,
                                  value: hsettings.useDomEvals,
                                  onChanged: (bool? value) {
                                    if (value != null) {
                                      hsettings.useDomEvals = value;
                                    }
                                  },
                                ),
                                Text(
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  "Only show domains with E-values in range\n (Only applicable to HMMER results)",
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 6.0),
                                  child: Text(
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium!.copyWith(
                                      color:
                                          hsettings.useDomEvals
                                              ? Theme.of(
                                                context,
                                              ).colorScheme.onSurface
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withAlpha(128),
                                    ),
                                    "Minimum:",
                                  ),
                                ),
                                IntrinsicWidth(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(minWidth: 200),
                                    child: TextFormField(
                                      enabled: hsettings.useDomEvals,
                                      controller:
                                          domEValMinTextController
                                            ..text =
                                                hsettings.domEvalMin.toString(),
                                      focusNode: domEvalMinNode,
                                      autovalidateMode:
                                          AutovalidateMode.onUserInteraction,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                          ),
                                        ),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                      ),
                                      onFieldSubmitted: (val) {
                                        var parsed = num.tryParse(val);
                                        if (parsed != null &&
                                            parsed >= 0 &&
                                            parsed != hsettings.domEvalMin) {
                                          hsettings.domEvalMin =
                                              parsed.toDouble();
                                          if (hsettings.domEvalMin >
                                              hsettings.domEvalMax) {
                                            // min > max means no hits will be shown
                                            _showEvalWarning();
                                          } else {
                                            _showReloadWarning();
                                          }
                                        } else {
                                          // If the value is invalid, reset the text field to the current valid value
                                          domEValMinTextController.text =
                                              hsettings.domEvalMin.toString();
                                        }
                                      },
                                      validator: (String? value) {
                                        return !(value != null &&
                                                num.tryParse(value) != null &&
                                                num.tryParse(value)! >= 0)
                                            ? "Enter a number >= 0"
                                            : null;
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 6.0),
                                  child: Text(
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium!.copyWith(
                                      color:
                                          hsettings.useDomEvals
                                              ? Theme.of(
                                                context,
                                              ).colorScheme.onSurface
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withAlpha(128),
                                    ),
                                    "Maximum:",
                                  ),
                                ),
                                IntrinsicWidth(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(minWidth: 200),
                                    child: TextFormField(
                                      enabled: hsettings.useDomEvals,
                                      controller:
                                          domEValMaxTextController
                                            ..text =
                                                hsettings.domEvalMax.toString(),
                                      focusNode: domEvalMaxNode,
                                      autovalidateMode:
                                          AutovalidateMode.onUserInteraction,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                          ),
                                        ),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                      ),
                                      onFieldSubmitted: (val) {
                                        var parsed = num.tryParse(val);
                                        if (parsed != null &&
                                            parsed >= 0 &&
                                            parsed != hsettings.domEvalMax) {
                                          hsettings.domEvalMax =
                                              parsed.toDouble();
                                          if (hsettings.domEvalMin >
                                              hsettings.domEvalMax) {
                                            // min > max means no hits will be shown
                                            _showEvalWarning();
                                          } else {
                                            _showReloadWarning();
                                          }
                                        } else {
                                          // If the value is invalid, reset the text field to the current valid value
                                          domEValMaxTextController.text =
                                              hsettings.domEvalMax.toString();
                                        }
                                      },
                                      validator: (String? value) {
                                        return !(value != null &&
                                                num.tryParse(value) != null &&
                                                num.tryParse(value)! >= 0)
                                            ? "Enter a number >= 0"
                                            : null;
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    /*                 Card(
                    color: Theme.of(context).colorScheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                      Text(style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium!.copyWith(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurface),
                          "InterPro Annotations (No Effect if Database Annotated From Another Source)"),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IntrinsicWidth(child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium!.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                "Show Annotations of Type(s)",
                              ),
                            CheckboxListTile(
                                title: Text(
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  "Superfamily",
                                ),
                                value: hsettings.showInterproSuperfamily,
                                onChanged: (bool? value) {
                                  if (value != null) {
                                    hsettings.showInterproSuperfamily = value;
                                  }
                                },
                              ),
                              CheckboxListTile(
                                title: Text(
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  "Family",
                                ),
                                value: hsettings.showInterproFamily,
                                onChanged: (bool? value) {
                                  if (value != null) {
                                    hsettings.showInterproFamily = value;
                                    _showReloadWarning();
                                  }
                                },
                              ),
                              CheckboxListTile(
                                title: Text(
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  "Domain",
                                ),
                                value: hsettings.showInterproDomain,
                                onChanged: (bool? value) {
                                  if (value != null) {
                                    hsettings.showInterproDomain = value;
                                    _showReloadWarning();
                                  }
                                },
                              ),

                              CheckboxListTile(
                                title: Text(
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  "Repeat",
                                ),
                                value: hsettings.showInterproRepeat,
                                onChanged: (bool? value) {
                                  if (value != null) {
                                    hsettings.showInterproRepeat = value;
                                    _showReloadWarning();
                                  }
                                },
                              ),
                              CheckboxListTile(
                                title: Text(
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  "Site",
                                ),
                                value: hsettings.showInterproSite,
                                onChanged: (bool? value) {
                                  if (value != null) {
                                    hsettings.showInterproSite = value;
                                    _showReloadWarning();
                                  }
                                },
                                
                              ),
                              CheckboxListTile(
                                title: Text(
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  "Other",
                                ),
                                value: hsettings.showInterproOther,
                                onChanged: (bool? value) {
                                  if (value != null) {
                                    hsettings.showInterproOther = value;
                                    _showReloadWarning();
                                  }
                                },
                              ),
                            ],
                          ),),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium!.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                "Show InterPro Annotations As",
                              ),
                              RadioGroup<ShowInterproIdEnum>(
                                groupValue: hsettings.showInterproIdAs,
                                onChanged: (ShowInterproIdEnum? value){
                                  if (value != null){
                                    hsettings.showInterproIdAs = value;
                                  }
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                  IntrinsicWidth( 
                                    child: RadioListTile<ShowInterproIdEnum>(
                                    title: Text('InterPro ID'),
                                    value: ShowInterproIdEnum.id,
                                  ),),
                                  IntrinsicWidth( 
                                    child: RadioListTile<ShowInterproIdEnum>(
                                    title: Text('InterPro Short Name (If Available)'),
                                    value: ShowInterproIdEnum.short_name,
                                  ),),
                                  IntrinsicWidth( 
                                    child: RadioListTile<ShowInterproIdEnum>(
                                  title: Text('InterPro Long Name (If Available)'),
                                    value: ShowInterproIdEnum.long_name,
                                  ),),
                                ],),
                              ),
                            ],
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium!.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                "Show Domain Names From",
                              ),
                              RadioGroup<ShowNamesFrom>(
                                groupValue: hsettings.showNamesFrom,
                                onChanged: (ShowNamesFrom? value){
                                  if (value != null){
                                    hsettings.showNamesFrom = value;
                                  }
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                  IntrinsicWidth( 
                                    child: RadioListTile<ShowNamesFrom>(
                                    title: Text('Pfam (If Available)'),
                                    value: ShowNamesFrom.pfam,
                                  ),),
                                  IntrinsicWidth( 
                                    child: RadioListTile<ShowNamesFrom>(
                                    title: Text('InterPro'),
                                    value: ShowNamesFrom.interpro,
                                  ),),
                                ],),
                              ),
                            ],
                          ),
                        ],
                      ),
                                            ],) 
                    ),*/
                  ],
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: MainNavBar(whereAmI: WhichPage.settings),
    );
  }
}

// input_quantity is still built on package:flutter/material, while this app uses
// package:material_ui.  Its widgets look for flutter/material's Theme,
// localizations and Material ancestor, which the material_ui widgets above them
// don't provide, so the page crashes with "No Material widget found".
// MaterialUiCompatibilityBridge supplies the legacy Theme (mapped from ours) and
// localizations; the transparent legacy Material satisfies the ancestor check
// without drawing anything.  Remove this once input_quantity moves to material_ui.
class _LegacyMaterial extends StatelessWidget {
  const _LegacyMaterial({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return MaterialUiCompatibilityBridge(
      child: fm.Material(type: fm.MaterialType.transparency, child: child),
    );
  }
}
