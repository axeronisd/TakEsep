import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thermal_printer_plus/thermal_printer.dart';
import '../../../providers/printer_provider.dart';
import '../../../services/thermal_printer_service.dart';

class ThermalPrinterSelector extends ConsumerStatefulWidget {
  const ThermalPrinterSelector({super.key});

  @override
  ConsumerState<ThermalPrinterSelector> createState() => _ThermalPrinterSelectorState();
}

class _ThermalPrinterSelectorState extends ConsumerState<ThermalPrinterSelector> {
  final List<PrinterDevice> _devices = [];
  StreamSubscription? _sub;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _startScan() {
    setState(() {
      _devices.clear();
      _isScanning = true;
    });
    _sub?.cancel();
    _sub = ThermalPrinterService.instance.discoverPrinters().listen((device) {
      if (!_devices.any((d) => d.name == device.name && d.address == device.address)) {
        setState(() {
          _devices.add(device);
        });
      }
    }, onDone: () {
      if (mounted) setState(() => _isScanning = false);
    }, onError: (e) {
      if (mounted) setState(() => _isScanning = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final config = ref.watch(defaultPrinterConfigProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('BLUETOOTH ПРИНТЕРЫ (ESC/POS)', style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5), letterSpacing: 1.2))),
            if (_isScanning) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else TextButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Поиск'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _devices.isEmpty && !_isScanning
              ? const Padding(padding: EdgeInsets.all(16), child: Text('Принтеры не найдены. Включите Bluetooth.'))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _devices.length,
                  itemBuilder: (ctx, i) {
                    final d = _devices[i];
                    final isSelected = config.isThermal && config.name == d.address;
                    return RadioListTile<String>(
                      value: d.address!,
                      groupValue: config.isThermal ? config.name : null,
                      onChanged: (val) {
                        ref.read(defaultPrinterConfigProvider.notifier).setDefaultPrinter(val, isThermal: true, thermalType: PrinterType.bluetooth);
                      },
                      title: Text(d.name.isNotEmpty ? d.name : 'Unknown Printer', style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                      subtitle: Text(d.address ?? ''),
                      secondary: Icon(Icons.bluetooth, color: isSelected ? cs.primary : cs.onSurface.withValues(alpha: 0.5)),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
