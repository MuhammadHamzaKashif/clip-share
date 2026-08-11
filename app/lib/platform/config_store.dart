import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class ConfigStore {
  ConfigStore(this.dir);

  final Directory dir;

  static ConfigStore defaultForPlatform() {
    final env = Platform.environment;
    String? base;
    if (Platform.isWindows) {
      base = env['APPDATA'];
    } else if (Platform.isLinux) {
      base = env['XDG_CONFIG_HOME'] ?? (env['HOME'] != null ? '${env['HOME']}/.config' : null);
    } else if (Platform.isMacOS) {
      base = env['HOME'] != null ? '${env['HOME']}/Library/Application Support' : null;
    }
    return ConfigStore(Directory(p.join(base ?? '.', 'ClipShare')));
  }

  Future<Map<String, dynamic>> read(String name) async {
    final file = _file(name);
    try {
      if (await file.exists()) {
        return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  Future<void> write(String name, Map<String, dynamic> data) async {
    await dir.create(recursive: true);
    await _file(name).writeAsString(jsonEncode(data));
  }

  File _file(String name) => File(p.join(dir.path, '$name.json'));
}
