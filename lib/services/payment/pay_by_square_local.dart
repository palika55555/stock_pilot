import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;
import 'package:base32/base32.dart' as b32;
import 'package:base32/encodings.dart';
import 'package:lzma/lzma.dart';

import '../../models/company.dart';
import '../../models/invoice.dart';

/// Lokálne vygeneruje **Pay by Square** reťazec (rovnaký postup ako npm `bysquare` 2.x `generate`).
/// Vyžaduje IBAN – vhodné pre SLSP a ostatné SK banky pri „Novej platbe“ → sken QR.
String? buildPayBySquareQrStringLocal({
  required Company company,
  required Invoice invoice,
}) {
  try {
    final iban = (company.iban ?? '').replaceAll(' ', '').trim();
    if (iban.isEmpty) return null;

    final amount = invoice.totalWithVat;
    if (amount <= 0) return null;

    final vs = (invoice.variableSymbol ?? invoice.invoiceNumber)
        .replaceAll(RegExp(r'[^0-9]'), '');
    final note = _deburr('Faktura ${invoice.invoiceNumber}');

    final model = <String, dynamic>{
      'invoiceId': null,
      'payments': [
        <String, dynamic>{
          'type': 1,
          'amount': amount,
          'currencyCode': 'EUR',
          'paymentDueDate': '',
          'variableSymbol': vs,
          'constantSymbol': '0308',
          'specificSymbol': '',
          'originatorRefInfo': '',
          'paymentNote': note,
          'bankAccounts': [
            <String, dynamic>{'iban': iban, 'bic': ''},
          ],
          'beneficiary': <String, dynamic>{
            'name': _deburr(company.name),
            'street': _deburr(company.address ?? ''),
            'city': _deburr([
              if ((company.postalCode ?? '').trim().isNotEmpty) company.postalCode!.trim(),
              if ((company.city ?? '').trim().isNotEmpty) company.city!.trim(),
            ].join(' ')),
          },
        },
      ],
    };

    final serialized = _serialize(model);
    final withChecksum = _addChecksum(serialized);
    final compressed = lzma.encode(withChecksum);
    if (compressed.length < 14) return null;

    final lzmaBody = compressed.sublist(13);
    final header = _headerBysquare();
    final lenHeader = _headerDataLength(withChecksum.length);
    final output = Uint8List.fromList([
      ...header,
      ...lenHeader,
      ...lzmaBody,
    ]);

    var s = b32.base32.encode(
      output,
      encoding: Encoding.base32Hex,
    );
    s = s.replaceAll('=', '');
    return s;
  } catch (_) {
    return null;
  }
}

/// Zjednodušená náhrada za lodash.deburr – ASCII pre Pay by Square.
String _deburr(String s) {
  if (s.isEmpty) return s;
  const map = {
    'á': 'a', 'ä': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'å': 'a', 'ā': 'a',
    'č': 'c', 'ć': 'c', 'ç': 'c',
    'ď': 'd', 'đ': 'd',
    'é': 'e', 'ě': 'e', 'ë': 'e', 'è': 'e', 'ê': 'e', 'ē': 'e',
    'í': 'i', 'ï': 'i', 'ì': 'i', 'î': 'i', 'ī': 'i',
    'ľ': 'l', 'ĺ': 'l', 'ł': 'l',
    'ň': 'n', 'ń': 'n', 'ñ': 'n',
    'ó': 'o', 'ö': 'o', 'ô': 'o', 'ò': 'o', 'õ': 'o', 'ō': 'o',
    'ř': 'r',
    'š': 's', 'ś': 's',
    'ť': 't',
    'ú': 'u', 'ů': 'u', 'ü': 'u', 'ù': 'u', 'û': 'u', 'ū': 'u',
    'ý': 'y', 'ÿ': 'y',
    'ž': 'z', 'ź': 'z',
    'Á': 'A', 'Ä': 'A', 'Č': 'C', 'Ď': 'D', 'É': 'E', 'Ě': 'E', 'Í': 'I',
    'Ĺ': 'L', 'Ľ': 'L', 'Ň': 'N', 'Ó': 'O', 'Ô': 'O', 'Ř': 'R', 'Š': 'S',
    'Ť': 'T', 'Ú': 'U', 'Ý': 'Y', 'Ž': 'Z',
  };
  final buf = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    buf.write(map[c] ?? c);
  }
  return buf.toString();
}

String _serialize(Map<String, dynamic> data) {
  final serialized = <String>[];
  final invId = data['invoiceId'];
  serialized.add(invId == null ? '' : invId.toString());

  final payments = data['payments'] as List<dynamic>;
  serialized.add(payments.length.toString());

  for (final p in payments) {
    final pm = p as Map<String, dynamic>;
    serialized.add(pm['type'].toString());
    serialized.add(pm['amount']?.toString() ?? '');
    serialized.add(pm['currencyCode']?.toString() ?? '');
    serialized.add(pm['paymentDueDate']?.toString() ?? '');
    serialized.add(pm['variableSymbol']?.toString() ?? '');
    serialized.add(pm['constantSymbol']?.toString() ?? '');
    serialized.add(pm['specificSymbol']?.toString() ?? '');
    serialized.add(pm['originatorRefInfo']?.toString() ?? '');
    serialized.add(pm['paymentNote']?.toString() ?? '');

    final bas = pm['bankAccounts'] as List<dynamic>;
    serialized.add(bas.length.toString());
    for (final ba in bas) {
      final b = ba as Map<String, dynamic>;
      serialized.add(b['iban']?.toString() ?? '');
      serialized.add(b['bic']?.toString() ?? '');
    }

    final t = pm['type'] as int;
    if (t == 2) {
      serialized.add('1');
      serialized.add(pm['day']?.toString() ?? '');
      serialized.add(pm['month']?.toString() ?? '');
      serialized.add(pm['periodicity']?.toString() ?? '');
      serialized.add(pm['lastDate']?.toString() ?? '');
    } else {
      serialized.add('0');
    }

    if (t == 4) {
      serialized.add('1');
      serialized.add(pm['directDebitScheme']?.toString() ?? '');
      serialized.add(pm['directDebitType']?.toString() ?? '');
      serialized.add(pm['variableSymbol']?.toString() ?? '');
      serialized.add(pm['specificSymbol']?.toString() ?? '');
      serialized.add(pm['originatorRefInfo']?.toString() ?? '');
      serialized.add(pm['mandateId']?.toString() ?? '');
      serialized.add(pm['creditorId']?.toString() ?? '');
      serialized.add(pm['contractId']?.toString() ?? '');
      serialized.add(pm['maxAmount']?.toString() ?? '');
      serialized.add(pm['validTillDate']?.toString() ?? '');
    } else {
      serialized.add('0');
    }
  }

  for (final p in payments) {
    final pm = p as Map<String, dynamic>;
    final ben = pm['beneficiary'] as Map<String, dynamic>?;
    serialized.add(ben?['name']?.toString() ?? '');
    serialized.add(ben?['street']?.toString() ?? '');
    serialized.add(ben?['city']?.toString() ?? '');
  }

  return serialized.join('\t');
}

Uint8List _addChecksum(String serialized) {
  final crc = getCrc32(utf8.encode(serialized));
  final bd = ByteData(4);
  bd.setUint32(0, crc, Endian.little);
  return Uint8List.fromList([
    bd.getUint8(0),
    bd.getUint8(1),
    bd.getUint8(2),
    bd.getUint8(3),
    ...utf8.encode(serialized),
  ]);
}

/// Tabuľka 3.5 – 2 bajty (4 nibbles × 0).
Uint8List _headerBysquare() {
  return Uint8List.fromList([0x00, 0x00]);
}

/// Dĺžka nekomprimovaných dát + CRC (little-endian uint16) – ako `bysquare` / DataView default BE?
/// V JS: `new DataView(header).setUint16(0, length)` → **big-endian** na väčšine platforiem.
Uint8List _headerDataLength(int length) {
  final bd = ByteData(2);
  bd.setUint16(0, length, Endian.big);
  return Uint8List.view(bd.buffer);
}
