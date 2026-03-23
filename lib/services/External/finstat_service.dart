import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import '../../models/supplier.dart';

class FinstatService {
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

  Future<Supplier?> fetchSupplierData(String ico) async {
    try {
      if (_finstatApiKey != 'YOUR_API_KEY_HERE' &&
          _finstatApiSecret != 'YOUR_API_SECRET_HERE') {
        return await _fetchFromFinstatAPI(ico);
      } else {
        return await _fetchFromAlternativeAPI(ico);
      }
    } catch (e) {

      return null;
    }
  }

  Future<Supplier?> _fetchFromFinstatAPI(String ico) async {
    try {
      final hash = _calculateHash(ico, _finstatApiKey, _finstatApiSecret);
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final url = Uri.parse('$_finstatBaseUrl/detail').replace(
        queryParameters: {
          'ico': ico,
          'apiKey': _finstatApiKey,
          'hash': hash,
          'timestamp': timestamp,
        },
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return Supplier(
          name: (data['Name'] ?? data['name'] ?? '').toString(),
          ico: ico,
          email: (data['Email'] ?? data['email'] ?? '').toString(),
          address: (data['Address'] ?? data['address'] ?? '').toString(),
          city: (data['City'] ?? data['city'] ?? '').toString(),
          postalCode: (data['PostalCode'] ?? data['postalCode'] ?? '')
              .toString(),
          dic: (data['DIC'] ?? data['dic'] ?? '').toString(),
          icDph: (data['ICDPH'] ?? data['icdph'] ?? '').toString(),
        );
      } else {
        return await _fetchFromAlternativeAPI(ico);
      }
    } catch (e) {
      return await _fetchFromAlternativeAPI(ico);
    }
  }

  Future<Supplier?> _fetchFromAlternativeAPI(String ico) async {
    try {
      return await _fetchFromFinstatWeb(ico);
    } catch (e) {
      try {
        return await _fetchFromORSRAPI(ico);
      } catch (e2) {
        return Supplier(name: 'Firma IČO: $ico', ico: ico);
      }
    }
  }

  Future<Supplier?> _fetchFromFinstatWeb(String ico) async {
    final url = Uri.parse('https://www.finstat.sk/$ico');
    final response = await http
        .get(
          url,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final document = html_parser.parse(utf8.decode(response.bodyBytes));
      return _parseFinstatHTML(document, ico);
    } else {
      throw Exception('Nepodarilo sa načítať stránku: ${response.statusCode}');
    }
  }

  Supplier? _parseFinstatHTML(html_dom.Document document, String ico) {
    final allText = document.body?.text ?? '';
    String? tempAddress;
    String? dic;
    String? icDph;
    String? name;
    String? email;
    String? city;
    String? postalCode;
    String? address;

    // 1. DIČ
    final dicMatch = RegExp(
      r'DIČ[:\s]*(\d{10})',
      caseSensitive: false,
    ).firstMatch(allText);
    if (dicMatch != null) dic = dicMatch.group(1)!;

    // 2. IČ DPH
    final icDphMatch = RegExp(
      r'IČ\s*DPH[:\s]*(SK\d{10})',
      caseSensitive: false,
    ).firstMatch(allText);
    if (icDphMatch != null) icDph = icDphMatch.group(1)!;

    // 3. Sídlo a Názov firmy
    final sidloPattern = RegExp(
      r'Sídlo[:\s]+(.+?)(?=\n\n|\nDátum vzniku|\nDIČ|\nIČ DPH|$)',
      caseSensitive: false,
      dotAll: true,
    );
    final sidloMatch = sidloPattern.firstMatch(allText);

    if (sidloMatch != null) {
      final sidloText = sidloMatch.group(1)?.trim() ?? '';
      final lines = sidloText
          .split(RegExp(r'\n|\r\n'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (lines.isNotEmpty) {
        String nameLine = lines[0];
        int postalLineIndex = -1;
        String? extractedPostal;
        String? extractedCity;
        String? extractedAddress;

        final postalMatchInFirstLine = RegExp(
          r'(\d{3}\s\d{2})\s+([A-ZÁÉÍÓÚÝÔäáéíóúýô][a-záéíóúýô]+(?:\s+[A-ZÁÉÍÓÚÝÔäáéíóúýô][a-záéíóúýô]+)*)',
          caseSensitive: false,
        ).firstMatch(nameLine);

        if (postalMatchInFirstLine != null) {
          extractedPostal = postalMatchInFirstLine.group(1)!.trim();
          extractedCity = postalMatchInFirstLine.group(2)!.trim();
          postalLineIndex = 0;
          final nameEndIndex = postalMatchInFirstLine.start;
          String fullNameAndAddress = nameLine
              .substring(0, nameEndIndex)
              .trim();
          final legalFormMatch = RegExp(
            r'^(.+?\s+(?:s\.\s*r\.\s*o\.|s\.r\.o\.|a\.s\.|spol\.))',
            caseSensitive: false,
          ).firstMatch(fullNameAndAddress);
          if (legalFormMatch != null) {
            name = legalFormMatch.group(1)!.trim();
            extractedAddress = fullNameAndAddress
                .substring(legalFormMatch.end)
                .trim();
          } else {
            final words = fullNameAndAddress.split(RegExp(r'\s+'));
            if (words.length > 1) {
              name = words.take(words.length - 2).join(' ');
              extractedAddress = words.skip(words.length - 2).join(' ');
            } else {
              name = fullNameAndAddress;
            }
          }
        } else {
          final legalFormMatch = RegExp(
            r'^(.+?\s+(?:s\.\s*r\.\s*o\.|s\.r\.o\.|a\.s\.|spol\.))',
            caseSensitive: false,
          ).firstMatch(nameLine);
          if (legalFormMatch != null) {
            name = legalFormMatch.group(1)!.trim();
            final remainingText = nameLine.substring(legalFormMatch.end).trim();
            if (remainingText.isNotEmpty) tempAddress = remainingText;
          } else {
            name = nameLine;
          }
          for (var i = 1; i < lines.length; i++) {
            final line = lines[i];
            final matchWithSpace = RegExp(
              r'(\d{3}\s\d{2})\s+([A-ZÁÉÍÓÚÝÔäáéíóúýô][a-záéíóúýô]+(?:\s+[A-ZÁÉÍÓÚÝÔäáéíóúýô][a-záéíóúýô]+)*)',
              caseSensitive: false,
            ).firstMatch(line);
            if (matchWithSpace != null) {
              extractedPostal = matchWithSpace.group(1)!.trim();
              extractedCity = matchWithSpace.group(2)!.trim();
              postalLineIndex = i;
              break;
            }
          }
        }

        if (extractedPostal != null && extractedCity != null) {
          postalCode = extractedPostal;
          city = extractedCity;
          if (extractedAddress != null && extractedAddress.isNotEmpty) {
            address = extractedAddress;
          } else if (tempAddress != null && tempAddress.isNotEmpty) {
            List<String> addressParts = [tempAddress];
            if (postalLineIndex > 0) {
              for (var j = 1; j < postalLineIndex; j++) {
                final addrLine = lines[j].trim();
                if (addrLine.isNotEmpty && !addressParts.contains(addrLine)) {
                  addressParts.add(addrLine);
                }
              }
            }
            String finalAddress = addressParts.join(', ');
            final stopWords = [
              'Dátum vzniku',
              'Právna forma',
              'SK NACE',
              'Druh vlastníctva',
            ];
            for (var word in stopWords) {
              if (finalAddress.contains(word)) {
                finalAddress = finalAddress.split(word)[0].trim();
              }
            }
            if (finalAddress.endsWith(','))
              finalAddress = finalAddress
                  .substring(0, finalAddress.length - 1)
                  .trim();
            if (finalAddress.isNotEmpty) {
              address = finalAddress;
            }
          }
        }
      }
    }

    final emailRegex = RegExp(
      r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
    );
    final emailMatch = emailRegex.firstMatch(allText);
    if (emailMatch != null) email = emailMatch.group(0)!;

    return Supplier(
      name: name ?? 'Firma IČO: $ico',
      ico: ico,
      dic: dic,
      icDph: icDph,
      email: email,
      address: address,
      city: city,
      postalCode: postalCode,
    );
  }

  Future<Supplier?> _fetchFromORSRAPI(String ico) async {
    final url = Uri.parse(
      'https://www.orsr.sk/api/search',
    ).replace(queryParameters: {'ico': ico, 'format': 'json'});
    final response = await http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      return Supplier(
        name: (data['name'] ?? data['Name'] ?? '').toString(),
        ico: ico,
        email: (data['email'] ?? data['Email'] ?? '').toString(),
        address: (data['address'] ?? data['Address'] ?? '').toString(),
        city: (data['city'] ?? data['City'] ?? '').toString(),
        postalCode:
            (data['postalCode'] ?? data['PostalCode'] ?? data['psc'] ?? '')
                .toString(),
        dic: (data['dic'] ?? data['DIC'] ?? '').toString(),
        icDph: (data['icDph'] ?? data['ICDPH'] ?? data['vatId'] ?? '')
            .toString(),
      );
    }
    return null;
  }
}
