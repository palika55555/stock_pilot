import 'dart:async'; // Pre TimeoutException
import 'dart:convert'; // Potrebné pre prácu s JSON
import 'package:crypto/crypto.dart'; // Pre hash výpočet
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Pre FilteringTextInputFormatter
import 'package:http/http.dart' as http; // Balíček pre API volania
import 'package:html/parser.dart' as html_parser; // Pre parsovanie HTML
import 'package:html/dom.dart' as html_dom; // Pre prácu s HTML DOM

class AddSupplierModal extends StatefulWidget {
  const AddSupplierModal({super.key});

  @override
  State<AddSupplierModal> createState() => _AddSupplierModalState();
}

class _AddSupplierModalState extends State<AddSupplierModal> {
  final _formKey = GlobalKey<FormState>();

  // Kontrolery
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _icoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _dicController = TextEditingController();
  final TextEditingController _icDphController = TextEditingController();

  // Stav pre načítavanie
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _icoController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _dicController.dispose();
    _icDphController.dispose();
    super.dispose();
  }

  // --- LOGIKA PRE FINSTAT / API ---
  static const String _finstatApiKey = 'YOUR_API_KEY_HERE';
  static const String _finstatApiSecret = 'YOUR_API_SECRET_HERE';
  static const String _finstatBaseUrl = 'https://www.finstat.sk/api';

  String _calculateHash(String ico, String apiKey, String apiSecret) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final data = '$ico$apiKey$apiSecret$timestamp';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _fetchFinstatData() async {
    final ico = _icoController.text.trim();
    if (ico.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zadajte najprv IČO')));
      return;
    }
    if (ico.length != 8 || !RegExp(r'^\d+$').hasMatch(ico)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('IČO musí obsahovať presne 8 číslic')));
      return;
    }

    setState(() { _isLoading = true; });

    try {
      if (_finstatApiKey != 'YOUR_API_KEY_HERE' && _finstatApiSecret != 'YOUR_API_SECRET_HERE') {
        await _fetchFromFinstatAPI(ico);
      } else {
        await _fetchFromAlternativeAPI(ico);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba pri načítaní dát: ${e.toString()}')));
      }
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  Future<void> _fetchFromFinstatAPI(String ico) async {
    try {
      final hash = _calculateHash(ico, _finstatApiKey, _finstatApiSecret);
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final url = Uri.parse('$_finstatBaseUrl/detail').replace(queryParameters: {
        'ico': ico, 'apiKey': _finstatApiKey, 'hash': hash, 'timestamp': timestamp,
      });
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        _parseFinstatResponse(json.decode(utf8.decode(response.bodyBytes)));
      } else {
        await _fetchFromAlternativeAPI(ico);
      }
    } catch (e) {
      await _fetchFromAlternativeAPI(ico);
    }
  }

  Future<void> _fetchFromAlternativeAPI(String ico) async {
    try {
      await _fetchFromFinstatWeb(ico);
    } catch (e) {
      try {
        await _fetchFromORSRAPI(ico);
      } catch (e2) {
        _setBasicData(ico);
      }
    }
  }

  Future<void> _fetchFromFinstatWeb(String ico) async {
    final url = Uri.parse('https://www.finstat.sk/$ico');
    final response = await http.get(url, headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    }).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final document = html_parser.parse(utf8.decode(response.bodyBytes));
      _parseFinstatHTML(document, ico);
    } else {
      throw Exception('Nepodarilo sa načítať stránku: ${response.statusCode}');
    }
  }

  void _parseFinstatHTML(html_dom.Document document, String ico) {
    setState(() {
      final allText = document.body?.text ?? '';
      String? tempAddress;
      
      // 1. DIČ
      final dicMatch = RegExp(r'DIČ[:\s]*(\d{10})', caseSensitive: false).firstMatch(allText);
      if (dicMatch != null) _dicController.text = dicMatch.group(1)!;

      // 2. IČ DPH
      final icDphMatch = RegExp(r'IČ\s*DPH[:\s]*(SK\d{10})', caseSensitive: false).firstMatch(allText);
      if (icDphMatch != null) _icDphController.text = icDphMatch.group(1)!;

      // 3. Sídlo a Názov firmy
      // Hľadáme sekciu Sídlo
      final sidloPattern = RegExp(r'Sídlo[:\s]+(.+?)(?=\n\n|\nDátum vzniku|\nDIČ|\nIČ DPH|$)', caseSensitive: false, dotAll: true);
      final sidloMatch = sidloPattern.firstMatch(allText);
      
      if (sidloMatch != null) {
        final sidloText = sidloMatch.group(1)?.trim() ?? '';
        final lines = sidloText.split(RegExp(r'\n|\r\n')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        
        print('=== DEBUG: Parsovanie Sídlo ===');
        print('Počet riadkov: ${lines.length}');
        for (var i = 0; i < lines.length; i++) {
          print('Riadok $i: "${lines[i]}"');
        }
        
        if (lines.isNotEmpty) {
          // --- PARSOVANIE NÁZVU FIRMY, ADRESY, PSČ A MESTA ---
          String nameLine = lines[0];
          int postalLineIndex = -1;
          String? extractedPostal;
          String? extractedCity;
          String? extractedAddress;

          // Najprv hľadáme PSČ a mesto v prvom riadku (môže tam byť všetko spolu)
          final postalMatchInFirstLine = RegExp(r'(\d{3}\s\d{2})\s+([A-ZÁÉÍÓÚÝÔäáéíóúýô][a-záéíóúýô]+(?:\s+[A-ZÁÉÍÓÚÝÔäáéíóúýô][a-záéíóúýô]+)*)', caseSensitive: false).firstMatch(nameLine);
          
          if (postalMatchInFirstLine != null) {
            extractedPostal = postalMatchInFirstLine.group(1)!.trim();
            extractedCity = postalMatchInFirstLine.group(2)!.trim();
            postalLineIndex = 0;
            
            // Extrahujeme názov firmy (všetko pred PSČ)
            final nameEndIndex = postalMatchInFirstLine.start;
            String fullNameAndAddress = nameLine.substring(0, nameEndIndex).trim();
            
            // Nájdeme koniec názvu firmy (s.r.o., a.s., atď.)
            final legalFormMatch = RegExp(r'^(.+?\s+(?:s\.\s*r\.\s*o\.|s\.r\.o\.|a\.s\.|spol\.))', caseSensitive: false).firstMatch(fullNameAndAddress);
            
            if (legalFormMatch != null) {
              _nameController.text = legalFormMatch.group(1)!.trim();
              // Zvyšok je adresa
              extractedAddress = fullNameAndAddress.substring(legalFormMatch.end).trim();
            } else {
              // Ak nenájdeme právnu formu, vezmeme prvých pár slov ako názov
              final words = fullNameAndAddress.split(RegExp(r'\s+'));
              if (words.length > 1) {
                _nameController.text = words.take(words.length - 2).join(' ');
                extractedAddress = words.skip(words.length - 2).join(' ');
              } else {
                _nameController.text = fullNameAndAddress;
              }
            }
            
            print('NÁJDENÉ v prvom riadku - PSČ: $extractedPostal, Mesto: $extractedCity, Adresa: $extractedAddress');
          } else {
            // Ak nie je PSČ v prvom riadku, parsujeme normálne
            final legalFormMatch = RegExp(r'^(.+?\s+(?:s\.\s*r\.\s*o\.|s\.r\.o\.|a\.s\.|spol\.))', caseSensitive: false).firstMatch(nameLine);
            
            if (legalFormMatch != null) {
              _nameController.text = legalFormMatch.group(1)!.trim();
              final remainingText = nameLine.substring(legalFormMatch.end).trim();
              if (remainingText.isNotEmpty) tempAddress = remainingText;
            } else {
              _nameController.text = nameLine;
            }

            // Hľadáme PSČ v ostatných riadkoch
            for (var i = 1; i < lines.length; i++) {
              final line = lines[i];
              print('Kontrolujem riadok $i: "$line"');
              
              final matchWithSpace = RegExp(r'(\d{3}\s\d{2})\s+([A-ZÁÉÍÓÚÝÔäáéíóúýô][a-záéíóúýô]+(?:\s+[A-ZÁÉÍÓÚÝÔäáéíóúýô][a-záéíóúýô]+)*)', caseSensitive: false).firstMatch(line);
              if (matchWithSpace != null) {
                extractedPostal = matchWithSpace.group(1)!.trim();
                extractedCity = matchWithSpace.group(2)!.trim();
                postalLineIndex = i;
                print('NÁJDENÉ PSČ s medzerou: $extractedPostal, Mesto: $extractedCity');
                break;
              }
            }
          }

          // Nastavenie PSČ a mesta
          if (extractedPostal != null && extractedCity != null) {
            _postalCodeController.text = extractedPostal;
            _cityController.text = extractedCity;

            // Nastavenie adresy
            if (extractedAddress != null && extractedAddress.isNotEmpty) {
              _addressController.text = extractedAddress;
            } else if (tempAddress != null && tempAddress.isNotEmpty) {
              List<String> addressParts = [tempAddress];
              
              // Pridáme riadky medzi názvom firmy a PSČ
              if (postalLineIndex > 0) {
                for (var j = 1; j < postalLineIndex; j++) {
                  final addrLine = lines[j].trim();
                  if (addrLine.isNotEmpty && !addressParts.contains(addrLine)) {
                    addressParts.add(addrLine);
                  }
                }
              }
              
              String finalAddress = addressParts.join(', ');
              // Odstránime balast
              final stopWords = ['Dátum vzniku', 'Právna forma', 'SK NACE', 'Druh vlastníctva'];
              for (var word in stopWords) {
                if (finalAddress.contains(word)) {
                  finalAddress = finalAddress.split(word)[0].trim();
                }
              }
              if (finalAddress.endsWith(',')) finalAddress = finalAddress.substring(0, finalAddress.length - 1).trim();
              
              if (finalAddress.isNotEmpty) {
                _addressController.text = finalAddress;
              }
            }
            
            print('Nastavená adresa: ${_addressController.text}');
            print('Nastavené PSČ: ${_postalCodeController.text}');
            print('Nastavené mesto: ${_cityController.text}');
          } else {
            print('PSČ a mesto sa NEPODARILO nájsť!');
          }
        }
      } else {
        print('Sekcia Sídlo sa NEPODARILA nájsť!');
      }

      // 4. Email
      final emailRegex = RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b');
      final emailMatch = emailRegex.firstMatch(allText);
      if (emailMatch != null) _emailController.text = emailMatch.group(0)!;
    });
  }

  Future<void> _fetchFromORSRAPI(String ico) async {
    final url = Uri.parse('https://www.orsr.sk/api/search').replace(queryParameters: {'ico': ico, 'format': 'json'});
    final response = await http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      _parseAlternativeResponse(json.decode(utf8.decode(response.bodyBytes)), ico);
    }
  }

  void _parseFinstatResponse(Map<String, dynamic> data) {
    setState(() {
      _nameController.text = (data['Name'] ?? data['name'] ?? '').toString();
      _emailController.text = (data['Email'] ?? data['email'] ?? '').toString();
      _addressController.text = (data['Address'] ?? data['address'] ?? '').toString();
      _cityController.text = (data['City'] ?? data['city'] ?? '').toString();
      _postalCodeController.text = (data['PostalCode'] ?? data['postalCode'] ?? '').toString();
      _dicController.text = (data['DIC'] ?? data['dic'] ?? '').toString();
      _icDphController.text = (data['ICDPH'] ?? data['icdph'] ?? '').toString();
    });
  }

  void _parseAlternativeResponse(Map<String, dynamic> data, String ico) {
    setState(() {
      _nameController.text = (data['name'] ?? data['Name'] ?? '').toString();
      _emailController.text = (data['email'] ?? data['Email'] ?? '').toString();
      _addressController.text = (data['address'] ?? data['Address'] ?? '').toString();
      _cityController.text = (data['city'] ?? data['City'] ?? '').toString();
      _postalCodeController.text = (data['postalCode'] ?? data['PostalCode'] ?? data['psc'] ?? '').toString();
      _dicController.text = (data['dic'] ?? data['DIC'] ?? '').toString();
      _icDphController.text = (data['icDph'] ?? data['ICDPH'] ?? data['vatId'] ?? '').toString();
    });
  }

  void _setBasicData(String ico) {
    setState(() { if (_nameController.text.isEmpty) _nameController.text = 'Firma IČO: $ico'; });
  }

  void _submitData() {
    if (_formKey.currentState!.validate()) {
      final newSupplier = {
        'name': _nameController.text,
        'ico': _icoController.text,
        'email': _emailController.text,
        'address': _addressController.text,
        'city': _cityController.text,
        'postalCode': _postalCodeController.text,
        'dic': _dicController.text,
        'icDph': _icDphController.text,
      };
      Navigator.pop(context, newSupplier);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Pridať nového dodávateľa', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _icoController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.search,
                onFieldSubmitted: (_) => _fetchFinstatData(),
                decoration: InputDecoration(
                  labelText: 'IČO',
                  hintText: 'Zadajte IČO a kliknite na lupu',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.numbers),
                  suffixIcon: _isLoading
                      ? const Padding(padding: EdgeInsets.all(10.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                      : IconButton(icon: const Icon(Icons.search, color: Colors.blue), onPressed: _fetchFinstatData, tooltip: 'Načítať dáta z Finstatu'),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Zadajte IČO' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Názov firmy', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business)),
                validator: (value) => value == null || value.isEmpty ? 'Zadajte názov' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Adresa', hintText: 'Ulica a číslo', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on)),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(flex: 2, child: TextFormField(controller: _cityController, decoration: const InputDecoration(labelText: 'Mesto', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_city)))),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(
                    controller: _postalCodeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'PSČ', hintText: '067 45', border: OutlineInputBorder(), prefixIcon: Icon(Icons.markunread_mailbox)),
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s]'))],
                  )),
                ],
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _dicController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'DIČ', hintText: 'Daňové identifikačné číslo', border: OutlineInputBorder(), prefixIcon: Icon(Icons.receipt)),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _icDphController,
                decoration: const InputDecoration(labelText: 'IČ DPH', hintText: 'Identifikačné číslo pre DPH', border: OutlineInputBorder(), prefixIcon: Icon(Icons.account_box)),
              ),
              const SizedBox(height: 25),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _submitData, style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white), child: const Text('Uložiť dodávateľa'))),
            ],
          ),
        ),
      ),
    );
  }
}
