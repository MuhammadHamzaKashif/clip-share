import 'dart:convert';
import 'dart:typed_data';

import 'package:clipshare/platform/clipboard_watcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('windows output parsing', () {
    test('parses text frames', () async {
      final watcher = ClipboardWatcher();
      final events = <ClipboardChange>[];
      final sub = watcher.changes.listen(events.add);
      final bytes = BytesBuilder();
      bytes.add(utf8.encode('TEXT:5\nhello'));
      bytes.add(utf8.encode('TEXT:6\nworld!'));
      watcher.parseForTest(bytes);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(events, hasLength(2));
      expect(events[0].kind, ClipboardKind.text);
      expect(events[0].payload, 'hello');
      expect(events[1].payload, 'world!');
      sub.cancel();
    });

    test('parses image frames with base64 payload', () async {
      final watcher = ClipboardWatcher();
      final events = <ClipboardChange>[];
      final sub = watcher.changes.listen(events.add);
      final payload = base64Encode(Uint8List.fromList(List.generate(64, (i) => i)));
      final frame = 'IMG:${payload.length}\n$payload';
      final bytes = BytesBuilder();
      bytes.add(utf8.encode(frame));
      bytes.add(utf8.encode('TEXT:3\nabc'));
      watcher.parseForTest(bytes);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(events, hasLength(2));
      expect(events[0].kind, ClipboardKind.image);
      expect(base64Decode(events[0].payload), List.generate(64, (i) => i));
      expect(events[1].kind, ClipboardKind.text);
      sub.cancel();
    });

    test('handles frames split across chunks', () async {
      final watcher = ClipboardWatcher();
      final events = <ClipboardChange>[];
      final sub = watcher.changes.listen(events.add);
      final frame = 'TEXT:5\nhello';
      final bytes = BytesBuilder();
      for (var i = 0; i < frame.length; i++) {
        bytes.add(utf8.encode(frame[i]));
        watcher.parseForTest(bytes);
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(events, hasLength(1));
      expect(events.single.payload, 'hello');
      sub.cancel();
    });

    test('dedupes repeated frames with same signature', () async {
      final watcher = ClipboardWatcher();
      final events = <ClipboardChange>[];
      final sub = watcher.changes.listen(events.add);
      final bytes = BytesBuilder();
      bytes.add(utf8.encode('TEXT:5\nhello'));
      watcher.parseForTest(bytes);
      watcher.parseForTest(bytes);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(events, hasLength(1));
      sub.cancel();
    });
  });
}
