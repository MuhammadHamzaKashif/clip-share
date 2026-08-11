import 'package:flutter/material.dart';

import '../models/clipboard_item.dart';
import '../models/device.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _devices = [
    Device(id: 'laptop', name: 'laptop', connected: true),
    Device(id: 'pc', name: 'pc', connected: true),
    Device(id: 'phone', name: 'phone', connected: false),
  ];

  static final _items = [
    ClipboardItem(
      itemId: 'a',
      kind: ItemKind.text,
      source: 'laptop',
      timestamp: DateTime(2026, 8, 12, 7, 42),
      text: 'https://example.com/some-link',
    ),
    ClipboardItem(
      itemId: 'b',
      kind: ItemKind.text,
      source: 'phone',
      timestamp: DateTime(2026, 8, 12, 7, 40),
      text: 'const answer = 42;',
    ),
    ClipboardItem(
      itemId: 'c',
      kind: ItemKind.image,
      source: 'pc',
      timestamp: DateTime(2026, 8, 12, 7, 35),
    ),
  ];

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
                  Text('this device', style: _mono(theme)),
                ],
              ),
              const SizedBox(height: 20),
              _DeviceList(devices: _devices),
              const SizedBox(height: 20),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Pair device'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Start sync'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text('Recent clipboard items', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _ItemRow(item: _items[index]),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('sync: off', style: _mono(theme)),
                  const Spacer(),
                  Text('history: 50 items', style: _mono(theme)),
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
    final label = item.kind == ItemKind.text
        ? (item.text ?? '')
        : 'image';
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
