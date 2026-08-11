import 'package:clipshare/discovery/discovery_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseTxt', () {
    test('parses newline separated key=value entries', () {
      final map = parseTxt('name=my laptop\nver=0\nkey=abc123\n');
      expect(map, {
        'name': 'my laptop',
        'ver': '0',
        'key': 'abc123',
      });
    });

    test('skips malformed entries', () {
      final map = parseTxt('novalue\n\na=b=c\nx=1\n');
      expect(map, {'a': 'b=c', 'x': '1'});
    });
  });

  group('instanceFromPtr', () {
    test('extracts instance from ptr domain', () {
      expect(
        instanceFromPtr('a1b2c3._clipshare._tcp.local.'),
        'a1b2c3',
      );
    });

    test('returns input when type missing', () {
      expect(instanceFromPtr('a1b2c3._other._tcp.local.'), 'a1b2c3._other._tcp.local.');
    });
  });
}
