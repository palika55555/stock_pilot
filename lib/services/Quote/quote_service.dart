import '../../models/quote.dart';
import '../database/database_service.dart';

class QuoteService {
  final DatabaseService _db = DatabaseService();

  Future<String> getNextQuoteNumber() async {
    return await _db.getNextQuoteNumber();
  }

  Future<int> createQuote(Quote quote) async {
    return await _db.insertQuote(quote);
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
    return await _db.updateQuote(quote);
  }

  Future<int> deleteQuote(int id) async {
    return await _db.deleteQuote(id);
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
