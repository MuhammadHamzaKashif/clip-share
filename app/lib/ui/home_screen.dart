import 'package:flutter/material.dart';

import '../crypto/identity_service.dart';
import '../discovery/discovery_service.dart';
import '../models/app_constants.dart';
import '../models/clipboard_item.dart';
import '../models/device.dart';
import '../models/settings.dart';
import '../pairing/pairing_service.dart';
import '../platform/config_store.dart';
import '../platform/settings_service.dart';
import '../platform/trust_store.dart';
import '../platform/tray_helper.dart';
import '../sync/sync_engine.dart';
import 'pair_device_sheet.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.store, this.startEngine = true});

  final ConfigStore? store;
  final bool startEngine;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ConfigStore _store;
  late final DiscoveryService _discovery;
  final TrayHelper _tray = TrayHelper();
  SyncEngine? _engine;
  Settings _settings = Settings.defaults;
  List<Device> _devices = [];
  List<ClipboardItem> _items = [];
  Set<String> _connected = {};
  bool _syncing = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? ConfigStore.defaultForPlatform();
    _discovery = DiscoveryService();
    _load();
  }

  @override
  void dispose() {
    _engine?.dispose();
    _discovery.dispose();
    _tray.stop();
    super.dispose();
  }

  Future<void> _load() async {
    final identity = await IdentityService(_store).loadOrCreate();
    final settings = await SettingsService(_store).load();
    _settings = settings;
    await _discovery.start(
      deviceId: identity.deviceId,
      deviceName: settings.deviceName,
      publicKey: identity.publicKey,
      port: kClipsharePort,
    );
    _discovery.updates.listen((devices) {
      if (!mounted) return;
      setState(() {
        _devices = devices
            .map((d) => Device(
                id: d.id,
                name: d.name,
                connected: _connected.contains(d.id)))
            .toList();
      });
    });
    if (widget.startEngine) {
      final engine = SyncEngine(
        identity: identity,
        settings: settings,
        trustStore: TrustStore(_store),
        pairingService: PairingService(identity),
        discovery: _discovery,
      );
      _engine = engine;
      engine.historyStream.listen((items) {
        if (mounted) setState(() => _items = items);
      });
      engine.stateStream.listen((syncing) {
        if (mounted) setState(() => _syncing = syncing);
      });
      engine.peersStream.listen((peers) {
        if (!mounted) return;
        setState(() {
          _connected = peers;
          _devices = _devices
              .map((d) => d.copyWithConnected(peers.contains(d.id)))
              .toList();
        });
      });
      await engine.start();
      await _tray.start();
      if (settings.autoConnect) {
        await engine.startSync();
      }
    }
    if (!mounted) return;
    setState(() => _loaded = true);
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<Settings>(
      MaterialPageRoute(builder: (_) => SettingsScreen(store: _store)),
    );
    if (result != null && mounted) {
      setState(() => _settings = result);
    }
  }

  Future<void> _toggleSync() async {
    final engine = _engine;
    if (engine == null) return;
    if (_syncing) {
      await engine.stopSync();
    } else {
      await engine.startSync();
    }
  }

  Future<void> _pair() async {
    final engine = _engine;
    if (engine == null) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => PairDeviceSheet(
        engine: engine,
        devices: _discovery.devices,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('ClipShare', style: theme.textTheme.headlineSmall),
                  const Spacer(),
                  Text(
                    _settings.deviceName,
                    style: _mono(theme),
                  ),
                  IconButton(
                    onPressed: _loaded ? _openSettings : null,
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    tooltip: 'Settings',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _devices.isEmpty
                  ? Text('no devices found on this network',
                      style: theme.textTheme.bodySmall)
                  : _DeviceList(devices: _devices),
              const SizedBox(height: 20),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _loaded ? _pair : null,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Pair device'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _loaded ? _toggleSync : null,
                    icon: Icon(
                        _syncing ? Icons.stop : Icons.play_arrow,
                        size: 18),
                    label: Text(_syncing ? 'Stop sync' : 'Start sync'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text('Recent clipboard items', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Expanded(
                child: _items.isEmpty
                    ? Center(
                        child: Text('nothing synced yet',
                            style: theme.textTheme.bodySmall))
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) =>
                            _ItemRow(item: _items[index]),
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('sync: ${_syncing ? 'on' : 'off'}', style: _mono(theme)),
                  const Spacer(),
                  Text('history: ${_settings.historySize} items',
                      style: _mono(theme)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle _mono(ThemeData theme) {
  return theme.textTheme.bodySmall!.copyWith(fontFamily: 'monospace');
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({required this.devices});

  final List<Device> devices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final device in devices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  device.connected ? Icons.check_circle : Icons.radio_button_off,
                  size: 16,
                  color: device.connected
                      ? Colors.green.shade600
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 10),
                Text(device.name, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final ClipboardItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time =
        '${item.timestamp.hour.toString().padLeft(2, '0')}:'
        '${item.timestamp.minute.toString().padLeft(2, '0')}';
    final label = item.kind == ItemKind.text ? (item.text ?? '') : 'image';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text('$time  ${item.source}', style: _mono(theme)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
