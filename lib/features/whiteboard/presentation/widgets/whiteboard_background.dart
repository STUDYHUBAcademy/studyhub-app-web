import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// Renders a question's uploaded source as the canvas background — a single
/// image, or every page of a PDF rasterized and stacked vertically so a
/// multi-page worksheet can be solved page by page, scrolling down through
/// it the way Inkodo/Samsung Notes let you write over an imported document.
class WhiteboardBackground extends StatefulWidget {
  const WhiteboardBackground({
    super.key,
    required this.bytes,
    required this.sourceType,
  });

  final Uint8List bytes;
  final String sourceType; // 'pdf' | 'image'

  @override
  State<WhiteboardBackground> createState() => _WhiteboardBackgroundState();
}

class _WhiteboardBackgroundState extends State<WhiteboardBackground> {
  late final Future<List<Uint8List>> _pages = _render();

  Future<List<Uint8List>> _render() async {
    if (widget.sourceType != 'pdf') return [widget.bytes];
    final doc = await PdfDocument.openData(widget.bytes);
    final pages = <Uint8List>[];
    for (var i = 1; i <= doc.pagesCount; i++) {
      final page = await doc.getPage(i);
      final rendered = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.png,
      );
      await page.close();
      if (rendered != null) pages.add(rendered.bytes);
    }
    await doc.close();
    return pages;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Uint8List>>(
      future: _pages,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final pages = snapshot.data!;
        return Column(
          children: [
            for (final p in pages)
              Image.memory(p, width: double.infinity, fit: BoxFit.fitWidth),
          ],
        );
      },
    );
  }
}
