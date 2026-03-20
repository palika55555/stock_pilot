import '../../models/company.dart';
import '../../models/invoice.dart';

/// Typ platobného QR reťazca.
enum InvoiceQrKind {
  /// Pay by Square (SK štandard – reťazec z backendu / bysquare).
  payBySquare,
  /// Európsky SEPA/EPC QR – funguje v mnohých bankách, nevyžaduje backend.
  epcSepa,
}

/// EMVCo „EPC069-12“ reťazec pre SEPA Credit Transfer (QR platba v EUR).
/// Nie je to Pay by Square, ale väčšina mobilných bánk vie takýto QR spracovať.
String? buildEpcSepaQrData({
  required Company company,
  required Invoice invoice,
}) {
  final iban = (company.iban ?? '').replaceAll(' ', '').trim();
  if (iban.isEmpty) return null;

  final name = company.name.replaceAll('\n', ' ').trim();
  if (name.isEmpty) return null;

  final vs = (invoice.variableSymbol ?? invoice.invoiceNumber)
      .replaceAll(RegExp(r'[^0-9]'), '');
  final remittance = vs.isNotEmpty ? 'VS: $vs' : 'Faktúra ${invoice.invoiceNumber}';

  final amt = invoice.totalWithVat;
  if (amt <= 0) return null;

  final amountStr = 'EUR${amt.toStringAsFixed(2)}';

  return [
    'BCD',
    '002',
    '1',
    'SCT',
    '', // BIC – voliteľné pri IBAN-only
    _epcField(name, 70),
    _epcField(iban, 34),
    _epcField(amountStr, 12),
    '', // purpose
    '', // structured reference
    _epcField(remittance, 140),
  ].join('\n');
}

String _epcField(String value, int maxLen) {
  var s = value.trim();
  if (s.length > maxLen) s = s.substring(0, maxLen);
  return s;
}
