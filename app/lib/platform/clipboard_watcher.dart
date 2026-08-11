import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

enum ClipboardKind { text, image }

class ClipboardChange {
  const ClipboardChange({required this.kind, required this.payload});

  final ClipboardKind kind;
  final String payload;
}

class ClipboardWatcher {
  final _changes = StreamController<ClipboardChange>.broadcast();
  Stream<ClipboardChange> get changes => _changes.stream;

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
$script:lastSig = ''
$ts = New-Object System.Windows.Forms.Timer
$ts.Interval = 400
$ts.Add_Tick({
  try {
    if ([System.Windows.Forms.Clipboard]::ContainsImage()) {
      $img = [System.Windows.Forms.Clipboard]::GetImage()
      $ms = New-Object System.IO.MemoryStream
      $img.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
      $b64 = [Convert]::ToBase64String($ms.ToArray())
      $sig = "IMG:$($b64.Length):" + $b64.Substring(0, 32) + $b64.Substring($b64.Length - 32)
      if ($sig -ne $script:lastSig) {
        $script:lastSig = $sig
        $out = [Text.Encoding]::UTF8.GetBytes("IMG:$($b64.Length)`n$b64")
        $stdout = [Console]::OpenStandardOutput()
        $stdout.Write($out, 0, $out.Length)
        $stdout.Flush()
      }
    } else {
      $t = [System.Windows.Forms.Clipboard]::GetText()
      $sig = "TEXT:$($t.Length):$t"
      if ($sig -ne $script:lastSig) {
        $script:lastSig = $sig
        $b = [Text.Encoding]::UTF8.GetBytes("TEXT:$($t.Length)`n$t")
        $stdout = [Console]::OpenStandardOutput()
        $stdout.Write($b, 0, $b.Length)
        $stdout.Flush()
      }
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
      if (bytes.isEmpty) return;
      final textIndex = _indexOf(bytes, utf8.encode('TEXT:'));
      final imgIndex = _indexOf(bytes, utf8.encode('IMG:'));
      var tagStart = -1;
      var prefixLen = 0;
      if (textIndex >= 0 && (imgIndex < 0 || textIndex < imgIndex)) {
        tagStart = textIndex;
        prefixLen = 5;
      } else if (imgIndex >= 0) {
        tagStart = imgIndex;
        prefixLen = 4;
      }
      if (tagStart < 0) return;
      final rest = bytes.sublist(tagStart);
      final newline = rest.indexOf(10);
      if (newline < 0) return;
      final header = utf8.decode(rest.sublist(0, newline), allowMalformed: true);
      final length = int.tryParse(header.substring(prefixLen));
      if (length == null || length < 0) {
        buffer.clear();
        return;
      }
      if (rest.length < newline + 1 + length) return;
      final payload = utf8.decode(
          rest.sublist(newline + 1, newline + 1 + length),
          allowMalformed: true);
      buffer.clear();
      if (rest.length > newline + 1 + length) {
        buffer.add(rest.sublist(newline + 1 + length));
      }
      final kind = header.startsWith('IMG:')
          ? ClipboardKind.image
          : ClipboardKind.text;
      final sig = '$kind:$length:'
          '${payload.length > 16 ? payload.substring(0, 16) : payload}:'
          '${payload.length > 16 ? payload.substring(payload.length - 16) : ''}';
      if (sig != _lastSeen) {
        _lastSeen = sig;
        if (!_changes.isClosed) {
          _changes.add(ClipboardChange(kind: kind, payload: payload));
        }
      }
    }
  }

  void parseForTest(BytesBuilder buffer) {
    _parseWindowsOutput(buffer);
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
            _changes.add(
                ClipboardChange(kind: ClipboardKind.text, payload: text));
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

  Future<void> setImage(List<int> pngBytes) async {
    if (Platform.isWindows) {
      final process = await Process.start('powershell', [
        '-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-Command',
        r'''
$b64 = [Console]::In.ReadToEnd().Trim()
$bytes = [Convert]::FromBase64String($b64)
$ms = New-Object System.IO.MemoryStream(,$bytes)
$img = [System.Drawing.Image]::FromStream($ms)
[System.Windows.Forms.Clipboard]::SetImage($img)
''',
      ]);
      process.stdin.write(base64Encode(pngBytes));
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
