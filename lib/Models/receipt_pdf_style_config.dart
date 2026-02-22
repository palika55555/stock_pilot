import 'package:shared_preferences/shared_preferences.dart';

/// Konfigurácia štýlu PDF pre príjemky. Ukladá sa do SharedPreferences.
class ReceiptPdfStyleConfig {
  static const String _keyPrefix = 'receipt_pdf_style_';
  static const String _keyTitleFontSize = '${_keyPrefix}title_font_size';
  static const String _keyDocumentTitle = '${_keyPrefix}document_title';
  static const String _keyShowIssuedBy = '${_keyPrefix}show_issued_by';
  static const String _keyShowSignatureBlock = '${_keyPrefix}show_signature_block';
  static const String _keyPrimaryColorHex = '${_keyPrefix}primary_color_hex';
  static const String _keyBodyFontSize = '${_keyPrefix}body_font_size';
  static const String _keyTableHeaderColorHex = '${_keyPrefix}table_header_color_hex';
  static const String _keyShowColProductName = '${_keyPrefix}show_col_product_name';
  static const String _keyShowColPlu = '${_keyPrefix}show_col_plu';
  static const String _keyShowColQty = '${_keyPrefix}show_col_qty';
  static const String _keyShowColUnit = '${_keyPrefix}show_col_unit';
  static const String _keyShowColUnitPriceWithVat = '${_keyPrefix}show_col_unit_price_with_vat';
  static const String _keyShowColUnitPriceWithoutVat = '${_keyPrefix}show_col_unit_price_without_vat';
  static const String _keyShowColTotal = '${_keyPrefix}show_col_total';
  static const String _keyShowColLastPurchaseDate = '${_keyPrefix}show_col_last_purchase_date';
  static const String _keyShowColVatRate = '${_keyPrefix}show_col_vat_rate';
  static const String _keyShowColVatAmount = '${_keyPrefix}show_col_vat_amount';

  /// Veľkosť písma nadpisu dokumentu (napr. PRÍJEMKA TOVARU).
  final int titleFontSize;
  /// Vlastný text nadpisu (ak prázdne, použije sa predvolený).
  final String documentTitle;
  /// Zobraziť sekciu „Vystavil“.
  final bool showIssuedBy;
  /// Zobraziť blok na podpis a dátum prijatia.
  final bool showSignatureBlock;
  /// Primárna farba (nadpis, dôležité texty) v hex napr. „#1E3A5F“. Null = predvolená.
  final String? primaryColorHex;
  /// Veľkosť písma tela (dátum, dodávateľ, tabuľka).
  final int bodyFontSize;
  /// Farba hlavičky tabuľky v hex. Null = predvolená šedá.
  final String? tableHeaderColorHex;

  /// Stĺpce v tabuľke PDF (zapínacie v konfigurátore).
  final bool showColProductName;
  final bool showColPlu;
  final bool showColQty;
  final bool showColUnit;
  final bool showColUnitPriceWithVat;
  final bool showColUnitPriceWithoutVat;
  final bool showColTotal;
  final bool showColLastPurchaseDate;
  /// Zobraziť stĺpec so sadzbou DPH (%).
  final bool showColVatRate;
  /// Zobraziť stĺpec s výškou DPH v € za riadok.
  final bool showColVatAmount;

  const ReceiptPdfStyleConfig({
    this.titleFontSize = 18,
    this.documentTitle = '',
    this.showIssuedBy = true,
    this.showSignatureBlock = true,
    this.primaryColorHex,
    this.bodyFontSize = 10,
    this.tableHeaderColorHex,
    this.showColProductName = true,
    this.showColPlu = true,
    this.showColQty = true,
    this.showColUnit = true,
    this.showColUnitPriceWithVat = true,
    this.showColUnitPriceWithoutVat = true,
    this.showColTotal = true,
    this.showColLastPurchaseDate = false,
    this.showColVatRate = true,
    this.showColVatAmount = true,
  });

  String get effectiveDocumentTitle =>
      documentTitle.trim().isEmpty ? 'PRÍJEMKA TOVARU' : documentTitle.trim();

  static const Object _omit = Object();

  ReceiptPdfStyleConfig copyWith({
    int? titleFontSize,
    String? documentTitle,
    bool? showIssuedBy,
    bool? showSignatureBlock,
    Object? primaryColorHex = _omit,
    int? bodyFontSize,
    Object? tableHeaderColorHex = _omit,
    bool? showColProductName,
    bool? showColPlu,
    bool? showColQty,
    bool? showColUnit,
    bool? showColUnitPriceWithVat,
    bool? showColUnitPriceWithoutVat,
    bool? showColTotal,
    bool? showColLastPurchaseDate,
    bool? showColVatRate,
    bool? showColVatAmount,
  }) {
    return ReceiptPdfStyleConfig(
      titleFontSize: titleFontSize ?? this.titleFontSize,
      documentTitle: documentTitle ?? this.documentTitle,
      showIssuedBy: showIssuedBy ?? this.showIssuedBy,
      showSignatureBlock: showSignatureBlock ?? this.showSignatureBlock,
      primaryColorHex: primaryColorHex == _omit ? this.primaryColorHex : primaryColorHex as String?,
      bodyFontSize: bodyFontSize ?? this.bodyFontSize,
      tableHeaderColorHex: tableHeaderColorHex == _omit ? this.tableHeaderColorHex : tableHeaderColorHex as String?,
      showColProductName: showColProductName ?? this.showColProductName,
      showColPlu: showColPlu ?? this.showColPlu,
      showColQty: showColQty ?? this.showColQty,
      showColUnit: showColUnit ?? this.showColUnit,
      showColUnitPriceWithVat: showColUnitPriceWithVat ?? this.showColUnitPriceWithVat,
      showColUnitPriceWithoutVat: showColUnitPriceWithoutVat ?? this.showColUnitPriceWithoutVat,
      showColTotal: showColTotal ?? this.showColTotal,
      showColLastPurchaseDate: showColLastPurchaseDate ?? this.showColLastPurchaseDate,
      showColVatRate: showColVatRate ?? this.showColVatRate,
      showColVatAmount: showColVatAmount ?? this.showColVatAmount,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTitleFontSize, titleFontSize);
    await prefs.setString(_keyDocumentTitle, documentTitle);
    await prefs.setBool(_keyShowIssuedBy, showIssuedBy);
    await prefs.setBool(_keyShowSignatureBlock, showSignatureBlock);
    await prefs.setInt(_keyBodyFontSize, bodyFontSize);
    await prefs.setBool(_keyShowColProductName, showColProductName);
    await prefs.setBool(_keyShowColPlu, showColPlu);
    await prefs.setBool(_keyShowColQty, showColQty);
    await prefs.setBool(_keyShowColUnit, showColUnit);
    await prefs.setBool(_keyShowColUnitPriceWithVat, showColUnitPriceWithVat);
    await prefs.setBool(_keyShowColUnitPriceWithoutVat, showColUnitPriceWithoutVat);
    await prefs.setBool(_keyShowColTotal, showColTotal);
    await prefs.setBool(_keyShowColLastPurchaseDate, showColLastPurchaseDate);
    await prefs.setBool(_keyShowColVatRate, showColVatRate);
    await prefs.setBool(_keyShowColVatAmount, showColVatAmount);
    if (primaryColorHex != null) {
      await prefs.setString(_keyPrimaryColorHex, primaryColorHex!);
    } else {
      await prefs.remove(_keyPrimaryColorHex);
    }
    if (tableHeaderColorHex != null) {
      await prefs.setString(_keyTableHeaderColorHex, tableHeaderColorHex!);
    } else {
      await prefs.remove(_keyTableHeaderColorHex);
    }
  }

  static Future<ReceiptPdfStyleConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ReceiptPdfStyleConfig(
      titleFontSize: prefs.getInt(_keyTitleFontSize) ?? 18,
      documentTitle: prefs.getString(_keyDocumentTitle) ?? '',
      showIssuedBy: prefs.getBool(_keyShowIssuedBy) ?? true,
      showSignatureBlock: prefs.getBool(_keyShowSignatureBlock) ?? true,
      primaryColorHex: prefs.getString(_keyPrimaryColorHex),
      bodyFontSize: prefs.getInt(_keyBodyFontSize) ?? 10,
      tableHeaderColorHex: prefs.getString(_keyTableHeaderColorHex),
      showColProductName: prefs.getBool(_keyShowColProductName) ?? true,
      showColPlu: prefs.getBool(_keyShowColPlu) ?? true,
      showColQty: prefs.getBool(_keyShowColQty) ?? true,
      showColUnit: prefs.getBool(_keyShowColUnit) ?? true,
      showColUnitPriceWithVat: prefs.getBool(_keyShowColUnitPriceWithVat) ?? true,
      showColUnitPriceWithoutVat: prefs.getBool(_keyShowColUnitPriceWithoutVat) ?? true,
      showColTotal: prefs.getBool(_keyShowColTotal) ?? true,
      showColLastPurchaseDate: prefs.getBool(_keyShowColLastPurchaseDate) ?? false,
      showColVatRate: prefs.getBool(_keyShowColVatRate) ?? true,
      showColVatAmount: prefs.getBool(_keyShowColVatAmount) ?? true,
    );
  }
}
