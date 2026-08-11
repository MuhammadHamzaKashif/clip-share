import 'dart:typed_data';

enum ItemKind { text, image }

class ClipboardItem {
  const ClipboardItem({
    required this.itemId,
    required this.kind,
    required this.source,
    required this.timestamp,
    this.text,
    this.imageBytes,
  });

  final String itemId;
  final ItemKind kind;
  final String? text;
  final Uint8List? imageBytes;
  final String source;
  final DateTime timestamp;
}
