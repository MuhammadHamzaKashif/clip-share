import 'dart:io';

class AutostartService {
  Future<bool> isEnabled() async {
    if (Platform.isWindows) {
      final result = await Process.run('reg', [
        'query', r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
        '/v', 'ClipShare',
      ]);
      return result.exitCode == 0 && (result.stdout as String).contains('ClipShare');
    }
    return false;
  }

  Future<void> setEnabled(bool enabled) async {
    if (Platform.isWindows) {
      final exe = Platform.resolvedExecutable;
      if (enabled) {
        await Process.run('reg', [
          'add', r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
          '/v', 'ClipShare', '/t', 'REG_SZ', '/d', '"$exe"', '/f',
        ]);
      } else {
        await Process.run('reg', [
          'delete', r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
          '/v', 'ClipShare', '/f',
        ]);
      }
    }
  }
}
