import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../services/Transport/transport_service.dart';
import '../../services/Database/database_service.dart';
import '../../services/Transport/transport_pdf_service.dart';
import '../../services/api_sync_service.dart' show syncTransportsToBackend;
import '../../models/transport.dart';
import '../../widgets/common/glassmorphism_container.dart';
import 'address_autocomplete_field.dart';
import 'transport_calculator_theme.dart';

class TransportCalculatorWidget extends StatefulWidget {
  const TransportCalculatorWidget({super.key});

  @override
  State<TransportCalculatorWidget> createState() =>
      _TransportCalculatorWidgetState();
}

class _TransportCalculatorWidgetState extends State<TransportCalculatorWidget> {
  final TransportService _transportService = TransportService();
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _pricePerKmController = TextEditingController(
    text: '1.5',
  );
  final TextEditingController _fuelConsumptionController =
      TextEditingController(text: '8.0');
  final TextEditingController _fuelPriceController = TextEditingController(
    text: '1.5',
  );
  final TextEditingController _apiKeyController = TextEditingController();

  String? get _effectiveApiKey {
    final customKey = _apiKeyController.text.trim();
    if (customKey.isNotEmpty) {
      return customKey;
    }
    // V produkcii by ste mali vrátiť null alebo vlastný kľúč
    // Pre teraz vrátime null, aby sa použil fallback
    return null;
  }

  bool _isCalculating = false;
  bool _isRoundTrip = false; // Cesta tam aj späť
  Map<String, double>? _calculationResult;
  double? _calculatedDistance;
  List<LatLng>? _routePolyline;
  LatLng? _originCoords;
  LatLng? _destinationCoords;
  final MapController _mapController = MapController();

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _pricePerKmController.dispose();
    _fuelConsumptionController.dispose();
    _fuelPriceController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _calculateTransport() async {
    if (_originController.text.isEmpty || _destinationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vyplňte adresy odkiaľ a kam'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isCalculating = true;
      _calculationResult = null;
      _calculatedDistance = null;
      _routePolyline = null;
      _originCoords = null;
      _destinationCoords = null;
    });

    try {
      // Vypočítame vzdialenosť a trasu
      final routeData = await _transportService.calculateDistanceWithRoute(
        origin: _originController.text,
        destination: _destinationController.text,
        apiKey: _effectiveApiKey,
      );

      double distance = routeData['distance'] as double;
      
      // Ak je zaškrtnutá cesta tam aj späť, zdvojnásobíme vzdialenosť
      if (_isRoundTrip) {
        distance = distance * 2;
      }
      
      final polyline = routeData['polyline'] as List<Map<String, double>>?;
      final originCoords = routeData['originCoords'] as Map<String, double>?;
      final destCoords = routeData['destinationCoords'] as Map<String, double>?;

      // Konvertujeme polyline na LatLng body
      List<LatLng>? routePoints;
      if (polyline != null && polyline.isNotEmpty) {
        routePoints = polyline.map((point) {
          return LatLng(point['lat']!, point['lon']!);
        }).toList();
      }

      // Konvertujeme súradnice
      LatLng? originLatLng;
      LatLng? destLatLng;
      if (originCoords != null) {
        originLatLng = LatLng(originCoords['lat']!, originCoords['lon']!);
      }
      if (destCoords != null) {
        destLatLng = LatLng(destCoords['lat']!, destCoords['lon']!);
      }

      // Vypočítame náklady
      final pricePerKm = double.tryParse(_pricePerKmController.text) ?? 1.5;
      final fuelConsumption = double.tryParse(_fuelConsumptionController.text);
      final fuelPrice = double.tryParse(_fuelPriceController.text);

      final costs = _transportService.calculateTransportCosts(
        distance: distance,
        pricePerKm: pricePerKm,
        fuelConsumption: fuelConsumption,
        fuelPrice: fuelPrice,
      );

      setState(() {
        _calculatedDistance = distance;
        _calculationResult = costs;
        _routePolyline = routePoints;
        _originCoords = originLatLng;
        _destinationCoords = destLatLng;
        _isCalculating = false;
      });

      // Nastavíme mapu na zobrazenie celej trasy
      if (originLatLng != null && destLatLng != null) {
        _fitMapToRoute();
      }
    } catch (e) {
      setState(() {
        _isCalculating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chyba pri výpočte: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _fitMapToRoute() {
    if (_originCoords == null || _destinationCoords == null) return;

    // Vypočítame stred medzi dvoma bodmi
    final centerLat = (_originCoords!.latitude + _destinationCoords!.latitude) / 2;
    final centerLon = (_originCoords!.longitude + _destinationCoords!.longitude) / 2;
    
    // Vypočítame približnú vzdialenosť pre zoom
    final latDiff = (_originCoords!.latitude - _destinationCoords!.latitude).abs();
    final lonDiff = (_originCoords!.longitude - _destinationCoords!.longitude).abs();
    final maxDiff = latDiff > lonDiff ? latDiff : lonDiff;
    
    double zoom;
    if (maxDiff > 1.0) {
      zoom = 7.0;
    } else if (maxDiff > 0.5) {
      zoom = 8.0;
    } else if (maxDiff > 0.1) {
      zoom = 9.0;
    } else if (maxDiff > 0.05) {
      zoom = 10.0;
    } else {
      zoom = 11.0;
    }

    _mapController.move(LatLng(centerLat, centerLon), zoom);
  }

  @override
  Widget build(BuildContext context) {
    final topPad =
        MediaQuery.paddingOf(context).top + kToolbarHeight + 12;

    return Container(
      constraints: const BoxConstraints.expand(),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
          colors: [
            TransportCalculatorTheme.bgDeep,
            TransportCalculatorTheme.bgDeep2,
            Color(0xFF151A22),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, topPad, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildGlassContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 30),
                    _buildFormFields(),
                    const SizedBox(height: 30),
                    _buildCalculateButton(),
                  ],
                ),
              ),

              if (_calculationResult != null) ...[
                const SizedBox(height: 25),
                _buildGlassContainer(
                  padding: const EdgeInsets.all(24),
                  child: _buildResultsSection(),
                ),
                if (_originCoords != null && _destinationCoords != null) ...[
                  const SizedBox(height: 25),
                  _buildGlassContainer(
                    padding: EdgeInsets.zero,
                    child: _buildMapSection(),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- GLASSMOPHISM WRAPPER ---
  Widget _buildGlassContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return GlassmorphismContainer(
      padding: padding,
      borderRadius: 28,
      blurSigma: 24,
      borderWidth: 1,
      borderColor: Colors.white.withOpacity(0.12),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          TransportCalculatorTheme.surfaceCard.withOpacity(0.72),
          TransportCalculatorTheme.surfaceCard.withOpacity(0.48),
          TransportCalculatorTheme.bgDeep2.withOpacity(0.55),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: TransportCalculatorTheme.accentAmber.withOpacity(0.10),
          blurRadius: 36,
          offset: const Offset(0, 14),
          spreadRadius: -8,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.45),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
      child: child,
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    TransportCalculatorTheme.accentAmber.withOpacity(0.22),
                    TransportCalculatorTheme.surfaceCard.withOpacity(0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: TransportCalculatorTheme.accentAmber.withOpacity(0.35),
                ),
              ),
              child: const Icon(
                Icons.local_shipping_rounded,
                color: TransportCalculatorTheme.accentAmber,
                size: 30,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Text(
            'Kalkulácia dopravy',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: TransportCalculatorTheme.textPrimary,
              letterSpacing: 0.4,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        AddressAutocompleteField(
          controller: _originController,
          label: 'Miesto nakládky',
          hint: 'Mesto, ulica...',
          icon: Icons.circle_outlined,
          apiKey: _effectiveApiKey,
        ),
        const SizedBox(height: 15),
        AddressAutocompleteField(
          controller: _destinationController,
          label: 'Miesto vykládky',
          hint: 'Mesto, ulica...',
          icon: Icons.location_on_rounded,
          apiKey: _effectiveApiKey,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildGlassInput(
                _pricePerKmController,
                'Cena/km (€)',
                Icons.euro,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildGlassInput(
                _fuelConsumptionController,
                'Spotreba (l)',
                Icons.ev_station,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildGlassInput(
                _fuelPriceController,
                'Cena paliva (€)',
                Icons.local_gas_station,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildGlassInput(
                _apiKeyController,
                'API kľúč (voliteľný)',
                Icons.vpn_key,
                obscureText: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        _GlassSurface(
          borderRadius: 14,
          blurSigma: 14,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Checkbox(
                  value: _isRoundTrip,
                  onChanged: (value) {
                    setState(() {
                      _isRoundTrip = value ?? false;
                    });
                  },
                  fillColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return TransportCalculatorTheme.accentAmber;
                    }
                    return Colors.transparent;
                  }),
                  checkColor: TransportCalculatorTheme.bgDeep,
                  side: BorderSide(color: Colors.white.withOpacity(0.28)),
                ),
                Expanded(
                  child: Text(
                    'Cesta tam aj späť (zdvojnásobí KM)',
                    style: TextStyle(
                      fontSize: 14,
                      color: TransportCalculatorTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
        _GlassSurface(
          borderRadius: 14,
          blurSigma: 12,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: TransportCalculatorTheme.accentAmber.withOpacity(0.85),
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Aplikácia používa OpenStreetMap (bezplatné). Pre ešte lepšie výsledky môžete zadať vlastný Google Maps API kľúč.',
                    style: TextStyle(
                      fontSize: 11,
                      color: TransportCalculatorTheme.textMuted,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Moderný vstupný prvok prispôsobený pre sklenený dizajn
  Widget _buildGlassInput(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscureText = false,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: TransportCalculatorTheme.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        _GlassSurface(
          borderRadius: 14,
          blurSigma: 16,
          child: Material(
            color: Colors.transparent,
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              onChanged:
                  onChanged ??
                  (value) {
                    if (controller == _apiKeyController) {
                      setState(() {});
                    }
                  },
              style: const TextStyle(color: TransportCalculatorTheme.textPrimary),
              keyboardType:
                  obscureText ? TextInputType.text : TextInputType.number,
              decoration: InputDecoration(
                prefixIcon: Icon(
                  icon,
                  color: TransportCalculatorTheme.accentAmberSoft,
                  size: 20,
                ),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: TransportCalculatorTheme.accentAmber.withOpacity(0.85),
                    width: 1.5,
                  ),
                ),
                hintStyle: TextStyle(
                  color: TransportCalculatorTheme.textMuted.withOpacity(0.65),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalculateButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: TransportCalculatorTheme.accentAmber.withOpacity(0.22),
            blurRadius: 28,
            offset: const Offset(0, 12),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isCalculating ? null : _calculateTransport,
        style: ElevatedButton.styleFrom(
          backgroundColor: TransportCalculatorTheme.actionBlue,
          foregroundColor: TransportCalculatorTheme.textPrimary,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: TransportCalculatorTheme.accentAmber.withOpacity(0.45),
              width: 1,
            ),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: _isCalculating
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    TransportCalculatorTheme.accentAmber,
                  ),
                ),
              )
            : const Text(
                'VYPOČÍTAŤ NÁKLADY',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
      ),
    );
  }

  Widget _buildResultsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Výsledky',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: TransportCalculatorTheme.textPrimary,
            letterSpacing: 0.35,
          ),
        ),
        const SizedBox(height: 20),

        // Vzdialenosť
        _buildResultCard(
          'Vzdialenosť',
          '${_calculatedDistance!.toStringAsFixed(2)} km',
          Icons.straighten_rounded,
        ),
        const SizedBox(height: 12),

        // Základná cena
        _buildResultCard(
          'Základná cena',
          '${_calculationResult!['baseCost']!.toStringAsFixed(2)} €',
          Icons.euro_rounded,
        ),
        const SizedBox(height: 12),

        // Náklady na palivo
        if (_calculationResult!['fuelCost']! > 0) ...[
          _buildResultCard(
            'Náklady na palivo',
            '${_calculationResult!['fuelCost']!.toStringAsFixed(2)} €',
            Icons.local_gas_station_rounded,
          ),
          const SizedBox(height: 12),
        ],

        // Celkové náklady
        _GlassSurface(
          borderRadius: 16,
          blurSigma: 18,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Celkové náklady',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: TransportCalculatorTheme.textPrimary,
                  ),
                ),
                Text(
                  '${_calculationResult!['totalCost']!.toStringAsFixed(2)} €',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: TransportCalculatorTheme.accentAmber,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Tlačidlá na uloženie a PDF
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'ULOŽIŤ',
                Icons.save_rounded,
                _saveTransport,
                glassTint: TransportCalculatorTheme.actionBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'PDF ŠTÍTOK',
                Icons.picture_as_pdf_rounded,
                _generatePdfLabel,
                glassTint: TransportCalculatorTheme.actionBurgundy,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    VoidCallback onPressed, {
    required Color glassTint,
  }) {
    return _GlassSurface(
      borderRadius: 12,
      blurSigma: 12,
      glassTint: glassTint,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: TransportCalculatorTheme.accentAmberSoft),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: TransportCalculatorTheme.textPrimary,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveTransport() async {
    if (_calculationResult == null || _calculatedDistance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Najprv vypočítajte náklady'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final pricePerKm = double.tryParse(_pricePerKmController.text) ?? 1.5;
      final fuelConsumption = double.tryParse(_fuelConsumptionController.text);
      final fuelPrice = double.tryParse(_fuelPriceController.text);

      final transport = Transport(
        origin: _originController.text,
        destination: _destinationController.text,
        distance: _calculatedDistance!,
        isRoundTrip: _isRoundTrip,
        pricePerKm: pricePerKm,
        fuelConsumption: fuelConsumption,
        fuelPrice: fuelPrice,
        baseCost: _calculationResult!['baseCost']!,
        fuelCost: _calculationResult!['fuelCost']!,
        totalCost: _calculationResult!['totalCost']!,
        createdAt: DateTime.now(),
      );

      final db = DatabaseService();
      await db.insertTransport(transport);
      syncTransportsToBackend().ignore();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preprava bola uložená'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri ukladaní: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generatePdfLabel() async {
    if (_calculationResult == null || _calculatedDistance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Najprv vypočítajte náklady'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final pricePerKm = double.tryParse(_pricePerKmController.text) ?? 1.5;
      final fuelConsumption = double.tryParse(_fuelConsumptionController.text);
      final fuelPrice = double.tryParse(_fuelPriceController.text);

      final transport = Transport(
        origin: _originController.text,
        destination: _destinationController.text,
        distance: _calculatedDistance!,
        isRoundTrip: _isRoundTrip,
        pricePerKm: pricePerKm,
        fuelConsumption: fuelConsumption,
        fuelPrice: fuelPrice,
        baseCost: _calculationResult!['baseCost']!,
        fuelCost: _calculationResult!['fuelCost']!,
        totalCost: _calculationResult!['totalCost']!,
        createdAt: DateTime.now(),
      );

      final pdfBytes = await TransportPdfService.buildLabelPdf(transport: transport);
      
      if (mounted) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri generovaní PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildResultCard(
    String title,
    String value,
    IconData icon,
  ) {
    return _GlassSurface(
      borderRadius: 14,
      blurSigma: 12,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: TransportCalculatorTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: TransportCalculatorTheme.accentAmber.withOpacity(0.35),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: TransportCalculatorTheme.accentAmber,
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: TransportCalculatorTheme.textMuted,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: TransportCalculatorTheme.accentAmber,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    if (_originCoords == null || _destinationCoords == null) {
      return const SizedBox.shrink();
    }

    // Vypočítame stred a zoom
    final centerLat = (_originCoords!.latitude + _destinationCoords!.latitude) / 2;
    final centerLon = (_originCoords!.longitude + _destinationCoords!.longitude) / 2;
    final latDiff = (_originCoords!.latitude - _destinationCoords!.latitude).abs();
    final lonDiff = (_originCoords!.longitude - _destinationCoords!.longitude).abs();
    final maxDiff = latDiff > lonDiff ? latDiff : lonDiff;
    
    double initialZoom;
    if (maxDiff > 1.0) {
      initialZoom = 7.0;
    } else if (maxDiff > 0.5) {
      initialZoom = 8.0;
    } else if (maxDiff > 0.1) {
      initialZoom = 9.0;
    } else if (maxDiff > 0.05) {
      initialZoom = 10.0;
    } else {
      initialZoom = 11.0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          child: const Text(
            'Trasa na mape',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: TransportCalculatorTheme.textPrimary,
              letterSpacing: 0.35,
            ),
          ),
        ),
        SizedBox(
          height: 400,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(centerLat, centerLon),
                initialZoom: initialZoom,
                minZoom: 5.0,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.stockpilot.app',
                  maxZoom: 19,
                ),
                if (_routePolyline != null && _routePolyline!.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePolyline!,
                        strokeWidth: 4.0,
                        color: TransportCalculatorTheme.accentAmber,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _originCoords!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.circle,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    Marker(
                      point: _destinationCoords!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Jemný sklenený panel (tmavý glass; voliteľný [glassTint] pre akčné tlačidlá).
class _GlassSurface extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final Color? glassTint;

  const _GlassSurface({
    required this.child,
    this.borderRadius = 14,
    this.blurSigma = 14,
    this.glassTint,
  });

  @override
  Widget build(BuildContext context) {
    final tint = glassTint;
    final List<Color> gradientColors = tint != null
        ? [
            tint.withOpacity(0.62),
            tint.withOpacity(0.42),
          ]
        : [
            TransportCalculatorTheme.surfaceCard.withOpacity(0.58),
            TransportCalculatorTheme.bgDeep.withOpacity(0.52),
          ];

    final Color borderColor = tint != null
        ? Colors.white.withOpacity(0.14)
        : TransportCalculatorTheme.accentAmber.withOpacity(0.18);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: TransportCalculatorTheme.accentAmber.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
