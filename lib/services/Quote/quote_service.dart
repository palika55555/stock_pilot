import '../../models/quote.dart';
import '../Database/database_service.dart';
import '../monthly_closure_service.dart';
import '../api_sync_service.dart' show syncQuotesToBackend;

class QuoteService {
  final DatabaseService _db = DatabaseService();
  final MonthlyClosureService _closures = MonthlyClosureService();

  Future<void> _assertQuoteOpen(int quoteId) async {
    final q = await _db.getQuoteById(quoteId);
    if (q != null) await _closures.assertDateOpen(q.createdAt);
  }

  Future<String> getNextQuoteNumber() async {
    return await _db.getNextQuoteNumber();
  }

  Future<int> createQuote(Quote quote) async {
    await _closures.assertDateOpen(quote.createdAt);
    final id = await _db.insertQuote(quote);
    syncQuotesToBackend().ignore();
    return id;
  }

  Future<Quote?> getQuoteById(int id) async {
    return await _db.getQuoteById(id);
  }

  Future<List<Quote>> getAllQuotes() async {
    return await _db.getQuotes();
  }

  Future<List<Quote>> getQuotesByCustomerId(int customerId) async {
    return await _db.getQuotesByCustomerId(customerId);
  }

  Future<int> updateQuote(Quote quote) async {
    if (quote.id != null) {
      final existing = await _db.getQuoteById(quote.id!);
      if (existing != null) await _closures.assertDateOpen(existing.createdAt);
    }
    await _closures.assertDateOpen(quote.createdAt);
    final n = await _db.updateQuote(quote);
    syncQuotesToBackend().ignore();
    return n;
  }

  Future<int> deleteQuote(int id) async {
    final existing = await _db.getQuoteById(id);
    if (existing != null) await _closures.assertDateOpen(existing.createdAt);
    final n = await _db.deleteQuote(id);
    syncQuotesToBackend().ignore();
    return n;
  }

  Future<List<QuoteItem>> getQuoteItems(int quoteId) async {
    return await _db.getQuoteItems(quoteId);
  }

  Future<int> addQuoteItem(QuoteItem item) async {
    await _assertQuoteOpen(item.quoteId);
    return await _db.insertQuoteItem(item);
  }

  Future<int> updateQuoteItem(QuoteItem item) async {
    await _assertQuoteOpen(item.quoteId);
    return await _db.updateQuoteItem(item);
  }

  Future<int> removeQuoteItem(int itemId) async {
    final row = await _db.getQuoteItemById(itemId);
    if (row != null) await _assertQuoteOpen(row.quoteId);
    return await _db.deleteQuoteItem(itemId);
  }

  Future<int> deleteQuoteItemsByQuoteId(int quoteId) async {
    await _assertQuoteOpen(quoteId);
    return await _db.deleteQuoteItemsByQuoteId(quoteId);
  }
}
