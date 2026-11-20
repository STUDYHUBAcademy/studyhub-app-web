import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../widgets/whiteboard_background.dart';
import '../widgets/whiteboard_canvas.dart';
import '../widgets/whiteboard_controller.dart';
import '../widgets/whiteboard_toolbar.dart';

/// A canvas the owner can open directly — to jot something down or try the
/// drawing tools on an uploaded file — without going through the full
/// "new assignment" form first.
class QuickCanvasScreen extends StatefulWidget {
  const QuickCanvasScreen({super.key});

  @override
  State<QuickCanvasScreen> createState() => _QuickCanvasScreenState();
}

class _QuickCanvasScreenState extends State<QuickCanvasScreen> {
  final _controller = WhiteboardController();
  Uint8List? _backgroundBytes;
  String _backgroundType = 'image';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    final file = files.firstOrNull;
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final isPdf = file.extension?.toLowerCase() == 'pdf';
    setState(() {
      _backgroundBytes = bytes;
      _backgroundType = isPdf ? 'pdf' : 'image';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سبورة سريعة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: 'ارفع ملف للكتابة عليه',
            onPressed: _pickFile,
          ),
        ],
      ),
      body: Column(
        children: [
          WhiteboardToolbar(controller: _controller),
          Expanded(
            child: WhiteboardCanvas(
              controller: _controller,
              background: _backgroundBytes == null
                  ? null
                  : WhiteboardBackground(
                      bytes: _backgroundBytes!,
                      sourceType: _backgroundType,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
