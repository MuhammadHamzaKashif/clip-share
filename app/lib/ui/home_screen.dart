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
import 'theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.store, this.startEngine = true});

  final ConfigStore? store;
  final bool startEngine;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
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
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (_) => PairDeviceSheet(
        engine: engine,
        devices: _discovery.devices,
      ),
    );
  }

  Future<void> _copyItem(ClipboardItem item) async {
    final text = item.text;
    if (text == null || text.isEmpty) return;
    await _engine?.clipboard.setText(text);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Copied to clipboard', style: const TextStyle(fontFamily: kFontSans)),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(48, 36, 48, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    deviceName: _settings.deviceName,
                    syncing: _syncing,
                    onSettings: _loaded ? _openSettings : null,
                  ),
                  const SizedBox(height: 44),
                  _SectionLabel('Devices'),
                  const SizedBox(height: 10),
                  _devices.isEmpty ? const _EmptyDevices() : _DeviceList(devices: _devices),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _loaded ? _toggleSync : null,
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: Icon(
                            _syncing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                            key: ValueKey(_syncing),
                            size: 18,
                          ),
                        ),
                        label: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Text(_syncing ? 'Stop sync' : 'Start sync',
                              key: ValueKey(_syncing)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _loaded ? _pair : null,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Pair device'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      const _SectionLabel('Recent'),
                      const Spacer(),
                      Text(
                        '${_items.length}',
                        style: mono(Theme.of(context).textTheme.bodySmall!)
                            .copyWith(color: context.clip.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _items.isEmpty
                          ? const _EmptyHistory()
                          : _HistoryList(items: _items, onCopy: _copyItem),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: context.clip.border),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        'sync ${_syncing ? 'on' : 'off'}',
                        style: mono(Theme.of(context).textTheme.bodySmall!)
                            .copyWith(color: context.clip.muted),
                      ),
                      const Spacer(),
                      Text(
                        'history: ${_settings.historySize} items',
                        style: mono(Theme.of(context).textTheme.bodySmall!)
                            .copyWith(color: context.clip.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.deviceName,
    required this.syncing,
    required this.onSettings,
  });

  final String deviceName;
  final bool syncing;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('ClipShare', style: Theme.of(context).textTheme.headlineSmall),
        const Spacer(),
        _StatusChip(syncing: syncing),
        const SizedBox(width: 14),
        Text(
          deviceName,
          style: mono(Theme.of(context).textTheme.bodySmall!)
              .copyWith(color: context.clip.muted),
        ),
        const SizedBox(width: 6),
        IconButton(
          onPressed: onSettings,
          icon: const Icon(Icons.tune_rounded, size: 19),
          tooltip: 'Settings',
          color: context.clip.muted,
          iconSize: 19,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ],
    );
  }
}

class _StatusChip extends StatefulWidget {
  const _StatusChip({required this.syncing});

  final bool syncing;

  @override
  State<_StatusChip> createState() => _StatusChipState();
}

class _StatusChipState extends State<_StatusChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.syncing) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _StatusChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.syncing && !oldWidget.syncing) {
      _pulse.repeat(reverse: true);
    } else if (!widget.syncing && oldWidget.syncing) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.syncing ? 'syncing' : 'idle';
    final color = widget.syncing ? context.clip.ok : context.clip.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: widget.syncing ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween(begin: 0.35, end: 1.0).animate(_pulse),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: mono(theme.textTheme.bodySmall!)
                .copyWith(color: color, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: sectionLabel(Theme.of(context)));
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({required this.devices});

  final List<Device> devices;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < devices.length; i++) ...[
          if (i > 0) Divider(color: context.clip.border),
          _DeviceRow(device: devices[i]),
        ],
      ],
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: device.connected ? context.clip.ok : context.clip.muted,
              boxShadow: device.connected
                  ? [
                      BoxShadow(
                        color: context.clip.ok.withValues(alpha: 0.35),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(device.name, style: theme.textTheme.bodyMedium),
          ),
          Text(
            device.connected ? 'connected' : 'nearby',
            style: mono(theme.textTheme.bodySmall!)
                .copyWith(color: context.clip.muted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.items, required this.onCopy});

  final List<ClipboardItem> items;
  final void Function(ClipboardItem) onCopy;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, _) => Divider(color: context.clip.border),
      itemBuilder: (context, index) => _ItemRow(item: items[index], onCopy: onCopy),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.onCopy});

  final ClipboardItem item;
  final void Function(ClipboardItem) onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time =
        '${item.timestamp.hour.toString().padLeft(2, '0')}:'
        '${item.timestamp.minute.toString().padLeft(2, '0')}';
    final label = item.kind == ItemKind.text ? (item.text ?? '') : 'image';
    return InkWell(
      onTap: () => onCopy(item),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Text(
              time,
              style: mono(theme.textTheme.bodySmall!)
                  .copyWith(color: context.clip.muted, fontSize: 11.5),
            ),
            const SizedBox(width: 12),
            Text(
              item.source,
              style: mono(theme.textTheme.bodySmall!)
                  .copyWith(color: context.clip.accent, fontSize: 11.5),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurface),
              ),
            ),
            Icon(
              Icons.copy_rounded,
              size: 15,
              color: context.clip.muted.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDevices extends StatelessWidget {
  const _EmptyDevices();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(kRadiusSurface),
        border: Border.all(color: context.clip.border),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.clip.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.wifi_tethering_rounded,
                size: 22, color: context.clip.accent),
          ),
          const SizedBox(height: 14),
          Text('No devices yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Pair your laptop or phone to build\nyour shared clipboard.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: context.clip.muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.content_paste_rounded,
              size: 28, color: context.clip.muted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'Nothing here yet',
            style: theme.textTheme.bodyMedium?.copyWith(color: context.clip.muted),
          ),
          const SizedBox(height: 4),
          Text(
            'Copy something on any device and it will appear here.',
            style: theme.textTheme.bodySmall?.copyWith(color: context.clip.muted),
          ),
        ],
      ),
    );
  }
}
