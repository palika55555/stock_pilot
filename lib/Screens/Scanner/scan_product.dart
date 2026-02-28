import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class ScanProductScreen extends StatefulWidget {
  const ScanProductScreen({super.key});

  @override
  State<ScanProductScreen> createState() => _ScanProductScreenState();
}

class _ScanProductScreenState extends State<ScanProductScreen> {
  bool isScanning = true;
  bool hasPermission = false;
  // Kontrolér s nastavením formátov a detekcie
  final MobileScannerController controller = MobileScannerController(
    autoStart: false, // Neštartujeme automaticky, počkáme na povolenia
    torchEnabled: false,
    formats: [BarcodeFormat.all],
  );

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() {
        hasPermission = true;
      });
      controller.start(); // Štartujeme skener až po získaní povolenia
    } else {
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Potrebné povolenie'),
        content: const Text(
          'Pre skenovanie čiarových kódov je potrebný prístup ku kamere.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zrušiť'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings(); // Otvorí nastavenia aplikácie
            },
            child: const Text('Nastavenia'),
          ),
        ],
      ),
    );
  }

  void _handleScannedBarcode(String? code) {
    if (code == null || !isScanning) return;

    setState(() => isScanning = false);
    _showProductDetail(code);
  }

  void _showProductDetail(String code) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.inventory_2_rounded,
                size: 60,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              Text(
                'Naskenovaný produkt',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kód: $code',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const Divider(height: 32),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Na sklade:', style: TextStyle(fontSize: 18)),
                  Text(
                    '42 ks',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => isScanning = true);
                  },
                  child: const Text(
                    'SKENOVAŤ ĎALEJ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skenovať tovar'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Oprava: Používame ValueListenableBuilder priamo na controller.torchState
          ValueListenableBuilder(
            valueListenable:
                controller, // Controller sám o sebe slúži ako listenable
            builder: (context, value, child) {
              // Získame stav blesku bezpečne z hodnoty controllera
              final TorchState state = value.torchState;
              return IconButton(
                onPressed: () => controller.toggleTorch(),
                icon: Icon(
                  state == TorchState.on ? Icons.flash_on : Icons.flash_off,
                  color: state == TorchState.on ? Colors.yellow : Colors.white,
                ),
              );
            },
          ),
          IconButton(
            onPressed: () => controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (hasPermission)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    'Namiřte kameru na čiarový kód (EAN, UPC) alebo QR kód',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: MobileScanner(
                    controller: controller,
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty) {
                        _handleScannedBarcode(barcodes.first.rawValue);
                      }
                    },
                  ),
                ),
              ],
            )
          else
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Čakám na povolenie kamery...'),
                ],
              ),
            ),
          // Zameriavač (len ak máme povolenie)
          if (hasPermission)
            Positioned.fill(
              child: CustomPaint(painter: ScannerOverlayPainter()),
            ),
          // Loading pri spracovaní
          if (!isScanning && hasPermission)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    final scanAreaWidth = size.width * 0.7;
    final scanAreaHeight = 200.0;
    final scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanAreaWidth,
      height: scanAreaHeight,
    );

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect),
        Path()..addRRect(
          RRect.fromRectAndRadius(scanRect, const Radius.circular(12)),
        ),
      ),
      paint,
    );

    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(scanRect, const Radius.circular(12)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
