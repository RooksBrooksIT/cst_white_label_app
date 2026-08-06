import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../widgets/glass_scaffold.dart';

class PdfPreviewPage extends StatelessWidget {
  final Uint8List pdfBytes;
  final String fileName;

  const PdfPreviewPage({
    super.key,
    required this.pdfBytes,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;

    return GlassScaffold(
      title: 'Report Preview',
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: PdfPreview(
        build: (format) => pdfBytes,
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        maxPageWidth: 700,
        pdfFileName: fileName,
        loadingWidget: const Center(child: CircularProgressIndicator()),
      ),
        ),
      ),
    );
  }
}
