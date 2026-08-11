enum ItemKind { text, image }

class ClipboardItem {
  const ClipboardItem({
    required this.itemId,
    required this.kind,
    required this.source,
    required this.timestamp,
    this.text,
  });

  final String itemId;
  final ItemKind kind;
  final String? text;
  final String source;
  final DateTime timestamp;
}
