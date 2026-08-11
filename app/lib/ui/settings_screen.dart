import 'package:flutter/material.dart';

import '../models/settings.dart';
import '../platform/config_store.dart';
import '../platform/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store});

  final ConfigStore store;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsService _service;
  Settings? _settings;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _service = SettingsService(widget.store);
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await _service.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _nameController.text = settings.deviceName;
    });
  }

  Future<void> _save() async {
    final settings = _settings;
    if (settings == null) return;
    await _service.save(
      settings.copyWith(deviceName: _nameController.text.trim().isEmpty
          ? settings.deviceName
          : _nameController.text.trim()),
    );
    if (mounted) {
      Navigator.of(context).pop(await _service.load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Device name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start sync at launch'),
                  value: settings.autoConnect,
                  onChanged: (v) => setState(() =>
                      _settings = settings.copyWith(autoConnect: v)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Apply received items'),
                  subtitle: const Text('Write synced items to the OS clipboard'),
                  value: settings.applyOnReceive,
                  onChanged: (v) => setState(() =>
                      _settings = settings.copyWith(applyOnReceive: v)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start at login'),
                  value: settings.startAtLogin,
                  onChanged: (v) => setState(() =>
                      _settings = settings.copyWith(startAtLogin: v)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('History size'),
                  trailing: DropdownButton<int>(
                    value: settings.historySize,
                    items: const [
                      DropdownMenuItem(value: 25, child: Text('25')),
                      DropdownMenuItem(value: 50, child: Text('50')),
                      DropdownMenuItem(value: 100, child: Text('100')),
                      DropdownMenuItem(value: 0, child: Text('none')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() =>
                            _settings = settings.copyWith(historySize: v));
                      }
                    },
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ],
            ),
    );
  }
}
