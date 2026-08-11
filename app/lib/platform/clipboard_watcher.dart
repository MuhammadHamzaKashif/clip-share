import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class ClipboardWatcher {
  final _changes = StreamController<String>.broadcast();
  Stream<String> get changes => _changes.stream;

  Process? _process;
  Timer? _pollTimer;
  String _lastSeen = '';
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    if (Platform.isWindows) {
      _startWindowsWatcher();
    } else if (Platform.isLinux) {
      _poll(const ['wl-paste', '-n'], const ['wl-copy']);
    } else if (Platform.isMacOS) {
      _poll(const ['pbpaste'], const ['pbcopy']);
    }
  }

  Future<void> _startWindowsWatcher() async {
    const script = r'''
Add-Type -AssemblyName System.Windows.Forms
$script:last = ''
$ts = New-Object System.Windows.Forms.Timer
$ts.Interval = 400
$ts.Add_Tick({
  try {
    $t = [System.Windows.Forms.Clipboard]::GetText()
    if ($t -ne $script:last) {
      $script:last = $t
      $b = [Text.Encoding]::UTF8.GetBytes("LEN:$($t.Length)`n$t")
      $stdout = [Console]::OpenStandardOutput()
      $stdout.Write($b, 0, $b.Length)
      $stdout.Flush()
    }
  } catch {}
})
$ts.Start()
[System.Windows.Forms.Application]::Run()
''';
    try {
      _process = await Process.start('powershell', [
        '-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-Command', script,
      ]);
      _readWindowsOutput(_process!.stdout);
      _process!.exitCode.then((_) {
        if (_started) {
          _changes.addError(StateError('clipboard watcher exited'));
          _process = null;
        }
      });
    } catch (_) {}
  }

  Future<void> _readWindowsOutput(Stream<List<int>> stream) async {
    final buffer = BytesBuilder();
    await for (final chunk in stream) {
      buffer.add(chunk);
      _parseWindowsOutput(buffer);
    }
  }

  void _parseWindowsOutput(BytesBuilder buffer) {
    while (true) {
      final bytes = buffer.toBytes();
      final lenIndex = _indexOf(bytes, utf8.encode('LEN:'));
      if (lenIndex < 0) {
        buffer.clear();
        return;
      }
      final rest = bytes.sublist(lenIndex);
      final newline = rest.indexOf(10);
      if (newline < 0) return;
      final header = utf8.decode(rest.sublist(0, newline), allowMalformed: true);
      final length = int.tryParse(header.substring(4));
      if (length == null) {
        buffer.clear();
        return;
      }
      if (rest.length < newline + 1 + length) return;
      final text = utf8.decode(
          rest.sublist(newline + 1, newline + 1 + length),
          allowMalformed: true);
      buffer.clear();
      if (text != _lastSeen) {
        _lastSeen = text;
        if (!_changes.isClosed) {
          _changes.add(text);
        }
      }
      if (rest.length > newline + 1 + length) {
        buffer.add(rest.sublist(newline + 1 + length));
      }
    }
  }

  int _indexOf(List<int> haystack, List<int> needle) {
    outer:
    for (var i = 0; i <= haystack.length - needle.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  Future<void> _poll(List<String> readCmd, List<String> writeCmd) async {
    _lastSeen = await _readClipboard(readCmd);
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final text = await _readClipboard(readCmd);
        if (text != _lastSeen) {
          _lastSeen = text;
          if (!_changes.isClosed) {
            _changes.add(text);
          }
        }
      } catch (_) {}
    });
  }

  Future<String> _readClipboard(List<String> cmd) async {
    final result = await Process.run(cmd.first, cmd.sublist(1));
    if (result.exitCode != 0) return '';
    return (result.stdout as String).trim();
  }

  Future<void> setText(String text) async {
    if (Platform.isWindows) {
      final process = await Process.start('powershell', [
        '-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-Command',
        r'$t = [Console]::In.ReadToEnd(); Set-Clipboard -Value $t',
      ]);
      process.stdin.write(text);
      await process.stdin.close();
      await process.exitCode;
    } else if (Platform.isLinux) {
      final process = await Process.start('wl-copy', []);
      process.stdin.write(text);
      await process.stdin.close();
      await process.exitCode;
    } else if (Platform.isMacOS) {
      final process = await Process.start('pbcopy', []);
      process.stdin.write(text);
      await process.stdin.close();
      await process.exitCode;
    }
  }

  Future<void> dispose() async {
    _started = false;
    _pollTimer?.cancel();
    _process?.kill();
    await _changes.close();
  }
}
