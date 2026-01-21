import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _isScanning = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Scan QR Code',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: MobileScanner(
        onDetect: (capture) {
          if (!_isScanning) return;

          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            // print('QR Code Detected: ${barcode.rawValue}');

            // Logic to handle scan (e.g., navigate to transfer screen)
            // For now, we just print and show a snackbar (optional) or stop scanning to prevent flood
            if (barcode.rawValue != null) {
              setState(() => _isScanning = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Detected: ${barcode.rawValue}')),
              );
              // In future: Navigator.pop(context, barcode.rawValue);
              // Or navigate to transfer flow.
            }
          }
        },
      ),
    );
  }
}
