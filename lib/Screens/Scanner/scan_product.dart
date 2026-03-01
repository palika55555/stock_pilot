import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/customer.dart';
import '../../models/pallet.dart';
import '../../models/product.dart';
import '../../services/Database/database_service.dart';
import '../production/production_batch_detail_screen.dart';
import '../pallet/pallet_expedition_screen.dart';

class ScanProductScreen extends StatefulWidget {
  /// Ak je nastavený, naskenovaná paleta sa automaticky priradí tomuto zákazníkovi (predaj / expedícia).
  final Customer? expeditionCustomer;

  const ScanProductScreen({super.key, this.expeditionCustomer});

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
    _lookupAndShowProduct(code);
  }

  Future<void> _lookupAndShowProduct(String code) async {
    final db = DatabaseService();
    final palletId = Pallet.parseIdFromQr(code);
    if (palletId != null) {
      final pallet = await db.getPalletById(palletId);
      if (!mounted) return;
      if (pallet != null) {
        if (widget.expeditionCustomer != null) {
          if (pallet.status == PalletStatus.uZakaznika) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Paleta je už priradená inému zákazníkovi')),
            );
            setState(() => isScanning = true);
            return;
          }
          await db.assignPalletToCustomer(palletId, widget.expeditionCustomer!.id!);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Paleta priradená zákazníkovi ${widget.expeditionCustomer!.name}'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() => isScanning = true);
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PalletExpeditionScreen(palletId: palletId),
          ),
        );
        setState(() => isScanning = true);
        return;
      }
    }
    final batchId = DatabaseService.parseProductionBatchIdFromQr(code);
    if (batchId != null) {
      final batch = await db.getProductionBatchById(batchId);
      if (!mounted) return;
      if (batch != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductionBatchDetailScreen(batchId: batchId),
          ),
        );
        setState(() => isScanning = true);
        return;
      }
    }
    final product = await db.getProductByBarcode(code);
    if (!mounted) return;
    _showProductDetail(code, product);
  }

  Future<void> _showAssignProductSheet(String code) async {
    final db = DatabaseService();
    final products = await db.getProducts();
    if (!mounted) return;
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('V databáze nie sú žiadne produkty. Najprv vytvorte produkt.'),
          backgroundColor: Colors.orange,
        ),
      );
      setState(() => isScanning = true);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AssignProductSheet(
        scannedCode: code,
        products: products,
        onAssigned: () {
          Navigator.pop(ctx);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('EAN bol priradený k produktu. Pri ďalšom skenovaní sa zobrazí množstvo.'),
                backgroundColor: Colors.green,
              ),
            );
            setState(() => isScanning = true);
          }
        },
        onCancel: () {
          Navigator.pop(ctx);
          setState(() => isScanning = true);
        },
      ),
    );
  }

  void _showProductDetail(String code, Product? product) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final found = product != null;
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                found ? Icons.inventory_2_rounded : Icons.qr_code_scanner_rounded,
                size: 60,
                color: found ? Colors.blue : Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                found ? 'Naskenovaný produkt' : 'Produkt nenájdený',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kód: $code',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              if (found) ...[
                const SizedBox(height: 8),
                Text(
                  product!.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ],
              const Divider(height: 32),
              if (found)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Na sklade:', style: TextStyle(fontSize: 18)),
                    Text(
                      '${product!.qty} ${product.unit}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                )
              else ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Vyberte produkt podľa PLU alebo názvu a priraďte mu tento kód, alebo pridajte EAN v karte produktu.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showAssignProductSheet(code);
                    },
                    icon: const Icon(Icons.link_rounded, size: 20),
                    label: const Text('Priradiť k produktu'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.blue),
                      foregroundColor: Colors.blue,
                    ),
                  ),
                ),
              ],
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
        title: Text(
          widget.expeditionCustomer != null
              ? 'Expedícia – ${widget.expeditionCustomer!.name}'
              : 'Skenovať tovar',
        ),
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

class _AssignProductSheet extends StatefulWidget {
  const _AssignProductSheet({
    required this.scannedCode,
    required this.products,
    required this.onAssigned,
    required this.onCancel,
  });

  final String scannedCode;
  final List<Product> products;
  final VoidCallback onAssigned;
  final VoidCallback onCancel;

  @override
  State<_AssignProductSheet> createState() => _AssignProductSheetState();
}

class _AssignProductSheetState extends State<_AssignProductSheet> {
  final TextEditingController _searchController = TextEditingController();
  final DatabaseService _db = DatabaseService();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return widget.products;
    return widget.products.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.plu.toLowerCase().contains(q) ||
          (p.ean?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _assignToProduct(Product product) async {
    final updated = product.copyWith(ean: widget.scannedCode);
    await _db.updateProduct(updated);
    widget.onAssigned();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Priradiť kód ${widget.scannedCode} k produktu',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vyhľadajte podľa PLU alebo názvu',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'PLU alebo názov produktu...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.trim().isEmpty
                              ? 'Žiadne produkty'
                              : 'Žiadny produkt nevyhovuje vyhľadávaniu',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final p = _filtered[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                p.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text('PLU: ${p.plu} · ${p.qty} ${p.unit}'),
                              trailing: const Icon(Icons.add_link_rounded),
                              onTap: () => _assignToProduct(p),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Zrušiť'),
              ),
            ],
          ),
        );
      },
    );
  }
}
