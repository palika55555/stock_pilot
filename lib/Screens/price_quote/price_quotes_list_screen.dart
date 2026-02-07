import 'package:flutter/material.dart';
import '../../models/quote.dart';
import '../../services/customer/customer_service.dart';
import '../../services/Quote/quote_service.dart';
import '../../l10n/app_localizations.dart';
import 'price_quote_screen.dart';

class PriceQuotesListScreen extends StatefulWidget {
  const PriceQuotesListScreen({super.key});

  @override
  State<PriceQuotesListScreen> createState() => _PriceQuotesListScreenState();
}

class _PriceQuotesListScreenState extends State<PriceQuotesListScreen> {
  final QuoteService _quoteService = QuoteService();
  final CustomerService _customerService = CustomerService();

  List<Quote> _quotes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadQuotes();
  }

  Future<void> _loadQuotes() async {
    setState(() => _loading = true);
    final list = await _quoteService.getAllQuotes();
    if (mounted) {
      setState(() {
        _quotes = list;
        _loading = false;
      });
    }
  }

  Future<void> _openQuote(Quote quote) async {
    final customer = await _customerService.getCustomerById(quote.customerId);
    if (!mounted) return;
    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.noResults),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PriceQuoteScreen(customer: customer, quoteId: quote.id),
      ),
    ).then((_) => _loadQuotes());
  }

  static String _formatDate(DateTime d) => '${d.day}.${d.month}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(l10n.priceQuote),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _quotes.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.request_quote, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noQuoteItems,
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vytvorte cenovú ponuku zo stránky Zákazníci.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadQuotes,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                itemCount: _quotes.length,
                itemBuilder: (context, index) {
                  final q = _quotes[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.request_quote,
                          color: Colors.teal,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        q.quoteNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        '${q.customerName ?? '—'} • ${_formatDate(q.createdAt)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.grey,
                      ),
                      onTap: () => _openQuote(q),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
