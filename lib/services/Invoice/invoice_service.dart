import '../../models/invoice.dart';
import '../../models/quote.dart';
import '../../models/customer.dart';
import '../Database/database_service.dart';
import '../api_sync_service.dart' show syncInvoicesToBackend;

class InvoiceService {
  final DatabaseService _db = DatabaseService();

  // ── Číslovanie ────────────────────────────────────────────────────────────

  Future<String> getNextInvoiceNumber(InvoiceType type) async {
    return await _db.getNextInvoiceNumber(type.numberPrefix);
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<int> createInvoice(Invoice invoice, List<InvoiceItem> items) async {
    final id = await _db.insertInvoice(invoice);
    for (final item in items) {
      await _db.insertInvoiceItem(item.copyWith(invoiceId: id));
    }
    syncInvoicesToBackend().ignore();
    return id;
  }

  Future<Invoice?> getInvoiceById(int id) async {
    return await _db.getInvoiceById(id);
  }

  Future<List<Invoice>> getAllInvoices({String? status, String? type}) async {
    return await _db.getInvoices(status: status, type: type);
  }

  Future<List<Invoice>> getInvoicesByCustomerId(int customerId) async {
    return await _db.getInvoicesByCustomerId(customerId);
  }

  Future<int> updateInvoice(Invoice invoice, List<InvoiceItem> items) async {
    final n = await _db.updateInvoice(invoice);
    if (invoice.id != null) {
      await _db.deleteInvoiceItemsByInvoiceId(invoice.id!);
      for (final item in items) {
        await _db.insertInvoiceItem(item.copyWith(invoiceId: invoice.id!));
      }
    }
    syncInvoicesToBackend().ignore();
    return n;
  }

  Future<int> deleteInvoice(int id) async {
    final n = await _db.deleteInvoice(id);
    syncInvoicesToBackend().ignore();
    return n;
  }

  Future<List<InvoiceItem>> getInvoiceItems(int invoiceId) async {
    return await _db.getInvoiceItems(invoiceId);
  }

  // ── Vytvorenie faktúry z cenovej ponuky ───────────────────────────────────

  Future<Invoice> buildFromQuote(Quote quote, List<QuoteItem> quoteItems, Customer customer) async {
    final invoiceNumber = await getNextInvoiceNumber(InvoiceType.issuedInvoice);
    final now = DateTime.now();
    final dueDate = now.add(const Duration(days: 14));

    final items = quoteItems.map((qi) {
      return InvoiceItem(
        invoiceId: 0,
        productUniqueId: qi.productUniqueId,
        productName: qi.productName,
        qty: qi.qty,
        unit: qi.unit,
        unitPrice: qi.getLineTotalWithoutVat(quote.pricesIncludeVat) / qi.qty,
        discountPercent: 0, // Zľava je už zahrnutá v cene
        vatPercent: qi.vatPercent,
        itemType: qi.itemType,
        description: qi.description,
      );
    }).toList();

    // Pridaj dopravu a ostatné poplatky ak sú
    if (quote.deliveryCost > 0) {
      items.add(InvoiceItem(
        invoiceId: 0,
        productName: 'Doprava',
        qty: 1,
        unit: 'ks',
        unitPrice: quote.deliveryCost,
        vatPercent: quote.defaultVatRate,
        itemType: 'Doprava',
      ));
    }
    if (quote.otherFees > 0) {
      items.add(InvoiceItem(
        invoiceId: 0,
        productName: 'Ostatné poplatky',
        qty: 1,
        unit: 'ks',
        unitPrice: quote.otherFees,
        vatPercent: quote.defaultVatRate,
        itemType: 'Služba',
      ));
    }

    final totals = calculateTotals(items);

    return Invoice(
      invoiceNumber: invoiceNumber,
      invoiceType: InvoiceType.issuedInvoice,
      issueDate: now,
      taxDate: now,
      dueDate: dueDate,
      customerId: customer.id,
      customerName: customer.name,
      customerAddress: customer.address,
      customerCity: customer.city,
      customerPostalCode: customer.postalCode,
      customerIco: customer.ico,
      customerDic: customer.dic,
      customerIcDph: customer.icDph,
      quoteId: quote.id,
      quoteNumber: quote.quoteNumber,
      projectId: quote.projectId,
      projectName: quote.projectName,
      paymentMethod: PaymentMethod.fromString(quote.paymentMethod),
      variableSymbol: invoiceNumber.replaceAll(RegExp(r'[^0-9]'), ''),
      totalWithoutVat: totals.$1,
      totalVat: totals.$2,
      totalWithVat: totals.$3,
    );
  }

  // ── Vytvorenie dobropisu (storna faktúry) ──────────────────────────────────

  Future<Invoice> buildCreditNote(Invoice original, List<InvoiceItem> originalItems) async {
    final creditNumber = await getNextInvoiceNumber(InvoiceType.creditNote);
    final now = DateTime.now();

    // Opačné hodnoty položiek (záporné množstvá)
    final items = originalItems.map((item) => item.copyWith(
      invoiceId: 0,
      qty: -item.qty.abs(),
    )).toList();

    final totals = calculateTotals(items);

    return Invoice(
      invoiceNumber: creditNumber,
      invoiceType: InvoiceType.creditNote,
      issueDate: now,
      taxDate: now,
      dueDate: now.add(const Duration(days: 14)),
      customerId: original.customerId,
      customerName: original.customerName,
      customerAddress: original.customerAddress,
      customerCity: original.customerCity,
      customerPostalCode: original.customerPostalCode,
      customerIco: original.customerIco,
      customerDic: original.customerDic,
      customerIcDph: original.customerIcDph,
      customerCountry: original.customerCountry,
      paymentMethod: original.paymentMethod,
      variableSymbol: creditNumber.replaceAll(RegExp(r'[^0-9]'), ''),
      totalWithoutVat: totals.$1,
      totalVat: totals.$2,
      totalWithVat: totals.$3,
      notes: 'Dobropis k faktúre ${original.invoiceNumber}',
      originalInvoiceId: original.id,
      originalInvoiceNumber: original.invoiceNumber,
      isVatPayer: original.isVatPayer,
    );
  }

  // ── Výpočet súm ───────────────────────────────────────────────────────────

  /// Vráti (totalWithoutVat, totalVat, totalWithVat)
  (double, double, double) calculateTotals(List<InvoiceItem> items) {
    double base = 0;
    double vat  = 0;
    for (final item in items) {
      base += item.lineBase;
      vat  += item.lineVat;
    }
    base = (base * 100).round() / 100;
    vat  = (vat  * 100).round() / 100;
    return (base, vat, (base + vat * 100).round() / 100);
  }
}
