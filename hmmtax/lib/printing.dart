import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:hmmtax/main.dart';
import 'package:hmmtax/utility.dart';
import 'package:hmmtax/pages.dart';
import 'package:hmmtax/graph_painter.dart';
import 'package:hmmtax/draw_data.dart';
import 'package:hmmtax/src/rust/api/graph.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:input_quantity/input_quantity.dart';
import 'package:system_fonts/system_fonts.dart';
import "package:go_router/go_router.dart";
import 'package:touchable/touchable.dart';
import 'package:matrix4_transform/matrix4_transform.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void printGraphToPdf(String filename, PlatformInt64 root, Map<PlatformInt64, Node> graph, double width, double height) async{
  final document = pw.Document();
  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(width*72, height*72),
      build: (pw.Context context) {
        return pw.Text("test");
  // Center
      },
    ),
  );
  final file = File(filename);
  await file.writeAsBytes(await document.save());
}