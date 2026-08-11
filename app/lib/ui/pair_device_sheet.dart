import 'package:flutter/material.dart';

import '../discovery/discovery_service.dart';
import '../sync/sync_engine.dart';

class PairDeviceSheet extends StatefulWidget {
  const PairDeviceSheet({super.key, required this.engine, required this.devices});

  final SyncEngine engine;
  final List<DiscoveredDevice> devices;

  @override
  State<PairDeviceSheet> createState() => _PairDeviceSheetState();
}

enum _PairMode { choose, host, join }

class _PairDeviceSheetState extends State<PairDeviceSheet> {
  _PairMode _mode = _PairMode.choose;
  DiscoveredDevice? _target;
  final _codeController = TextEditingController();
  String? _error;
  bool _busy = false;
  String? _shownCode;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _hostMode() async {
    setState(() {
      _mode = _PairMode.host;
      _error = null;
    });
    widget.engine.pairingEvents.listen((deviceId) {
      if (!mounted) return;
      Navigator.of(context).pop();
    });
    await widget.engine.beginPairing();
    if (!mounted) return;
    setState(() => _shownCode = widget.engine.pairingCode);
  }

  Future<void> _joinMode() async {
    if (_target == null) {
      setState(() => _error = 'pick a device first');
      return;
    }
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'enter the 6-character code');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.engine.pairWith(_target!, code);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'pairing failed: ${e.toString().replaceFirst('Bad state: ', '')}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pair a device', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          if (_mode == _PairMode.choose) ...[
            FilledButton.icon(
              onPressed: _hostMode,
              icon: const Icon(Icons.qr_code_2, size: 18),
              label: const Text('Show my code'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => setState(() => _mode = _PairMode.join),
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Enter a code'),
            ),
          ] else if (_mode == _PairMode.host) ...[
            Text('Share this code with the device you want to pair:',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _shownCode ?? 'generating...',
                style: theme.textTheme.displaySmall!
                    .copyWith(fontFamily: 'monospace', letterSpacing: 6),
              ),
            ),
            const SizedBox(height: 12),
            Text('Waiting for the other device...',
                style: theme.textTheme.bodySmall),
          ] else ...[
            Text('Which device?', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            if (widget.devices.isEmpty)
              Text('no devices found on this network',
                  style: theme.textTheme.bodySmall)
            else
              DropdownButtonFormField<DiscoveredDevice>(
                initialValue: _target,
                isExpanded: true,
                items: [
                  for (final device in widget.devices)
                    DropdownMenuItem(value: device, child: Text(device.name)),
                ],
                onChanged: (v) => setState(() => _target = v),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Pairing code',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              onSubmitted: (_) => _joinMode(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _joinMode,
                child: Text(_busy ? 'Pairing...' : 'Pair'),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
    );
  }
}
