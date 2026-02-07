import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../services/Transport/transport_service.dart';
import '../../services/Database/database_service.dart';
import '../../services/Transport/transport_pdf_service.dart';
import '../../models/transport.dart';
import '../../widgets/common/glassmorphism_container.dart';
import 'address_autocomplete_field.dart';

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
    return Container(
      constraints: const BoxConstraints.expand(),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667EEA),
            Color(0xFF764BA2),
            Color(
              0xFF6B8DD6,
            ), // Pridaná ďalšia farba pre lepší lom svetla pod sklom
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor:
            Colors.transparent, // Dôležité: Scaffold nesmie prekrývať gradient
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
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
    return GlassmorphismContainer(padding: padding, child: child);
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.local_shipping_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Text(
            'Kalkulácia dopravy',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
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
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Checkbox(
                value: _isRoundTrip,
                onChanged: (value) {
                  setState(() {
                    _isRoundTrip = value ?? false;
                  });
                },
                activeColor: Colors.white,
                checkColor: const Color(0xFF764BA2),
              ),
              Expanded(
                child: Text(
                  'Cesta tam aj späť (zdvojnásobí KM)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Colors.white.withOpacity(0.8),
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Aplikácia používa OpenStreetMap (bezplatné). Pre ešte lepšie výsledky môžete zadať vlastný Google Maps API kľúč.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
              ),
            ],
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
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          onChanged:
              onChanged ??
              (value) {
                if (controller == _apiKeyController) {
                  setState(() {});
                }
              },
          style: const TextStyle(color: Colors.white),
          keyboardType: obscureText ? TextInputType.text : TextInputType.number,
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: Colors.white.withOpacity(0.7),
              size: 20,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
          ),
        ),
      ],
    );
  }

  Widget _buildCalculateButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isCalculating ? null : _calculateTransport,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF764BA2),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
        ),
        child: _isCalculating
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF764BA2)),
                ),
              )
            : const Text(
                'VYPOČÍTAŤ NÁKLADY',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
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
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 20),

        // Vzdialenosť
        _buildResultCard(
          'Vzdialenosť',
          '${_calculatedDistance!.toStringAsFixed(2)} km',
          Icons.straighten_rounded,
          Colors.white,
        ),
        const SizedBox(height: 12),

        // Základná cena
        _buildResultCard(
          'Základná cena',
          '${_calculationResult!['baseCost']!.toStringAsFixed(2)} €',
          Icons.euro_rounded,
          Colors.white,
        ),
        const SizedBox(height: 12),

        // Náklady na palivo
        if (_calculationResult!['fuelCost']! > 0) ...[
          _buildResultCard(
            'Náklady na palivo',
            '${_calculationResult!['fuelCost']!.toStringAsFixed(2)} €',
            Icons.local_gas_station_rounded,
            Colors.white,
          ),
          const SizedBox(height: 12),
        ],

        // Celkové náklady
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.3),
                Colors.white.withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Celkové náklady',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '${_calculationResult!['totalCost']!.toStringAsFixed(2)} €',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
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
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'PDF ŠTÍTOK',
                Icons.picture_as_pdf_rounded,
                _generatePdfLabel,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String text, IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.2),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          elevation: 0,
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
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
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
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
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
                        color: const Color(0xFF6366F1),
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
