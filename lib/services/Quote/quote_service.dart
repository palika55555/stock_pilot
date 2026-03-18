import '../../models/quote.dart';
import '../Database/database_service.dart';
import '../api_sync_service.dart' show syncQuotesToBackend;

class QuoteService {
  final DatabaseService _db = DatabaseService();

  Future<String> getNextQuoteNumber() async {
    return await _db.getNextQuoteNumber();
  }

  Future<int> createQuote(Quote quote) async {
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
    final n = await _db.updateQuote(quote);
    syncQuotesToBackend().ignore();
    return n;
  }

  Future<int> deleteQuote(int id) async {
    final n = await _db.deleteQuote(id);
    syncQuotesToBackend().ignore();
    return n;
  }

  Future<List<QuoteItem>> getQuoteItems(int quoteId) async {
    return await _db.getQuoteItems(quoteId);
  }

  Future<int> addQuoteItem(QuoteItem item) async {
    return await _db.insertQuoteItem(item);
  }

  Future<int> updateQuoteItem(QuoteItem item) async {
    return await _db.updateQuoteItem(item);
  }

  Future<int> removeQuoteItem(int itemId) async {
    return await _db.deleteQuoteItem(itemId);
  }

  Future<int> deleteQuoteItemsByQuoteId(int quoteId) async {
    return await _db.deleteQuoteItemsByQuoteId(quoteId);
  }
}
